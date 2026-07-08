---
name: levels-verify
description: Run the Levels production verification suite — golden scoring tests, clamp/consistency discriminators, classification tests, trigger and RLS checks — against the deployed Supabase project via MCP, and report a pass/fail table. Use this skill at the start of any session touching the Levels backend, whenever the user says "run the golden tests", "verify production", "confirm you can reach Supabase", "check the deployed functions", or after ANY deployed function, enum, or schema change. Also use it when CLAUDE.md's Verify-as-you-go section is referenced.
---

# Levels production verify

Run the canonical verification suite against production project `dnqwsgpkinieitiiikij` using the Supabase MCP `execute_sql` tool (read-only SELECTs only — never DDL). Expected values below are the source of truth from CLAUDE.md, verified against production 2026-07-06. If any check fails, STOP and report — do not "fix" a deployed function without explicit approval.

## Step 1 — Scalar golden tests (one combined query)

The SQL editor and MCP return one result set, so run this as ONE query:

```sql
SELECT * FROM (VALUES
  ('score_to_zone(60)',      score_to_zone(60)::text,     'collapsed'),
  ('score_to_zone(89.99)',   score_to_zone(89.99)::text,  'collapsed'),
  ('score_to_zone(90)',      score_to_zone(90)::text,     'contracted'),
  ('score_to_zone(110)',     score_to_zone(110)::text,    'contracted'),
  ('score_to_zone(139.99)',  score_to_zone(139.99)::text, 'contracted'),
  ('score_to_zone(140)',     score_to_zone(140)::text,    'reactive'),
  ('score_to_zone(165)',     score_to_zone(165)::text,    'reactive'),
  ('score_to_zone(199.99)',  score_to_zone(199.99)::text, 'reactive'),
  ('score_to_zone(200)',     score_to_zone(200)::text,    'threshold'),
  ('score_to_zone(230)',     score_to_zone(230)::text,    'threshold'),
  ('score_to_zone(299.99)',  score_to_zone(299.99)::text, 'threshold'),
  ('score_to_zone(300)',     score_to_zone(300)::text,    'builder'),
  ('score_to_zone(380)',     score_to_zone(380)::text,    'builder'),
  ('score_to_zone(499.99)',  score_to_zone(499.99)::text, 'builder'),
  ('score_to_zone(500)',     score_to_zone(500)::text,    'flow'),
  ('score_to_zone(520)',     score_to_zone(520)::text,    'flow'),
  ('weight(100)',  apply_downward_anchor_weight(100)::text, '150.00'),
  ('weight(199)',  apply_downward_anchor_weight(199)::text, '298.50'),
  ('weight(200)',  apply_downward_anchor_weight(200)::text, '200.00'),
  ('weight(225)',  apply_downward_anchor_weight(225)::text, '225.00'),
  ('raw(shame_apathy)', answer_to_raw_score('shame_apathy')::text, '30'),
  ('raw(apathy_grief)', answer_to_raw_score('apathy_grief')::text, '65'),
  ('raw(contentment)',  answer_to_raw_score('contentment')::text,  '200'),
  ('raw(courage)',      answer_to_raw_score('courage')::text,      '275'),
  ('raw(willingness)',  answer_to_raw_score('willingness')::text,  '320'),
  ('raw(neutrality)',   answer_to_raw_score('neutrality')::text,   '400'),
  ('raw(love_flow)',    answer_to_raw_score('love_flow')::text,    '530')
) AS t(check_name, actual, expected);
```

Compare actual vs expected yourself; numeric formatting may differ (150 vs 150.00) — compare numerically, not as strings.

## Step 2 — Classification tests

`SELECT * FROM compute_phase5_classification(30, 28.5, 'ascension');` → delta 29.25, `true_ascension`, `new_loop`
`SELECT * FROM compute_phase5_classification(15, 12.0, 'movement');` → `residual_charge`, `deepening_protocol`
`SELECT * FROM compute_phase5_classification(-5, -8.0, 'regression');` → `false_positive`, `track_reassignment`

## Step 3 — Clamp & consistency discriminators (function-body check)

These require full `compute_center_of_gravity` runs against assessment rows; do NOT create production rows just to test. Instead verify by function body:

```sql
SELECT pg_get_functiondef(p.oid) FROM pg_proc p WHERE proname = 'compute_center_of_gravity';
```

Confirm, in this order inside the body: (a) `v_was_clamped := (v_cog > 499.99)` appears BEFORE (b) `v_cog := LEAST(v_cog, 499.99)`, and (c) the consistency cluster check compares raw scores to the raw mean (`ABS(s - v_raw_mean) <= 50`), not the weighted/clamped CoG. Expected behavioral facts (verified 2026-07-06): all-`love_flow` → 499.99, builder, was_clamped=true; 5×love_flow+2×neutrality → 492.86, was_clamped=false; all-`pride` → 285.00, `consistent`.

## Step 4 — Infrastructure checks

One combined query where possible:

- Trigger: `SELECT tgname, tgrelid::regclass FROM pg_trigger WHERE tgname = 'on_auth_user_created';` → one row on `users`.
- RLS: check `with_check` on `pg_policies` for any table touched this session (`SELECT policyname, cmd, qual, with_check FROM pg_policies WHERE tablename = '<table>';`).
- Enum values (only if enums changed): query `pg_type` joined to `pg_enum` — never `information_schema.columns`.

## Step 5 — Client mirror suite

If working in the repo, also run `flutter test` and confirm `test/scoring_mirror_test.dart` passes. DB checks and mirror tests together close the loop.

## Output

A single markdown table: check | expected | actual | PASS/FAIL, followed by one line stating either "All N checks pass against production" or exactly which checks failed and that no fix was attempted. Never gloss a failure; never mark a check passed that wasn't actually run (report skipped checks as SKIPPED with the reason).
