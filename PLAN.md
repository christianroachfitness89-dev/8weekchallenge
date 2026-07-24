# 8-Week Challenge - Hosted Site Plan

## Decisions confirmed

- **Payment:** Stripe Payment Links (no server needed).
- **Login:** Email + password accounts via Supabase Auth.
- **Backend/hosting:** Supabase (database + auth + storage) + Netlify (static hosting).
- **Admin area:** Yes - manage entrants, verify weigh-ins, export data.
- **Units:** Kilograms throughout (no lbs anywhere).

## Goals

1. Public landing page that explains the challenge and drives sign-ups.
2. Sign-up flow that creates an account and redirects to Stripe to pay.
3. Login page for returning entrants.
4. Entrant dashboard with weekly check-in (kg) and personal progress.
5. Public leaderboard ranked by % body weight lost (raw weights never shown publicly).
6. Admin panel for the organiser only.
7. Step-by-step deployment guide.

## Tech stack

| Layer | Tool | Why |
|-------|------|-----|
| Auth & database | Supabase (free tier) | One account gives PostgreSQL, email auth, file storage, and security rules. |
| Payments | Stripe Payment Links | No server code required. Two links: Standard $280, F2F $792. |
| Hosting | Netlify | Drag-and-drop or Git deploy, free SSL, fast CDN. |
| Frontend | Plain HTML/CSS/JS | Matches your existing files; easy to host anywhere later. |

## Supabase schema

### `profiles` (extends each authenticated user)

- `id` (uuid, PK, linked to `auth.users`)
- `full_name` (text)
- `phone` (text)
- `tier` (text: `standard` | `f2f`)
- `paid` (boolean, default `false`)
- `is_admin` (boolean, default `false`)
- `starting_weight_kg` (numeric)
- `created_at` (timestamptz)

### `checkins`

- `id` (uuid, PK)
- `user_id` (uuid, FK -> `auth.users`)
- `week` (integer, 0–8)
- `weight_kg` (numeric)
- `photo_url` (text, optional, for Week 0/4/8 verification photos)
- `workouts_completed` (integer)
- `energy_rating` (integer 1–5)
- `adherence_rating` (integer 1–5)
- `notes` (text)
- `created_at` (timestamptz)

## Pages

| Page | Purpose | Auth needed |
|------|---------|-------------|
| `index.html` | Landing page: hero, pricing, prizes, rules, CTA. | No |
| `signup.html` | Create account, pick tier, then pay via Stripe. | No |
| `login.html` | Email + password login. | No |
| `dashboard.html` | Entrant check-in form + personal progress chart. | Yes |
| `leaderboard.html` | Public live leaderboard. | No |
| `admin.html` | Entrant list, payment status, weigh-in photos, export. | Admin only |
| `payment-success.html` | Stripe return page that marks the user as paid. | No (uses Stripe session) |

## Key features

### Sign-up + payment
1. User fills name, email, phone, tier, starting weight (kg), and password.
2. Supabase creates the auth account and profile.
3. They are redirected to the correct Stripe Payment Link (`$280` or `$792`).
4. After Stripe success, they land on `payment-success.html`, which calls Supabase to set `paid = true`.
5. Unpaid users can log in but cannot check in until payment is confirmed.

### Check-in
- Only logged-in, paid entrants can submit.
- Week selector 0–8.
- Weight in kg.
- Optional official weigh-in photo upload for Weeks 0, 4, and 8.
- Weekly accountability fields: workouts, energy, adherence, notes.

### Leaderboard
- Ranks by `((starting_weight_kg - latest_weight_kg) / starting_weight_kg) * 100`.
- Shows rank, first name/initials, percent lost, and weeks checked in.
- Never shows raw kg on the public board.
- Top 3 highlighted gold/silver/bronze.
- Auto-refreshes every 20 seconds.

### Admin
- Login gates to `is_admin = true`.
- Table of all entrants: name, tier, paid status, starting weight, latest weight, % lost.
- Toggle paid status manually for offline payments.
- View/download weigh-in photos.
- Export entrants/check-ins to CSV.
- Safety flag: anyone losing >3% in one week is highlighted.

### Security (Supabase RLS)
- Users can read/update only their own `profiles` and `checkins` rows.
- Leaderboard is exposed through a public, read-only database function/view.
- Admin page calls Supabase via a secure function or checks `is_admin`.
- Weigh-in photos are stored in a private bucket; public URLs are never exposed.

## Files to create / modify

### New files
- `index.html`
- `signup.html`
- `login.html`
- `dashboard.html`
- `leaderboard.html`
- `admin.html`
- `payment-success.html`
- `js/supabase-client.js`
- `js/auth.js`
- `js/leaderboard.js`
- `js/admin.js`
- `css/main.css`
- `SETUP.md`

### Existing files
- `8-week-challenge-signup.html` → kept as reference/backup.
- `8-week-challenge-checkin-leaderboard.html` → replaced by new dashboard + leaderboard pages.
- `8-Week-Challenge-Rules-and-Accountability.md` → content already used for rules text.
- `8-Week-Fitness-Challenge-Plan.md` → content already used for prizes/timeline text.

## Deployment steps (summarised; full guide in SETUP.md)

1. Create a Supabase project.
2. Run the SQL setup (tables, RLS policies, storage bucket).
3. Create two Stripe Payment Links and copy their URLs.
4. Add Supabase URL + anon key to `js/supabase-client.js`.
5. Add Stripe links to `signup.html`.
6. Deploy the folder to Netlify.
7. Test sign-up, payment success, check-in, leaderboard, and admin flow.

## Out of scope for this first build

- Automated weekly reminder emails (can be added later with Supabase Edge Functions or Zapier).
- In-person session booking calendar.
- Nutrition/meal plan delivery.

These can be added once the core sign-up → pay → check-in → leaderboard loop is live.
