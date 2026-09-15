# KarmaWorkspace

KarmaWorkspace is a YouTube-style creator platform where everyone can have their own channel and share **videos**, **notes** and **image posts**. Visitors can like, comment on and share any post.

## Live site

https://samratbarman1013-commits.github.io/karmaworkspace/

## How it works

- **Frontend** — a single-file app (`index.html`) served by GitHub Pages.
- **Backend** — [Supabase](https://supabase.com) provides authentication, the database (channels, posts, likes, comments, follows) and file storage for uploaded media.
- **Deploying updates** — site files are attached to GitHub Releases; the `sync-site` workflow copies them to the `main` branch, and GitHub Pages republishes automatically.

## Setup (one time)

1. Create a free project at [supabase.com](https://supabase.com).
2. Open **SQL Editor** and run `supabase-setup.sql` (included in this repo).
3. In **Authentication → Providers → Email**, you may turn off "Confirm email" so sign-ups are instant.
4. Paste your project URL and anon key into the `SUPABASE_URL` / `SUPABASE_ANON_KEY` constants at the top of `index.html`.

The anon key is designed to be public — database security is enforced by Row Level Security policies created by the setup SQL.
