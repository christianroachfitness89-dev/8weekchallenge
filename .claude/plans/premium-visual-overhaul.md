# Plan: Premium Visual Overhaul (Template First)

## User intent
- Make the site feel premium and high-value while keeping the same challenge offer and pricing.
- Keep the existing brand colours but elevate the execution.
- Use placeholder assets for now (photos, testimonials, coach bio).
- Deliver a standalone preview page for approval before applying changes to the main site.

## What stays the same
- Challenge structure: 8 weeks, KG weigh-ins, cohort model, leaderboard, dashboard, chat.
- Pricing tiers: Standard ($280) and Face-to-Face ($792).
- Supabase backend, auth, Stripe links, storage, RLS policies.

## What changes in the preview
- **Hero**: full-width cinematic feel, larger condensed headline, subhead with more whitespace, premium ticket/card treatment for the prize pool, subtle entrance animation.
- **Typography**: larger scale hierarchy, tighter line-height on headlines, more generous section spacing.
- **Sections**:
  - A "Why this works" credibility band with 3 premium stats/credibility points.
  - An editorial "How it works" timeline instead of the current stacked rhythm rows.
  - A transformation/testimonial grid with placeholder before/after cards and client quotes.
  - A pricing section that feels like a membership choice, with feature comparison and a highlighted recommended tier.
  - A "Meet your coach" section with placeholder photo and bio.
  - A refined FAQ/rules section.
  - A stronger final CTA section.
- **UI details**:
  - Subtle shadows, 1px borders, refined radius, hover lift on cards.
  - Smooth scroll reveals (simple CSS/JS, not heavy).
  - Premium button states and focus rings.
  - Mobile-first responsive layout preserved.

## Deliverable
A single file: `premium-preview.html` in the project root.
- It will be self-contained with inline styles and use the existing `css/main.css` as a base where useful, but mostly define its own premium overrides so it is easy to review in isolation.
- It will not connect to Supabase or Stripe (no live functionality) — it is purely a visual and content template.

## After approval
- Merge the approved design into the real pages:
  - `index.html` (landing page)
  - `signup.html` (sign-up page styling)
  - `dashboard.html` (dashboard shell styling)
  - `admin.html` (admin panel styling)
  - `css/main.css` (shared design system)
- Remove `premium-preview.html` or keep it as a style reference.

## Scope boundaries
- No backend changes for this phase.
- No new features (chat remains as-is, dashboard functionality unchanged).
- Placeholder images will use CSS-generated gradients/patterns or Unsplash source URLs where appropriate, with clear notes on what to replace.
