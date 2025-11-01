-- Direct messaging schema for Wai

-- Threads table stores conversation metadata.
create table if not exists public.direct_threads (
    id uuid primary key default gen_random_uuid(),
    created_at timestamptz not null default timezone('utc', now()),
    created_by uuid not null references public.profiles (id) on delete cascade,
    last_message_preview text,
    last_message_at timestamptz,
    last_message_sender uuid references public.profiles (id),
    updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists direct_threads_last_message_at_idx
    on public.direct_threads (last_message_at desc nulls last);

-- Participants table keeps track of who belongs to each thread.
create table if not exists public.direct_thread_participants (
    thread_id uuid not null references public.direct_threads (id) on delete cascade,
    profile_id uuid not null references public.profiles (id) on delete cascade,
    added_by uuid not null references public.profiles (id) on delete cascade,
    joined_at timestamptz not null default timezone('utc', now()),
    last_read_at timestamptz,
    primary key (thread_id, profile_id)
);

create index if not exists direct_thread_participants_profile_idx
    on public.direct_thread_participants (profile_id);

-- Helper function to check membership without triggering RLS recursion.
create or replace function public.is_member_of_direct_thread(thread uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.direct_thread_participants
        where thread_id = thread
          and profile_id = auth.uid()
    );
$$;

-- Messages table stores each chat message.
create table if not exists public.direct_messages (
    id uuid primary key default gen_random_uuid(),
    thread_id uuid not null references public.direct_threads (id) on delete cascade,
    sender_id uuid not null references public.profiles (id) on delete cascade,
    body text,
    reply_to uuid references public.direct_messages (id) on delete set null,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    deleted_at timestamptz
);

create index if not exists direct_messages_thread_idx
    on public.direct_messages (thread_id, created_at);

create index if not exists direct_messages_sender_idx
    on public.direct_messages (sender_id);

-- Enable row level security.
alter table public.direct_threads enable row level security;
alter table public.direct_thread_participants enable row level security;
alter table public.direct_messages enable row level security;

-- Policies for direct_threads.
drop policy if exists direct_threads_select on public.direct_threads;
create policy direct_threads_select
    on public.direct_threads
    for select
    using (
        auth.uid() = created_by
        or exists (
            select 1 from public.direct_thread_participants
            where direct_thread_participants.thread_id = id
              and direct_thread_participants.profile_id = auth.uid()
        )
    );

drop policy if exists direct_threads_insert on public.direct_threads;
create policy direct_threads_insert
    on public.direct_threads
    for insert
    with check (auth.uid() = created_by);

-- Allow thread updates for participants (used to keep metadata fresh).
drop policy if exists direct_threads_update on public.direct_threads;
create policy direct_threads_update
    on public.direct_threads
    for update
    using (
        exists (
            select 1 from public.direct_thread_participants
            where direct_thread_participants.thread_id = id
              and direct_thread_participants.profile_id = auth.uid()
        )
    )
    with check (
        exists (
            select 1 from public.direct_thread_participants
            where direct_thread_participants.thread_id = id
              and direct_thread_participants.profile_id = auth.uid()
        )
    );

-- Policies for participants.
drop policy if exists direct_thread_participants_select on public.direct_thread_participants;
create policy direct_thread_participants_select
    on public.direct_thread_participants
    for select
    using (
        profile_id = auth.uid()
        or public.is_member_of_direct_thread(thread_id)
    );

-- Allow inserts when the authenticated user is the participant being added.
drop policy if exists direct_thread_participants_insert on public.direct_thread_participants;
create policy direct_thread_participants_insert
    on public.direct_thread_participants
    for insert
    with check (
        added_by = auth.uid()
        and (
            profile_id = auth.uid()
            or exists (
                select 1 from public.direct_thread_participants as existing
                where existing.thread_id = thread_id
                  and existing.profile_id = auth.uid()
            )
        )
    );

-- Policies for messages.
drop policy if exists direct_messages_select on public.direct_messages;
create policy direct_messages_select
    on public.direct_messages
    for select
    using (
        exists (
            select 1 from public.direct_thread_participants
            where direct_thread_participants.thread_id = thread_id
              and direct_thread_participants.profile_id = auth.uid()
        )
    );

-- Allow sending messages for participants.
drop policy if exists direct_messages_insert on public.direct_messages;
create policy direct_messages_insert
    on public.direct_messages
    for insert
    with check (
        auth.uid() = sender_id and
        exists (
            select 1 from public.direct_thread_participants
            where direct_thread_participants.thread_id = thread_id
              and direct_thread_participants.profile_id = auth.uid()
        )
    );

-- Allow soft deletion of own messages.
drop policy if exists direct_messages_update on public.direct_messages;
create policy direct_messages_update
    on public.direct_messages
    for update
    using (auth.uid() = sender_id)
    with check (auth.uid() = sender_id);

-- Add messaging tables to realtime publication.
do $$
begin
    if not exists (
        select 1 from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = 'direct_threads'
    ) then
        alter publication supabase_realtime add table public.direct_threads;
    end if;

    if not exists (
        select 1 from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = 'direct_thread_participants'
    ) then
        alter publication supabase_realtime add table public.direct_thread_participants;
    end if;

    if not exists (
        select 1 from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = 'direct_messages'
    ) then
        alter publication supabase_realtime add table public.direct_messages;
    end if;
end $$;
