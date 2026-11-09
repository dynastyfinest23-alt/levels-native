<!-- Purpose: design doc for the block map, an optional 48-item instrument that suggests the Phase 3 origin domain. Source: approved sections 1-4 + decisions in 2026-11-08-block-map-brainstorm-notes.md (that file is the decision log; this file is the buildable spec). Revised 2026-11-08 after the Fable 5.1 review (docs/superpowers/reviews/2026-11-08-block-map-fable-review.md). -->

# Block map: design

Status: APPROVED by Noah, 2026-11-08. Revised the same day with the Fable 5.1 review findings and Noah's calls on its proposed cuts (section 10).

## 1. What it is

The block map is an optional, deeper self-assessment offered after the Phase 2 reveal. It has 48 statements, one per screen, answered on a 5-point Likert scale. It ranks the 12 existing `origin_domain` values and preselects the top one as the Phase 3 drill's domain. The user can confirm the top one, take one of the next two, or pick any of the 12.

It doesn't touch Phase 1, the CoG score, zones, or classification. The 7-question assessment stays as it is.

**Hooked map:** the hub card is the internal trigger (curiosity after the reveal). Answering is the Action, and each saved answer is Investment. The wheel is the Variable Reward: the shape is new each time and the copy is fixed. **Ethics:** no numbers, and no labels used as identity. Honesty flags only lower confidence and never change the result. The suggestion can always be overridden.

## 2. Flow

1. **Hub card.** It appears once the loop has a Phase 2 dashboard row and no completed `initial` block map. It's a quiet `surface` card with a text-link action, never a filled button, because the hub keeps its one primary CTA.
2. **Primer screen.** Shows `blockMapPrimerTitle` and `blockMapPrimer` (`lib/features/block_map/block_map_items.dart`).
3. **Runner.** The 48 items come in the shuffled `item_order` stored for that assessment. Each tap upserts one response and advances. Back is allowed. Closing saves and exits, and resuming continues at the first unanswered item in `item_order`. If the session is already completed (for example, browser Back from the result), the runner goes straight to the result route.
4. **Finish.** The client calls `score_block_map(id)` and then reads the row back. The result screen renders only from the DB row, the same rule as `AssessmentResult`.
5. **Results.** The wheel, a hero card ("Where you're most held" plus the domain label), and one primary CTA, "Begin the drill". The CTA opens the Phase 3 drill with the top domain preselected and the next two offered.
6. **Day 21 retake: DEFERRED to a later plan** (Noah, 2026-11-08, after the Fable review). The schema keeps `kind = 'retake'` and the route keeps `?kind=`, so the retake needs no re-migration. The later plan must cover a data-source call for the initial row (`fetchRowByKind`), the prior-shape overlay, and a cold-judge check that the overlay doesn't read as "I got worse".

## 3. Question bank (done)

The bank is in `lib/features/block_map/block_map_items.dart`: 48 items, keyed `<origin_domain>_<1..4>`. `_1`..`_3` are forward items and `_4` is the reverse item. Each reverse item pairs with `_1`, except `relational_attachment_4`, which pairs with `_3`. The Likert scale runs 0..4: "Not at all like me" / "Rarely like me" / "Sometimes like me" / "Often like me" / "Always like me". The cold-judge log and the decisions are in the notes. **Gate still open:** Noah reads all 48 before the seed migration.

The Likert labels go into `block_map_items.dart` as `blockMapLikertLabels`, pinned by the copy-rules test.

## 4. Scoring (pure, integer-only)

- The effective value is the raw value for a forward item and 4 minus the raw value for a reverse item.
- A domain's sum is the total of its 4 effective values, 0..16. These are sums, not means, so the Dart mirror has no float rounding.
- All 48 answers are required, and every value must be in 0..4. Otherwise raise.
- Rank by sum, descending. Tie-break 1: more effective values >= 3. Tie-break 2: `origin_domain` enum order.

**Honesty checks.** The thresholds are named constants. They are identical in the SQL function and in `block_map_scoring.dart`, and they change only together, in one commit, as part of mirror-sync group 5:

| Constant | Value | Flag fires when |
|---|---|---|
| `straightLineMin` | 40 | `straight_line`: the most common raw value appears on >= 40 of 48 items |
| `minimizingMin` | 36 | `minimizing`: effective value is 0 on >= 36 of 48 items |
| `contradictionPairDiff` | 3 | a pair contradicts when \|effective(forward) - effective(reverse)\| >= 3 |
| `contradictionPairsMin` | 3 | `contradiction`: >= 3 of the 12 pairs contradict |

Confidence: 0 flags = `high`, 1 = `moderate`, 2 or more = `low`.

The contradiction check compares **effective** values. Once the reverse item is flipped, both members of a pair measure the same thing, so a consistent person shows a small difference.

**Known skew (accepted by Noah, 2026-11-08).** Four reverse items (adequacy_impostor, status_achievement, internal_self_directed, visibility_fear) are worded as the healthy pole and may draw inflated agreement. That only feeds the contradiction flag, which only lowers confidence. Tune it once real data exists.

## 5. Data

**Migration 1** runs as one transaction. `CREATE TYPE` is fine inside a transaction; only `ADD VALUE` is not.

- `CREATE TYPE block_map_kind AS ENUM ('initial','retake')`, `block_map_flag AS ENUM ('straight_line','minimizing','contradiction')`, and `block_map_confidence AS ENUM ('high','moderate','low')`.
- `block_map_items` (config table). Columns: `item_key text PK`, `domain origin_domain NOT NULL`, `reverse_scored boolean NOT NULL`, `pair_key text NULL`, `position smallint UNIQUE NOT NULL` (canonical order 1..48). It's seeded in this migration from the Dart bank's metadata and holds no statement text. `REVOKE ALL ... FROM anon, PUBLIC`; `authenticated` gets SELECT only.
- `block_map_assessments`. Columns:
  - `id uuid PK default gen_random_uuid()`
  - `user_id uuid NOT NULL → users(id) ON DELETE CASCADE`
  - `loop_id uuid NOT NULL → ascension_loops(id) ON DELETE CASCADE`
  - `kind block_map_kind NOT NULL`
  - `item_order text[] NOT NULL CHECK (cardinality(item_order) = 48)`, client-shuffled
  - `started_at timestamptz default now()`
  - `completed_at timestamptz NULL`
  - `domain_sums smallint[]` (12 values, in enum order)
  - `ranked_domains origin_domain[]` (12 values)
  - `flags block_map_flag[]`
  - `confidence block_map_confidence`
  
  Constraint: `UNIQUE (loop_id, kind)`.
- `block_map_responses`. Columns: `assessment_id uuid → block_map_assessments(id) ON DELETE CASCADE`, `item_key text → block_map_items`, `value smallint CHECK (value BETWEEN 0 AND 4)`, `answered_at timestamptz default now()`, and `PK (assessment_id, item_key)`. **There is no `user_id` column.** Ownership always comes from the parent row, so no client-supplied owner field can be trusted by mistake.
- `phase3_origin_drills` gains two columns: `suggested_origin_domain origin_domain NULL` and `block_map_assessment_id uuid NULL → block_map_assessments(id) ON DELETE SET NULL`. The final pick stays in the existing `q2_domain`. A mismatch between the suggestion and the pick is derived at query time and never stored.

**RLS.** Every `CREATE POLICY` is preceded by `DROP POLICY IF EXISTS`.

- `block_map_assessments` gets **SELECT and INSERT only**.
  - SELECT: `auth.uid() = user_id`.
  - INSERT WITH CHECK: `auth.uid() = user_id AND EXISTS (SELECT 1 FROM ascension_loops l WHERE l.id = loop_id AND l.user_id = auth.uid())`. Checking the loop owner stops a user from squatting another user's `(loop_id, kind)` slot.
  - No UPDATE and no DELETE policy, plus `REVOKE UPDATE, DELETE ON block_map_assessments FROM authenticated, anon`. Row policies can't restrict columns, so any UPDATE right would let a client write its own results. Results are written only by `score_block_map`, which is SECURITY DEFINER.
- `block_map_responses`:
  - SELECT: `EXISTS (owned parent)`.
  - INSERT and UPDATE WITH CHECK: `EXISTS (parent WHERE id = assessment_id AND user_id = auth.uid() AND completed_at IS NULL)`.
  - No DELETE policy.
- **Orphaned runs (accepted).** If a loop lapses or completes mid-run, its in-progress assessment stays attached to that loop. The new loop's hub shows a fresh card. This matches the lapse policy (a lapsed loop means a fresh start, and copy never shames the gap).

**Migration 2** adds the functions and grants.

- `compute_block_map(p_values smallint[])` returns `TABLE(domain_sums smallint[], ranked_domains origin_domain[], flags block_map_flag[], confidence block_map_confidence)`. It is SECURITY INVOKER, STABLE, and `SET search_path = public, pg_temp`. It takes 48 values in canonical `position` order and reads the reverse/pair metadata from `block_map_items`. It raises if the array length isn't 48, if any value is NULL or outside 0..4, or if `block_map_items` doesn't return exactly 48 rows. The thresholds are named constants declared at the top of the function body.
- `score_block_map(p_assessment_id uuid)` is SECURITY DEFINER with `search_path` pinned. Its steps, in order:
  1. `SELECT ... FOR UPDATE` on the assessment row.
  2. NOT FOUND guard.
  3. `auth.uid()` ownership guard (rule 8).
  4. If `completed_at IS NOT NULL`, return the row unchanged.
  5. Raise `'block map incomplete'` unless all 48 responses exist.
  6. Order the responses by `position`, call the pure function, write the results and `completed_at`, and return the row.
- Grants: EXECUTE on both functions to `authenticated` only. Revoke from `anon` and `PUBLIC`.

## 6. Client

The new code goes in `lib/features/block_map/`:

- `block_map_items.dart` is done. Add `blockMapLikertLabels`.
- `block_map_tokens.dart`: typed mirrors of `block_map_kind`, `block_map_flag`, and `block_map_confidence`, each with a throwing `fromToken`.
- `block_map_scoring.dart`: an exact integer mirror of `compute_block_map`, with the same named threshold constants. It's for instant preview only; the DB result wins.
- `block_map_controller.dart`: a `ChangeNotifier`.
  - It holds the assessment id, `item_order`, and the answers.
  - Create-or-resume: an INSERT that hits a `UNIQUE (loop_id, kind)` conflict (`23505`, from a second tab or a double open) falls back to fetching the existing session.
  - It upserts one response per tap.
  - Finish calls the RPC and then reads the row back.
  - A completed session exposes its id so the screen can go to the result route.
  - Errors surface; they are never swallowed.
- `block_map_screen.dart` (runner plus primer) and `block_map_result_screen.dart`.
- `block_map_wheel.dart`: a `CustomPainter`.
  - 12 spokes in `OriginDomain` enum order. There's no outer ring and no second ordering (the ring was cut by Noah, 2026-11-08).
  - The shape is filled with `wheelFill`, over a grid in `wheelGrid`, and the top spoke glows.
  - Tapping a spoke shows its domain label, which reuses the `drill_questions.dart` labels (kept by Noah, 2026-11-08).
  - It fades in with the existing `reveal` motion and never grows from the center.

**Runner reuse.** `assessment_screen.dart` keeps `_AnswerCard` private. The first slice moves it into `lib/core/widgets/answer_card.dart`. That's a pure refactor, and the existing tests stay green.

**Routes.** `/block-map/:loopId?kind=initial|retake` (the default is `initial`) and `/block-map/:loopId/result/:assessmentId`. Both are private by default under `authRedirect`, and both stay unreachable (no hub card) until the hand-off slice lands.

**Drill hand-off.** `/drill/:loopId?bm=<assessmentId>`. `drill_controller.dart` loads the ranking from the DB row, preselects `ranked[0]`, offers `ranked[1..2]`, and writes `suggested_origin_domain` plus `block_map_assessment_id` alongside `q2_domain`.

**MASTER.md.** Add the tokens `wheelFill` (zoneColor @ 18%) and `wheelGrid` (white @ 7%). Record the named exception "top spoke glows" (Noah, 2026-11-08) so an anti-pattern sweep doesn't remove it. `priorShape` moves to the retake plan.

## 7. Mirror-sync group 5 (new)

These artifacts change together, in one commit:

- `compute_block_map`, including its named threshold constants, and the `block_map_items` seed
- `block_map_scoring.dart`, with the same constants
- the item metadata in `block_map_items.dart`
- `block_map_tokens.dart`
- `test/block_map_mirror_test.dart` and `test/block_map_seed_test.dart`
- the golden values in the `levels-verify` skill
- the CLAUDE.md sync map

**The enum-order pin is a member of this group.** `domain_sums` indexing and tie-break 2 both depend on the Postgres `origin_domain` order matching the Dart `OriginDomain.values` order. `levels-verify` checks that `enum_range(NULL::origin_domain)` equals the Dart token list in order. The existing bank test already pins `blockMapItems[i].domain == OriginDomain.values[i ~/ 4]`.

## 8. Copy still to write (cold-judge gated)

- The hub card title and link.
- The results hero ("Where you're most held") and the CTA ("Begin the drill") are already approved.
- Spoke tap labels reuse the `drill_questions.dart` domain labels.
- The low-confidence caption is written (`blockMapLowConfidenceCaption`).

Everything runs the four mechanic-leak checks and delete-ai-words.

## 9. Build slices (each one PR)

1. Shared answer-card extraction (refactor only).
2. Migration 1 (types, tables, RLS, seed, Phase 3 columns) via levels-dev-loop, with an MCP read-back. **Blocked on Noah's 48-item read-through.** Opus tier, because the security surface lives here.
3. Migration 2 (functions, grants), the Dart scoring mirror, the tokens, the golden mirror tests, the levels-verify golden values, and the CLAUDE.md sync map. Opus tier (mirror-sync).
4. Controller, runner, and primer. The route is present but there's no hub card.
5. Wheel painter, result screen, and MASTER.md tokens.
6. Drill hand-off, hub card, and the copy gate. This slice makes the feature reachable. Manual browser run end to end on a release build, per CLAUDE.md.

The Day 21 retake is deferred to a later plan (section 2, step 6).

## 10. Decisions closed (Noah, 2026-11-08)

1. Flag and confidence are typed enums (`block_map_flag`, `block_map_confidence`) with Dart mirrors.
2. `compute_block_map` reads the reverse/pair metadata from `block_map_items` (STABLE) instead of hard-coding it.
3. The hub card shows as soon as the loop's Phase 2 dashboard row exists.
4. After the Fable review: cut the wheel's outer ring and `blockMapDisplayOrder`; keep the spoke-tap labels; defer the Day 21 retake to a later plan.
5. Fable findings applied: no client UPDATE/DELETE on assessments; a loop-owner check on INSERT; `item_order` cardinality CHECK; responses lose `user_id`; anon revoked on `block_map_items`; drill FK `ON DELETE SET NULL`; named thresholds in group 5; the enum-order pin; the value-range and metadata-count raises; `FOR UPDATE` in the scorer; the create-race and completed-session handling; `?kind=` in the route; Task 2 moved to Opus.
