# 8-Week Challenge - Hosted Site

A complete, hosted website for running an 8-week fitness/weight-loss challenge.

## What's included

| Page | Purpose |
|------|---------|
| `index.html` | Public landing page with challenge info, pricing, prizes, rules |
| `signup.html` | Create an account, pick a tier, then pay via Stripe |
| `login.html` | Email + password login for returning entrants |
| `dashboard.html` | Submit weekly weigh-ins (in **kg**) and track personal progress |
| `leaderboard.html` | Public live leaderboard ranked by % body weight lost |
| `admin.html` | Organiser panel: manage entrants, verify payments, view photos, export CSV |
| `payment-success.html` | Post-payment thank-you page |

## Shared code

- `js/supabase-client.js` - Supabase client config
- `js/auth.js` - sign up, sign in, session, profile helpers
- `js/leaderboard.js` - leaderboard data + rendering
- `css/main.css` - shared styles
- `supabase-setup.sql` - database schema, RLS policies, storage bucket, leaderboard function

## How to deploy

See [`SETUP.md`](SETUP.md) for step-by-step instructions covering Supabase, Stripe, and Netlify.

## Important notes

- **All weights are in kilograms.** Every form, label, and calculation uses kg.
- The leaderboard shows only **rank** and **% progress**. Raw weights are private.
- Entrants must be marked **paid** before their dashboard unlocks. You confirm payments in the Stripe Dashboard, then mark them paid in `admin.html`.
- The two older HTML files in this folder (`8-week-challenge-signup.html` and `8-week-challenge-checkin-leaderboard.html`) are kept as reference but are replaced by the new pages above.

## Next features you could add

- Automated weekly reminder emails (Supabase Edge Functions or Zapier)
- Stripe Checkout auto-activation instead of manual payment confirmation
- In-person session booking calendar for F2F members
- Nutrition/wellness content hub
