<!-- Purpose: design doc for the block map, an optional 48-item instrument that suggests the Phase 3 origin domain. Source: approved sections 1-4 + decisions in 2026-11-08-block-map-brainstorm-notes.md (that file is the decision log; this file is the buildable spec). -->

# Block map: design

Status: APPROVED by Noah, 2026-11-08, including the three section 10 calls (marked **(new, approved)**).

## 1. What it is

An optional, deeper self-assessment offered after the Phase 2 reveal. 48 statements, one per screen, 5-point Likert. It ranks the 12 existing `origin_domain` values and preselects the top one as the Phase 3 drill's domain. The user can confirm, take one of the next two, or pick any of the 12.

It does not touch Phase 1, the CoG score, zones, or classification. The 7-question assessment stays as is.

**Hooked map:** the hub card is an internal trigger (curiosity after the reveal). Answering is Action, and every saved answer is Investment. The wheel is the Variable Reward: the shape is new each time, and the copy is fixed. The Day 21 retake rides the existing Window 3 external trigger. **Ethics:** no numbers, no labels as identity. Honesty flags only lower confidence and never change the result. The suggestion is always overridable.

## 2. Flow

1. **Hub card** appears once the loop has a Phase 2 dashboard row and no completed `initial` block map. It's a quiet `surface` card with a text-link action, never a filled button, because the hub keeps its one primary CTA.
2. **Primer screen:** `blockMapPrimerTitle` + `blockMapPrimer` (`lib/features/block_map/block_map_items.dart`).
3. **Runner:** 48 items in the per-assessment shuffled `item_order`. Each tap upserts one response and advances. Back is allowed. Close means save and exit, and resume continues at the first unanswered item in `item_order`.
4. **Finish:** the client calls `score_block_map(id)`, then reads the row back. The result screen renders only from the DB row (the same rule as `AssessmentResult`).
5. **Results:** the wheel, plus a hero card ("Where you're most held" + domain label) and one primary CTA, "Begin the drill". The CTA opens the Phase 3 drill with the top domain preselected and the next two offered.
6. **Day 21 retake:** offered alongside Window 3. The new shape is filled, the first shape is a dashed outline under it, and there are no numbers.

## 3. Question bank (done)

`lib/features/block_map/block_map_items.dart`: 48 items, keyed `<origin_domain>_<1..4>`. `_1`..`_3` are forward and `_4` is reverse. Pairs: `_4` with `_1`, except `relational_attachment_4` with `_3`. Likert 0..4: "Not at all like me" / "Rarely like me" / "Sometimes like me" / "Often like me" / "Always like me". Cold judge log and decisions are in the notes. **Gate still open:** Noah's read-through of all 48 before the seed migration.

The Likert labels are not in Dart yet. They go in `block_map_items.dart` as `blockMapLikertLabels` (5 strings), pinned by the existing copy-rules test.

## 4. Scoring (pure, integer-only)

- effective = value for forward items, and 4 - value for reverse items.
- domain sum = the sum of its 4 effective values, 0..16. Sums, not means, so the Dart mirror has no float rounding.
- All 48 answers are required, otherwise raise.
- Rank descending by sum. Tie-break 1: more effective values >= 3. Tie-break 2: `origin_domain` enum order.

**Honesty checks** (thresholds tunable by migration):

| Flag | Fires when |
|---|---|
| `straight_line` | the same raw value on >= 40 of 48 items |
| `minimizing` | effective 0 on >= 36 of 48 items |
| `contradiction` | >= 3 of 12 pairs have \|effective(forward) - effective(reverse)\| >= 3 |

Confidence: 0 flags = `high`, 1 = `moderate`, 2+ = `low`.

Contradiction compares **effective** values. Both members of a pair measure the same thing once reversed, so a consistent person has a small difference.

**Known skew (accepted by Noah, 2026-11-08):** 4 reverse items (adequacy_impostor, status_achievement, internal_self_directed, visibility_fear) are the healthy pole and may draw inflated agreement. That only feeds the contradiction flag, which only lowers confidence. Tune it after real data exists.

## 5. Data

Migration 1 (one transaction; `CREATE TYPE` is fine in-transaction, only `ADD VALUE` is not):

- `CREATE TYPE block_map_kind AS ENUM ('initial','retake')`
- **(new, approved)** `CREATE TYPE block_map_flag AS ENUM ('straight_line','minimizing','contradiction')` and `CREATE TYPE block_map_confidence AS ENUM ('high','moderate','low')`. Section 2 left `flags` and `confidence` untyped. Enums match the repo's typed-token pattern, and each gets a Dart mirror in group 5.
- `block_map_items` (config): `item_key text PK`, `domain origin_domain NOT NULL`, `reverse_scored boolean NOT NULL`, `pair_key text NULL`, `position smallint UNIQUE NOT NULL` (canonical order 1..48). Seeded in this migration from the Dart bank's metadata. Authenticated SELECT only, no writes. No statement text.
- `block_map_assessments`: `id uuid PK default gen_random_uuid()`, `user_id uuid NOT NULL → users(id) ON DELETE CASCADE`, `loop_id uuid NOT NULL → ascension_loops(id) ON DELETE CASCADE`, `kind block_map_kind NOT NULL`, `item_order text[] NOT NULL` (48 keys, client-shuffled), `started_at timestamptz default now()`, `completed_at timestamptz NULL`, `domain_sums smallint[]` (12, enum order), `ranked_domains origin_domain[]` (12), `flags block_map_flag[]`, `confidence block_map_confidence`. `UNIQUE (loop_id, kind)`.
- `block_map_responses`: `assessment_id uuid → block_map_assessments(id) ON DELETE CASCADE`, `user_id uuid NOT NULL`, `item_key text → block_map_items`, `value smallint CHECK (value BETWEEN 0 AND 4)`, `answered_at timestamptz default now()`, `PK (assessment_id, item_key)`.
- `phase3_origin_drills` gains `suggested_origin_domain origin_domain NULL` and `block_map_assessment_id uuid NULL → block_map_assessments(id)`. The final pick stays in the existing `q2_domain`. Suggestion vs. pick mismatch is derived at query time and never stored.

**RLS** (`DROP POLICY IF EXISTS` before each `CREATE POLICY`): SELECT/INSERT/UPDATE on both user tables require `auth.uid() = user_id`. Response INSERT/UPDATE also require the parent assessment to be owned by the caller and `completed_at IS NULL`. Assessment UPDATE by the client is limited by policy to rows with `completed_at IS NULL`. Results columns are written only by `score_block_map`, which is SECURITY DEFINER. No DELETE policy on either table.

Migration 2, functions + grants:

- `compute_block_map(p_values smallint[])` → `(domain_sums smallint[], ranked_domains origin_domain[], flags block_map_flag[], confidence block_map_confidence)`. SECURITY INVOKER, STABLE, `SET search_path = public, pg_temp`. Takes 48 values in canonical `position` order. **(new, approved)** It reads reverse/pair metadata from `block_map_items` instead of hard-coding it, so the seed is the single DB source; that is why it is STABLE, not IMMUTABLE. Raises on length ≠ 48 or a null value.
- `score_block_map(p_assessment_id uuid)`: SECURITY DEFINER, `search_path` pinned, NOT FOUND guard, then the `auth.uid()` ownership guard (rule 8). It reads the responses, raises unless all 48 are present, orders them by `position`, calls the pure function, writes the results and `completed_at`, and returns the row. Idempotent: a second call on a completed row returns it unchanged.
- Grants: EXECUTE on both to `authenticated` only. Revoke from `anon` and `PUBLIC`.

## 6. Client

New `lib/features/block_map/`:

- `block_map_items.dart`: done. Add `blockMapLikertLabels`.
- `block_map_tokens.dart`: typed mirrors of `block_map_kind`, `block_map_flag`, `block_map_confidence`, with throwing `fromToken`.
- `block_map_scoring.dart`: an exact integer mirror of `compute_block_map`, used for instant preview only. The DB result wins.
- `block_map_controller.dart`: a `ChangeNotifier` that holds the assessment id, `item_order`, and answers. It does create-or-resume (`(loop_id, kind)` unique), an upsert per tap, and finish → RPC → read-back. Errors surface and are never swallowed.
- `block_map_screen.dart` (runner + primer) and `block_map_result_screen.dart`.
- `block_map_wheel.dart`: a `CustomPainter` with 12 spokes in display order, a filled shape at `wheelFill`, a `wheelGrid` grid, an outer ring of four quiet arcs (Self / Others / Standing / World, three domains each, display only), glow on the top spoke, and an optional `priorShape` dashed outline. Fades in with the existing `reveal` motion and never grows from the center.

**Runner reuse:** `assessment_screen.dart` keeps `_QuestionPage` and `_AnswerCard` private and coupled to `AssessmentController`. The first slice extracts them into a shared widget (pure refactor; the existing assessment tests must stay green) so both runners use the same visuals.

**Routes:** `/block-map` and `/block-map/result` stay private by default under `authRedirect`. They stay unreachable (no hub card) until the last slice lands.

**Drill hand-off:** `drill_controller.dart` accepts an optional `suggestedDomain` + `blockMapAssessmentId`, preselects the domain, and writes both new columns alongside `q2_domain`.

**MASTER.md:** add the tokens `wheelFill` (zoneColor @ 18%), `wheelGrid` (white @ 7%), and `priorShape` (textFaint, dashed). Record the named exception "top spoke glows" (Noah, 2026-11-08) so an anti-pattern sweep doesn't remove it.

## 7. Mirror-sync group 5 (new)

`compute_block_map` + `block_map_items` seed ↔ `block_map_scoring.dart` + item metadata in `block_map_items.dart` ↔ `block_map_tokens.dart` ↔ `test/block_map_mirror_test.dart` ↔ golden values in the `levels-verify` skill ↔ the CLAUDE.md sync map. A test pins that the Dart bank's key/domain/reverse/pair equal the seed (the seed SQL is generated from or checked against the Dart list in the same commit).

## 8. Copy still to write (cold-judge gated)

The hub card title and link, the results hero ("Where you're most held" is approved), the CTA ("Begin the drill" is approved), the spoke tap label (reuses the `drill_questions.dart` domain labels), the low-confidence caption (written: `blockMapLowConfidenceCaption`), the retake prompt, and the Self / Others / Standing / World ring labels (Claude's grouping, display only). All of it runs the four mechanic-leak checks and delete-ai-words.

## 9. Build slices (each one PR)

1. Shared runner widget extraction (refactor only).
2. Migration 1 (types, tables, RLS, seed, Phase 3 columns) via levels-dev-loop, MCP read-back. **Blocked on Noah's 48-item read-through.**
3. Migration 2 (functions, grants) + Dart scoring mirror + tokens + golden mirror tests + levels-verify golden values + CLAUDE.md sync map. Opus tier (mirror-sync).
4. Controller + runner + primer (route present, no hub card).
5. Wheel painter + result screen + MASTER.md tokens.
6. Drill hand-off + hub card + copy gate; this slice makes it reachable. Manual browser run end to end (release build, per CLAUDE.md).
7. Day 21 retake + prior-shape overlay.

## 10. Decisions closed (Noah, 2026-11-08)

1. Flag and confidence are typed enums (`block_map_flag`, `block_map_confidence`) with Dart mirrors.
2. `compute_block_map` reads reverse/pair metadata from `block_map_items` (STABLE), not hard-coded.
3. The hub card shows as soon as the loop's Phase 2 dashboard row exists.
