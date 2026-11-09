<!-- Purpose: brainstorm state for the SQ-Test-inspired "block map" instrument (decisions locked so far + Noah's pasted reference UI spec, kept verbatim as a pattern library). Source: session of 2026-11-07/08. Not yet a spec; the design doc is written after sections 2+ are approved. -->

# Block map brainstorm notes (2026-11-08)

## Research summary (SQ Test, Aaron Abke / 4D University)
- Live app: https://the4dulab.lovable.app (Noah has an account; his test is in progress at Q12/180, untouched by Claude).
- Observed directly: 180 first-person statements, 5-point Likert ("Not at all like me" to "Always like me"), one per screen, progress bar, autosave/resume, tutorial video gate, "Before you begin" honesty primer ("when in doubt, go lower"; "honesty traps" mirror higher vs lower centers), "a blank leaves its whole category unscored". Menu Work is member-gated (/member-gate).
- Not observed by Claude: results page (requires finishing all 180). Noah's pasted spec below covers it from Abke's public YouTube demos.
- Public claims: six centers Root to Third Eye, 30 categories, outputs SQ score + chakra map + biggest block + program recommendation; retest at 3 months.

## Decisions locked (Noah, 2026-11-07/08)
1. **Path: inspired-by.** Original questions and copy; reuse patterns only. No verbatim Abke items, copy, names, or logos.
2. **Role:** optional deeper "block map" taken after the Phase 2 reveal; the 7-question Phase 1 stays as is.
3. **Categories:** the 12 existing `origin_domain` values (`lib/features/drill/drill_tokens.dart:35`, labels in `drill_questions.dart:116`). No new taxonomy; canon-safe.
4. **Phase 3 hand-off:** suggest + confirm/override. Top domain preselected, next two shown as alternatives, any of 12 still selectable. Store both suggestion and final pick (mismatch = honesty signal).
5. **Results layout:** radial wheel (12 spokes, one filled shape, brightest point = top domain) with option A's hero card under it ("Where you're most held" + domain label + "Begin the drill"). Mockups: `.superpowers/brainstorm/1978-1794110865/content/results-layout.html`.
6. **Approach 1 + design section 1 APPROVED:** offered as one card in the hub after the reveal; ~48 items (4 per domain), one per screen, 5-point Likert, autosave per tap, resume anytime, our own intro primer, some reverse-worded items; result screen as in 5; Day 21 retake offered alongside Window 3 with new shape overlaid on old (shape only, no numbers).
7. **Pasted UI spec = pattern library, not scope.** Fold in: honesty checks (inflation / denial / contradiction via reverse-scored items + consistency groups; flags lower confidence, never change the result), segmented outer ring on the wheel (grouping domains, not chakra tiers), progress overlay with hollow markers for low-confidence retakes, per-answer `responses` rows + randomized order. Park as later candidates: 7-tab dashboard (Occlusion Index, Inner Balance, Vertical), guided-session wizard engine.

## Rejected from the pasted spec (standing rules)
- Visible second score (1-1000, score pill, tier names, %): mechanic-leak rule + competes with CoG.
- Chakra hue per tier, light parchment theme: MASTER.md (dark, single ascending spectrum, no chakra rainbow).
- 6x5 tiers, blockage/quality kinds: replaced by 12 origin domains; Abke structure stays out of mechanics (canon rule 2026-07-11).
- `fl_chart`: new dependency not approved; wheel = `CustomPainter`.
- "FlutterFlow": this repo is the native Flutter track.

## Design section 2: scoring + data (APPROVED by Noah, 2026-11-08)
- **Encoding:** Likert 0..4 ("Not at all like me"=0 .. "Always like me"=4). Statements worded so agreement = "this holds me"; reverse-worded items use effective = 4 - value. 4 items per domain: 3 forward + 1 reverse.
- **Scoring (pure, integer-only):** domain score = sum of its 4 effective values (0..16); sums, not means, so the Dart mirror has no float rounding. All 48 answers required (raise otherwise). Rank descending. Tie-break 1: more effective values >= 3 wins; tie-break 2: `origin_domain` enum order (fixed fallback). (Claude's call.)
- **Honesty checks** (lower confidence, never change ranking; thresholds Claude's call, tunable by migration): straight-line = same raw value on >= 40/48; minimizing = effective 0 on >= 36/48; contradiction = each domain's reverse item paired with one forward item, pair contradicts at |diff| >= 3, flag at >= 3/12 pairs. Confidence: 0 flags high, 1 moderate, 2+ low.
- **Functions:** `compute_block_map(p_values smallint[48])` SECURITY INVOKER, pure, canonical item order in; returns 12 sums, ranked domains, flags, confidence (golden tests call it with literal arrays, levels-verify style). `score_block_map(p_assessment_id)` SECURITY DEFINER, `search_path` pinned, NOT FOUND guard then `auth.uid()` ownership guard, reads responses, calls the pure fn, writes results; idempotent. Dart mirror: `lib/features/block_map/block_map_scoring.dart`, exact integer copy.
- **Tables:** `block_map_items` (config: `item_key` PK, `domain origin_domain`, `reverse_scored`, `pair_key`; migration-seeded; authenticated read-only; statement text lives in Dart like `drill_questions.dart`). `block_map_assessments` (`id, user_id, loop_id, kind block_map_kind('initial','retake'), item_order text[]` client-shuffled for resume, `started_at, completed_at, domain_sums smallint[12], ranked_domains origin_domain[12], flags, confidence`; unique `(loop_id, kind)`). `block_map_responses` (`assessment_id, user_id, item_key, value smallint CHECK 0..4, answered_at`; PK `(assessment_id, item_key)`; client upserts per tap).
- **RLS:** `auth.uid() = user_id` on both user tables; response insert/update only while parent `completed_at IS NULL`.
- **Phase 3 hand-off:** `phase3_origin_drills` gains nullable `suggested_origin_domain origin_domain` + `block_map_assessment_id uuid FK`. Suggestion-vs-pick mismatch derived at query time, not stored. The final pick is the existing `q2_domain origin_domain` column (verified against production 2026-11-08, along with: live `origin_domain` enum = the 12 Dart values in the same order; no `block_map_*` tables exist yet).
- **Mirror-sync group 5 (new):** pure fn + item seed <-> Dart scoring + item metadata <-> `test/block_map_mirror_test.dart` <-> `levels-verify` golden values <-> CLAUDE.md sync map.
- **Migrations** (via levels-dev-loop): (1) enum + 3 tables + RLS + Phase 3 columns; (2) functions + grants. Item seed needs section 4's keys, so migrations ship after the question bank is authored.
- **Hooked:** responses = Investment; wheel = Variable Reward; Day 21 retake rides the Window 3 trigger.

## Design section 3: UI + tokens (APPROVED by Noah, 2026-11-08)
Mockup: `.superpowers/brainstorm/2278-1794118967/content/section3-top-marker.html`.
- **Test runner:** reuse the Phase 1 assessment screen as is (back, close = save & exit, thin `neutralAccent` progress bar with no count, glass answer cards with selected left accent). One statement per screen, tap saves + advances. No per-domain background tint.
- **Hub card:** quiet `surface` card with a text-link action, never a filled button (the hub keeps its one primary CTA).
- **Results:** `CustomPainter` wheel in the user's current `zoneColor`, shape filled at low alpha; outer ring of four quiet arcs grouping spokes Self / Others / Standing / World, three domains each (grouping = Claude's call, display order only, never touches scoring). Hero card below (glass, zone hairline, "Where you're most held" + domain label) and one primary CTA "Begin the drill". Tap a spoke to read its label. No numbers.
- **Top spoke: GLOW** (Noah chose option A over a non-glowing ring, 2026-11-08, knowing it is an exception to MASTER.md's "brightness = energy" rule). Record it in MASTER.md as a named exception when the tokens land, so a later anti-pattern sweep doesn't "fix" it.
- **Day 21 retake:** first map as dashed `textFaint` outline under today's filled shape; a low-confidence map's outline is dashed with one quiet caption (copy goes through the gate).
- **Motion:** shape fades in with existing `reveal`; never grows from center (anti-pattern 6).
- **New MASTER.md tokens:** `wheelFill` (zoneColor @ 18%), `wheelGrid` (white @ 7%), `priorShape` (textFaint, dashed), plus the glow exception above.

## Design section 4: question bank (APPROVED by Noah, 2026-11-08)
- 48 statements, 4 per domain: 3 forward ("agree = this holds me") + 1 reverse, reverse paired with one forward item asking the same thing from the other side (drives the contradiction check).
- Every statement: first person, behavioral, present tense (what you do, not what you feel/believe); one idea, under ~15 words, plain reading level; original wording only (no Abke/SQ items, no book vocabulary = leak class 3); no diagnosis/clinical/shaming/verdict tone; no em dashes; reads sensibly on all 5 Likert options.
- Text lives in Dart (`block_map_items.dart`, keys like `self_perfectionism_1`); DB seed holds key/domain/reverse/pair only. User-facing domain labels reuse `drill_questions.dart`.
- Gate: cold rubric judge pass (M2.4 method): fresh model, no authorship memory, scores each item on the rules above + reverse truly opposes its pair + each domain distinct from neighbors + all four mechanic-leak classes. Fail = rewrite + re-judge. Then Noah reads all 48 and approves before seeding.
- Model tier: drafting = Sonnet against the rubric; judge = fresh Sonnet.
- Also in scope: intro primer (our own honesty framing, e.g. "when torn, pick the lower answer") and the low-confidence caption, same gate.

## Next: author the question bank (Sonnet) + cold rubric judge gate + Noah read-through, then write the spec doc here and run writing-plans.

---

## Noah's pasted reference spec (verbatim, 2026-11-08)

# Levels App: Assessment, Results & Guided-Session UI Spec

> **Purpose.** This is a build spec for Claude Code covering the UI for (1) a self-assessment test, (2) a multi-tab results dashboard, and (3) a step-by-step guided-practice flow inside the **Levels** app (FlutterFlow + Supabase).
>
> **Source.** These are layout and interaction patterns observed by watching Aaron Abke's public YouTube demos of his SQ Test results app ("The 4DU Lab") and his Menu Work session web app. Both are Lovable builds. All screens below were captured from video frames; anything inferred rather than seen is marked **(inferred)**.
>
> **Ground rule.** Reuse the *patterns* (layouts, chart types, flows, interactions), **not** his content. His level names, 30 category names, question statements, copy, "structures" list and logos are his IP. Everything content-related here is a placeholder config. Fill it from the Levels app's own framework and its 1–1000 scale. The observed reference values in §9 are there only so you understand the layout density. **Do not ship them.**

---

## 0. Quick map

| # | Surface | What it is | Observed in |
|---|---------|-----------|-------------|
| A | Auth screen | Dark card, Google + email sign-in | the4dulab.lovable.app |
| B | Test runner | One statement per screen, 5-option Likert, chakra-tinted dark gradient | SQ Test video 5:17–5:30 |
| C | Results dashboard | 7 tabs: Overview, Integration Map, Occlusion Index, Vertical SQ, Inner Balance, Honesty Meter, Progress | SQ Test video 14:00–15:50 |
| D | Guided session | Card-based wizard with Back / step label / help, yes-no branching, numbered menu | Menu Work Q&A 50:05–52:30 |

Videos: SQ Test intro https://www.youtube.com/watch?v=4v1y2V9iOOI · Menu Work Q&A https://www.youtube.com/watch?v=u7RPx2Fu1gY

---

## 1. Design system

### 1.1 Results dashboard (light, "sacred-manuscript" feel)
- **Page background:** very pale mint/cream (`~#F4F8F2`). Chart cards use a warm parchment radial gradient (`~#FBF7F0` center → `~#EDE6DA` edges).
- **Display type:** small-caps serif with wide tracking for tab labels, section headers, category labels and level names. Looks like **Cinzel** or a similar Trajan-style face.
- **Body / subtitles:** italic old-style serif, e.g. *"how integrated you are across all 30 facets of consciousness"*. Looks like **Cormorant Garamond Italic**.
- **Numbers:** the same serif, bold (score `3.7`), with the percentage on a smaller line beneath (`75%`).
- **Score pill:** a rounded-full pill with an indigo→violet gradient (`~#3B3A8F → #7B4FA6`), white small-caps text, e.g. `SQ SCORE: 122.8 · AWAKENING`.
- **Balanced/blocked split bar:** a horizontal bar, blue fill (`~#3A7BD5`) for the balanced % and red (`~#D9443A`) for the remainder. Thin (6–8px), rounded ends.
- **Cards:** white, ~12px radius, 1px hairline border (`~#E6E2DA`), subtle shadow, generous padding.
- **Modals:** pale mint card, ~16px radius, centered, dimmed backdrop, circular outlined close (×) button top-right in the accent green.

### 1.2 Level / chakra color tokens
Each level has one hue. It is used for the row tint, label text, radar arc segment, chip outline, dot markers and progress band.

| Token | Hue (approx.) | Row tint (≈10% alpha) |
|------|---------------|-----------------------|
| `level1` (root) | red `#C8372D` | `#FBE9E6` |
| `level2` (sacral) | orange `#E0802A` | `#FCEFE3` |
| `level3` (solar plexus) | gold `#D4B21F` | `#FBF6E0` |
| `level4` (heart) | green `#3E9B4F` | `#E8F4EA` |
| `level5` (throat) | sky blue `#2E8FCB` | `#E6F2F9` |
| `level6` (third eye) | violet `#6A4BC4` | `#EEEAF8` |

> Levels uses a 1–1000 scale, so map these hues onto Levels' own bands. The *pattern* is: one hue per tier, reused consistently everywhere.

### 1.3 Test runner (dark, immersive)
- Full-bleed **dark gradient** tinted with the current category's level hue. A heart-tier question showed deep forest green → teal-black.
- Prompt above the card: italic, ~22px, white at 85% opacity, e.g. *"How accurately does this reflect you?"*
- Statement card: translucent white (~6–8% fill), 1px white-15% border, ~12px radius, ~26px semibold geometric sans (looks like **Manrope**).
- Options: 5 full-width stacked buttons with the same translucent style, left-aligned ~17px text (looks like **Lato**). Hover/selected state is a brighter fill (~14%) and a brighter border.

### 1.4 Guided session (dark, focused)
- Near-black page (`~#0B0F0C`). Centered card `~#151C17`, max-width ~560px, ~12px radius, faint border.
- **Accent:** neon lime green (`~#7ED957`). Used for H1 headings (serif, e.g. "Arrive", "Calibrate"), primary buttons (filled lime, dark text), and the progress underline.
- Body: off-white sans ~15px, line-height 1.6.
- Secondary button: near-black fill with off-white text (the "No" in yes/no pairs).
- List rows: dark-teal tinted rows (`~#1E3A33`), ~8px radius, serif text. The row brightens on hover.

### 1.5 Auth screen
- Charcoal background (`~#0F1513`) with a centered card (`~#18201E`) and a teal accent circle/logo on top (`~#16A3B8`).
- Small-caps serif title "Welcome back" and a muted subtitle.
- Optional info callout box with a teal-tinted border.
- "Continue with Google" button, "or with email" divider, email + password inputs, a full-width teal primary button, a "Forgot password?" link, and a "New here? Create an account" link.

---

## 2. Data model (Supabase)

Content-agnostic, so Levels can plug in its own taxonomy.

```sql
-- Framework (config, seeded by you)
tiers(id, slug, name, order, color_hex, band_min, band_max, weight)        -- weight lets one tier count double (observed: lowest tier scored /50, others /25)
categories(id, tier_id, slug, name, kind)                                   -- kind: 'blockage' (lower tiers) | 'quality' (upper tiers)
items(id, category_id, statement, reverse_scored bool, consistency_group)  -- N statements per category, shown in random order
quality_blockage_links(quality_id, blockage_id, short_reason)              -- powers Occlusion Index ("feels unworthy of joy")

-- User data
assessments(id, user_id, started_at, completed_at, total_score, tier_label, confidence enum('low','moderate','high'))
responses(assessment_id, item_id, value smallint 0..4, answered_at)        -- autosave per answer; resume anytime
category_scores(assessment_id, category_id, score numeric(3,2), pct numeric(5,2))  -- score 0–5, pct = score/5
tier_scores(assessment_id, tier_id, score numeric)                          -- sum of its categories × tier.weight
honesty_checks(assessment_id, check enum('inflation','denial','contradiction'), status enum('clear','flagged'), flagged_item_ids int[])

-- Guided session
session_protocols(id, slug, title, steps jsonb)                             -- data-driven step graph (see §6)
session_runs(id, user_id, protocol_id, started_at, finished_at, path jsonb) -- which branch was taken
journal_entries(id, user_id, kind, ref_id, value numeric, note text, created_at)  -- e.g. 0–10 calibration readings over time
```

**Scoring as observed (adapt to Levels' 1–1000):**
- Likert 5 options → item value 0–4 (or 1–5). Category score = normalized mean on a **0–5** scale, shown to 1 decimal. Percent = score ÷ 5.
- Tier score = sum of its 5 category scores (max 25). The lowest tier was shown **/50** (its sum doubled). Total = sum of tiers, so max 175, and each tier owns a band (1–50, 50–75, 75–100 … 150–175).
- For Levels, keep the same mechanics but rescale the total to 1–1000 and set bands to Levels' own tiers.

---

## 3. Screen B — Test runner

**Flow:** Intro / rules screen → items one at a time (randomized across categories) → autosave on every tap → finish → compute → route to Results.

**Layout (mobile-first, centered column, max-width ~620px):**
```
[ gradient bg tinted by current item's tier hue ]
  How accurately does this reflect you?          ← italic prompt
  ┌──────────────────────────────────────────┐
  │  <Statement text, 2–3 lines>             │   ← statement card
  └──────────────────────────────────────────┘
  [ Not at all like me                       ]
  [ Rarely like me                           ]
  [ Sometimes like me                        ]   ← 5 stacked option buttons
  [ Often like me                            ]
  [ Always like me                           ]
```
- Tapping an option saves it and advances, with a short crossfade (~250ms) of the statement and the background tint.
- **Progress, back button and save/exit were not visible in the frames I captured.** The video says progress saves and you can resume across sessions. **(inferred)** Add a slim top progress bar, a back arrow, and "Save & exit". The video also tells users *not* to count questions, so consider hiding the numeric count and showing only a thin bar.
- Rules screen copy pattern: honesty framing, answer from feeling not thinking, when torn pick the lower answer, take breaks, about 1 hour. Write your own version.

---

## 4. Screen C — Results dashboard

**Shell:**
- Top bar: logo + product title (serif) on the left, `BACK TO DASHBOARD` (small caps, muted) on the right.
- **Tab bar:** horizontal small-caps tabs with a 2px green underline on the active tab. They wrap to two lines on narrow widths. Tabs: `OVERVIEW · INTEGRATION MAP · OCCLUSION INDEX · VERTICAL SQ · INNER BALANCE · HONESTY METER · SQ PROGRESS`. Rename for Levels.

### 4.1 Overview tab
1. **Header row:** score pill on the left (`SCORE: 122.8 · <TIER NAME>`). Legend on the right: blue dot `BALANCED`, red dot `BLOCKED`, italic `(each category scored 0–5)`.
2. **Tier rows**, highest tier at the top and lowest at the bottom. Each row is a full-width rounded panel tinted with the tier color:
   - Left (~22%): tier name in tier color (small caps), a thin connector line, then a **tier medallion**. The medallion is a circular mandala/lotus icon in the tier hue with the tier score inside (`18.5` over `/25`).
   - Right (~78%): **5 category cells** in a row. Each cell shows a bold score `3.7`, a percent `75%`, the blue/red split bar, and the category label in small caps beneath.
3. **"WHERE TO FOCUS"** section:
   - Header plus italic hint *"Tap any blockage below to explore it in depth."*
   - Three columns: **MAJOR BLOCKAGES** (red header), **MODERATE BLOCKAGES** (amber), **MINOR BLOCKAGES** (green).
   - Each item is a white card with a tier-colored dot, the name in small caps, and score + % right-aligned. Lists are sorted ascending.
   - Bucket thresholds **(inferred from values seen)**: major < 2.5, moderate 2.5–3.4, minor ≥ 3.5. Only blockage-type categories are listed.
   - Tap → detail modal for that blockage. Content not captured; mirror the Occlusion modal pattern.

### 4.2 Integration Map tab
- Parchment card, title `THE INTEGRATION MAP` (small caps) plus an italic subtitle. A small score pill sits top-right.
- **30-axis radar chart.** Concentric light gridlines and a grey translucent filled polygon of the user's category %s. Each vertex has a dot in its tier color.
- Around the outside is a **thick colored ring split into 6 arcs**, one per tier color, each spanning that tier's 5 axes. Category labels sit just outside in small caps, colored by tier.
- Legend row at the bottom: colored dot + tier name for all 6.
- What it communicates: a perfectly round polygon means even integration, and dents show weak areas.
- Flutter: `fl_chart` RadarChart for the polygon, plus a `CustomPainter` for the segmented outer ring and labels.

### 4.3 Occlusion Index tab
- Title `THE OCCLUSION INDEX` (large small caps) and an italic explainer: upper qualities are dimmed by lower blockages; tap one to see which, and what to clear first.
- One panel per **upper tier** (`HEART QUALITIES`, `THROAT QUALITIES`, `THIRD EYE QUALITIES`), tinted with the tier color.
- Each panel holds **5 quality cards** in a row. A card shows the name (serif small caps, truncated with … if long), a large `%`, a status on the right (`unblocked` or `N dimming`), a progress bar in the tier hue, and `TAP FOR DETAILS`.
- **Quality modal:**
  - Header: big serif quality name, `63% ACTIVATED · UNBLOCKED`, and an italic sub like *"Heart Quality — activation work"*.
  - Below that, a list of **linked blockages**. Each has its name in its tier color (small caps), `61% CLEARED` right-aligned, a full-width progress bar in the blockage's tier color, and a one-line italic reason (from `quality_blockage_links.short_reason`).
  - **(inferred)** Recommended practices, which the video describes as "custom guidance," likely sit below the list.
- **(inferred)** The "dimming" count is the number of linked blockages under the unblocking ceiling (3.0/5).

### 4.4 Vertical SQ tab
- Present in the tab bar but **never opened in the demo**. No visual reference. Leave it as a placeholder or define it yourself (e.g., a vertical per-tier bar stack).

### 4.5 Inner Balance tab
- Title `INNER BALANCE` and an italic sub: *how cleared your blockages are, weighed against how activated your qualities are.*
- **Seesaw chart:**
  - Y-axis 0–5. A dashed horizontal line at 3.0 is labeled *"Unblocking ceiling (3.0)"*.
  - Background zones: a pink-tinted `BLOCKAGE ZONE` (left, below the line) and a lavender `ACTIVATION ZONE` (right, above the line).
  - Two tall rounded bars: a **red** left bar (average blockage-cleared score) and a **violet** right bar (average quality-activated score). Each is topped by a glossy sphere and labeled above with a big `%` and `3.40 / 5`.
  - A brown **beam** connects the two spheres over a beige triangular **fulcrum** in the middle. The beam tilts based on the difference.
  - Below the bars: `BLOCKAGES` / *cleared* and `QUALITIES` / *activated*.
  - One-line italic verdict, e.g. *"You're in balance — keep clearing and begin activating to rise higher."* Write your own rule-based messages.
- **Compare picker:**
  - `BY BLOCKAGE` row of outline pills in tier colors, then `BY QUALITY` row of pills.
  - Selecting one of each fills them (solid tier color, white text) and redraws the seesaw for that pair. The heading reads e.g. `PRIDE CLEARED · HUMILITY ACTIVATED`.
  - **(inferred)** Choosing a blockage narrows the quality row to its linked qualities. After selecting Pride, only 5 quality pills showed.
- Flutter: `CustomPainter`, animating the beam angle with an implicit animation.

### 4.6 Honesty Meter tab
- Title `TEST-TAKING HONESTY` and italic sub *"how self-honest your responses read — a gift, not a grade."*
- Label `CONFIDENCE: HIGH` with a ▼ pointer above a **3-segment bar**: `LOW` (muted red), `MODERATE` (muted amber), `HIGH` (green). The active segment is saturated and the others are washed out.
- **3 check cards**: `INFLATION`, `DENIAL`, `CONTRADICTION`. Each shows `✓ CLEAR` in green (or flagged) and `TAP FOR DETAILS`.
- Card modal: title (e.g. `DENIAL`), sub *"The answers behind this reading."*, then the list of flagged answers or *"Nothing flagged here — no answers to revisit."*, plus a reassurance line that a flag never changes the score.
- Footer copy: responses read as self-honest; the score is unchanged; this tells you how much to trust the result.
- Logic **(inferred)**:
  - *Inflation*: too many top-end answers.
  - *Denial*: reverse-scored or "shadow" items answered implausibly low.
  - *Contradiction*: variance within a `consistency_group` above a threshold.
  - Any flag sets the assessment's `confidence` to low or moderate.

### 4.7 Progress tab
1. Header: score pill `LATEST SQ: 122.9 · AWAKENING` on the left. On the right, green small caps `+11.9 SINCE YOUR FIRST TEST (3 TESTS)`.
2. **`GLOBAL SQ OVER TIME`** card:
   - Line chart with x = test dates and y = 1–175.
   - The background is **horizontal bands tinted per tier**, with tier names and ranges labeled on the right edge (e.g. `ILLUMINATION 150–175` … `SURVIVAL 1–50`).
   - Violet line with filled dots. **Hollow/dashed dots mark low-confidence tests.**
   - Legend: ● High confidence ○ Low confidence.
3. **Test history list**: two-column grid of cards. Each card shows the date, a `LOW CONFIDENCE` tag when applicable, and right-aligned `116.2 · AWAKENING`. Caption warns that comparing against low-confidence tests can show false movement.
4. **`THE THIRTY CATEGORIES OVER TIME`**:
   - Italic sub. A wrap of **filter chips**: `ALL CHAKRAS` plus one chip per category, outlined in tier color and filled when selected.
   - With *All*: a 3×2 grid of **small-multiple line charts**, one per tier, each showing its 5 categories as lines in shades of the tier hue, y 0–100%, with a legend under each.
   - With one category selected: a single large line chart for that category in its tier color. Hollow points again mark low-confidence tests.

---

## 5. Screen A — Auth
See §1.5. Standard Supabase auth (Google OAuth + email/password), redirect back to the requested route after login (observed: `/auth?mode=signin&redirect=/home`).

---

## 6. Screen D — Guided session (data-driven wizard)

Build this as a **generic step engine** driven by `session_protocols.steps` JSON, so new practices can be added without new UI.

**Shell:**
- Top nav: small logo + wordmark (small caps) on the left. Links on the right: `PROTOCOL`, `ABOUT`, plus a parent-site link.
- Card header: `← Back` on the left, a centered small-caps step label (e.g. `PROTOCOL 1 · STRUCTURE`), and a `?` help icon on the right.
- Under the header, a thin lime progress line that grows per step.
- Footer: logo, one-line tagline, © line.

**Step types observed:**

| type | UI | Example screen |
|------|----|----------------|
| `landing` | Big logo, small-caps eyebrow, H1, italic subtitle, primary CTA "Begin Session", tiny footer caption | Session start |
| `instruction` | H1 + paragraphs + one primary button | "Arrive" (center, breathe, ask for guidance → Continue) |
| `instruction_with_example` | H1 + paragraph + "Example:" lines + primary button | "Calibrate" (test a true and a false statement → "I'm Calibrated — Let's Begin") |
| `menu` | H1 + hint + vertical list of tappable option rows | "Open the Menu" (4 top-level practices) |
| `binary_search_hint` | H1 + instructions for narrowing a numbered list by halves (1–6? then 7–12?) + button to reveal list | "Identify the …" |
| `numbered_list` | H1 + list rows, each with a faint index number on the left. **(inferred option)** In the video he narrows by number before reading names, to avoid bias; you could hide names until a number is picked | "The 12 …" |
| `detail_confirm` | H1 = selected item, a description paragraph, "Confirm: Is this the correct …?", then **No** (dark) / **Yes** (lime) side by side | item detail |
| `calibrate_value` | H1 + instruction to find a 0–10 value with one decimal + "Record this in your Journal" + Continue | "Calibrate Congruence" |
| `yes_no` | H1 + question in quotes + No / Yes buttons, each routing to a different next step | "Move Up the Tree", "Already Identified?" |
| `checklist_prompt` | H1 + intro line + bullet questions + "Write all this down." + "Proceed to Next Step" | "Identify the Sequence" |

**Engine JSON sketch:**
```json
{
  "slug": "protocol-1",
  "steps": {
    "start":   {"type":"landing","title":"<Practice name>","subtitle":"<tagline>","cta":"Begin Session","next":"arrive"},
    "arrive":  {"type":"instruction","title":"Arrive","body":["..."],"cta":"Continue","next":"calibrate"},
    "calibrate":{"type":"instruction_with_example","title":"Calibrate","body":["..."],"examples":["...","..."],"cta":"I'm ready","next":"menu"},
    "menu":    {"type":"menu","title":"Open the Menu","hint":"...","options":[{"label":"Option A","next":"a_identify"},{"label":"Option B","next":"b_start"}]},
    "a_identify":{"type":"binary_search_hint","title":"Identify the item","body":["..."],"cta":"View list","next":"a_list"},
    "a_list":  {"type":"numbered_list","title":"The N items","source":"items_table","onSelect":"a_detail"},
    "a_detail":{"type":"detail_confirm","yes":"a_calibrate","no":"a_list"},
    "a_calibrate":{"type":"calibrate_value","min":0,"max":10,"step":0.1,"journal_kind":"item_congruence","next":"a_tree"},
    "a_tree":  {"type":"yes_no","title":"Go deeper?","question":"...","yes":"a_known","no":"end"}
  }
}
```
- Persist the run path in `session_runs.path` and any `calibrate_value` readings in `journal_entries`. That gives you a "congruence over time" chart for free, reusing the §4.7 line-chart component.
- **Levels-specific:** replace muscle-testing steps with whatever input method Levels uses (self-rating slider, reflection prompt, etc.). The wizard engine itself doesn't care.

---

## 7. Interaction and motion
- Tabs: content crossfade ~200ms; underline slides between tabs.
- Modals: fade + scale 0.96→1, backdrop dims to ~40% black.
- Charts animate in on first view (radar polygon grows from center; seesaw beam settles with a light spring).
- Chips: outline → filled transition 150ms.
- Test runner: background hue tween between tiers ~400ms.

## 8. Responsive notes
- Desktop demo widths were ~1200px. On mobile:
  - Overview tier rows stack: medallion and name on top, then a 5-cell grid that wraps to 3 + 2 (or becomes horizontal scroll).
  - Occlusion cards become 2-up.
  - Where-to-Focus columns become stacked sections.
  - Progress small multiples become 1-up.
  - The tab bar becomes a horizontally scrollable row.
- The test runner and guided-session card are already single-column and phone-friendly.

---

## 9. Observed reference values (for layout only — DO NOT SHIP)
These show the density and shape of the data in the demo. Replace every name with Levels' own taxonomy.
- 6 tiers × 5 categories = 30 categories. Lower 3 tiers are "blockage" kind, upper 3 are "quality" kind.
- 6 statements per category, 180 items total, about 1 hour.
- Results example: total 122.8, tier scores ~15–19 /25 (lowest tier 35.5 /50), category scores 2.0–4.3, Inner Balance 3.40 vs 3.61.
- Guided session: 4 top-level menu options at launch, growing weekly. One sub-list had 12 numbered items. Calibration used 0–10 with one decimal.

## 10. Build checklist for Claude Code
1. Seed `tiers`, `categories`, `items`, `quality_blockage_links` from **Levels' framework** (ask Noah for the taxonomy and scale mapping).
2. Build a shared theme: tier color tokens, serif display + italic + sans font roles, the pill, split bar, card and modal components.
3. Build the test runner with autosave/resume and randomized order.
4. Build the scoring function in a Supabase edge function or Postgres function: category → tier → total, plus honesty checks.
5. Build the results shell and tabs in this order: Overview → Integration Map → Progress → Occlusion → Inner Balance → Honesty → (Vertical, your own design).
6. Build the generic wizard engine and one sample protocol.
7. Check each screen on a phone width before calling it done.


---

## Question bank draft + cold judge gate (2026-11-08, Sonnet)
Files: `lib/features/block_map/block_map_items.dart` (48 items, primer, caption), `test/block_map_items_test.dart` (structure + copy-rule pins).

**Gate status: NOT fully met.** Four cold judge passes (fresh Sonnet each). Item FAILs per pass: 16 (round 1), 7 (round 2), 6 (round 3), 4 (round 4, targeted at the 6 items changed after round 3). The same four reverse items (`existential_catastrophic_4`, `status_achievement_4`, `relational_reciprocity_4`, `societal_comparative_4`) kept failing R7/R1 with a different complaint each round, so I stopped looping and applied the round-4 rewrites without a fifth pass. Those four are the ones to read hardest. Every other item passed its last judged round. Primer: PASS rounds 2-3 (round 1 FAIL for "choose the lower one", removed). Caption: now "Check this against what you know about yourself." PASS round 4.

**Final items**

| item_key | statement | status |
|---|---|---|
| relational_attachment_1 | I reread messages from people close to me, looking for signs they're pulling away. | PASS (last judged) |
| relational_attachment_2 | I hold on to relationships I know aren't working. | PASS (last judged) |
| relational_attachment_3 | When someone close goes quiet, I assume I did something wrong. | PASS (last judged) |
| relational_attachment_4 | When a close friend is slow to reply, I assume they're busy. | PASS (last judged) |
| adequacy_impostor_1 | When things go well, I wait for someone to find out I'm less capable. | PASS (last judged) |
| adequacy_impostor_2 | When someone praises my work, I assume they're being generous. | PASS (last judged) |
| adequacy_impostor_3 | I over-prepare so no one sees what I don't know. | PASS (last judged) |
| adequacy_impostor_4 | When I'm trusted with something, I take it as a fair read of me. | PASS (last judged) |
| existential_catastrophic_1 | I picture the world getting worse in ways I can't do anything about. | PASS (last judged) |
| existential_catastrophic_2 | News about large-scale problems stays on my mind for days. | PASS (last judged) |
| existential_catastrophic_3 | I hold off on long-term plans when the world feels unstable. | PASS (last judged) |
| existential_catastrophic_4 | When I think about where the world is headed, I picture things holding together. | REWRITTEN after FAIL, not re-judged |
| autonomy_sovereignty_1 | I let other people decide how my days go. | PASS (last judged) |
| autonomy_sovereignty_2 | I drop my own plans when someone else wants something. | PASS (last judged) |
| autonomy_sovereignty_3 | I put up with situations I didn't choose instead of trying to change them. | PASS (last judged) |
| autonomy_sovereignty_4 | I decide for myself how my days go. | PASS (last judged) |
| status_achievement_1 | I make sure people know about what I've achieved. | PASS (last judged) |
| status_achievement_2 | I wait for someone else to notice a win before I let myself enjoy it. | PASS (last judged) |
| status_achievement_3 | I judge a day as good or bad by what I accomplished. | PASS (last judged) |
| status_achievement_4 | I'm fine with people not knowing what I've achieved. | REWRITTEN after FAIL, not re-judged |
| relational_reciprocity_1 | I keep track of who has done what for whom. | PASS (last judged) |
| relational_reciprocity_2 | When I give more than I get, I start to pull back. | PASS (last judged) |
| relational_reciprocity_3 | I avoid accepting help I can't pay back. | PASS (last judged) |
| relational_reciprocity_4 | I give and receive without keeping score. | REWRITTEN after FAIL, not re-judged |
| ideological_systemic_1 | When I deal with institutions, I brace for being treated unfairly. | PASS (last judged) |
| ideological_systemic_2 | I read official rules and forms looking for the catch. | PASS (last judged) |
| ideological_systemic_3 | I skip applying for things when I assume the odds are stacked. | PASS (last judged) |
| ideological_systemic_4 | When I deal with institutions, I expect to be treated fairly. | PASS (last judged) |
| internal_self_directed_1 | I talk to myself in ways I'd never talk to a friend. | PASS (last judged) |
| internal_self_directed_2 | When I make a mistake, the voice in my head turns harsh. | PASS (last judged) |
| internal_self_directed_3 | I replay things I said or did and criticize myself for them. | PASS (last judged) |
| internal_self_directed_4 | I speak to myself as kindly as I would to a friend. | PASS (last judged) |
| internalized_authority_1 | Around bosses or authority figures, I get quieter and more careful. | PASS (last judged) |
| internalized_authority_2 | I follow rules I disagree with rather than risk disapproval. | PASS (last judged) |
| internalized_authority_3 | Before I decide, I think about what the people in charge would want. | PASS (last judged) |
| internalized_authority_4 | I speak up to bosses or authority figures as easily as to anyone. | PASS (last judged) |
| societal_comparative_1 | I compare my life to other people's lives, even strangers'. | PASS (last judged) |
| societal_comparative_2 | I measure myself against where other people my age are. | PASS (last judged) |
| societal_comparative_3 | After scrolling through other people's lives, I think less of my own. | PASS (last judged) |
| societal_comparative_4 | I notice how others are doing without comparing my life to theirs. | REWRITTEN after FAIL, not re-judged |
| self_perfectionism_1 | I keep reworking things long after others would call them finished. | PASS (last judged) |
| self_perfectionism_2 | I hold my own work to a higher standard than I'd hold anyone else's. | PASS (last judged) |
| self_perfectionism_3 | Even when it's done well, I notice only what could be better. | PASS (last judged) |
| self_perfectionism_4 | I stop working on something once it does the job. | PASS (last judged) |
| visibility_fear_1 | In groups, I hold back my ideas so I don't stand out. | PASS (last judged) |
| visibility_fear_2 | I avoid being the center of attention whenever I can. | PASS (last judged) |
| visibility_fear_3 | I let others take credit rather than put myself forward. | PASS (last judged) |
| visibility_fear_4 | In groups, I share my ideas when I have them. | PASS (last judged) |

**Open findings from the judges (design calls, not copy fails)**
- Reverse items are mostly the flattering option ("kindly", "fairly", "easily"), so they partly measure social desirability and will skew high; pair checks may flag noisily.
- `_4` is always the reverse item and always pairs with `_1`. The runner must shuffle (section 2 already has `item_order`), never render canonical order.
- Weak pair: `relational_attachment_4` opposes `_3` more tightly than `_1`; consider re-pairing it with `_3` in the seed.
- Expect `internalized_authority` and `visibility_fear` to co-move, and `adequacy_impostor_3` / `self_perfectionism_1` to blur.
- `ideological_systemic_4` and `autonomy_sovereignty_4`: low answers can be accurate for people facing real unfair treatment or structural limits. Downstream domain copy needs care.
- Primer says "Your answers save as you go": true only once autosave-per-tap ships (section 2). Verify before release.
- Likert middle labels not chosen yet (endpoints locked: "Not at all like me" / "Always like me").

**Reverse-item rewrite: cold judge log (2026-11-08, fresh Sonnet judge each round, rubric = section 4 rules + "not the flattering option" + "truly opposes its pair")**

Round 1 (all 12 rewritten): 5 PASS (existential_catastrophic_4, relational_reciprocity_4, ideological_systemic_4, internalized_authority_4, self_perfectionism_4), 7 FAIL. Judge finding: indifference ("barely notice") is not the opposite of anxiety or comparison; several items were the healthy pole with a thin cost clause.

Round 2 (the 7 failures rewritten, new judge): 3 PASS (relational_attachment_4, autonomy_sovereignty_4, societal_comparative_4), 4 FAIL:

| key | statement (current in Dart) | failed | reason |
|---|---|---|---|
| adequacy_impostor_4 | When things go well, I take the credit, even when others helped. | opposes pair, domain drift | grabbing credit is not the opposite of fearing exposure; drifts into status |
| status_achievement_4 | I let my wins go unmentioned unless someone asks me directly. | flattering, domain drift | modesty with no cost; overlaps visibility_fear |
| internal_self_directed_4 | I brush off my own mistakes without much thought. | opposes pair | indifference is not the opposite of harsh self-talk |
| visibility_fear_4 | In groups, I voice ideas before I've fully thought them through. | opposes pair | measures impulsivity, not the absence of holding back |

Round 2 suggested rewrites circle back to wording round 1 failed. For these 4 domains the true opposite of the pattern is the healthy pole, so "opposes its pair" and "not flattering" conflict. Stopped rewriting; design call queued for Noah.

Noah's call on the 4 (2026-11-08): **true opposite, accept skew.** For adequacy_impostor_4, status_achievement_4, internal_self_directed_4, visibility_fear_4 the reverse item is the plain healthy opposite; flattery is a documented, accepted skew (honesty flags only lower confidence and are tunable by migration). Later judges were told not to fail these for flattery.

Round 3 (true-opposite wording, new judge): PASS internal_self_directed_4 ("When I make a mistake, I talk to myself the way I'd talk to a friend."), PASS visibility_fear_4 ("In groups, I share my ideas when I have them."). FAIL adequacy_impostor_4 ("...I take it as a fair sign of what I can do.": a belief, not a behavior) and status_achievement_4 ("I leave it to others to notice what I've achieved.": nearly restates _2, drifts into visibility_fear).

Round 4 (new judge): both FAIL again.
- adequacy_impostor_4 "When things go well, I accept the result as mine and move on.": two actions; owning a result is not the opposite of bracing for exposure.
- status_achievement_4 "I mention my achievements only when they come up naturally.": "only" muddles with "Not at all like me"; "naturally" is vague.
Round 4's status suggestion ("go unmentioned unless someone asks") is the round 2 wording that failed for visibility_fear overlap, so the judges are cycling. **Stopped: these 2 stay at the round-4 wording and go to Noah's read-through as open items.** 10/12 reverse items PASS.

Final wording, Noah's pick (2026-11-08), closing the 2 open items:
- adequacy_impostor_4: "When my work goes well, I share it without bracing for it to be picked apart."
- status_achievement_4: "I talk about my achievements about as much as anything else."
