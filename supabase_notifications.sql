-- =====================================================
-- NOTIFICACIONES PARA WAI
-- =====================================================
-- Ejecuta este script en el SQL editor de Supabase.
-- Crea la tabla de notificaciones, dispositivos y triggers
-- que generan los eventos automaticamente.
-- =====================================================

-- Tabla principal de notificaciones
create table if not exists public.notifications (
    id uuid primary key default gen_random_uuid(),
    profile_id uuid not null references public.profiles (id) on delete cascade,
    type text not null check (type in (
        'book_like',
        'new_follower',
        'book_comment',
        'chapter_comment',
        'chat_message',
        'new_chapter'
    )),
    title text,
    body text not null,
    data jsonb,
    created_at timestamptz not null default timezone('utc', now()),
    read_at timestamptz,
    updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists notifications_profile_id_created_at_idx
    on public.notifications (profile_id, created_at desc);

create index if not exists notifications_profile_unread_idx
    on public.notifications (profile_id) where read_at is null;

-- Helper para mantener updated_at sincronizado
create or replace function public.set_updated_at()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    new.updated_at = timezone('utc', now());
    return new;
end;
$$;

create trigger notifications_set_updated_at
    before update on public.notifications
    for each row
    execute function public.set_updated_at();

-- Tabla para tokens de dispositivos push
create table if not exists public.notification_devices (
    profile_id uuid not null references public.profiles (id) on delete cascade,
    token text not null,
    platform text,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    primary key (profile_id, token)
);

create trigger notification_devices_set_updated_at
    before update on public.notification_devices
    for each row
    execute function public.set_updated_at();

-- Habilitar RLS
alter table public.notifications enable row level security;
alter table public.notification_devices enable row level security;

-- Policies para notifications
drop policy if exists notifications_select on public.notifications;
create policy notifications_select
    on public.notifications
    for select
    using (profile_id = auth.uid());

drop policy if exists notifications_update on public.notifications;
create policy notifications_update
    on public.notifications
    for update
    using (profile_id = auth.uid())
    with check (profile_id = auth.uid());

-- Sólo funciones del backend insertan registros.
-- Los usuarios no necesitan permisos de inserción directamente.

drop policy if exists notification_devices_manage on public.notification_devices;
create policy notification_devices_manage
    on public.notification_devices
    for all
    using (profile_id = auth.uid())
    with check (profile_id = auth.uid());

-- =====================================================
-- FUNCIONES AUXILIARES PARA INSERTAR NOTIFICACIONES
-- =====================================================

create or replace function public.create_notification(
    p_profile_id uuid,
    p_type text,
    p_title text,
    p_body text,
    p_data jsonb
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.notifications (profile_id, type, title, body, data)
    values (p_profile_id, p_type, p_title, p_body, p_data);
end;
$$;

create or replace function public.notification_actor_name(p_profile_id uuid)
returns text
language sql
security definer
set search_path = public
as $$
    select coalesce((
        select username from public.profiles where id = p_profile_id
    ), 'Alguien');
$$;

-- Marcar notificaciones como leídas
create or replace function public.notifications_mark_all_read()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    update public.notifications
       set read_at = timezone('utc', now())
     where profile_id = auth.uid()
       and read_at is null;
end;
$$;

create or replace function public.notifications_mark_category_read(p_type text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    update public.notifications
       set read_at = timezone('utc', now())
     where profile_id = auth.uid()
       and read_at is null
       and type = p_type;
end;
$$;

create or replace function public.notifications_mark_one_read(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    update public.notifications
       set read_at = timezone('utc', now())
     where profile_id = auth.uid()
       and read_at is null
       and id = p_id;
end;
$$;

-- =====================================================
-- TRIGGERS PARA GENERAR NOTIFICACIONES AUTOMATICAMENTE
-- =====================================================

-- Likes en libros
drop function if exists public.handle_book_reaction_notification() cascade;
create function public.handle_book_reaction_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    book_rec record;
    actor_name text;
begin
    if NEW.reaction <> 'like' then
        return NEW;
    end if;

    if TG_OP = 'UPDATE' and (OLD.reaction = NEW.reaction or OLD.reaction = 'like') then
        return NEW;
    end if;

    select id, author_id, title
      into book_rec
      from public.books
     where id = NEW.book_id;

    if book_rec.author_id is null or book_rec.author_id = NEW.user_id then
        return NEW;
    end if;

    actor_name := public.notification_actor_name(NEW.user_id);

    perform public.create_notification(
        book_rec.author_id,
        'book_like',
        'Nuevo me gusta',
        actor_name || ' marco \"' || coalesce(book_rec.title, 'tu libro') || '\" como favorito.',
        jsonb_build_object(
            'book_id', NEW.book_id,
            'actor_id', NEW.user_id
        )
    );

    return NEW;
end;
$$;

drop trigger if exists book_reaction_notification on public.book_reactions;
create trigger book_reaction_notification
    after insert or update on public.book_reactions
    for each row
    execute function public.handle_book_reaction_notification();

-- Nuevos seguidores
drop function if exists public.handle_follow_notification() cascade;
create function public.handle_follow_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    follower_name text;
begin
    if NEW.followed_id = NEW.follower_id then
        return NEW;
    end if;

    follower_name := public.notification_actor_name(NEW.follower_id);

    perform public.create_notification(
        NEW.followed_id,
        'new_follower',
        'Nuevo seguidor',
        follower_name || ' empezo a seguirte.',
        jsonb_build_object(
            'actor_id', NEW.follower_id
        )
    );

    return NEW;
end;
$$;

drop trigger if exists follower_notification on public.followers;
create trigger follower_notification
    after insert on public.followers
    for each row
    execute function public.handle_follow_notification();

-- Comentarios en libros
drop function if exists public.handle_book_comment_notification() cascade;
create function public.handle_book_comment_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    book_rec record;
    actor_name text;
    preview text;
begin
    select b.id, b.author_id, b.title
      into book_rec
      from public.books b
     where b.id = NEW.book_id;

    if book_rec.author_id is null or book_rec.author_id = NEW.user_id then
        return NEW;
    end if;

    actor_name := public.notification_actor_name(NEW.user_id);
    preview := coalesce(left(NEW.content, 120), 'Nuevo comentario');

    perform public.create_notification(
        book_rec.author_id,
        'book_comment',
        'Nuevo comentario',
        actor_name || ' comento tu libro \"' || coalesce(book_rec.title, '') || '\".',
        jsonb_build_object(
            'book_id', NEW.book_id,
            'comment_id', NEW.id,
            'actor_id', NEW.user_id,
            'preview', preview
        )
    );

    return NEW;
end;
$$;

drop trigger if exists book_comment_notification on public.book_comments;
create trigger book_comment_notification
    after insert on public.book_comments
    for each row
    execute function public.handle_book_comment_notification();

-- Comentarios en capitulos
drop function if exists public.handle_chapter_comment_notification() cascade;
create function public.handle_chapter_comment_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    chapter_rec record;
    actor_name text;
    preview text;
begin
    select c.book_id, c.title as chapter_title, b.author_id, b.title as book_title
      into chapter_rec
      from public.book_chapters c
      join public.books b on b.id = c.book_id
     where c.id = NEW.chapter_id;

    if chapter_rec.author_id is null or chapter_rec.author_id = NEW.user_id then
        return NEW;
    end if;

    actor_name := public.notification_actor_name(NEW.user_id);
    preview := coalesce(left(NEW.content, 120), 'Nuevo comentario');

    perform public.create_notification(
        chapter_rec.author_id,
        'chapter_comment',
        'Nuevo comentario en capitulo',
        actor_name || ' comento el capitulo \"' || coalesce(chapter_rec.chapter_title, '') || '\" de \"' || coalesce(chapter_rec.book_title, '') || '\".',
        jsonb_build_object(
            'book_id', chapter_rec.book_id,
            'chapter_id', NEW.chapter_id,
            'comment_id', NEW.id,
            'actor_id', NEW.user_id,
            'preview', preview
        )
    );

    return NEW;
end;
$$;

drop trigger if exists chapter_comment_notification on public.chapter_comments;
create trigger chapter_comment_notification
    after insert on public.chapter_comments
    for each row
    execute function public.handle_chapter_comment_notification();

-- Mensajes directos
drop function if exists public.handle_direct_message_notification() cascade;
create function public.handle_direct_message_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    participant record;
    actor_name text;
    preview text;
begin
    actor_name := public.notification_actor_name(NEW.sender_id);
    preview := coalesce(left(coalesce(NEW.body, 'Mensaje sin texto'), 120), 'Nuevo mensaje');

    for participant in
        select profile_id
          from public.direct_thread_participants
         where thread_id = NEW.thread_id
           and profile_id <> NEW.sender_id
    loop
        perform public.create_notification(
            participant.profile_id,
            'chat_message',
            'Nuevo mensaje',
            actor_name || ' te envio un mensaje.',
            jsonb_build_object(
                'thread_id', NEW.thread_id,
                'message_id', NEW.id,
                'actor_id', NEW.sender_id,
                'preview', preview
            )
        );
    end loop;

    return NEW;
end;
$$;

drop trigger if exists direct_message_notification on public.direct_messages;
create trigger direct_message_notification
    after insert on public.direct_messages
    for each row
    execute function public.handle_direct_message_notification();

-- Nuevos capitulos publicados
drop function if exists public.handle_chapter_publication_notification() cascade;
create function public.handle_chapter_publication_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    chapter_rec record;
    fav record;
begin
    if NEW.is_published is distinct from true then
        return NEW;
    end if;

    if TG_OP = 'UPDATE' and coalesce(OLD.is_published, false) = true then
        return NEW;
    end if;

    select c.book_id, c.title as chapter_title, c.chapter_order, b.author_id, b.title as book_title
      into chapter_rec
      from public.book_chapters c
      join public.books b on b.id = c.book_id
     where c.id = NEW.id;

    if chapter_rec.book_id is null then
        return NEW;
    end if;

    for fav in
        select user_id
          from public.favorites
         where book_id = chapter_rec.book_id
    loop
        if fav.user_id = chapter_rec.author_id then
            continue;
        end if;

        perform public.create_notification(
            fav.user_id,
            'new_chapter',
            'Nuevo capitulo disponible',
            'Se publico el capitulo ' || chapter_rec.chapter_order || ' de \"' || coalesce(chapter_rec.book_title, '') || '\".',
            jsonb_build_object(
                'book_id', chapter_rec.book_id,
                'chapter_id', NEW.id
            )
        );
    end loop;

    return NEW;
end;
$$;

drop trigger if exists chapter_publication_notification on public.book_chapters;
create trigger chapter_publication_notification
    after insert or update on public.book_chapters
    for each row
    when (NEW.is_published is true)
    execute function public.handle_chapter_publication_notification();

-- =====================================================
-- PUBLICACION EN REALTIME Y RELOAD DEL ESQUEMA
-- =====================================================

do $$
begin
    if not exists (
        select 1 from pg_publication_tables
         where pubname = 'supabase_realtime'
           and schemaname = 'public'
           and tablename = 'notifications'
    ) then
        alter publication supabase_realtime add table public.notifications;
    end if;

    if not exists (
        select 1 from pg_publication_tables
         where pubname = 'supabase_realtime'
           and schemaname = 'public'
           and tablename = 'notification_devices'
    ) then
        alter publication supabase_realtime add table public.notification_devices;
    end if;
end;
$$;

notify pgrst, 'reload schema';
