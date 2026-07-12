# Levels Marketing Site

Promotional website for the Levels app. Built on the Flow Shader template with a full visual adaptation to the Levels design system.

## Tech Stack

- React 19 + TypeScript + Vite
- Three.js (fluid shader background)
- GSAP + ScrollTrigger (scroll-driven animations)
- Lenis (smooth scroll)
- Tailwind CSS + shadcn/ui primitives
- Supabase (waitlist backend)

## Sections

1. **Hero** — "LEVELS" wordmark with aurora fluid shader backdrop
2. **Philosophy** — Six zones in a 3D rolling text ring (Collapsed → Flow)
3. **Vision** — Consciousness mission manifesto
4. **Journey Gallery** — Four phases: Read · See · Climb · Hold
5. **Testimonials** — Glassmorphism quote cards
6. **Tracks** — Four ascension tracks with gooey hover animation
7. **Waitlist** — Email signup wired to Supabase
8. **Footer** — Vision close + links

## Design System

All colors, typography, and motion tokens are derived from `levels-native/design-system/MASTER.md`:

- **Void:** `#0B0C15`
- **Surface:** `#131525`
- **Aurora:** `#20265C` → `#3A2E6E` → `#1C3A56`
- **Builder accent:** `#DB7E93`
- **Typography:** Fraunces (display) + Inter (body)

## Quick Start

```bash
cd marketing-site
npm install
npm run dev
```

Open `http://localhost:5173`

## Build

```bash
npm run build
```

Output is written to `dist/` — ready for any static host.

## Deploy to Vercel

```bash
npm install -g vercel
vercel --prod
```

Or drag the `dist/` folder into [vercel.com](https://vercel.com).

## Environment Variables

Copy `.env.example` to `.env` and fill in your Supabase credentials:

```bash
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-publishable-key
```

The fallback values in `src/lib/supabase.ts` point to the production project.

## Waitlist Backend

The waitlist form calls the `join_waitlist` RPC function on the Supabase project. The table is `public.waitlist` with RLS enabled for anonymous inserts.

## Credits

- Design system: Levels MASTER.md (Noah, 2026-07-08)
- Base template: Flow Shader Frontend (swarm-coding skill)
- Zone framework: Frederick Dodson, *Levels of Energy*
