-- Followers relationship setup
create table if not exists public.followers (
    id uuid primary key default gen_random_uuid(),
    follower_id uuid not null references public.profiles (id) on delete cascade,
    followed_id uuid not null references public.profiles (id) on delete cascade,
    created_at timestamptz not null default timezone('utc', now()),
    constraint followers_unique_pair unique (follower_id, followed_id)
);

create index if not exists followers_follower_id_idx on public.followers (follower_id);
create index if not exists followers_followed_id_idx on public.followers (followed_id);

alter table public.followers enable row level security;

-- Followers policies
drop policy if exists followers_select on public.followers;
create policy followers_select
    on public.followers
    for select
    using (true);

drop policy if exists followers_insert on public.followers;
create policy followers_insert
    on public.followers
    for insert
    with check (auth.uid() = follower_id);

drop policy if exists followers_delete on public.followers;
create policy followers_delete
    on public.followers
    for delete
    using (auth.uid() = follower_id);

-- Favorites table constraints
alter table public.favorites
    add column if not exists created_at timestamptz not null default timezone('utc', now());

alter table public.favorites
    drop constraint if exists favorites_user_id_fkey;
alter table public.favorites
    add constraint favorites_user_id_fkey foreign key (user_id)
        references public.profiles (id) on delete cascade
        not valid;
alter table public.favorites validate constraint favorites_user_id_fkey;

alter table public.favorites
    drop constraint if exists favorites_book_id_fkey;
alter table public.favorites
    add constraint favorites_book_id_fkey foreign key (book_id)
        references public.books (id) on delete cascade
        not valid;
alter table public.favorites validate constraint favorites_book_id_fkey;

create unique index if not exists favorites_user_book_idx
    on public.favorites (user_id, book_id);

alter table public.favorites enable row level security;

-- Favorites policies
drop policy if exists favorites_select on public.favorites;
create policy favorites_select
    on public.favorites
    for select
    using (true);

drop policy if exists favorites_insert on public.favorites;
create policy favorites_insert
    on public.favorites
    for insert
    with check (auth.uid() = user_id);

drop policy if exists favorites_delete on public.favorites;
create policy favorites_delete
    on public.favorites
    for delete
    using (auth.uid() = user_id);

-- Policies para editar perfiles (asegura que cada usuario pueda cambiar su nombre)
alter table public.profiles enable row level security;

drop policy if exists profiles_update_current_user on public.profiles;
create policy profiles_update_current_user
    on public.profiles
    for update
    using (auth.uid() = id)
    with check (auth.uid() = id);

-- Permitir que los usuarios actualicen su nombre en comentarios existentes
alter table public.book_comments enable row level security;

drop policy if exists book_comments_select on public.book_comments;
create policy book_comments_select
    on public.book_comments
    for select
    using (true);

drop policy if exists book_comments_insert on public.book_comments;
create policy book_comments_insert
    on public.book_comments
    for insert
    with check (auth.uid() = user_id);

drop policy if exists book_comments_update_owner on public.book_comments;
create policy book_comments_update_owner
    on public.book_comments
    for update
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

alter table public.chapter_comments enable row level security;

drop policy if exists chapter_comments_select on public.chapter_comments;
create policy chapter_comments_select
    on public.chapter_comments
    for select
    using (true);

drop policy if exists chapter_comments_insert on public.chapter_comments;
create policy chapter_comments_insert
    on public.chapter_comments
    for insert
    with check (auth.uid() = user_id);

drop policy if exists chapter_comments_update_owner on public.chapter_comments;
create policy chapter_comments_update_owner
    on public.chapter_comments
    for update
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

-- Habilitar Realtime para las tablas followers y favorites solo si aún no están añadidas
do $$
begin
    if not exists (
        select 1
        from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = 'followers'
    ) then
        alter publication supabase_realtime add table public.followers;
    end if;

    if not exists (
        select 1
        from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = 'favorites'
    ) then
        alter publication supabase_realtime add table public.favorites;
    end if;
end $$;
