# Dodson 2e calibration reference (book-verified)

> Source: Levels-of-Energy-2e-master.pdf (image scans). Extracted 2026-07-12 by a
> Sonnet terminal session. VERIFICATION ARTIFACT ONLY — this file does not
> authorize any change to deployed scoring. Any mismatch is flagged for Noah,
> not fixed here. Book canon hierarchy: Dodson 2e is sole canon for mechanics.

## 12-anchor verdict table

| Anchor | Deployed | Book value | Printed page # | Verbatim book snippet | Verdict |
|--------|----------|-----------|----------------|-----------------------|---------|
| shame | 30 | 30 | p. 87 | "30: Guilt, Humiliation, Hatred" | match (heading names guilt/humiliation/hatred, not literally "shame" — see note below) |
| apathy | 50 | 50 | p. 90 | "50: Apathy, Hopelessness, Depression, Desperation" | match |
| grief | 80 | 80 | p. 110 | "80: Sorrow, Grief, Self-Pity, Depression, Pity" | match |
| fear | 100 | 100 | p. 126 | "100: Fear, Worry, Shyness, Panic, Inferiority" | match |
| desire | 120 | 125 | p. 150 | "125: Craving, Neediness, Addiction, Compulsion, Unfulfilled Desire, Longing, Obsession" | MISMATCH |
| anger | 160 | 160 | p. 172 | "160 Anger, Domination, Aggression, Violence, Rage, Revenge" | match |
| pride | 190 | 190 | p. 202 | "190 Pride, Arrogance, Superiority, Narcissism" | match |
| contentment | 200 | 200 | p. 218 | "200 Boredom, Contentment, Laziness, Functionality, Routine" | match |
| courage | 275 | 275 | p. 249 | "275 Courage, Relaxation, Eagerness, Fun" | match |
| willingness | 320 | 320 | p. 281 | "320 Willingness, Eagerness, Optimism, Activity, Kindness" | match |
| neutrality | 400 | 400 | p. 306 | "400 Neutrality, Acceptance, Interest, Attention, Concentration" | match |
| love | 530 | 550 (see note) | p. 374 | "The Love of 550 is unconditional, that of 505 is not." | MISMATCH |

**Note on shame (p.87):** the book's dedicated heading for level 30 reads "Guilt, Humiliation, Hatred" — it does not use the word "shame" in the heading itself, though the surrounding chapter text discusses shame-adjacent material. The *number* matches (30=30); this is a wording nuance, not a value mismatch.

**Note on love (p.374):** unlike the other 11 anchors, the book has no single dedicated numbered chapter heading in the format `"<number>: <names>"` for "Love." The 475–600+ range of the book is written as continuous prose/discussion rather than discrete numbered chapters. The value 550 is the book's most explicit, directly-quotable numeric statement about "Love" specifically ("The Love of 550 is unconditional"), found while reading printed pages 342–390 in full (two chunks, ~48 pages) searching specifically for a Love heading. Supporting context found in the same reading:
- p. 371: dedicated heading "505 Appreciation, Creativity, Beauty, Imagination" — the book treats "Appreciation" (505) as textually and numerically *distinct* from "Love."
- p. 379: "500 is the first level beyond mind, the first level of love which becomes increasingly unconditional as one moves upwards." (500 = entry point of love as a category, not a discrete anchor value)
- p. 381: "[Mecca] measure[s] at 530" — 530 does appear in the book, but attached to a place (Mecca), never to the "Love" concept.
- p. 385: Paramhansa Yogananda "measures at 530" — again 530 appears, attached to a person, not to "Love" as a concept.
- No dedicated "550: Love..." or "530: Love..." heading exists anywhere in the ~150 pages spanning printed pages ~214–390 that were read for this extraction.

Given the citation standard (dedicated heading + page, matching the other 11 anchors) could not be met for love, the verdict is recorded as MISMATCH against the strongest available direct textual citation (550, p.374), with the caveat above surfaced for Noah's adjudication rather than silently treated as NOT FOUND — the book unambiguously states a number for "Love" on p.374, it just isn't in chapter-heading form.

## Anchor → enum token mapping (reference)

(11 deployed `p1_answer` tokens; composite tokens anchor on their range low — `shame_apathy`=30 anchors on shame, `apathy_grief`=65, `love_flow`=530, etc. Copied verbatim from CLAUDE.md "Answer enum → raw score" — not recomputed here.)

| Token | Raw score |
|---|---|
| shame_apathy | 30 |
| apathy_grief | 65 |
| fear | 100 |
| desire | 120 |
| anger | 160 |
| pride | 190 |
| contentment | 200 |
| courage | 275 |
| willingness | 320 |
| neutrality | 400 |
| love_flow | 530 |

## Flagged discrepancies

1. **desire = 120 (deployed) vs. book = 125 (p. 150).** The book's dedicated heading for this level is "125: Craving, Neediness, Addiction, Compulsion, Unfulfilled Desire, Longing, Obsession" — the heading itself contains the phrase "Unfulfilled Desire," confirming it is the book's treatment of the desire concept, but the book anchors it at 125, not 120. Clean, unambiguous MISMATCH — same heading format as the other 10 matching anchors, just a different number.

2. **love = 530 (deployed) vs. book = 550 (p. 374, inline quote, not a chapter heading).** "The Love of 550 is unconditional, that of 505 is not." No dedicated "Love" chapter heading exists anywhere in the book's 475–600+ discussion (searched printed pages ~342–390 in full). 530 does appear elsewhere in the book, but only attached to places/people (Mecca, Yogananda), never to "Love" as a concept. This is the weaker of the two discrepancies from a citation-format standpoint (no heading to match the other 11 anchors' format), but the book's own words are unambiguous that when it *does* name a specific number for "Love," that number is 550, not 530.

## Not found

None — all 12 anchors have either a clean heading citation (10 of 12) or the book's best available direct textual citation with page number (love, p.374 — see caveat above; no anchor was left without any citation).
