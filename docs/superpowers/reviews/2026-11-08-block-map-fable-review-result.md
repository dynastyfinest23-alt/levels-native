<!-- Purpose: Fable 5.1's review of the block-map design + plan (verbatim, as pasted by Noah 2026-11-08) and the disposition of every finding. Source: review run on the packet 2026-11-08-block-map-fable-review.md. -->

# Block map: Fable 5.1 review result and disposition

## Disposition (Claude, 2026-11-08; cuts decided by Noah)

| # | Finding | Disposition |
|---|---|---|
| 1 | Assessment UPDATE policy lets clients write results | Applied: SELECT + INSERT policies only, `REVOKE UPDATE, DELETE` from authenticated/anon, read-back checks it (spec §5, Task 2) |
| 2 | INSERT doesn't check loop ownership (slot squatting) | Applied: loop-owner EXISTS in WITH CHECK + `cardinality(item_order) = 48` |
| 3 | Enum order unpinned | Applied: `enum_range` check in levels-verify, listed in group 5; Dart side already pinned by the bank test |
| 4 | Thresholds can drift between SQL and Dart | Applied: four named constants in both, in group 5, plus boundary vectors G6a-G8b |
| 5 | Create race on `(loop_id, kind)` | Applied: `23505` → fetch existing session; controller test (RF2) |
| 6 | Route can't express kind | Applied: `/block-map/:loopId?kind=initial\|retake` (the pasted finding was cut off mid-sentence; intent taken from the visible text) |
| 7 | Back from result lands on a dead runner | Applied: completed session → result route; controller test (RF3) + manual-run step |
| 8 | Drill FK has no ON DELETE | Applied: `ON DELETE SET NULL` |
| 9 | SQL doesn't range-check values or metadata count | Applied: raises on value outside 0..4 and metadata count ≠ 48; levels-verify checks the raise |
| 10 | Scorer race with a late upsert | Applied: `SELECT ... FOR UPDATE` first |
| 11 | Responses trust a client-supplied `user_id` | Applied: column dropped; ownership derived from the parent |
| 12 | Retake needs the initial row's sums | Moved to the deferred retake plan (`fetchRowByKind`) |
| 13 | Task 2 holds the security surface but was on Sonnet | Applied: Task 2 → Opus |
| 14 | Orphaned in-progress runs; anon on `block_map_items` | Orphaning documented as accepted (matches the lapse policy); `REVOKE ALL ... FROM anon, PUBLIC` applied |
| 15 | Retake overlay may read as regression | Moved to the deferred retake plan (cold-judge check + equal-weight styling option) |
| Golden check | G1-G5 match | Confirmed. Fable's proposed G6 was wrong: it used relational_attachment, whose `_3` pairing gives diff 2, so only 2 pairs contradict and no flag fires. Replaced with G6a/G6b using ai/ec/as; G7a/b and G8a/b built by hand at the 40/39 and 36/35 edges. |
| Cut: outer ring | | Noah: **cut** (with `blockMapDisplayOrder`) |
| Cut: spoke-tap labels | | Noah: **keep** |
| Cut: Task 7 retake | | Noah: **defer** to a later plan |

## Fable 5.1 review (verbatim)

Let me read the full packet directly from the uploaded markdown.

Verdict: ship after fixes. The scoring is right and the golden vectors check out; the defects are in the RLS surface, two mirror-sync gaps, and three interface mismatches in the plan.

Findings
#    Sev    Location    Problem    Fix
1    blocker    Spec §5 RLS / Task 2 step 3    CONFIRMED (author's concern). Postgres row policies don't restrict columns. With an UPDATE policy on block_map_assessments, an authenticated client can PATCH domain_sums, ranked_domains, flags, confidence, kind, loop_id, item_order on any of its own uncompleted rows. completed_at is blocked only if WITH CHECK repeats completed_at IS NULL. Nothing in the client needs UPDATE: item_order is set at INSERT, results come from the RPC.    Create no UPDATE policy on block_map_assessments and REVOKE UPDATE, DELETE ON block_map_assessments FROM authenticated, anon. Keep SELECT + INSERT only. Add the absence of an UPDATE policy to the Task 2 step 6 read-back.
2    major    Spec §5 INSERT policy    CONFIRMED gap. INSERT WITH CHECK is only auth.uid() = user_id; loop_id is unchecked. A user who knows another user's loop_id can create (that_loop, 'initial') and, via UNIQUE (loop_id, kind), permanently block that user from ever starting a block map.    WITH CHECK adds EXISTS (SELECT 1 FROM ascension_loops l WHERE l.id = loop_id AND l.user_id = auth.uid()). Add CHECK (cardinality(item_order) = 48).
3    major    Spec §7 / Task 3    CONFIRMED gap. domain_sums index and tie-break 2 both depend on the Postgres origin_domain enum order equalling Dart OriginDomain.values order. Nothing in group 5 pins that. One ALTER TYPE ... ADD VALUE BEFORE or a Dart reorder silently misattributes every sum and the wheel draws the wrong domain glowing.    Add to group 5 and levels-verify: SELECT enum_range(NULL::origin_domain) must equal the Dart token list in order; add a Dart test that blockMapItems[i].domain == OriginDomain.values[i ~/ 4].
4    major    Spec §4 "thresholds tunable by migration"    CONFIRMED ambiguity. 40/36/3 live in the SQL function body and in computeBlockMap. Tuning "by migration" changes only one side and the golden tests still pass if the vectors don't straddle the threshold (none of G1–G5 do).    Name the thresholds as named constants in both artifacts, list them explicitly in group 5, and add boundary vectors (see Golden check).
5    major    Task 4 step 3 (create-or-resume)    HYPOTHESIS, high likelihood. Two tabs, or a tap on the hub card while the first createSession is in flight, both INSERT; the second hits 23505 on (loop_id, kind) and the controller surfaces a raw error on first open. Not in Review Focus.    Data source: catch 23505 and fetchSession; or INSERT with on_conflict=loop_id,kind + ignoreDuplicates then fetch. Add a controller test.
6    major    Task 4 route vs Task 7    CONFIRMED mismatch. The only runner route is /block-map/:loopId; Task 7 opens BlockMapScreen(kind: retake) but the route has no way to express kind. Also spec §6 names routes /block-map and /block-map/result, which disagree with both tasks.    Define `/block-map/:loopId?kind=initial
7    major    Task 5 step 4 / back-navigation    CONFIRMED untested. Browser Back from /block-map/:loopId/result/:id lands on the runner; load() finds a completed session, and the spec doesn't say what happens. Likely outcome: runner shows item 48 with answers that can no longer be saved (RLS denies) → error toast.    load(): if session.completed, context.go to the result route. Pin in Task 4 tests.
8    minor    Spec §5 phase3_origin_drills.block_map_assessment_id    CONFIRMED gap. FK has no ON DELETE action. Deleting an ascension_loops row cascades to the assessment but the drill row's FK blocks it unless the drill also cascades from the loop.    ON DELETE SET NULL.
9    minor    Task 3 step 5, compute_block_map    CONFIRMED divergence. Dart throws on a value outside 0..4; the SQL function only checks length and NULL. On the levels-verify literal [5, ...] the two sides disagree. Also, under RLS a future restrictive policy on block_map_items would silently feed <48 metadata rows.    Raise on any value outside 0..4 and on count(*) FROM block_map_items <> 48. Add "throws on value 5" to levels-verify.
10    minor    Task 3 step 5, score_block_map    HYPOTHESIS. Without a row lock, a response upsert whose statement snapshot predates the scorer's commit can land after the results are written, leaving responses ≠ results. Two concurrent first calls are harmless (deterministic) but double-write.    SELECT ... FOR UPDATE on the assessment row before reading responses.
11    minor    Spec §5 responses policy    CONFIRMED gap. block_map_responses.user_id is client-supplied; policy checks it equals auth.uid() and that the parent is owned, but never that user_id = parent.user_id. Redundant column, but a future join on it would trust it.    Either drop user_id from responses (derive via parent) or add the equality to WITH CHECK.
12    minor    Task 7 step 3    CONFIRMED gap. Result route carries one assessmentId; the retake needs the initial row's sums too. No data-source method is specified for it.    Add fetchSession(loopId, BlockMapKind.initial) use, or a fetchRowByKind(loopId, kind).
13    minor    Plan tiers    IDEA. Task 2 is where findings 1, 2, 8, 11 live and it's on Sonnet; Task 3's scoring is the easy, test-pinned part.    Opus (or Opus review) for Task 2; Task 3 can stay Opus.
14    minor    Review Focus    CONFIRMED untested: loop lapses mid-run (new loop → new loop_id → old in-progress assessment orphaned, hub shows a fresh card with no explanation); anon SELECT on block_map_items not explicitly revoked.    Document orphaning as accepted or hide the card when an in-progress row exists for a prior loop; add REVOKE ALL ON block_map_items FROM anon.
15    nit    Spec §2 retake overlay    IDEA (ethics). Filled new shape over dashed old shape invites "did I get worse"; a spoke that grew reads as regression. No number shown, but the comparison is the mechanic.    Keep, but have the cold judge test the retake copy for the "regression" reading; consider equal-weight styling.
Golden vector check
Enum order from block_map_items.dart: ra, ai, ec, as, sa, rr, is, isd, ia, sc, sp, vf. Forward effective = v, reverse = 4 − v.

G1 all 0: each domain 0+0+0+4 = 4. Ties → one effective ≥3 each → enum order. 48 identical raw → straight_line; effective 0 on 36 items (≥36) → minimizing; every pair |0−4| = 4 → contradiction. 3 flags → low. Matches.
G2 all 4: 4+4+4+0 = 12. straight_line; effective 0 on only 12 → no minimizing; |4−0| = 4 ×12 → contradiction. 2 flags → low. Matches.
G3 all 2: 8; straight_line only; |2−2| = 0. 1 flag → moderate. Matches.
G4 vf [4,4,4,0] → 4,4,4,4 = 16; sp [3,3,3,1] → 3,3,3,3 = 12; rest [1,1,1,3] → 1,1,1,1 = 4. Most common raw = 1 (30×) <40; no effective 0; all pair diffs 0. None → high. Matches.
G5 ra [4,2,1,3] → 4,2,1,1 = 8 (one ≥3); vf [3,3,2,4] → 3,3,2,0 = 8 (two ≥3); rest 4. vf before ra by tie-break 1. Pairs: ra (_3 vs _4) |1−1| = 0; vf |3−0| = 3 → one pair only; raw 1 appears 31×. None → high. Matches.
Discrimination: G1 vs G2 does isolate minimizing. Nothing isolates contradiction from straight_line (both appear only together), and no vector sits on a threshold edge. Add: G6 contradiction-only (3 pairs at diff ≥3, varied raws, e.g. ra/ai/ec [4,2,2,4], rest [2,1,2,2]) → flags [contradiction], moderate; G7 39 identical raws → no straight_line; G8 exactly 35 effective zeros → no minimizing. Also G5's ra pairing with _3 does nothing observable: with a _1 pairing it would be |4−1| = 3, giving 2 pairs, still no flag. The seed test is the only pin, as the plan admits.

What I'd cut
Self / Others / Standing / World outer ring + blockMapDisplayOrder. New taxonomy, new copy through the cold judge, a second ordering that can drift from enum order, display-only. Spokes in enum order with tap labels do the job.
Spoke-tap label on the result screen. The hero card already names the top domain; tap labels are the only place the other 11 domain names leak into the "no labels as identity" surface.
Task 7 (retake overlay) from this plan. Ship Tasks 1–6, get real data to tune the thresholds (spec §4 says so), then plan the retake with the route/kind issue (finding 6) already resolved.
