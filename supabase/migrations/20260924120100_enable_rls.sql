-- Row Level Security (RLS)
--
-- Supabase exposes the database directly to browsers through its API, using a
-- publishable "anon" key that anyone can read out of the page source. RLS is
-- what stops that key being a way in: with RLS enabled and no policy granting
-- access, every request made with the anon key is refused.
--
-- PitchPay does all of its reads and writes in server-side code using the
-- service role key, which bypasses RLS and is never sent to the browser. So the
-- correct state for every table here is: RLS on, no policies.
--
-- (Phase 6 adds Supabase Realtime. Realtime subscriptions use the anon key and
-- obey RLS, so if we want live updates we will either add narrow read policies
-- then, or fall back to polling. That decision is deliberately not made here.)

alter table players    enable row level security;
alter table organisers enable row level security;
alter table games      enable row level security;
alter table spots      enable row level security;
alter table credits    enable row level security;
alter table handovers  enable row level security;
alter table audit_log  enable row level security;

-- Belt and braces: revoke the default grants Supabase gives the browser-facing
-- roles, so a future table created without RLS is not silently exposed.
revoke all on all tables in schema public from anon, authenticated;
