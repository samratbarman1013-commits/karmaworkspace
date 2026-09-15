-- ============================================================
-- KarmaWorkspace — Supabase database setup
-- Run this ONCE in: Supabase Dashboard > SQL Editor > New query > Run
-- ============================================================

-- ---------- 1. TABLES ----------

create table if not exists public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  handle      text unique not null,
  name        text not null,
  bio         text,
  avatar_url  text,
  banner_url  text,
  created_at  timestamptz not null default now()
);

create table if not exists public.posts (
  id          uuid primary key default gen_random_uuid(),
  owner       uuid not null references public.profiles (id) on delete cascade,
  type        text not null check (type in ('video', 'image', 'note')),
  title       text not null,
  description text,
  content     text,
  media_url   text,
  thumb_url   text,
  created_at  timestamptz not null default now()
);
create index if not exists posts_created_idx on public.posts (created_at desc);
create index if not exists posts_owner_idx  on public.posts (owner);

create table if not exists public.likes (
  post_id     uuid not null references public.posts (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table if not exists public.comments (
  id          uuid primary key default gen_random_uuid(),
  post_id     uuid not null references public.posts (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  text        text not null,
  created_at  timestamptz not null default now()
);
create index if not exists comments_post_idx on public.comments (post_id, created_at);

create table if not exists public.follows (
  channel_id  uuid not null references public.profiles (id) on delete cascade,
  follower_id uuid not null references public.profiles (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (channel_id, follower_id)
);

-- ---------- 2. ROW LEVEL SECURITY ----------
-- Everyone can READ everything; you can only WRITE your own data.

alter table public.profiles enable row level security;
alter table public.posts    enable row level security;
alter table public.likes    enable row level security;
alter table public.comments enable row level security;
alter table public.follows  enable row level security;

-- profiles
drop policy if exists profiles_read   on public.profiles;
drop policy if exists profiles_insert on public.profiles;
drop policy if exists profiles_update on public.profiles;
create policy profiles_read   on public.profiles for select using (true);
create policy profiles_insert on public.profiles for insert with check (auth.uid() = id);
create policy profiles_update on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);

-- posts
drop policy if exists posts_read   on public.posts;
drop policy if exists posts_write  on public.posts;
drop policy if exists posts_delete on public.posts;
create policy posts_read    on public.posts for select using (true);
create policy posts_write   on public.posts for insert with check (auth.uid() = owner);
create policy posts_update  on public.posts for update using (auth.uid() = owner);
create policy posts_delete  on public.posts for delete using (auth.uid() = owner);

-- likes
drop policy if exists likes_read   on public.likes;
drop policy if exists likes_insert on public.likes;
drop policy if exists likes_delete on public.likes;
create policy likes_read   on public.likes for select using (true);
create policy likes_insert on public.likes for insert with check (auth.uid() = user_id);
create policy likes_delete on public.likes for delete using (auth.uid() = user_id);

-- comments
drop policy if exists comments_read   on public.comments;
drop policy if exists comments_insert on public.comments;
drop policy if exists comments_delete on public.comments;
create policy comments_read   on public.comments for select using (true);
create policy comments_insert on public.comments for insert with check (auth.uid() = user_id);
create policy comments_delete on public.comments for delete using (auth.uid() = user_id);

-- follows
drop policy if exists follows_read   on public.follows;
drop policy if exists follows_insert on public.follows;
drop policy if exists follows_delete on public.follows;
create policy follows_read   on public.follows for select using (true);
create policy follows_insert on public.follows for insert with check (auth.uid() = follower_id);
create policy follows_delete on public.follows for delete using (auth.uid() = follower_id);

-- ---------- 3. AUTO-CREATE A CHANNEL FOR EVERY NEW USER ----------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
as $$
begin
  insert into public.profiles (id, handle, name)
  values (
    new.id,
    'user_' || substr(replace(new.id::text, '-', ''), 1, 8),
    coalesce(nullif(new.raw_user_meta_data ->> 'name', ''), split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- 4. MEDIA STORAGE (videos, images, avatars, banners) ----------

insert into storage.buckets (id, name, public)
values ('media', 'media', true)
on conflict (id) do nothing;

drop policy if exists media_public_read  on storage.objects;
drop policy if exists media_auth_insert  on storage.objects;
drop policy if exists media_delete_own   on storage.objects;

create policy media_public_read on storage.objects
  for select using (bucket_id = 'media');

create policy media_auth_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text);

create policy media_delete_own on storage.objects
  for delete to authenticated
  using (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text);
