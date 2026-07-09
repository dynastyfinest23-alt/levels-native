---
name: session-handoff
description: >
  Capture end-of-session state into a handoff block and reconstruct it at the start of
  the next session, so no session begins by re-deriving where the last one stopped. Use
  this skill whenever the user says "wrap up", "let's stop here", "I'll continue tomorrow",
  "draft the next session prompt", "hand this off", or when a session is ending mid-task.
  Also use at session START when the user pastes a handoff block or says "continue where
  we left off" — verify the claimed state before building on it.
---

# Session Handoff

Sessions on this project routinely end mid-task (mid-verification, mid-debug, mid-build).
The next session then pays a reconstruction tax — or worse, builds on an unverified
assumption about what shipped. This skill makes the boundary explicit in both directions.

## ENDING a session — produce the handoff block

Write a block with exactly these five sections, terse, no narrative:

1. **SHIPPED & VERIFIED** — only things confirmed by MCP read-back, passing test, or
   observed runtime behavior. Include migration filenames / function names.
2. **IN FLIGHT** — the task that was interrupted, its exact stopping point, and the
   current hypothesis if mid-debug (e.g., "400 on invoke; next check: model ID validity").
3. **NOT STARTED** — the next 1–3 planned items, in order.
4. **LANDMINES** — anything the next session could waste time on: known-stale docs,
   platform incidents, env quirks, half-applied changes.
5. **NEXT SESSION PROMPT** — a paste-ready opening prompt for the next Claude Code
   session: role line, the one goal, the first concrete action, and the verification
   that proves it done ("done-when").

Then, if CLAUDE.md is stale relative to SHIPPED & VERIFIED, update it now — a handoff
that points at stale docs is a landmine, not a handoff.

## STARTING a session — verify before building

When given a handoff block (or asked to continue):
1. Treat SHIPPED & VERIFIED claims as *probably* true — but re-verify the one item the
   new work depends on (one MCP read, one test run) before building on it.
2. Resume IN FLIGHT at the recorded stopping point; do not restart the task from scratch
   and do not skip ahead to NOT STARTED while IN FLIGHT is unresolved.
3. Read LANDMINES before running anything.
4. If no handoff block exists, reconstruct one from: CLAUDE.md, `git log --oneline -10`,
   and one MCP state read — then confirm the reconstruction with the user in ≤5 lines
   before proceeding.

## Output
- On end: the five-section handoff block (and the CLAUDE.md sync, if needed).
- On start: a ≤5-line "resuming from" summary naming what was re-verified, then the work.

## Rules
- Never list anything under SHIPPED & VERIFIED that wasn't actually verified — "pushed"
  is not "verified".
- The NEXT SESSION PROMPT must contain a done-when. A goal without a verification
  criterion is how sessions drift.
- Keep the whole block under ~30 lines. A handoff nobody reads is worse than none.
