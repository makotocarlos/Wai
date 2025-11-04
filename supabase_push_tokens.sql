create table if not exists public.user_push_tokens (
    user_id uuid not null references public.profiles(id) on delete cascade,
    token text not null,
    platform text not null default 'other',
    updated_at timestamp with time zone not null default timezone('utc', now()),
    primary key (user_id, token)
);

alter table public.user_push_tokens enable row level security;

create unique index if not exists user_push_tokens_token_key
    on public.user_push_tokens (token);

create or replace function public.handle_user_push_tokens_updated_at()
returns trigger
language plpgsql as
$$
begin
    new.updated_at = timezone('utc', now());
    return new;
end;
$$;

drop trigger if exists user_push_tokens_set_updated_at
    on public.user_push_tokens;

create trigger user_push_tokens_set_updated_at
    before insert or update on public.user_push_tokens
    for each row
    execute procedure public.handle_user_push_tokens_updated_at();

create policy "Users manage their push tokens"
    on public.user_push_tokens
    for all
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

notify pgrst, 'reload schema';
