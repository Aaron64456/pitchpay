-- PitchPay initial schema
-- Money is always stored as integer pence (see docs/requirements.md).

-- ---------------------------------------------------------------------------
-- Enums: a column can only ever hold one of these values. Postgres rejects
-- anything else, so a typo like 'confirmd_bank' fails at the database, not
-- silently three weeks later.
-- ---------------------------------------------------------------------------
create type game_status as enum ('open', 'locked', 'played', 'cancelled');

create type spot_list as enum ('playing', 'reserve', 'left');

create type payment_status as enum (
  'not_paid',
  'says_paid',
  'cash_promised',
  'confirmed_bank',
  'cash_received',
  'paid_by_credit',
  'let_off',
  'refunded',
  'credited'
);

-- ---------------------------------------------------------------------------
-- players
-- ---------------------------------------------------------------------------
create table players (
  id uuid primary key default gen_random_uuid(),
  display_name text not null check (length(trim(display_name)) between 1 and 40),
  created_at timestamptz not null default now()
);

-- Names are unique ignoring case: "Sam" and "sam" are the same player.
create unique index players_display_name_lower_key
  on players (lower(display_name));

-- ---------------------------------------------------------------------------
-- organisers
-- ---------------------------------------------------------------------------
create table organisers (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null unique references players (id) on delete restrict,
  pin_hash text,                       -- bcrypt hash, set in Phase 7
  active boolean not null default true,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- games
-- ---------------------------------------------------------------------------
create table games (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9-]{6,40}$'),
  date date not null,
  kickoff_time time not null,
  venue text,
  price_pence integer not null default 720 check (price_pence >= 0),
  cap integer not null default 14 check (cap > 0),
  minimum integer not null default 14 check (minimum > 0),
  payee_organiser_id uuid references organisers (id) on delete restrict,
  monzo_link text,
  bank_name text,
  bank_account text,
  bank_sort_code text,
  status game_status not null default 'open',
  locked_at timestamptz,
  cancelled_at timestamptz,
  created_by uuid references organisers (id) on delete set null,
  created_at timestamptz not null default now(),
  constraint games_minimum_not_above_cap check (minimum <= cap)
);

create index games_date_idx on games (date desc);

-- ---------------------------------------------------------------------------
-- spots: one row per player per game. This is the heart of the app.
-- ---------------------------------------------------------------------------
create table spots (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references games (id) on delete cascade,
  player_id uuid not null references players (id) on delete restrict,
  list spot_list not null default 'playing',
  position integer not null,
  payment_status payment_status not null default 'not_paid',
  received_by_organiser_id uuid references organisers (id) on delete set null,
  last_reminded_at timestamptz,
  left_after_lock boolean not null default false,
  joined_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- A player can only hold one spot in a given game.
  constraint spots_one_per_player_per_game unique (game_id, player_id)
);

create index spots_game_list_position_idx on spots (game_id, list, position);

-- ---------------------------------------------------------------------------
-- credits: a ledger. Positive rows add credit, negative rows spend it.
-- A balance is the sum of the rows, never a stored number that can drift.
-- ---------------------------------------------------------------------------
create table credits (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references players (id) on delete restrict,
  organiser_id uuid not null references organisers (id) on delete restrict,
  amount_pence integer not null check (amount_pence <> 0),
  game_id uuid references games (id) on delete set null,
  spot_id uuid references spots (id) on delete set null,
  note text,
  created_at timestamptz not null default now()
);

create index credits_player_idx on credits (player_id);

-- ---------------------------------------------------------------------------
-- handovers: organiser A passes collected money to organiser B.
-- ---------------------------------------------------------------------------
create table handovers (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references games (id) on delete cascade,
  from_organiser_id uuid not null references organisers (id) on delete restrict,
  to_organiser_id uuid not null references organisers (id) on delete restrict,
  amount_pence integer not null check (amount_pence >= 0),
  payment_count integer not null default 0 check (payment_count >= 0),
  received boolean not null default false,
  created_at timestamptz not null default now(),
  constraint handovers_different_organisers
    check (from_organiser_id <> to_organiser_id)
);

-- ---------------------------------------------------------------------------
-- audit_log: who did what. Append-only; never updated.
-- ---------------------------------------------------------------------------
create table audit_log (
  id bigserial primary key,
  actor text not null,
  action text not null,
  entity text not null,
  entity_id uuid,
  details jsonb,
  created_at timestamptz not null default now()
);

create index audit_log_entity_idx on audit_log (entity, entity_id);

-- ---------------------------------------------------------------------------
-- Keep spots.updated_at honest without the application having to remember.
-- ---------------------------------------------------------------------------
create function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger spots_set_updated_at
  before update on spots
  for each row
  execute function set_updated_at();
