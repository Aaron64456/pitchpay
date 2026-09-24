# Decisions

A log of major decisions: what was decided, what else was considered, and why.

| Date | Decision | Alternatives considered | Reason |
|---|---|---|---|
| 16 Sep 2026 | Website only, mobile-first | Native iOS/Android app | Players already live in WhatsApp; a link opens instantly with nothing to install. |
| 16 Sep 2026 | No payment processing — players pay via the organiser's Monzo.me link or bank transfer and self-report | Stripe / in-site card payments | Avoids fees, regulation and handling money; matches how the group already pays. |
| 16 Sep 2026 | No player logins — players pick their name; only organisers use a PIN | Accounts for every player | Low friction is essential for adoption; the stakes (£7.20) don't justify accounts. |
| 16 Sep 2026 | Next.js (App Router) + TypeScript + Tailwind | Plain React SPA, Remix | Server-side rendering and server actions in one framework; strong typing; widely used in industry. |
| 16 Sep 2026 | Supabase (Postgres) | Firebase, SQLite, PlanetScale | Relational data (games, spots, credits) suits SQL; free tier; built-in Realtime and Row Level Security. |
| 16 Sep 2026 | Vercel hosting | Netlify, Render | Made by the Next.js team; free tier; preview deploy for every pull request. |
| 16 Sep 2026 | Money stored as integer pence | Decimal/float pounds | Floats can't represent money exactly (0.1 + 0.2 ≠ 0.3); integers avoid rounding errors. |
| 16 Sep 2026 | Balances calculated from spots and credit entries, not stored | A single balance column per player | A ledger is auditable and can't drift out of sync with the underlying records. |
