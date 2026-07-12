# Dodson 2e extraction prompt — run in a separate Sonnet Claude Code terminal

> Purpose: produce `docs/dodson-2e-reference.md` — a verification artifact that
> checks the deployed Levels calibration anchors against the book itself, so the
> book (not web summaries) is the recorded source of truth. Written by the Opus
> planning session 2026-07-12 for a Sonnet executor to run.

## How to run

1. Open a Claude Code terminal on `C:\Users\Administrator\levels-native`, set model to **Sonnet 5** (`/model`).
2. Paste this single instruction:

   > Read `docs/dodson-2e-extraction-prompt.md` in full and execute the task it describes. Follow every constraint. Stop at the review gate — do not edit any scoring code, migration, or CLAUDE.md table.

3. When it finishes, it hands the draft `docs/dodson-2e-reference.md` back to Noah for the review gate.

---

## The task

Produce `docs/dodson-2e-reference.md`: a table verifying each of the 12 Dodson
calibration anchors against the book's own text.

### Source (primary only)

`H:\My Drive\Levels of energy\Levels-of-Energy-2e-master.pdf` — Frederick
Dodson, *Levels of Energy* 2nd edition. The pages are **image-only scans**, so
read them as images. **Do not read all 264 pages.** Use the PDF bookmarks /
front-matter to locate the section that defines the calibration scale (the list
of levels with their numeric values — typically a "map"/"scale of levels"
table or the chapter that walks the levels in order). Read only the pages that
carry the anchor values, plus enough surrounding text to quote each one.

**No web sources.** A 2026-07-10 web check disagreed with the book on at least
one anchor (anger). The book is canon; the web is not. If you cannot find a
value in the PDF, mark it `NOT FOUND IN PDF` — never fill it from memory or the
web.

### The 12 anchors to verify (deployed values, from CLAUDE.md)

| Anchor | Deployed value |
|---|---|
| shame | 30 |
| apathy | 50 |
| grief | 80 |
| fear | 100 |
| desire | 120 |
| anger | 160 |
| pride | 190 |
| contentment | 200 |
| courage | 275 |
| willingness | 320 |
| neutrality | 400 |
| love | 530 |

These are the *deployed* numbers (already verified against the production
`answer_to_raw_score` function body 2026-07-03). Your job is the *other* leg:
confirm each against the book. **anger = 160** is the known watch-item — quote
the book's exact value and page for it specifically.

### Output schema — write to `docs/dodson-2e-reference.md`

```
# Dodson 2e calibration reference (book-verified)

> Source: Levels-of-Energy-2e-master.pdf (image scans). Extracted <date> by a
> Sonnet terminal session. VERIFICATION ARTIFACT ONLY — this file does not
> authorize any change to deployed scoring. Any mismatch is flagged for Noah,
> not fixed here. Book canon hierarchy: Dodson 2e is sole canon for mechanics.

## 12-anchor verdict table

| Anchor | Deployed | Book value | Printed page # | Verbatim book snippet | Verdict |
|--------|----------|-----------|----------------|-----------------------|---------|
| shame  | 30       | ...       | p. ...         | "..."                 | match / MISMATCH |
| ...    |          |           |                |                       |         |

## Anchor → enum token mapping (reference)
(11 deployed p1_answer tokens; composite tokens anchor on their range low —
shame_apathy=30 anchors on shame, apathy_grief=65, love_flow=530, etc. Copy the
canonical table from CLAUDE.md "Answer enum → raw score"; do not recompute it.)

## Flagged discrepancies
(Every row whose Verdict is MISMATCH, restated with the book snippet + page so
Noah can adjudicate. If none, write "None — all 12 anchors match the book.")

## Not found
(Any anchor whose value could not be located in the PDF.)
```

Rules for the table:
- Quote the book **verbatim** (short snippet, in quotes) with the **printed page
  number** shown on the scan, so Noah can spot-check without re-reading.
- If the book gives a value that differs from the deployed number, the verdict is
  `MISMATCH` — record it, do not "correct" either side.
- Read each anchor's page twice before recording its number (these feed scoring;
  a transcription slip here is expensive).

### Hard constraints (do not violate)

- **Change nothing but the new doc.** No edits to `scoring.dart`, any migration,
  any deployed function, or the CLAUDE.md scoring tables. This is read-and-record.
- The deployed function bodies are **frozen** — a book/deploy mismatch is a
  question for Noah, not a license to edit. Log mismatches in the "Flagged
  discrepancies" section and stop.
- Cite the printed page number for every value. No page number → treat as
  `NOT FOUND`.
- End at the review gate: present the draft and the flagged-discrepancies list to
  Noah. Do not commit until he approves (content gate, per CLAUDE.md).

### Done when

- `docs/dodson-2e-reference.md` exists with all 12 anchors filled (value + page +
  snippet + verdict), the enum-token mapping section, and the discrepancies
  section.
- Every anchor either has a book page citation or is marked `NOT FOUND IN PDF`.
- No file other than the new doc was modified.
- The draft is handed to Noah; nothing committed yet.
