---
name: levels-dev-loop
description: >
  Enforce the Levels project's migration, verification, and doc-sync discipline for any
  change to the Supabase backend (project dnqwsgpkinieitiiikij) or its Dart mirrors. Use
  this skill whenever a session touches a Postgres migration, enum, trigger, RPC, Edge
  Function, RLS policy, or the Dart scoring mirror in levels-native — or whenever the user
  says "push this", "add a migration", "change the scoring", "update the function", or
  asks whether the DB matches the docs. Also trigger before trusting any value found in
  levels_schema.sql or CLAUDE.md scoring tables.
---

# Levels Dev Loop

The database is the ground truth; every doc lags it. This skill exists because stale docs
caused a real calibration bug (Hawkins values in CLAUDE.md vs. Dodson values in the DB)
and because unverified pushes have burned multi-hour debug chains. Follow the loop in
order, every time, even for "trivial" changes.

## Inputs
- The intended change (SQL, Edge Function code, or Dart mirror change)
- Access to Supabase MCP for project `dnqwsgpkinieitiiikij`

## The loop — always in this order

### 1. READ the live state first (never trust the docs)
Before writing any migration, read what is actually deployed:
- Function bodies: `SELECT pg_get_functiondef(p.oid) FROM pg_proc p WHERE proname = '<name>';`
- Enum members: join `pg_type` to `pg_enum` (information_schema does NOT list enum members)
- Triggers: `SELECT tgname, tgrelid::regclass, tgenabled FROM pg_trigger WHERE tgname = '<name>';`
- `levels_schema.sql` and CLAUDE.md tables are reference sketches only. If the live read
  disagrees with them, the live read wins and the doc gets a fix task (step 6).

### 2. WRITE the migration under the known constraints
- `npx supabase migration new <name>` → paste SQL → `npx supabase db push`
  from the repo root. Docker Desktop warnings and "failed to cache migrations catalog"
  are non-fatal noise; the success signal is `Applying migration ...` + `Finished supabase db push`.
- **`ALTER TYPE ... ADD VALUE` must be its own migration**, pushed before any function
  that references the new value (Postgres transaction constraint).
- **Never call `REFRESH MATERIALIZED VIEW CONCURRENTLY` inside a transaction.**
- Every `SECURITY DEFINER` function gets `SET search_path = public, pg_temp`.
- `CREATE POLICY` has no `IF NOT EXISTS` — pair with `DROP POLICY IF EXISTS`.

### 3. VERIFY via MCP immediately after push
Re-run the step-1 reads and confirm the deployed body/enum/trigger matches intent.
A push without an MCP read-back is not done.

### 4. MIRROR to Dart if scoring logic changed
Any change to `compute_center_of_gravity`, zone boundaries, enum tokens, or the clamp
must be reflected in the Dart scoring mirror the same session. The mirror is preview-only
("LLM never decides, functions do" — and neither does the client), but drift causes
confusing UX bugs.

### 5. GOLDEN TEST the boundaries
If a calibration, clamp, or zone boundary changed, add/adjust golden tests for the edge
cases (clamped vs. unclamped CoG, values at each zone boundary). Pattern for DB-side
verification: insert a crafted row via MCP `execute_sql` → run the RPC → read back →
delete the test row.

### 6. SYNC the docs, last
Update CLAUDE.md (and levels_schema.sql if touched) to match what was verified — not
what was intended. Note the migration filename next to changed values.

## Output
A short checklist confirmation per change: live-read done → migration pushed → MCP
verified → mirror synced (or N/A) → golden tests (or N/A) → docs synced. If any step is
skipped, say which and why.

## Hard stops
- Never include a secret's literal value in any command (defer to secrets-and-debug-discipline).
- Never push a migration that both adds an enum value and uses it.
- Never mark a change complete on `db push` output alone.
