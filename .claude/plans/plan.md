# Plan: Cohort Community Chat inside the Dashboard

## Goal
Add a real-time, cohort-scoped chat / community feed directly inside the entrant dashboard so it becomes a one-stop shop for challenge updates, camaraderie, and support. Admins can moderate and post announcements.

## High-level approach
Build a simple real-time chat feed (not threaded forum) for the MVP. It is the fastest path to "community and camaraderie" and keeps the dashboard unified.

## New database objects

### Table: `public.chat_messages`
- `id uuid` PK
- `challenge_id uuid` FK → `public.challenges` (cohort scope)
- `user_id uuid` FK → `auth.users`
- `content text not null` (validated length 1–500)
- `is_pinned boolean default false` (for admin announcements)
- `created_at timestamptz default now()`
- Index on `(challenge_id, created_at desc)`

### Table: `public.chat_reactions` (optional v1.5)
- `message_id`, `user_id`, `emoji` - if we want lightweight reactions. Can be deferred.

### RLS policies
- `select`: any authenticated user whose `profiles.challenge_id` matches the message's `challenge_id`. This is the safest way to scope by cohort without recursion.
- `insert`: authenticated user and their own `profiles.challenge_id` matches the message's `challenge_id`.
- `delete/update`: admin only (for moderation / pinning).

### Realtime
- Enable `supabase_realtime` publication for `chat_messages` so new messages appear instantly without polling.

## Dashboard UI changes

### Layout
- Convert the dashboard from a two-column static layout into a tabbed layout inside the paid/active area:
  - **Tab: Progress** (existing weight chart + check-in form + stats)
  - **Tab: Community** (new chat feed)
  - **Tab: Photos** (progress photos - moved here to reduce clutter)

Or, keep the existing layout and add a full-width "Community" card below the current grid. Tabbed is cleaner for a one-stop shop.

### Community tab components
- Message list: newest at bottom, auto-scroll to latest.
- Message bubble: display name (first name + initial), relative timestamp, content.
- Pinned announcements at top.
- Input box + send button.
- "No messages yet - say hello!" empty state.
- Admin-only: delete button on each message, pin toggle.

## Implementation steps
1. Update `supabase-setup.sql` with new table, policies, indexes, and realtime publication.
2. Update `dashboard.html`:
   - Add tab navigation.
   - Wrap existing content in Progress tab.
   - Add Community tab markup (message list, input, pinned area).
   - Optionally move progress photos to a Photos tab.
3. Add dashboard JavaScript:
   - Load messages for current cohort.
   - Subscribe to realtime inserts.
   - Handle send, delete, pin (admin).
   - Auto-scroll and relative timestamps.
4. Add CSS for chat bubbles, tabs, and responsive layout.
5. Update `admin.html`:
   - Allow admins to delete/pin any cohort message (same realtime feed).
6. Update `SETUP.md` with a note about the community feature.
7. Push to GitHub and guide SQL re-run.

## Trade-offs considered
- **Real-time chat vs forum threads**: Chosen chat because it matches "community and camaraderie" better and is simpler. Threads can be added later if conversations get noisy.
- **Embedding in dashboard vs separate page**: Embedded in dashboard as requested for the one-stop-shop experience.
- **RLS scoped by profile vs message challenge_id**: Using `profiles.challenge_id` in RLS ensures users only see their own cohort's chat and cannot spoof into another cohort.

## Open questions
1. Should messages support images (e.g. meal photos, workout proof)? Adds storage complexity; recommend deferring to v2 unless wanted now.
2. Should entrants be able to reply to / thread a specific message? Recommend no for MVP.
3. Should admins be able to send a separate "Announcement" type? Can be handled via the `is_pinned` flag; pinned messages render differently.
4. Emoji reactions in v1? Nice-to-have; can be added cheaply but will be skipped unless requested.

## Recommended decision
Proceed with real-time cohort chat (text only), two tabs (Progress + Community), admin delete/pin, and pinned announcements. This keeps scope tight and delivers the one-stop-shop feel.
