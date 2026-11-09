<!-- Purpose: self-contained review packet for an independent Fable 5.1 review of the block-map design + plan before any build starts. Source: snapshot of branch docs/block-map-design at commit a4eb8fe; the embedded files below are exact copies, not edited. -->

# Block map: review packet for Fable 5.1

## Your role

You are an independent senior reviewer. You did not write this design or plan. Review it before a single line of it is built. Be direct: a weak "looks good" wastes the review. You have no repo access, so everything you need is embedded below as exact copies.

## Context in five lines

- **Levels** is a Flutter (web) + Supabase app based on Frederick Dodson's *Levels of Energy*. Users take a 7-question assessment that maps them to an energy zone, then work through drills.
- **The block map** is a new, optional 48-item self-assessment. It ranks 12 existing `origin_domain` values and suggests the top one for the Phase 3 drill. The user can always override the suggestion.
- **House rule 1, "the LLM never decides; functions do":** all scoring lives in deterministic Postgres functions. Dart has exact integer mirrors for preview only, pinned by golden tests. The UI renders only DB rows.
- **House rule 2, security:** RLS is scoped to `auth.uid() = user_id`. Every SECURITY DEFINER function pins `search_path` and checks `auth.uid()` ownership before mutating. Migrations are the only schema path.
- **House rule 3, product ethics:** no numbers, scores, or zone names on screen. No urgency or shame. Honesty flags only lower confidence and never change a result.

## What to review (priority order)

1. **Security and RLS** (spec section 5, plan Tasks 2-3). Can any client write what only `score_block_map` should write? Can one user read or alter another user's rows? Are the grants right? Is a SECURITY INVOKER STABLE `compute_block_map` that reads `block_map_items` under RLS sound?
2. **Scoring correctness** (spec section 4). Recompute golden vectors G1 to G5 (plan, "Golden vectors") by hand from the item metadata in the embedded `block_map_items.dart`. Do the tie-breaks and honesty thresholds do what they claim? Do the vectors actually discriminate what they say they discriminate?
3. **Mirror-sync completeness** (spec section 7). Is any artifact that has to stay in lockstep with the DB function missing from group 5?
4. **Plan quality.** Is each task unambiguous to an executor who has never seen the repo? Are interfaces consistent across tasks (names, types, routes)? Is the order right? Are the model-tier assignments right (Opus only for Task 3)?
5. **Review Focus gaps.** Which realistic failure modes are still untested (concurrency, resume, partial writes, back-navigation after finishing, retake vs. initial collisions on `UNIQUE (loop_id, kind)`, a loop that lapses mid-run)?
6. **Product and ethics.** Does anything leak mechanics to the user, manufacture urgency, or let the suggestion feel like a verdict?

## Concern the author already suspects (confirm or refute)

- **Assessment UPDATE policy.** Spec section 5 allows a client UPDATE on `block_map_assessments` while `completed_at IS NULL`. A row-level policy doesn't restrict columns. If that's true, a client could write `domain_sums`, `ranked_domains`, `flags`, `confidence`, or `completed_at` directly, and bypass the scoring RPC. Is there any client need to UPDATE that table at all (`item_order` is set once at INSERT)? If not, should the policy be dropped, or should results columns be revoked by column-level privilege?

## Locked decisions (do not relitigate; flag only if one causes a concrete defect)

- The 12 `origin_domain` values are the categories. 48 items, 4 per domain (3 forward + 1 reverse).
- `relational_attachment_4` pairs with `_3`. Every other reverse item pairs with `_1`.
- Four reverse items (adequacy_impostor, status_achievement, internal_self_directed, visibility_fear) are intentionally the healthy pole, so the skew is accepted. Statement wording passed a separate cold copy review, so don't re-review the copy.
- Results show no numbers, as a radial wheel. The top spoke glows, which is an approved design-system exception.
- No new dependencies. State management is plain `ChangeNotifier`.

## Output format

1. **Verdict:** ship as is / ship after fixes / rework. One line.
2. **Findings table:** `# | severity (blocker / major / minor / nit) | location (spec section or plan task + step) | problem | concrete fix`. Most severe first. Each finding names a concrete failure scenario, not a style preference.
3. **Golden vector check:** for G1 to G5, "matches" or the corrected expected values with your arithmetic.
4. **Anything you would cut.** Name scope that isn't earning its place.

Keep it under ~1,500 words. No preamble.

---

## Embedded file: `docs/superpowers/specs/2026-11-08-block-map-design.md`

````markdown
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

````

## Embedded file: `docs/superpowers/plans/2026-11-08-block-map.md`

````markdown
<!-- Purpose: task-by-task build plan for the block map. Source: docs/superpowers/specs/2026-11-08-block-map-design.md (approved by Noah 2026-11-08). -->

# Block Map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the optional 48-item block map: answer, score in Postgres, show the wheel, and hand the top domain to the Phase 3 drill as a confirm/override suggestion.

**Architecture:** Two migrations add the config table, two user tables, RLS, Phase 3 columns, a pure scoring fn and an owner-guarded scoring RPC. The Dart side mirrors the pure fn exactly (mirror-sync group 5), runs a resumable one-item-per-screen runner on the Phase 1 visuals, and renders a `CustomPainter` wheel from the DB row only.

**Tech Stack:** Flutter (web), `go_router`, `supabase_flutter`, plain `ChangeNotifier`; Supabase Postgres via CLI migrations.

**Spec:** `docs/superpowers/specs/2026-11-08-block-map-design.md` (read it with this plan; decisions log: `docs/superpowers/specs/2026-11-08-block-map-brainstorm-notes.md`).

## Global Constraints

- No new dependencies. State is `ChangeNotifier`. The wheel is a `CustomPainter` (no `fl_chart`).
- The LLM never decides: scoring lives in `compute_block_map`; Dart is an exact integer mirror for preview; UI renders only the DB row.
- No numbers, scores, zone names, or flags on screen. Copy passes the four mechanic-leak classes and delete-ai-words. No em dashes in copy.
- New copy ships only after a cold-context rubric judge pass (M2.4 method).
- Every SECURITY DEFINER fn: `SET search_path = public, pg_temp` + NOT FOUND guard + `auth.uid()` ownership guard. SECURITY INVOKER fns pin `search_path` too. EXECUTE to `authenticated` only.
- `CREATE POLICY` is always preceded by `DROP POLICY IF EXISTS`. Migrations in `BEGIN/COMMIT`.
- Production migrations run only from `main`, after merge: `git switch main && git pull && npx supabase db push --remote`, then MCP read-back. Never DDL via `execute_sql`.
- One branch + one PR per task (`feat/block-map-<n>-<slug>`). Noah merges. `flutter analyze` clean + `flutter test` green before every commit.
- Routes stay unreachable from the hub (no card) until Task 6.
- Commit messages: imperative, one line, no prefixes, no AI trailers (CLAUDE.md).

## Review Focus

1. **Resume mid-run:** closing at item 20 and reopening continues at the first unanswered key in the stored `item_order`, never reshuffles. Pinned in Task 4.
2. **Rapid double tap:** two taps on one screen write one response row and advance once. Pinned in Task 4.
3. **A lost upsert:** finishing with < 48 stored responses makes `score_block_map` raise; the runner shows the error and jumps to the first missing item. Pinned in Tasks 3 and 4.
4. **Entering early or with no loop:** `/block-map` before the loop has a Phase 2 row, or with no active loop, shows a not-available state and inserts nothing. Pinned in Task 4.
5. **Re-scoring / foreign id:** a second `score_block_map` call returns the stored row unchanged; another user's id raises. Pinned in Task 3 (SQL read-back) and the levels-verify additions.

## Golden vectors (used by Task 3's Dart mirror test AND its levels-verify SQL)

Values are raw answers in canonical order (= `blockMapItems` order: `OriginDomain` enum order, then `_1`..`_4`). Domains not named take the "rest" pattern.

| ID | Raw answers | Expected sums | Expected ranked | Flags | Confidence |
|---|---|---|---|---|---|
| G1 | all 0 | all 4 | enum order | straight_line, minimizing, contradiction | low |
| G2 | all 4 | all 12 | enum order | straight_line, contradiction | low |
| G3 | all 2 | all 8 | enum order | straight_line | moderate |
| G4 | visibility_fear `[4,4,4,0]`; self_perfectionism `[3,3,3,1]`; rest `[1,1,1,3]` | vf 16, sp 12, rest 4 | visibility_fear, self_perfectionism, then the other 10 in enum order | none | high |
| G5 | relational_attachment `[4,2,1,3]`; visibility_fear `[3,3,2,4]`; rest `[1,1,1,3]` | ra 8, vf 8, rest 4 | visibility_fear, relational_attachment, then the other 10 in enum order (tie-break 1: vf has two effective >= 3, ra one) | none | high |

G4 discriminates rank order; G5 discriminates tie-break 1 against enum order (enum order alone would put relational_attachment first). G1 vs G2 discriminates `minimizing`. The relational `_3` pairing is pinned by Task 2's seed test, not by a vector (one pair can never reach the 3-pair flag threshold).

---

### Task 1: Extract the shared Likert answer widgets (refactor only) (Sonnet)

**Files:**
- Create: `lib/core/widgets/answer_card.dart`
- Modify: `lib/features/assessment/assessment_screen.dart:187-226` (remove `_AnswerCard`, use the shared one)
- Test: `test/answer_card_test.dart`

**Interfaces:**
- Produces: `class AnswerCard extends StatelessWidget { const AnswerCard({required String label, required bool selected, required VoidCallback onTap}); }` (identical visuals to today's `_AnswerCard`).

- [ ] **Step 1: Write the failing widget test** `answer card shows label and calls onTap`: pump `AnswerCard(label: 'Often like me', selected: true, onTap: ...)`, expect `find.text('Often like me')`, tap it, expect the callback fired once; and `selected: true` renders a left border of width 2 in `LevelsColors.neutralAccent`, `selected: false` width 1 in `LevelsColors.glassStroke`.
- [ ] **Step 2: Run** `flutter test test/answer_card_test.dart`. Expected: FAIL (file missing).
- [ ] **Step 3: Move `_AnswerCard` to `lib/core/widgets/answer_card.dart` as public `AnswerCard`; point `_QuestionPage` at it.** `_QuestionPage` stays in the assessment screen (it is typed to `AssessmentQuestion`).
- [ ] **Step 4: Run** `flutter test` and `flutter analyze`. Expected: all pass (224 + new), no issues.
- [ ] **Step 5: Commit** `Extract the assessment answer card into a shared widget`, push, open PR.

### Task 2: Migration 1, schema + seed + RLS (Sonnet, via levels-dev-loop)

**Gate:** do not push until Noah has approved the 48-item read-through (seed keys are frozen after this).

**Files:**
- Create: `supabase/migrations/<ts>_block_map_schema.sql` (via `npx supabase migration new block_map_schema`)
- Test: `test/block_map_seed_test.dart`

**Interfaces:**
- Produces (DB): types `block_map_kind('initial','retake')`, `block_map_flag('straight_line','minimizing','contradiction')`, `block_map_confidence('high','moderate','low')`; tables `block_map_items`, `block_map_assessments`, `block_map_responses`; columns `phase3_origin_drills.suggested_origin_domain`, `phase3_origin_drills.block_map_assessment_id`. Exact columns: spec section 5.

- [ ] **Step 1: Write the failing seed-mirror test** `block_map_items seed equals the Dart bank`: read the migration file, extract every seed row with `RegExp(r"\('([a-z_]+_[1-4])', '([a-z_]+)', (true|false), (NULL|'[a-z_]+'), (\d+)\)")`, and assert 48 rows where row *i* (position *i+1*) equals `blockMapItems[i]`: same key, `domain.token`, `reverse`, `pairKey` (NULL when null).
- [ ] **Step 2: Run** `flutter test test/block_map_seed_test.dart`. Expected: FAIL (no migration file).
- [ ] **Step 3: Write the migration** in `BEGIN/COMMIT`: the 3 types; the 3 tables with every column/constraint in spec section 5 (including `position smallint UNIQUE NOT NULL` and `UNIQUE (loop_id, kind)`); the 48-row seed in canonical order in the exact tuple format the test parses; RLS enabled on all three; `block_map_items` SELECT to `authenticated` only; user-table policies per spec section 5 (each preceded by `DROP POLICY IF EXISTS`), responses INSERT/UPDATE `WITH CHECK` requiring `auth.uid() = user_id` AND an owned parent with `completed_at IS NULL`; no DELETE policies; the two `phase3_origin_drills` columns.
- [ ] **Step 4: Run** `flutter test` + `flutter analyze`. Expected: pass.
- [ ] **Step 5: Commit** `Add block-map schema, item seed, RLS, and Phase 3 suggestion columns`, push, PR. After Noah merges: push from `main` with `--remote`.
- [ ] **Step 6: MCP read-back** (one labeled SELECT): enum values via `pg_type`+`pg_enum` for the 3 types; `count(*)` of `block_map_items` = 48 and `count(*) FILTER (WHERE reverse_scored)` = 12; `pg_policies` rows for the 3 tables incl. `with_check`; the two new `phase3_origin_drills` columns in `information_schema.columns`; `get_advisors` security shows no new warnings. Record results + date in the PR.

### Task 3: Migration 2 + Dart scoring mirror (mirror-sync group 5) (Opus)

**Files:**
- Create: `supabase/migrations/<ts>_block_map_functions.sql`
- Create: `lib/features/block_map/block_map_tokens.dart`
- Create: `lib/features/block_map/block_map_scoring.dart`
- Test: `test/block_map_mirror_test.dart`, `test/block_map_tokens_test.dart`
- Modify: `.claude/skills/levels-verify/SKILL.md` (add G1-G5 + guard checks), `CLAUDE.md` (mirror sync map: add group 5; database inventory: new tables/functions)

**Interfaces:**
- Consumes: Task 2 tables/types; `blockMapItems` (`lib/features/block_map/block_map_items.dart`); `OriginDomain`.
- Produces (Dart): `enum BlockMapKind { initial, retake }`, `enum BlockMapFlag { straightLine, minimizing, contradiction }`, `enum BlockMapConfidence { high, moderate, low }`, each with `final String token` and throwing `static fromToken(String)`; `class BlockMapResult { final List<int> domainSums; final List<OriginDomain> ranked; final List<BlockMapFlag> flags; final BlockMapConfidence confidence; }`; `BlockMapResult computeBlockMap(List<int> rawValues)` (throws `ArgumentError` unless length 48 and every value 0..4). `domainSums` is in `OriginDomain` enum order; `flags` in enum declaration order.
- Produces (DB): `compute_block_map(p_values smallint[]) RETURNS TABLE(domain_sums smallint[], ranked_domains origin_domain[], flags block_map_flag[], confidence block_map_confidence)` SECURITY INVOKER STABLE; `score_block_map(p_assessment_id uuid) RETURNS block_map_assessments` SECURITY DEFINER.

- [ ] **Step 1: Write the failing tests.** `block_map_tokens_test.dart`: each enum's tokens equal the DB labels listed in Task 2, and `fromToken('nope')` throws. `block_map_mirror_test.dart`: one test per golden vector G1-G5 asserting all four result fields exactly as in the table; plus `throws on 47 values`, `throws on value 5`. Header comment names group 5 and the verification date.
- [ ] **Step 2: Run** both tests. Expected: FAIL (missing files).
- [ ] **Step 3: Implement `computeBlockMap`** per spec section 4: effective = reverse ? 4 - v : v; sums per domain; rank by (sum desc, count(effective >= 3) desc, enum index asc); `straight_line` when the most common raw value occurs >= 40 times; `minimizing` when effective == 0 on >= 36; `contradiction` when >= 3 pairs have |effective(forward) - effective(reverse)| >= 3, pairs taken from `pairKey`; confidence by flag count 0/1/2+.
- [ ] **Step 4: Run** the two tests. Expected: PASS.
- [ ] **Step 5: Write migration 2** in `BEGIN/COMMIT`: `compute_block_map` as the same algorithm, reading `reverse_scored`/`pair_key`/`domain` from `block_map_items` ordered by `position`, raising on `array_length <> 48` or any NULL; `score_block_map` with NOT FOUND guard, `auth.uid()` guard, early return of the row when `completed_at IS NOT NULL`, raise `'block map incomplete'` unless 48 responses exist, else compute (values ordered by item `position`), write `domain_sums`, `ranked_domains`, `flags`, `confidence`, `completed_at = now()`, return the row. `REVOKE ALL ... FROM PUBLIC, anon; GRANT EXECUTE ... TO authenticated` on both.
- [ ] **Step 6: Update levels-verify** with SQL calling `compute_block_map` on G1-G5 (literal arrays) and expected values, plus: `score_block_map` on a random uuid raises NOT FOUND. Update CLAUDE.md's sync map (group 5 members listed in spec section 7) and database inventory.
- [ ] **Step 7: Run** `flutter test` + `flutter analyze`; commit `Add block-map scoring function, owner-guarded scoring RPC, and Dart mirror`; push; PR. After merge: `db push --remote` from `main`.
- [ ] **Step 8: Verify live:** run levels-verify; all G1-G5 match the Dart test, `pg_get_functiondef` shows the pinned `search_path` and both guards, `get_advisors` clean. Report the table in the PR.

### Task 4: Controller, runner, primer (Sonnet)

**Files:**
- Create: `lib/features/block_map/block_map_controller.dart`, `lib/features/block_map/block_map_screen.dart`
- Modify: `lib/features/block_map/block_map_items.dart` (add `blockMapLikertLabels`), `lib/core/router.dart` (`'/block-map/:loopId': _buildBlockMap`), `test/router_test.dart`, `test/block_map_items_test.dart` (labels go through the copy-rules test)
- Test: `test/block_map_controller_test.dart`

**Interfaces:**
- Consumes: Task 3 tokens; `AnswerCard` (Task 1); `blockMapItems`.
- Produces: `abstract class BlockMapDataSource { Future<bool> loopReadyForBlockMap(String loopId); Future<BlockMapSession?> fetchSession(String loopId, BlockMapKind kind); Future<BlockMapSession> createSession(String loopId, BlockMapKind kind, List<String> itemOrder); Future<void> saveAnswer(String assessmentId, String itemKey, int value); Future<BlockMapRow> score(String assessmentId); Future<BlockMapRow> fetchRow(String assessmentId); }`; `class BlockMapSession { final String id; final List<String> itemOrder; final Map<String, int> answers; final bool completed; }`; `class BlockMapRow { final String id; final BlockMapKind kind; final List<OriginDomain> ranked; final List<int> domainSums; final BlockMapConfidence confidence; }` (built only from the DB row); `class BlockMapController extends ChangeNotifier { BlockMapController({required String loopId, required BlockMapKind kind, BlockMapDataSource? dataSource}); Future<void> load(); int get currentIndex; String get currentKey; int? answerFor(String key); Future<void> answer(int value); void back(); Future<BlockMapRow> finish(); bool get notAvailable; String? get error; }`.
- `blockMapLikertLabels` = `['Not at all like me', 'Rarely like me', 'Sometimes like me', 'Often like me', 'Always like me']` (index = value).

- [ ] **Step 1: Write failing controller tests** with a fake data source: `load creates a session with a 48-key shuffle of every item key`; `resume continues at the first unanswered key in the stored order` (Review Focus 1); `answer saves once and advances once under a double tap` (call `answer(3)` twice without awaiting the first; expect one `saveAnswer` and `currentIndex` + 1) (Review Focus 2); `finish surfaces the incomplete error and moves to the first missing key` (fake `score` throws) (Review Focus 3); `notAvailable when the loop has no Phase 2 row, and nothing is created` (Review Focus 4); `save failure sets error and does not advance`.
- [ ] **Step 2: Run** `flutter test test/block_map_controller_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** the controller and the Supabase data source (upsert on `(assessment_id, item_key)`; `loopReadyForBlockMap` = a `phase2_dashboard_views` row exists for the loop; shuffle with `Random()` once at create; `finish` = `score` RPC then `fetchRow`). Errors are stored and shown, never swallowed.
- [ ] **Step 4: Implement `BlockMapScreen(loopId, kind)`**: primer screen (`blockMapPrimerTitle`, `blockMapPrimer`, one primary CTA) then one statement per screen with 5 `AnswerCard`s in label order, thin `neutralAccent` progress bar with no count, back, close = save and exit to `/`. On finish success: `context.go('/block-map/<loopId>/result/<assessmentId>')` (route added in Task 5; until then, go to `/`).
- [ ] **Step 5: Register the route** and update `router_test.dart`'s pinned path list.
- [ ] **Step 6: Run** `flutter test` + `flutter analyze`. Commit `Add the block-map runner, controller, and primer behind an unlinked route`, push, PR.

### Task 5: Wheel + result screen + MASTER.md tokens (Sonnet)

**Files:**
- Create: `lib/features/block_map/block_map_wheel.dart`, `lib/features/block_map/block_map_result_screen.dart`
- Modify: `lib/core/design_tokens.dart` (tokens), `design-system/MASTER.md` (tokens + named glow exception), `lib/core/router.dart` (`'/block-map/:loopId/result/:assessmentId'`), `test/router_test.dart`
- Test: `test/block_map_wheel_test.dart`

**Interfaces:**
- Consumes: `BlockMapRow`, `BlockMapDataSource.fetchRow` (Task 4); `ZoneStyle.of(zone).zoneColor`; `drill_questions.dart` domain labels.
- Produces: `const List<OriginDomain> blockMapDisplayOrder` (12, grouped Self / Others / Standing / World, three each); `class BlockMapWheelPainter extends CustomPainter { BlockMapWheelPainter({required List<int> domainSums, required OriginDomain top, required Color zoneColor, List<int>? priorSums}); }`; tokens `LevelsColors.wheelGrid` (white @ 7%), `LevelsColors.priorShape` (= `textFaint`), and `wheelFill(Color zoneColor)` (@ 18%).

- [ ] **Step 1: Write failing tests**: `display order holds all 12 domains exactly once`; `spoke radius is sum / 16 of max radius` (expose a pure `spokePoint(int index, int sum, double radius) -> Offset` and pin index 0 sum 16 and index 6 sum 8); `shouldRepaint is true when sums change and false when equal`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement the painter** per spec section 6: 12 spokes in `blockMapDisplayOrder`, grid in `wheelGrid`, shape filled with `wheelFill(zoneColor)`, glow on the top spoke, four quiet outer arcs, optional dashed prior outline in `priorShape`. No text or numbers drawn.
- [ ] **Step 4: Implement `BlockMapResultScreen(loopId, assessmentId)`**: fetch the row; wheel fades in with the existing `reveal` motion (never scales from the center); tapping a spoke shows that domain's label; hero glass card "Where you're most held" + top domain label; `blockMapLowConfidenceCaption` when `confidence == low`; one primary CTA "Begin the drill" → `/drill/<loopId>?bm=<assessmentId>`. Register the route; point Task 4's finish navigation at it.
- [ ] **Step 5: Add the tokens to MASTER.md**, plus the named exception: "Block-map top spoke glows (Noah, 2026-11-08): deliberate exception to brightness = energy; anti-pattern sweeps must not remove it."
- [ ] **Step 6: Run** `flutter test` + `flutter analyze`; commit `Add the block-map wheel, result screen, and design tokens`; push; PR.

### Task 6: Drill hand-off + hub card + copy gate (makes it reachable) (Sonnet)

**Files:**
- Modify: `lib/features/drill/drill_controller.dart` (constructor, `load`, `saveDrill`), `lib/features/drill/drill_screen.dart`, `lib/core/router.dart` (`_buildDrill` reads `bm`), `lib/features/journey/journey_repository.dart` (block-map status), `lib/features/home/home_screen.dart` (card)
- Test: `test/drill_controller_test.dart`, `test/block_map_hub_test.dart`

**Interfaces:**
- Consumes: `BlockMapRow.ranked` via a new `DrillDataSource.fetchBlockMapRanking(String assessmentId) -> Future<List<OriginDomain>>`.
- Produces: `DrillController({..., String? blockMapAssessmentId})`; `List<OriginDomain> get suggestedDomains` (top 3, empty without a block map); `saveDrill(..., OriginDomain? suggestedOriginDomain, String? blockMapAssessmentId)` writing `suggested_origin_domain` + `block_map_assessment_id` only when non-null; `JourneyData.blockMapInitial` (`BlockMapStatus? { String id; bool completed; }`) and `blockMapRetake`; pure `bool showBlockMapCard(JourneyData d)` = phase is not `assessment` and not `complete`, and `blockMapInitial?.completed != true`.

- [ ] **Step 1: Write failing tests**: `with bm, load preselects the top domain and offers the next two`; `user override keeps q2_domain as the pick and still writes the suggestion` (fake records `suggestedOriginDomain` = ranked[0], `originDomain` = the override); `without bm, nothing changes` (existing tests stay green); `showBlockMapCard` table: hidden in `assessment`, shown in `dashboard` with no block map, shown with an in-progress one, hidden once completed, hidden when `complete`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement** the hand-off (drill screen shows the three suggested domains first with the top preselected; all 12 stay selectable) and the hub card: a quiet `surface` card with a text-link action (never a `FilledButton`), linking to `/block-map/<loopId>`; in-progress state links to the same route (resume).
- [ ] **Step 4: Write the copy** (hub card title + link text; in-progress variant) and run a cold rubric judge subagent on it (rubric: CLAUDE.md four leak classes, no numbers, no urgency, no em dashes, delete-ai-words). Fail → rewrite → re-judge. Log the judge table in the PR.
- [ ] **Step 5: Run** `flutter test` + `flutter analyze`; commit `Link the block map from the hub and hand its top domain to the drill`; push; PR.
- [ ] **Step 6: Manual run (release build, per CLAUDE.md Commands):** a fresh test account completes Phase 1, opens the reveal, sees the card, answers 20, closes, resumes, finishes, sees the wheel, taps "Begin the drill", overrides the domain, submits. MCP read-back: 48 responses, a completed assessment row, the drill row with `suggested_origin_domain` ≠ `q2_domain` and `block_map_assessment_id` set. Delete the test account (`DELETE FROM auth.users` path, CLAUDE.md). Task stays IN FLIGHT if this is blocked.

### Task 7: Day 21 retake + prior-shape overlay (Sonnet)

**Files:**
- Modify: `lib/features/home/home_screen.dart`, `lib/features/block_map/block_map_result_screen.dart`, `lib/features/journey/journey_repository.dart` (if not done in Task 6)
- Test: `test/block_map_hub_test.dart`

**Interfaces:**
- Consumes: `BlockMapKind.retake`; `BlockMapScreen(loopId, kind)`; `BlockMapWheelPainter.priorSums`.
- Produces: pure `bool showBlockMapRetake(JourneyData d)` = `loopState.window3Open` and `blockMapInitial?.completed == true` and `blockMapRetake?.completed != true`.

- [ ] **Step 1: Write failing tests** for `showBlockMapRetake`: hidden before Window 3, hidden without a completed initial, shown in Window 3 with a completed initial, hidden after the retake completes.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement**: the retake prompt sits alongside the Window 3 CTA (quiet text link, not a second filled button) and opens `BlockMapScreen(kind: retake)`; the retake result passes the initial row's sums as `priorSums`; if either map's confidence is `low`, show `blockMapLowConfidenceCaption` once.
- [ ] **Step 4: Write + cold-judge the retake prompt copy** (same rubric as Task 6).
- [ ] **Step 5: Run** `flutter test` + `flutter analyze`; commit `Offer the Day 21 block-map retake with the first map overlaid`; push; PR.
- [ ] **Step 6: Manual run:** with a test account whose loop is in Window 3 (set `ascension_loops.started_at` back 21 days on that throwaway row via a migration-free UPDATE only if Noah approves the write; otherwise log as blocked), complete a retake and confirm the dashed prior outline renders. Clean up the account.

````

## Embedded file: `lib/features/block_map/block_map_items.dart`

````dart
// Purpose: the 48-statement block-map question bank (4 per origin_domain), plus
// intro primer and low-confidence caption. Source: design section 4 of
// docs/superpowers/specs/2026-11-08-block-map-brainstorm-notes.md. Text lives
// here (like drill_questions.dart); the DB seed will hold key/domain/reverse/
// pair only. Likert 0..4; reverse items score 4 - value. Original wording.
import '../drill/drill_tokens.dart';

class BlockMapItem {
  const BlockMapItem(
    this.key,
    this.domain,
    this.text, {
    this.reverse = false,
    this.pairKey,
  });

  /// `<origin_domain token>_<1..4>`; stable, seeded into `block_map_items`.
  final String key;
  final OriginDomain domain;
  final String text;

  /// Agreement means "this does NOT hold me"; effective value = 4 - value.
  final bool reverse;

  /// Shared by one forward item and the reverse item that asks the same thing
  /// from the other side. Drives the contradiction check.
  final String? pairKey;
}

const String blockMapPrimerTitle = 'Before you start';
const String blockMapPrimer =
    'Read each statement and choose how much it sounds like you. Go with '
    'your first read, and answer for how you are most days. Stop whenever '
    'you like. Your answers save as you go.';

const String blockMapLowConfidenceCaption =
    'Check this against what you know about yourself.';

/// Canonical order: `OriginDomain` enum order, then _1.._4. _4 is reverse and
/// pairs with _1, except relational_attachment_4, which pairs with _3 (Noah's
/// call on the judge finding, 2026-11-08). Reverse items are worded so
/// agreeing carries a small cost, not the flattering answer (same decision).
const List<BlockMapItem> blockMapItems = [
  // relational_attachment
  BlockMapItem(
    'relational_attachment_1',
    OriginDomain.relationalAttachment,
    'I reread messages from people close to me, looking for signs '
    "they're pulling away.",
  ),
  BlockMapItem(
    'relational_attachment_2',
    OriginDomain.relationalAttachment,
    "I hold on to relationships I know aren't working.",
  ),
  BlockMapItem(
    'relational_attachment_3',
    OriginDomain.relationalAttachment,
    'When someone close goes quiet, I assume I did something wrong.',
    pairKey: 'relational_attachment_pair',
  ),
  BlockMapItem(
    'relational_attachment_4',
    OriginDomain.relationalAttachment,
    "When someone close goes quiet, I figure it has nothing to do with me.",
    reverse: true,
    pairKey: 'relational_attachment_pair',
  ),

  // adequacy_impostor
  BlockMapItem(
    'adequacy_impostor_1',
    OriginDomain.adequacyImpostor,
    "When things go well, I wait for someone to find out I'm less capable.",
    pairKey: 'adequacy_impostor_pair',
  ),
  BlockMapItem(
    'adequacy_impostor_2',
    OriginDomain.adequacyImpostor,
    "When someone praises my work, I assume they're being generous.",
  ),
  BlockMapItem(
    'adequacy_impostor_3',
    OriginDomain.adequacyImpostor,
    "I over-prepare so no one sees what I don't know.",
  ),
  BlockMapItem(
    'adequacy_impostor_4',
    OriginDomain.adequacyImpostor,
    'When my work goes well, I share it without bracing for it to be picked apart.',
    reverse: true,
    pairKey: 'adequacy_impostor_pair',
  ),

  // existential_catastrophic
  BlockMapItem(
    'existential_catastrophic_1',
    OriginDomain.existentialCatastrophic,
    "I picture the world getting worse in ways I can't do anything about.",
    pairKey: 'existential_catastrophic_pair',
  ),
  BlockMapItem(
    'existential_catastrophic_2',
    OriginDomain.existentialCatastrophic,
    'News about large-scale problems stays on my mind for days.',
  ),
  BlockMapItem(
    'existential_catastrophic_3',
    OriginDomain.existentialCatastrophic,
    "I hold off on long-term plans when the world feels unstable.",
  ),
  BlockMapItem(
    'existential_catastrophic_4',
    OriginDomain.existentialCatastrophic,
    "When I think about the world's future, I shrug and get on with my day.",
    reverse: true,
    pairKey: 'existential_catastrophic_pair',
  ),

  // autonomy_sovereignty
  BlockMapItem(
    'autonomy_sovereignty_1',
    OriginDomain.autonomySovereignty,
    'I let other people decide how my days go.',
    pairKey: 'autonomy_sovereignty_pair',
  ),
  BlockMapItem(
    'autonomy_sovereignty_2',
    OriginDomain.autonomySovereignty,
    "I drop my own plans when someone else wants something.",
  ),
  BlockMapItem(
    'autonomy_sovereignty_3',
    OriginDomain.autonomySovereignty,
    "I put up with situations I didn't choose instead of trying to change them.",
  ),
  BlockMapItem(
    'autonomy_sovereignty_4',
    OriginDomain.autonomySovereignty,
    'I hold to my own plans, even when it annoys other people.',
    reverse: true,
    pairKey: 'autonomy_sovereignty_pair',
  ),

  // status_achievement
  BlockMapItem(
    'status_achievement_1',
    OriginDomain.statusAchievement,
    "I make sure people know about what I've achieved.",
    pairKey: 'status_achievement_pair',
  ),
  BlockMapItem(
    'status_achievement_2',
    OriginDomain.statusAchievement,
    "I wait for someone else to notice a win before I let myself enjoy it.",
  ),
  BlockMapItem(
    'status_achievement_3',
    OriginDomain.statusAchievement,
    'I judge a day as good or bad by what I accomplished.',
  ),
  BlockMapItem(
    'status_achievement_4',
    OriginDomain.statusAchievement,
    'I talk about my achievements about as much as anything else.',
    reverse: true,
    pairKey: 'status_achievement_pair',
  ),

  // relational_reciprocity
  BlockMapItem(
    'relational_reciprocity_1',
    OriginDomain.relationalReciprocity,
    'I keep track of who has done what for whom.',
    pairKey: 'relational_reciprocity_pair',
  ),
  BlockMapItem(
    'relational_reciprocity_2',
    OriginDomain.relationalReciprocity,
    'When I give more than I get, I start to pull back.',
  ),
  BlockMapItem(
    'relational_reciprocity_3',
    OriginDomain.relationalReciprocity,
    "I avoid accepting help I can't pay back.",
  ),
  BlockMapItem(
    'relational_reciprocity_4',
    OriginDomain.relationalReciprocity,
    'I lose track of who has done what for whom.',
    reverse: true,
    pairKey: 'relational_reciprocity_pair',
  ),

  // ideological_systemic
  BlockMapItem(
    'ideological_systemic_1',
    OriginDomain.ideologicalSystemic,
    'When I deal with institutions, I brace for being treated unfairly.',
    pairKey: 'ideological_systemic_pair',
  ),
  BlockMapItem(
    'ideological_systemic_2',
    OriginDomain.ideologicalSystemic,
    'I read official rules and forms looking for the catch.',
  ),
  BlockMapItem(
    'ideological_systemic_3',
    OriginDomain.ideologicalSystemic,
    'I skip applying for things when I assume the odds are stacked.',
  ),
  BlockMapItem(
    'ideological_systemic_4',
    OriginDomain.ideologicalSystemic,
    'When I deal with institutions, I take what they tell me at face value.',
    reverse: true,
    pairKey: 'ideological_systemic_pair',
  ),

  // internal_self_directed
  BlockMapItem(
    'internal_self_directed_1',
    OriginDomain.internalSelfDirected,
    "I talk to myself in ways I'd never talk to a friend.",
    pairKey: 'internal_self_directed_pair',
  ),
  BlockMapItem(
    'internal_self_directed_2',
    OriginDomain.internalSelfDirected,
    'When I make a mistake, the voice in my head turns harsh.',
  ),
  BlockMapItem(
    'internal_self_directed_3',
    OriginDomain.internalSelfDirected,
    'I replay things I said or did and criticize myself for them.',
  ),
  BlockMapItem(
    'internal_self_directed_4',
    OriginDomain.internalSelfDirected,
    "When I make a mistake, I talk to myself the way I'd talk to a friend.",
    reverse: true,
    pairKey: 'internal_self_directed_pair',
  ),

  // internalized_authority
  BlockMapItem(
    'internalized_authority_1',
    OriginDomain.internalizedAuthority,
    'Around bosses or authority figures, I get quieter and more careful.',
    pairKey: 'internalized_authority_pair',
  ),
  BlockMapItem(
    'internalized_authority_2',
    OriginDomain.internalizedAuthority,
    'I follow rules I disagree with rather than risk disapproval.',
  ),
  BlockMapItem(
    'internalized_authority_3',
    OriginDomain.internalizedAuthority,
    "Before I decide, I think about what the people in charge would want.",
  ),
  BlockMapItem(
    'internalized_authority_4',
    OriginDomain.internalizedAuthority,
    'I tell bosses what I think, even when keeping quiet would be smarter.',
    reverse: true,
    pairKey: 'internalized_authority_pair',
  ),

  // societal_comparative
  BlockMapItem(
    'societal_comparative_1',
    OriginDomain.societalComparative,
    "I compare my life to other people's lives, even strangers'.",
    pairKey: 'societal_comparative_pair',
  ),
  BlockMapItem(
    'societal_comparative_2',
    OriginDomain.societalComparative,
    'I measure myself against where other people my age are.',
  ),
  BlockMapItem(
    'societal_comparative_3',
    OriginDomain.societalComparative,
    "After scrolling through other people's lives, I think less of my own.",
  ),
  BlockMapItem(
    'societal_comparative_4',
    OriginDomain.societalComparative,
    'I ignore how others are doing when I size up my own life.',
    reverse: true,
    pairKey: 'societal_comparative_pair',
  ),

  // self_perfectionism
  BlockMapItem(
    'self_perfectionism_1',
    OriginDomain.selfPerfectionism,
    "I keep reworking things long after others would call them finished.",
    pairKey: 'self_perfectionism_pair',
  ),
  BlockMapItem(
    'self_perfectionism_2',
    OriginDomain.selfPerfectionism,
    "I hold my own work to a higher standard than I'd hold anyone else's.",
  ),
  BlockMapItem(
    'self_perfectionism_3',
    OriginDomain.selfPerfectionism,
    "Even when it's done well, I notice only what could be better.",
  ),
  BlockMapItem(
    'self_perfectionism_4',
    OriginDomain.selfPerfectionism,
    "I hand things in once they're good enough, even if they're a bit rough.",
    reverse: true,
    pairKey: 'self_perfectionism_pair',
  ),

  // visibility_fear
  BlockMapItem(
    'visibility_fear_1',
    OriginDomain.visibilityFear,
    "In groups, I hold back my ideas so I don't stand out.",
    pairKey: 'visibility_fear_pair',
  ),
  BlockMapItem(
    'visibility_fear_2',
    OriginDomain.visibilityFear,
    'I avoid being the center of attention whenever I can.',
  ),
  BlockMapItem(
    'visibility_fear_3',
    OriginDomain.visibilityFear,
    'I let others take credit rather than put myself forward.',
  ),
  BlockMapItem(
    'visibility_fear_4',
    OriginDomain.visibilityFear,
    'In groups, I share my ideas when I have them.',
    reverse: true,
    pairKey: 'visibility_fear_pair',
  ),
];

````

