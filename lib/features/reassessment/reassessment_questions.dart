// Behavioral copy for the Phase 5 reassessment flow (Window 2 / Window 3
// check-ins) and the false-positive rediag path. M5.1 content — pending
// Noah's written approval before M5.2 builds screens against it.

import '../assessment/questions.dart' show AnswerOption;
import '../assessment/scoring.dart';

/// One of the two re-run questions (Q1 trigger, Q2 body-state).
///
/// Both reuse `P1Answer` and are verbatim re-asks of their Phase 1 source
/// question — `process_phase5_reassessment` computes q1_delta/q2_delta by
/// diffing the new raw score against the original Phase 1 raw score on the
/// identical scale, so the stimulus must not change between assessment and
/// re-check. Verified against production 2026-07-19: `q5_raw_score` (Q5,
/// Locus of Control) maps to Q1 of the check-in; `q6_raw_score` (Q6,
/// Body-State Scan) maps to Q2, both via `pg_get_functiondef` on
/// `process_phase5_reassessment`.
class ReassessmentRecheckQuestion {
  const ReassessmentRecheckQuestion({
    required this.title,
    required this.prompt,
    required this.options,
  });

  final String title;
  final String prompt;
  final List<AnswerOption> options;
}

/// Q1 — re-run of Phase 1 Q5 (Locus of Control), the loop's trigger question.
const ReassessmentRecheckQuestion reassessmentQ1Trigger =
    ReassessmentRecheckQuestion(
  title: 'Your position',
  prompt:
      'Looking honestly at where your life is right now, '
      'what put you here?',
  options: [
    AnswerOption(
      'My own defects. I have sabotaged everything good',
      P1Answer.shameApathy,
    ),
    AnswerOption(
      'Losses I never got a say in',
      P1Answer.apathyGrief,
    ),
    AnswerOption(
      'Forces mostly outside my control',
      P1Answer.fear,
    ),
    AnswerOption(
      'People who blocked me and systems rigged against me',
      P1Answer.anger,
    ),
    AnswerOption(
      'My grit. I made it here despite everyone',
      P1Answer.pride,
    ),
    AnswerOption(
      'My choices, including the bad ones, which I own',
      P1Answer.courage,
    ),
    AnswerOption(
      'A mix of choice and circumstance, and both are workable',
      P1Answer.neutrality,
    ),
  ],
);

/// Q2 — re-run of Phase 1 Q6 (Body-State Scan).
const ReassessmentRecheckQuestion reassessmentQ2BodyState =
    ReassessmentRecheckQuestion(
  title: 'Body check',
  prompt:
      'Close your eyes for three seconds and scan your body. '
      'What is the dominant signal?',
  options: [
    AnswerOption(
      'Heaviness, like moving through wet sand',
      P1Answer.apathyGrief,
    ),
    AnswerOption(
      'A tight chest or knotted stomach that never fully unwinds',
      P1Answer.fear,
    ),
    AnswerOption(
      'Restless craving, reaching for the next thing',
      P1Answer.desire,
    ),
    AnswerOption(
      'A clenched jaw, coiled tension looking for a target',
      P1Answer.anger,
    ),
    AnswerOption(
      'Settled and warm',
      P1Answer.contentment,
    ),
    AnswerOption(
      'Quiet and open, nothing gripping',
      P1Answer.neutrality,
    ),
    AnswerOption(
      'Lightness, energy moving freely',
      P1Answer.loveFlow,
    ),
  ],
);

/// Wire tokens for `q3_block_flag` — verified against production 2026-07-19
/// via `pg_enum` (`regression`, `movement`, `ascension`, in that sort order).
enum Q3BlockFlag {
  regression('regression'),
  movement('movement'),
  ascension('ascension');

  const Q3BlockFlag(this.token);

  /// Wire value sent to Postgres.
  final String token;
}

/// One selectable answer for a non-`P1Answer` reassessment question.
class ReassessmentOption<T> {
  const ReassessmentOption(this.label, this.value);

  final String label;
  final T value;
}

/// Q3 — behavioral block-flag check: did the original trigger situation
/// recur, and what actually happened, not how the user felt about it.
class Q3Question {
  const Q3Question({
    required this.title,
    required this.prompt,
    required this.options,
  });

  final String title;
  final String prompt;
  final List<ReassessmentOption<Q3BlockFlag>> options;
}

const Q3Question reassessmentQ3BlockFlag = Q3Question(
  title: 'Since then',
  prompt:
      'Think about the last time you faced the situation you started this '
      'loop with, or something close to it. What actually happened?',
  options: [
    ReassessmentOption(
      'I reacted the same old way, maybe even stronger',
      Q3BlockFlag.regression,
    ),
    ReassessmentOption(
      'I caught myself partway through. Different, but not clean',
      Q3BlockFlag.movement,
    ),
    ReassessmentOption(
      'I responded in a genuinely new way, without forcing it',
      Q3BlockFlag.ascension,
    ),
  ],
);

/// Wire tokens for `rediag_resistance` — verified against production
/// 2026-07-19 via `pg_enum` (`specific`, `general`, `none`).
enum RediagResistance {
  specific('specific'),
  general('general'),
  none('none');

  const RediagResistance(this.token);
  final String token;
}

/// Wire tokens for `rediag_feeling` — verified against production
/// 2026-07-19 via `pg_enum` (`relief`, `satisfaction`, `flatness`,
/// `skepticism`).
enum RediagFeeling {
  relief('relief'),
  satisfaction('satisfaction'),
  flatness('flatness'),
  skepticism('skepticism');

  const RediagFeeling(this.token);
  final String token;
}

/// Wire tokens for `rediag_pattern` — verified against production
/// 2026-07-19 via `pg_enum` (`handled_differently`, `same`, `not_noticed`).
enum RediagPattern {
  handledDifferently('handled_differently'),
  same('same'),
  notNoticed('not_noticed');

  const RediagPattern(this.token);
  final String token;
}

/// A single-select rediag question with typed options.
class RediagQuestion<T> {
  const RediagQuestion({
    required this.title,
    required this.prompt,
    required this.options,
  });

  final String title;
  final String prompt;
  final List<ReassessmentOption<T>> options;
}

/// Rediag Q1 — resistance: where the block is actually showing up now,
/// asked only when Window 2 classification comes back `false_positive`.
const RediagQuestion<RediagResistance> rediagQ1Resistance = RediagQuestion(
  title: 'Where it sticks',
  prompt: "If change hasn't held, where does it show up?",
  options: [
    ReassessmentOption(
      'One particular situation or person, not everywhere',
      RediagResistance.specific,
    ),
    ReassessmentOption(
      "Everywhere, low-grade, hard to pin to one thing",
      RediagResistance.general,
    ),
    ReassessmentOption(
      "It doesn't feel like resistance, just flat",
      RediagResistance.none,
    ),
  ],
);

/// Rediag Q2 — the user's honest reaction to the retest itself.
const RediagQuestion<RediagFeeling> rediagQ2Feeling = RediagQuestion(
  title: 'Looking at this',
  prompt: "Looking at where things landed, what's the honest reaction?",
  options: [
    ReassessmentOption('Relief, like something let go', RediagFeeling.relief),
    ReassessmentOption(
      "Quiet satisfaction. This tracks with what I've noticed",
      RediagFeeling.satisfaction,
    ),
    ReassessmentOption(
      'Flat, no real reaction either way',
      RediagFeeling.flatness,
    ),
    ReassessmentOption(
      "Skepticism. Not sure this reflects anything real",
      RediagFeeling.skepticism,
    ),
  ],
);

/// Rediag Q3 — behavioral pattern check, day-to-day, since the loop began.
const RediagQuestion<RediagPattern> rediagQ3Pattern = RediagQuestion(
  title: 'Compared to before',
  prompt: 'Compared to before this loop, how did you handle things day to day?',
  options: [
    ReassessmentOption(
      'Noticeably different. I caught myself doing something new',
      RediagPattern.handledDifferently,
    ),
    ReassessmentOption('About the same as always', RediagPattern.same),
    ReassessmentOption(
      "Honestly, I wasn't paying attention either way",
      RediagPattern.notNoticed,
    ),
  ],
);

/// Rediag Q4 — free text, stored as `rediag_q4_free_text`. Never sent to
/// the LLM (product decision, CLAUDE.md 2026-07-15): free-text answers stay
/// in Postgres under RLS.
const String rediagQ4Prompt =
    "Anything about the last few days these questions didn't capture?";
