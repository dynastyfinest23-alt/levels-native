# Action items for Noah

## M2.4 full-flow artifact — screenshot path unavailable (2026-07-15)

PRD M2.4 status now cites the M-DS.3 reveal-flow screenshot set as its
full-flow artifact, but `Screenshots/` at the repo root is currently
empty/absent (per CLAUDE.md, that folder is transient and only present when
populated). Did not re-shoot per Task 2c instructions — flagging instead.

If you want a durable artifact on record for this gate, either point to
where the M-DS.3 screenshots actually live now, or ask for a fresh screenshot
pass next session.

## love_flow decision brief — 530 (deployed) vs. book (2026-07-15)

**What the book says (`docs/dodson-2e-reference.md`, "Not found" / anchor
table, p. 374 + supporting pages 371/379/381/385):** unlike the other 11
anchors, the book has no dedicated "N: Love, ..." chapter heading. Its most
explicit direct quote naming a number for "Love" is p. 374: *"The Love of
550 is unconditional, that of 505 is not."* Supporting context: p. 371 gives
"505 Appreciation, Creativity, Beauty, Imagination" as textually distinct
from Love; p. 379 says "500 is the first level beyond mind, the first level
of love"; pp. 381/385 show 530 attached to a place (Mecca) and a person
(Yogananda) — never to the "Love" concept itself. The reference doc's own
verdict calls this the *weaker* of its two flagged mismatches specifically
because no heading exists to cite in the same format as the other 11
anchors (desire's 120→125 mismatch, by contrast, was a clean heading-to-
heading citation).

**What production has:** `love_flow` = 530 (deployed `answer_to_raw_score`;
mirrored in `lib/features/assessment/scoring.dart` as `P1Answer.loveFlow`).

**Why 530 vs. 550 barely matters for the common case:** in a single
assessment, `love_flow`'s raw score only needs to clear the 500 Flow
threshold for the clamp mechanic (`LEAST(v_cog, 499.99)`) to fire — both 530
and 550 clamp identically to 499.99/`builder`/`was_clamped=true`. The number
only changes outcomes in **mixed** assessments (some `love_flow` answers,
some lower-scoring ones) where the weighted average lands under 500 and
isn't clamped — there the literal value shifts the CoG. Concretely, the
existing pinned discriminator in CLAUDE.md's Verify-as-you-go section
(5×`love_flow` + 2×`neutrality` → 492.86, `builder`, `was_clamped=false`)
would flip to `was_clamped=true` at 550 ((5×550+2×400)/7 = 507.14, which
clamps) — that specific documented example would need to be replaced, not
just renumbered.

**Options:**
1. **Defer — keep 530.** The book itself never commits to a number for
   "Love" as a concept in the heading format used everywhere else; 550 is
   the strongest quote found, but it's adjacent, not a direct anchor
   citation. Lowest-risk choice; no mirror-sync churn.
2. **Recalibrate to 550** per the book's most explicit textual number,
   accepting the weaker citation standard.

**Recommendation: defer (option 1).** Desire's correction was a clean
heading mismatch (same format, different number) — this one isn't. Given
the citation gap the reference doc itself flags, and that a change here
buys no behavioral difference in the common full-`love_flow` case, I'd hold
off unless you want to explicitly adjudicate the ambiguous citation.

**If you do want to change it, the full mirror-sync set to touch in one
commit:** (1) deployed `answer_to_raw_score` Postgres function body via a
new additive migration (no enum ALTER needed — `love_flow` token already
exists, only its returned raw score changes); (2)
`lib/features/assessment/scoring.dart` (`P1Answer.loveFlow` raw score); (3)
`test/scoring_mirror_test.dart`, including replacing the
5×love_flow+2×neutrality discriminator with a composition that still
demonstrates `was_clamped=false` at the new value; (4) CLAUDE.md's scoring
table, the Downward anchor weighting/clamp prose, and the Verify-as-you-go
golden-test line; (5) `docs/dodson-2e-reference.md`'s verdict row, flipped
from MISMATCH to match/adjudicated — follow the `levels-dev-loop` skill
end to end, same pattern as the desire 120→125 migration.
