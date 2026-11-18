-- Community features for AnimeW Menu: public polls and private direct messages.
create table if not exists public.community_polls (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references auth.users(id) on delete cascade,
  question text not null check (char_length(question) between 4 and 180),
  description text not null default '',
  created_at timestamptz not null default now(),
  expires_at timestamptz
);

create table if not exists public.community_poll_options (
  id uuid primary key default gen_random_uuid(),
  poll_id uuid not null references public.community_polls(id) on delete cascade,
  label text not null check (char_length(label) between 1 and 90),
  position integer not null default 0
);

create table if not exists public.community_poll_votes (
  poll_id uuid not null references public.community_polls(id) on delete cascade,
  option_id uuid not null references public.community_poll_options(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (poll_id, user_id)
);

create index if not exists community_polls_created_idx on public.community_polls(created_at desc);
create index if not exists community_poll_options_poll_idx on public.community_poll_options(poll_id, position);
create index if not exists community_poll_votes_poll_idx on public.community_poll_votes(poll_id);

alter table public.community_polls enable row level security;
alter table public.community_poll_options enable row level security;
alter table public.community_poll_votes enable row level security;

create policy community_polls_read on public.community_polls
  for select to authenticated using (true);
create policy community_polls_create on public.community_polls
  for insert to authenticated with check (creator_id = auth.uid());
create policy community_polls_edit_own on public.community_polls
  for update to authenticated using (creator_id = auth.uid()) with check (creator_id = auth.uid());
create policy community_polls_delete_own on public.community_polls
  for delete to authenticated using (creator_id = auth.uid());

create policy community_poll_options_read on public.community_poll_options
  for select to authenticated using (exists (
    select 1 from public.community_polls p where p.id = poll_id
  ));
create policy community_poll_options_create on public.community_poll_options
  for insert to authenticated with check (exists (
    select 1 from public.community_polls p where p.id = poll_id and p.creator_id = auth.uid()
  ));
create policy community_poll_options_delete on public.community_poll_options
  for delete to authenticated using (exists (
    select 1 from public.community_polls p where p.id = poll_id and p.creator_id = auth.uid()
  ));

create policy community_poll_votes_read on public.community_poll_votes
  for select to authenticated using (true);
create policy community_poll_votes_create on public.community_poll_votes
  for insert to authenticated with check (
    user_id = auth.uid() and exists (
      select 1 from public.community_poll_options o where o.id = option_id and o.poll_id = poll_id
    )
  );
create policy community_poll_votes_change_own on public.community_poll_votes
  for update to authenticated using (user_id = auth.uid()) with check (
    user_id = auth.uid() and exists (
      select 1 from public.community_poll_options o where o.id = option_id and o.poll_id = poll_id
    )
  );
create policy community_poll_votes_delete_own on public.community_poll_votes
  for delete to authenticated using (user_id = auth.uid());
