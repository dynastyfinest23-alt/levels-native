---
name: levels-dev-loop
description: >
  End-to-end runbook for any change to the Levels deployed backend (Supabase project
  dnqwsgpkinieitiiikij) or its Dart mirrors — migrations, enums, triggers, RPCs, Edge
  Functions, RLS policies, or lib/features/assessment/scoring.dart. Use this skill
  whenever the user says "push this", "add a migration", "change the scoring", "deploy
  the function", "add a column", "recalibrate", or asks whether the DB matches the
  docs. Also trigger before trusting any value found in levels_schema.sql or CLAUDE.md
  scoring tables. (Merged from levels-backend-change 2026-07-09; this is the single
  backend runbook.)
---

# Levels dev loop — the backend runbook

The database is the ground truth; every doc lags it. This skill exists because stale
docs caused a real calibration bug (Hawkins values in CLAUDE.md vs. Dodson values in
the DB) and unverified pushes burned multi-hour debug chains. Backend changes are
shared with another client (the FlutterFlow repo) — nothing but this discipline keeps
the artifact copies aligned. Follow the phases in order, every time, even for
"trivial" changes.

## Phase 0 — Gate

1. Shared schema/functions must not change without explicit user approval (other
   clients depend on them). If the request is ambiguous about scope, ask ONE
   question, then proceed.
2. Identify which mirror-sync group(s) the change touches (CLAUDE.md "Mirror sync
   map") and list the exact files you will update in the same commit.

## Phase 1 — READ the live state first (never trust the docs)

- Function bodies: `SELECT pg_get_functiondef(p.oid) FROM pg_proc p WHERE proname = '<name>';`
- Enum members: join `pg_type` to `pg_enum` (information_schema does NOT list enum members).
- Triggers: `SELECT tgname, tgrelid::regclass, tgenabled FROM pg_trigger WHERE tgname = '<name>';`
- `levels_schema.sql` and CLAUDE.md tables are reference sketches only. If the live
  read disagrees, the live read wins and the doc gets a fix in the same session.

## Phase 2 — WRITE the migration under the known constraints

- `npx supabase migration new <name>` → paste SQL → `npx supabase db push` from this
  repo (sole migration authority — never from levels-app). Success signal:
  `Applying migration ...` + `Finished supabase db push`; Docker Desktop warnings are noise.
- **`ALTER TYPE ... ADD VALUE` must be its own migration**, pushed before any function
  that references the new value. Never write the retired v1.0 tokens
  (`courage_neutrality`, `willingness_acceptance`, `reason`).
- `CREATE POLICY` has no `IF NOT EXISTS` — pair with `DROP POLICY IF EXISTS`.
- Never `REFRESH MATERIALIZED VIEW CONCURRENTLY` inside a transaction; otherwise wrap in BEGIN/COMMIT.
- Every SECURITY DEFINER function gets `SET search_path = public, pg_temp`. New
  tables get RLS scoped to `auth.uid() = user_id` for SELECT/INSERT/UPDATE.
- Migrations are the ONLY schema-change path; never DDL via ad-hoc `execute_sql`.

## Phase 2b — Edge Functions (if applicable)

- Deploy: `npx supabase functions deploy generate-dashboard-copy` (canonical name uses hyphens).
- Secrets: NEVER put a key's literal value in any command — the user types
  `supabase secrets set` in their own terminal; confirm via `secrets list` (names only).
- Debug failures via the secrets-and-debug-discipline ladder: read the actual status
  + body before any hypothesis. Known history: every generate-dashboard-copy failure
  so far was key validity or credit balance, never architecture.
- Before invoking anything with a one-shot cache write (`one_dashboard_per_loop`),
  test against a disposable loop row, then clean it up.

## Phase 3 — VERIFY via MCP immediately after push

Run the `levels-verify` skill (full suite if scoring/classification changed; at
minimum the checks for what you touched plus trigger/RLS checks for new objects).
Re-read changed function bodies with `pg_get_functiondef` — verify what deployed,
not what you intended. A push without an MCP read-back is not done.

## Phase 4 — MIRROR sync + golden tests

Update every member of the touched mirror-sync group in the same change:

1. Dart mirrors in `lib/features/assessment/scoring.dart` — exact arithmetic copies
   (DB authoritative; mirrors preview-only).
2. `test/scoring_mirror_test.dart` — golden values for any new behavior; each group
   states what it pins and the verification date. DB-side pattern: insert a crafted
   row via `execute_sql` → run the RPC → read back → delete the test row.
3. CLAUDE.md canonical tables/golden values, stamped "verified against production YYYY-MM-DD".
4. Four-part reveal schema changes: `fallback.ts` + `index.ts` (`REQUIRED_FIELDS`,
   prompt, JSON schema) + `dashboard_copy.dart` together.

## Phase 5 — Done means done

- `flutter analyze` clean, `flutter test` passes.
- Report verify results as a PASS/FAIL/SKIPPED table — actual outputs, never assumptions.
- Commit: imperative mood, no prefixes, no AI trailers, one line covering the change
  AND its mirrors. Only commit when the user asked.
- Anything failed or skipped is stated plainly at the top of the report.

## Hard stops

- Never include a secret's literal value in any command.
- Never push a migration that both adds an enum value and uses it.
- Never mark a change complete on `db push` output alone.
