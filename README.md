# PitchPay ⚽

A mobile-first website for running a weekly 7-a-side football game: players add themselves, pay the organiser via Monzo or bank transfer and mark themselves as paid; the organiser confirms payments, chases unpaid players and sees balances across weeks.

> 🚧 Work in progress

**Live site:** _coming soon_

## The problem

Every Wednesday one person books the pitch and collects £7.20 per player. Today this runs on a copy-pasted WhatsApp message with emojis. The organiser has to chase people manually, can't easily see who hasn't paid and cash promises get forgotten.

## Tech stack

| Layer | Choice |
|---|---|
| Framework | Next.js (App Router) + TypeScript |
| Styling | Tailwind CSS |
| Database | Supabase (Postgres) |
| Hosting | Vercel |
| Testing | Vitest, Playwright |

## Running locally

Requires Node.js LTS.

```bash
git clone https://github.com/Aaron64456/pitchpay.git
cd pitchpay
npm install
cp .env.example .env.local   # then fill in values
npm run dev
```

Open http://localhost:3000.

## Project docs

- [`PROJECT-CONTEXT.md`](PROJECT-CONTEXT.md) — requirements, business rules and data model
- [`docs/decisions.md`](docs/decisions.md) — key technical decisions and why

## Licence

MIT
