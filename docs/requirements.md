# PitchPay — Requirements

The source of truth for what PitchPay does and the rules it follows. When a rule changes, update this file in the same pull request as the code and add a line to the Changelog.

_Last updated: 17 Sep 2026_

## 1. The problem

Every Wednesday a group plays 7-a-side football. One person (usually the main organiser, sometimes someone else) books the pitch and collects £7.20 per player via a Monzo.me link or bank transfer. Today this runs on a copy-pasted WhatsApp message with emojis (💰 payee, 💵 pinged, 🪙 cash on the day, ✅ confirmed). The organiser has to manually chase and can't easily see who hasn't paid, and cash promises are forgotten.

## 2. The solution (one sentence)

A mobile-first website: the organiser creates a game and shares one link in WhatsApp; players add themselves, pay through the organiser's Monzo link and mark themselves as paid; the organiser confirms, chases unpaid players with a generated message, and sees balances carried across weeks.

## 3. Hard constraints

- No native app. Website only, works on phone browsers.
- No payment processing. Money moves via the organiser's Monzo.me link or bank transfer. The site cannot detect payments; it relies on player self-report + organiser confirmation.
- No player logins. Players tap/enter their name. Only organisers authenticate (PIN).
- Free hosting tier only.
- Public GitHub repo: no real bank details, names, phone numbers, keys or PINs in code, seed data, screenshots or commits. Real details live only in the production database.

## 4. Tech stack

| Layer | Choice |
|---|---|
| Framework | Next.js (App Router) + TypeScript |
| Styling | Tailwind CSS |
| Database | Supabase (Postgres) |
| Live updates | Supabase Realtime (fallback: polling) |
| Hosting | Vercel, auto-deploy from GitHub `main`, preview deploys per PR |
| Testing | Vitest (unit, business logic), Playwright (end-to-end) |
| Source control | GitHub, feature branches + pull requests |

Security rules:

- All writes go through server-side code (Server Actions / Route Handlers) with validation. No direct client writes to the database.
- Supabase Row Level Security enabled on every table.
- Organiser PINs hashed (bcrypt), session in an httpOnly signed cookie.
- Secrets only in `.env.local` / Vercel env vars. `.env.example` committed with placeholders.
- Multi-step changes (leave + promote reserve) run in a single database transaction/function to avoid race conditions.

## 5. Users

- **Player** — joins/leaves a game, pays, marks status. Can only remove themselves.
- **Organiser** — any member of the organiser group. Creates games, confirms payments, manages lists, locks/cancels games, handles refunds/credit and handovers. Can remove/reorder anyone.
- **Payee** — the organiser collecting money for a specific game. Set per game, can change mid-week.

## 6. Business rules

### 6.1 Game

- Fields: date, kick-off time, venue (optional), price (default £7.20, editable), cap (default 14), minimum (default 14), payee, payee Monzo link, payee bank details (name, account number, sort code), status.
- Organisers can duplicate last week's game (copies settings, not players).
- Price is fixed per game — not split by head count. If there aren't enough players, the game is cancelled.

### 6.2 Game lifecycle

| Status | Behaviour |
|---|---|
| `open` | Players join/leave/pay freely. Reserves auto-promote. |
| `locked` | Organiser taps Lock (usually a few hours before kick-off). List is final; no self-join/leave. If someone drops out, organiser chooses still owes or let off. No auto-promotion. |
| `cancelled` | No one owes anything for this game. Anyone who already paid is resolved by organiser choosing refund or credit per player. |
| `played` | Set after kick-off. Any unpaid or unreceived-cash spot becomes an outstanding debt on that player's balance. |

- Page shows player count vs minimum, e.g. "11/14 — need 3 more".
- Organiser dashboard warns when a game is short near kick-off.

### 6.3 Playing list and reserves

- Two lists: Playing (up to cap) and Reserves (ordered by join time; organisers can reorder).
- No teams — teams are picked on the day.
- Joining when Playing is full → added to the bottom of Reserves.
- When a Playing player leaves while open, Reserve #1 is automatically promoted, gets status `not_paid`, and is named in the next chase message ("Sam — you're in, please pay").
- Reserves owe nothing until promoted.
- Player names must be unique (case-insensitive); when adding, suggest existing names to avoid duplicates like "sam" vs "sam jones".

### 6.4 Payment statuses (per spot)

| Status | Meaning | Set by |
|---|---|---|
| `not_paid` | Default for Playing | System |
| `says_paid` | Player says they paid by bank/Monzo; awaiting check | Player |
| `cash_promised` | Will pay cash on the day | Player |
| `confirmed_bank` | Organiser saw the money arrive | Organiser |
| `cash_received` | Organiser received the cash | Organiser |
| `paid_by_credit` | Covered by the player's existing credit | System/Organiser |
| `let_off` | Organiser waived it | Organiser |
| `refunded` / `credited` | Resolution after a cancelled game | Organiser |

- "Reminded" is not a status — it's a `last_reminded_at` timestamp shown alongside any unpaid status.
- Only organisers can set confirmed/received/let off/refunded/credited.
- Every confirmed payment records `received_by` (which organiser holds the money).
- `cash_promised` is never treated as paid — it stays outstanding until `cash_received`.

### 6.5 Balances and history

- Balances are calculated from spots and credit entries, not stored as a single number.
- A player's page shows outstanding debt next to their name, e.g. "Owes £7.20 from 9 Sep".
- Organiser Outstanding view: who owes, how much, which games, and which organiser they owe.
- Credit: created when a cancelled-game payment is credited. Held against the organiser who received the money. Can be applied to a future game (`paid_by_credit`).

### 6.6 Payee handover

- An organiser can change a game's payee at any time. Existing confirmed payments keep their `received_by`.
- The system creates a handover record: from organiser, to organiser, amount, number of payments, received yes/no. The new payee can mark it received.

### 6.7 WhatsApp helpers

- **Copy chase message:** lists only unpaid Playing players (incl. newly promoted), with the game link and payment link.
- **Copy full list:** text version of the game similar to the current WhatsApp format, for gradual adoption.

## 7. Pages

| Route | Who | Purpose |
|---|---|---|
| `/g/[slug]` | Anyone with link | Game page: details, pay button, bank details, Playing list, Reserves, statuses, join/leave, "I've paid"/"Cash on the day" |
| `/admin/login` | Organisers | PIN login |
| `/admin` | Organisers | Games list, create/duplicate game, Outstanding view |
| `/admin/g/[slug]` | Organisers | Dashboard: totals (expected / confirmed / outstanding), confirm, remind, remove/reorder, lock, cancel, refund/credit, change payee, copy messages |
| `/admin/handovers` | Organisers | Handover records |

The device remembers "this is me" (localStorage) so a returning player sees their own row highlighted. It is only a convenience, not authentication.

## 8. Data model (initial)

- **players:** id, display_name (unique, case-insensitive), created_at
- **organisers:** id, player_id, pin_hash, active
- **games:** id, slug, date, kickoff_time, venue, price_pence, cap, minimum, payee_organiser_id, monzo_link, bank_name, bank_account, bank_sort_code, status, locked_at, cancelled_at, created_by
- **spots:** id, game_id, player_id, list (playing/reserve/left), position, payment_status, received_by_organiser_id, last_reminded_at, left_after_lock, joined_at, updated_at
- **credits:** id, player_id, organiser_id, amount_pence (+ added / − used), game_id, spot_id, created_at
- **handovers:** id, game_id, from_organiser_id, to_organiser_id, amount_pence, payment_count, received, created_at
- **audit_log:** id, actor, action, entity, entity_id, details, created_at

Money is stored as integer pence.

## 9. Scope

- **v1 (MVP):** everything in sections 6–8.
- **Later:** automatic Monzo matching via the payee's own Monzo API access; reliability stats (late dropouts); team picker; push/email reminders.
- **Out of scope:** in-site card payments, native apps, player accounts.

## 10. Conventions

- Business logic (promotion, balances, chase message text) lives in pure, unit-tested functions in `src/lib/`.
- Commits follow Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`).
- One feature = one branch = one pull request.
- Major decisions logged in `docs/decisions.md` (date, decision, alternatives, reason).
- Seed/demo data uses fictional names and fake bank details only.

## 11. Changelog

- 16 Sep 2026 — Initial context: requirements, rules, stack, data model agreed.
- 17 Sep 2026 — Added to repo as `docs/requirements.md`: real names replaced with fictional examples; Claude-specific instructions removed.
