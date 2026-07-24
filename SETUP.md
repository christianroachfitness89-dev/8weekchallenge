# 8-Week Challenge - Deployment Setup Guide

This guide walks you through getting the hosted site live with Supabase (database + auth + storage) and Stripe (payments), deployed on Netlify.

## What you need

- A free [Supabase](https://supabase.com) account
- A free [Stripe](https://stripe.com) account
- A free [Netlify](https://netlify.com) account (or any static host)
- About 30 minutes

---

## Step 1: Create a Supabase project

1. Go to [supabase.com](https://supabase.com) and sign in.
2. Click **New Project**.
3. Give it a name like `eight-week-challenge` and choose a region close to your entrants.
4. Save the generated **Project URL** and **anon public API key** - you’ll paste them into the code in Step 4.

---

## Step 2: Set up the database

1. In Supabase, open the **SQL Editor**.
2. Create a **New query**.
3. Copy the entire contents of `supabase-setup.sql` from this folder and paste it in.
4. Click **Run**.

This creates:
- `challenges` table (one row per cohort, with Monday start dates, 48h baseline window, and 8-week end date)
- `profiles` table (one row per entrant, with a `challenge_id` assignment)
- `checkins` table (weekly weigh-ins, tied to a specific challenge)
- `progress_photos` table (private progress photos per cohort)
- `chat_messages` table (real-time cohort community chat)
- Row Level Security policies (entrants only see their own data; admins see everything)
- A public `get_leaderboard(target_challenge_id)` function for per-cohort leaderboards
- Private `weighin-photos` and `progress-photos` storage buckets
- Triggers that keep the profile row in sync with the auth user and enforce the challenge lifecycle

---

## Step 3: Configure Supabase Auth

### Option A - Keep email confirmation enabled (recommended for production)

1. In Supabase, go to **Authentication > Providers**.
2. Make sure **Email** is enabled.
3. Go to **Authentication > Email Templates** and review the confirmation email.
4. For production, go to **Authentication > SMTP** and connect your own email provider so confirmation emails don’t land in spam.

### Option B - Disable email confirmation (faster for testing)

1. In Supabase, go to **Authentication > Providers > Email**.
2. Turn **Confirm email** OFF.
3. This lets entrants sign up and log in immediately without clicking a confirmation link.

---

## Step 4: Paste your Supabase credentials into the code

1. Open `js/supabase-client.js`.
2. Replace:
   - `https://YOUR_PROJECT_ID.supabase.co` with your Supabase **Project URL**
   - `YOUR_SUPABASE_ANON_KEY` with your Supabase **anon public API key**
3. Save the file.

> Never paste your service-role key into the frontend. Only the anon key belongs in `supabase-client.js`.

---

## Step 5: Set up Stripe Payment Links

1. Log in to your [Stripe Dashboard](https://dashboard.stripe.com).
2. Go to **Payment Links** and create two products:
   - **Standard** - $280, one-time payment
   - **Face-to-Face** - $792, one-time payment
3. For each Payment Link, set the **After payment** redirect URL to:
   `https://YOUR_NETLIFY_SITE_URL/payment-success.html`
4. Copy each Payment Link URL.
5. Open `signup.html` and replace:
   - `https://buy.stripe.com/YOUR_STANDARD_PAYMENT_LINK` with the Standard link
   - `https://buy.stripe.com/YOUR_F2F_PAYMENT_LINK` with the F2F link
6. Save the file.

> The sign-up page automatically appends the entrant’s `client_reference_id` and `prefilled_email` to the Stripe link, so you can match payments to users in the Stripe Dashboard.

---

## Step 6: Make yourself an admin

1. Deploy the site first (see Step 7) so you can sign up through the normal sign-up form.
2. Sign up on your live site as the organiser.
3. In Supabase, open the **Table Editor > profiles**.
4. Find your row and change `is_admin` to `true`.
5. Now when you log in and visit `admin.html`, the admin panel will load.

---

## Step 7: Deploy to Netlify

1. Log in to [Netlify](https://netlify.com).
2. Drag and drop this entire project folder onto the Netlify deploy area, **or** connect a Git repo.
3. Netlify will give you a site URL like `https://eight-week-challenge-abc123.netlify.app`.
4. Replace `YOUR_NETLIFY_SITE_URL` in Step 5 with that URL, then redeploy if needed.

### Custom domain (optional)

If you own a domain, go to **Netlify > Domain settings** and connect it. Then update the Stripe redirect URL to use your custom domain.

---

## Step 8: Create your first cohort

1. Log in to the admin panel at `admin.html`.
2. Under **Create New Cohort**, give it a name (e.g. “Summer 2026”) and pick a Monday start date/time.
3. Click **Create Cohort**.
4. Supabase automatically sets:
   - **Baseline opens** = 48 hours before the start
   - **End date** = 8 weeks after the start

You can create multiple cohorts. Each entrant is assigned to exactly one cohort at a time.

---

## Step 9: Test the full flow

1. Visit your live site and click **Enter Now**.
2. Sign up as a test entrant with a real email.
3. You should be redirected to Stripe.
4. Complete a test payment (use Stripe test card `4242 4242 4242 4242`, any future date, any CVC, any ZIP).
5. You land on `payment-success.html`.
6. In Supabase or in `admin.html`, set your test entrant’s `paid` flag to `true` and assign them to your test cohort.
7. Log in at `login.html`.
8. During the 48-hour baseline window, submit a Week 0 weigh-in in kg and upload a photo.
9. After the Monday start, submit a Week 1 weigh-in in kg.
10. Visit `leaderboard.html`, pick your cohort, and confirm your test entrant appears.

---

## Step 10: Running the challenge each week

| Day | Action |
|-----|--------|
| Saturday/Sunday (baseline window) | Remind entrants to submit Week 0 before the Monday start. |
| Monday | Post the updated leaderboard to the community group. Review any safety flags in `admin.html`. |
| Sunday | Remind entrants to check in before the new week starts. |
| Anytime | Mark entrants paid and assign them to a cohort in `admin.html` after confirming their Stripe payment. |
| Week 4 & 8 | Remind entrants to upload their official weigh-in photo. |
| After Week 8 | Click **Lock / Archive** on the cohort in `admin.html` to freeze the leaderboard and stop further check-ins. |
| Anytime | Monitor the **Cohort Chat** section in `admin.html`. Pin announcements, delete off-topic or harmful messages, and keep the community positive. |

---

## Common issues

### “Supabase credentials are still placeholders”

You forgot to update `js/supabase-client.js`. The sign-up page will refuse to redirect to Stripe until you do.

### Sign-up fails with “Email not confirmed”

Email confirmation is still enabled in Supabase. Either configure SMTP properly or disable confirmation in Auth settings.

### Dashboard says “Not assigned to a cohort yet”

The entrant is paid but has not been assigned to a challenge. Go to `admin.html` and select a cohort in the entrant row.

### “Baseline check-in opens at …”

The entrant is trying to submit a Week 0 weigh-in before the 48-hour baseline window opens. They must wait until Saturday/Sunday before the Monday start.

### “Only Week X is open”

Entrants can only submit the currently open week. The database trigger blocks early or late submissions. Admins can override from `admin.html` if needed.

### Leaderboard is empty

The leaderboard only shows **paid** entrants assigned to that cohort who have submitted a **Week 0 baseline**. Make sure the entrant is paid, assigned to the cohort, and has a Week 0 check-in.

### Admin page redirects to dashboard

Your profile row has `is_admin = false`. Update it in Supabase.

### Photo uploads fail

Check that you ran `supabase-setup.sql` completely, including both storage buckets and storage policies.

---

## Switching from kg to lb later

All user-facing copy and code uses kilograms. To switch back to pounds, you would need to:
1. Update labels from “kg” to “lb” across all pages.
2. Rename database columns (`weight_kg` → `weight_lb`) or just treat the numeric values as pounds.
3. Update the leaderboard function to reference the new column name.

For now, everything is built for kilograms as requested.
