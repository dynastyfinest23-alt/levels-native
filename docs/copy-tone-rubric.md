# Copy tone rubric — Levels reveal & LLM copy

Purpose: source-of-truth checklist for any cold-context judge pass on
user-facing copy (dashboard reveal, drill/track content, LLM-generated text).
Reconstructed from CLAUDE.md's four mechanic-leak classes, the
`delete-ai-words` rules, MASTER.md §6, and CLAUDE.md's Tone and product ethics
section. A judge scores each generated sample against all 10 criteria; any
fail routes to fallback copy or a prompt fix (never ships as-is).

1. **No raw zone enum tokens.** Copy never surfaces a DB token
   (`builder`, `love_flow`, etc.) — always the `ZoneStyle` display name.
2. **No zone name used as a noun/identity label** ("that flow maintains
   itself"). Zones are positions in a climb, described as states the person
   is in, not labels they are. *(Caught: flow/R2, zone-name-as-mechanic.)*
3. **No book/calibration vocabulary.** No Dodson/Hawkins/Law of One scale
   terms, numbers, or classifications in user-facing copy — plain
   behavioral language only.
4. **No raw mechanic numbers or instrument meta-commentary.** No
   verified-floor numbers, no "you're at the edge of what one assessment
   can measure" — the copy never narrates the scoring instrument itself.
5. **`bridge_question` is an invitation, never a fourth data panel.** It
   must not recap or restate what the reveal panels (`reality_tunnel`,
   `hidden_benefit`, `illusion`) already said — it opens a new question
   forward, per MASTER.md §6's invitation/data-panel distinction.
   *(Caught: builder_clamped/R8, bridge-question-as-recap.)*
6. **No manufactured urgency.** No countdown framing, streak-guilt, or
   alarm language around a user's energy state.
7. **No implied single-assessment Flow, no permanent-identity framing.**
   Never imply Flow is reachable from one quiz; never imply a low zone is
   who the person is rather than where they currently are.
8. **Variable reward is framing only.** Copy may vary how a true result is
   presented; it may never imply the score itself is randomized, inflated,
   or negotiable.
9. **No AI-tell vocabulary or puffery.** Cut `delete-ai-words`-banned words
   (unlock, elevate, game-changer, dive in, seamless, empower, journey,
   etc.), rule-of-three padding, and inflated claims about ordinary facts.
10. **No reframe rhetoric or instrument meta-commentary as style.** No
    "this isn't X, it's Y" reframes, no rhetorical-question pivots, no
    commentary about the copy/assessment process itself — say the thing
    directly.

Judge pass runs cold (no authorship memory) per CLAUDE.md's M2.4 method:
score each of the 10 criteria pass/fail per sample; any fail blocks ship.
