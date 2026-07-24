# 8-Week Challenge - Multi-Cohort Architecture Plan

## Decisions confirmed

- **One challenge at a time per participant** (`challenge_id` on `profiles`).
- **Reset existing data** is acceptable - only test data exists.
- **Admin manually assigns** participants to a challenge after payment.
- **Baseline opens 48 hours before the Monday start**.
- **After a challenge ends:** lock check-ins and archive the leaderboard.

## New database model

### `challenges`

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid | Primary key |
| `name` | text | e.g. "Cohort July 2026" |
| `baseline_opens_at` | timestamptz | Saturday before the Monday start |
| `starts_at` | timestamptz | Monday challenge start |
| `ends_at` | timestamptz | 8 weeks after start |
| `locked` | boolean | True after challenge ends |
| `active` | boolean | Show on signup/admin |
| `created_at` | timestamptz | Auto |

### `profiles`

Add `challenge_id uuid references challenges(id)` (nullable until assigned).

### `checkins`

Add `challenge_id uuid references challenges(id)`.
Every check-in is scoped to the participant's current challenge.

## New business rules

### Challenge lifecycle

1. **Upcoming challenge created** by admin with:
   - Name
   - Start date (Monday)
   - `baseline_opens_at` auto-calculated = start date minus 48 hours (Saturday)
   - `ends_at` auto-calculated = start date plus 56 days (8 weeks)

2. **Baseline window (Saturday & Sunday before start)**
   - Participants can only submit **Week 0**.
   - Dashboard shows countdown to challenge start.

3. **Challenge start (Monday)**
   - Week 1 opens.
   - Each subsequent week unlocks each Monday.

4. **Challenge ends (Monday, 8 weeks later)**
   - `locked` flips to true.
   - No more check-ins allowed.
   - Leaderboard becomes a read-only archive.

### Dashboard week calculation

- If now is before `starts_at`:
  - Only allow Week 0 submissions.
  - Suggested week = 0.
- Else:
  - `diffDays = floor((now - starts_at) / 86400000)`
  - `currentWeek = min(8, max(1, floor(diffDays / 7)))`
  - Suggested week = currentWeek.

### Assignment flow

1. Participant signs up and pays.
2. Admin sees them as "Unassigned" in admin panel.
3. Admin picks a challenge from a dropdown and assigns them.
4. Participant's dashboard now follows that challenge's dates.

### Leaderboard

- `get_leaderboard(challenge_id uuid)` returns rankings for one challenge only.
- Leaderboard page accepts `?challenge=UUID` and shows the active/assigned challenge by default.
- Admin can switch between archived challenges.

## Files to update

| File | Changes |
|------|---------|
| `supabase-setup.sql` | New `challenges` table; add `challenge_id` to `profiles` and `checkins`; update RLS; update leaderboard function |
| `signup.html` | No major change - participant signs up unassigned |
| `login.html` | No change |
| `dashboard.html` | Read `profile.challenge_id`; enforce baseline window; calculate weeks from challenge start; submit `challenge_id` with check-ins |
| `leaderboard.html` | Accept challenge param; call `get_leaderboard(challenge_id)` |
| `admin.html` | Create/manage challenges; assign participants to challenges; per-challenge leaderboards; lock/archive challenges |
| `index.html` | Show current/next open challenge dates |
| `payment-success.html` | Minor copy update |

## Key UX changes

### Admin panel new sections

1. **Challenges**
   - Create challenge: name + start date
   - List: name, baseline opens, starts, ends, status, actions
   - Lock/archive button
   - View leaderboard per challenge

2. **Entrants**
   - Show current challenge assignment
   - Dropdown to assign/unassign challenge
   - Mark paid / unpaid

### Participant dashboard

- If no challenge assigned: show "You haven't been assigned to a challenge yet. The organiser will add you shortly."
- If baseline window open: show countdown to challenge start, only Week 0 form.
- During challenge: show current week, chart, progress photos.
- If challenge locked: show "This challenge has ended. View your final results."

## Migration / reset approach

Since reset is acceptable, the SQL script will:
1. Drop dependent triggers/policies.
2. Drop and recreate `checkins` and `profiles` with `challenge_id`.
3. Create `challenges` table.
4. Recreate all policies/triggers/functions with new schema.
5. The script is idempotent so it can be re-run safely.

## Out of scope

- Automated recurring cohort creation (can be added later).
- Email reminders for baseline/check-in deadlines.
- Public challenge calendar page.

## Deployment steps

1. Update all files and push to GitHub.
2. Run the updated `supabase-setup.sql` in Supabase SQL Editor.
3. Create the first challenge in admin panel.
4. Assign yourself to it.
5. Set baseline opens to now (or a past Saturday) for testing.
6. Test Week 0 submission, then Week 1, leaderboard, and locking.
