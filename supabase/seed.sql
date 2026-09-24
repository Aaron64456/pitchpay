-- Demo data for PitchPay.
-- Fictional players and fake bank details only — this file is public.
-- Safe to run more than once: it clears the tables first.

truncate audit_log, handovers, credits, spots, games, organisers, players
  restart identity cascade;

-- Players -------------------------------------------------------------------
insert into players (display_name) values
  ('Sam Okafor'),
  ('Ravi Patel'),
  ('Tom Bright'),
  ('Jay Mensah'),
  ('Ollie Grant'),
  ('Ade Salami'),
  ('Marco Rossi'),
  ('Dan Whitby'),
  ('Krish Shah'),
  ('Leon Carter'),
  ('Freddie Hall'),
  ('Hassan Ali'),
  ('Nico Alvarez'),
  ('Ben Doyle'),
  ('Ethan Reid'),
  ('Joe Kim');

-- Organisers ----------------------------------------------------------------
-- pin_hash stays null until Phase 7 adds PIN login.
insert into organisers (player_id)
select id from players where display_name in ('Sam Okafor', 'Tom Bright');

-- Games ---------------------------------------------------------------------
-- One game last week (played, with an unpaid spot) and one open game this week.
insert into games (
  slug, date, kickoff_time, venue, price_pence, cap, minimum,
  payee_organiser_id, monzo_link, bank_name, bank_account, bank_sort_code,
  status, created_by
)
select
  'demo-last-week',
  -- last Wednesday: the coming Wednesday (today if it is one) minus a week
  (current_date + ((3 - extract(dow from current_date)::int + 7) % 7) - 7)::date,
  '19:00',
  'Goals Sports Centre, Pitch 3',
  720, 14, 14,
  o.id,
  'https://monzo.me/example/7.20',
  'S OKAFOR', '12345678', '00-00-00',
  'played',
  o.id
from organisers o
join players p on p.id = o.player_id
where p.display_name = 'Sam Okafor';

insert into games (
  slug, date, kickoff_time, venue, price_pence, cap, minimum,
  payee_organiser_id, monzo_link, bank_name, bank_account, bank_sort_code,
  status, created_by
)
select
  'demo-this-week',
  -- the coming Wednesday (today if today is a Wednesday).
  -- dow: 0 = Sunday ... 3 = Wednesday; "+ 7) % 7" keeps the gap positive.
  (current_date + ((3 - extract(dow from current_date)::int + 7) % 7))::date,
  '19:00',
  'Goals Sports Centre, Pitch 3',
  720, 14, 14,
  o.id,
  'https://monzo.me/example/7.20',
  'S OKAFOR', '12345678', '00-00-00',
  'open',
  o.id
from organisers o
join players p on p.id = o.player_id
where p.display_name = 'Sam Okafor';

-- Last week's spots: everyone played, one person never paid ------------------
insert into spots (game_id, player_id, list, position, payment_status, received_by_organiser_id)
select
  g.id,
  p.id,
  'playing',
  row_number() over (order by p.display_name),
  case when p.display_name = 'Ben Doyle' then 'not_paid'::payment_status
       else 'confirmed_bank'::payment_status end,
  case when p.display_name = 'Ben Doyle' then null else o.id end
from games g
cross join players p
join organisers o on o.id = g.payee_organiser_id
where g.slug = 'demo-last-week'
  and p.display_name in (
    'Sam Okafor','Ravi Patel','Tom Bright','Jay Mensah','Ollie Grant','Ade Salami',
    'Marco Rossi','Dan Whitby','Krish Shah','Leon Carter','Freddie Hall','Hassan Ali',
    'Nico Alvarez','Ben Doyle'
  );

-- This week: 12 playing with a mix of statuses, 2 on the reserve list --------
insert into spots (game_id, player_id, list, position, payment_status, received_by_organiser_id)
select
  g.id,
  p.id,
  'playing',
  x.position,
  x.status::payment_status,
  case when x.status in ('confirmed_bank', 'cash_received') then g.payee_organiser_id end
from games g
join (values
  ('Sam Okafor',   1, 'confirmed_bank'),
  ('Ravi Patel',   2, 'confirmed_bank'),
  ('Tom Bright',   3, 'confirmed_bank'),
  ('Jay Mensah',   4, 'says_paid'),
  ('Ollie Grant',  5, 'says_paid'),
  ('Ade Salami',   6, 'cash_promised'),
  ('Marco Rossi',  7, 'cash_received'),
  ('Dan Whitby',   8, 'not_paid'),
  ('Krish Shah',   9, 'not_paid'),
  ('Leon Carter', 10, 'not_paid'),
  ('Freddie Hall',11, 'let_off'),
  ('Hassan Ali',  12, 'not_paid')
) as x(name, position, status) on true
join players p on p.display_name = x.name
where g.slug = 'demo-this-week';

insert into spots (game_id, player_id, list, position, payment_status)
select g.id, p.id, 'reserve', x.position, 'not_paid'
from games g
join (values ('Ethan Reid', 1), ('Joe Kim', 2)) as x(name, position) on true
join players p on p.display_name = x.name
where g.slug = 'demo-this-week';

-- A reminder was sent yesterday to the unpaid players -----------------------
update spots
set last_reminded_at = now() - interval '1 day'
where payment_status in ('not_paid', 'says_paid', 'cash_promised')
  and game_id = (select id from games where slug = 'demo-this-week');
