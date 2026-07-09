---
name: levels-backend-change
description: End-to-end runbook for any change to the Levels deployed backend — new or altered Postgres functions, enums, tables, RLS policies, or Edge Functions. Use this skill whenever the user asks to add/modify a migration, change a scoring or classification function, deploy or debug an Edge Function, add a column, or anything that touches supabase/migrations or supabase/functions. Trigger on "migration", "db push", "deploy function", "add column", "change the function", "recalibrate", or any request that would alter what is deployed to Supabase project dnqwsgpkinieitiiikij.
---

# Levels backend change runbook

Backend changes here are shared with another client (the FlutterFlow repo). Nothing but this discipline keeps five artifact copies aligned. Follow the phases in order; do not skip the confirmation gate or the verify phase. Ground truth is the live database (read it via MCP before writing SQL — see the levels-dev-loop skill); CLAUDE.md documents the canonical numbers but lags production when stale, so read its relevant section AND verify against the live function body.

## Phase 0 — Gate

1. Confirm the change is approved: shared schema/functions must not change without explicit user approval (other clients depend on them). If the request is ambiguous about scope, ask ONE question, then proceed.
2. Identify which mirror-sync group(s) the change touches (CLAUDE.md "Mirror sync map"). List the exact files you will need to update in the same commit. If scoring changes: deployed fn + `lib/features/assessment/scoring.dart` + `test/scoring_mirror_test.dart` + CLAUDE.md golden values.

## Phase 1 — Write the migration

- `npx supabase migration new <name>` → paste SQL → `npx supabase db push`. Migrations are the ONLY schema-change path; never DDL via ad-hoc `execute_sql`.
- Enum value additions: TWO sequential migration files — `ALTER TYPE ... ADD VALUE` cannot be referenced in the same transaction. Never write the retired v1.0 tokens (`courage_neutrality`, `willingness_acceptance`, `reason`).
- `CREATE POLICY` has no `IF NOT EXISTS` — precede with `DROP POLICY IF EXISTS`.
- `REFRESH MATERIALIZED VIEW CONCURRENTLY` must run outside BEGIN/COMMIT.
- Otherwise wrap in BEGIN/COMMIT.
- New/replaced SECURITY DEFINER functions: `SET search_path = public, pg_temp`. New tables: RLS scoped to `auth.uid() = user_id` for SELECT/INSERT/UPDATE.
- Success signal for `db push`: `Applying migration <file>...` then `Finished supabase db push`. Docker Desktop warnings are noise.

## Phase 2 — Edge Functions (if applicable)

- Deploy: `npx supabase functions deploy generate-dashboard-copy` (canonical name uses hyphens).
- Secrets: NEVER put a key's literal value in any command — the user types `supabase secrets set` in their own terminal. Confirm by `npx supabase secrets list` (names only).
- Debugging failures: follow the debug ladder in the secrets-and-debug-discipline skill — read the actual status + body before forming any hypothesis; test the upstream API directly before blaming the wrapper. Known history: every generate-dashboard-copy failure so far was key validity or credit balance, never architecture.
- Before invoking anything with a one-shot cache write (`one_dashboard_per_loop`), test against a disposable loop row, then clean it up.

## Phase 3 — Verify against production

Run the `levels-verify` skill (full suite if scoring/classification changed; at minimum the checks for what you touched, plus trigger/RLS checks for new objects). Re-read changed function bodies with `pg_get_functiondef` — verify what deployed, not what you intended.

## Phase 4 — Mirror sync

Update every member of the touched mirror-sync group in this same change:

1. Dart mirrors in `lib/features/assessment/scoring.dart` must be exact arithmetic copies (the DB is authoritative; mirrors are preview only).
2. Extend `test/scoring_mirror_test.dart` with golden values for any new behavior; each test group states what it pins and the verification date.
3. Update CLAUDE.md's canonical tables/golden values and stamp "verified against production YYYY-MM-DD".
4. If the four-part reveal schema changed: `fallback.ts` + `index.ts` (`REQUIRED_FIELDS`, prompt, JSON schema) + `dashboard_copy.dart` together.

## Phase 5 — Done means done

- `flutter analyze` clean, `flutter test` passes.
- Report the verify results as a table (PASS/FAIL/SKIPPED) — actual outputs, never assumptions.
- Commit: imperative mood, no prefixes, one summary line covering the change AND its mirrors (match `git log` register). Only commit when the user asked.
- If anything failed or was skipped, say so plainly at the top of the report.
