/// Phase 4 track content: static stage-by-stage copy for all four
/// ascension tracks (`completion`, `belief_audit`, `embodiment`,
/// `commitment`), each stage keyed to the `phase4_track_sessions` /
/// `embodiment_daily_logs` column it fills (see `docs/PRD.md` §2).
///
/// Options are behavioral descriptions, never emotion labels or raw enum
/// names — the token mapping stays invisible to the user, matching
/// `lib/features/assessment/questions.dart` and
/// `lib/features/drill/drill_questions.dart`. This is this app's own
/// protocol taxonomy, not Dodson mechanics — the CLAUDE.md book canon
/// hierarchy does not gate this content (no book numbers/scales in play).
///
/// STAGED FOR REVIEWER GATE (M4.1) — not self-approved. Needs a
/// cold-context rubric judge pass against `docs/copy-tone-rubric.md`, then
/// Noah's written approval, before any screen ships this copy to users.
library;

import 'track_tokens.dart';

// ---------------------------------------------------------------------------
// completion
// ---------------------------------------------------------------------------

/// Single stage: name the unfinished thing, then size how long it's been
/// sitting. Fills `completion_statement` and `prep_duration`.
const String completionStatementTitle = 'Name it';
const String completionStatementPrompt =
    "Something has been sitting half-finished, or perpetually 'almost "
    'ready.\' What is it?';

const String completionDurationTitle = 'How long, honestly';
const String completionDurationPrompt =
    'Be straight about the timeline. How long has it been sitting like '
    'this?';

class PrepDurationOption {
  const PrepDurationOption(this.label, this.duration);

  final String label;
  final PrepDuration duration;
}

const List<PrepDurationOption> completionDurationOptions = [
  PrepDurationOption('A few months, tops', PrepDuration.under3mo),
  PrepDurationOption('Under a year', PrepDuration.months3to12),
  PrepDurationOption('One to three years', PrepDuration.years1to3),
  PrepDurationOption(
    'Longer than three years — possibly much longer',
    PrepDuration.over3yr,
  ),
];

/// Shown when the controller detects a mismatch worth naming (statement
/// implies imminent action, duration says otherwise). Sets
/// `integrity_check_triggered = true`; this copy is display-only, no
/// separate answer is captured.
const String completionIntegrityCheckTitle = 'One more look';
const String completionIntegrityCheckCopy =
    "If nothing about your approach changes, is this still sitting here a "
    "year from now, the same way? Just notice the honest answer — you don't "
    'have to act on it yet.';

// ---------------------------------------------------------------------------
// belief_audit
// ---------------------------------------------------------------------------

/// Repeatable stage: flag a belief that runs decisions without permission.
/// Each entry becomes one index of `flagged_beliefs`.
const String beliefFlagTitle = 'Flag the belief';
const String beliefFlagPrompt =
    'Name a belief about yourself that runs your decisions without asking '
    'first.';

/// Authorship, per flagged belief. Index-aligned with `flagged_beliefs` —
/// fills `belief_authorship_age` and `belief_authorship_source`.
const String beliefAuthorshipAgeTitle = 'When it started';
const String beliefAuthorshipAgePrompt =
    'How old were you when this belief first took hold?';

const String beliefAuthorshipSourceTitle = 'Where it came from';
const String beliefAuthorshipSourcePrompt =
    'Who or what taught you this, originally?';

/// Cross-exam, per flagged belief. Index-aligned — fills
/// `cross_exam_verdict`.
const String beliefCrossExamTitle = 'Fact or conclusion';
const String beliefCrossExamPrompt =
    'Look at the belief straight on. Is it something you have actually '
    'verified, or something you concluded once and never checked again?';

class BeliefVerdictOption {
  const BeliefVerdictOption(this.label, this.verdict);

  final String label;
  final BeliefVerdict verdict;
}

const List<BeliefVerdictOption> beliefCrossExamOptions = [
  BeliefVerdictOption(
    "I've tested this directly and it holds up",
    BeliefVerdict.fact,
  ),
  BeliefVerdictOption(
    'I decided this was true once and never checked',
    BeliefVerdict.conclusion,
  ),
];

// ---------------------------------------------------------------------------
// embodiment
// ---------------------------------------------------------------------------

/// Session screen: locate the pattern in the body, name the sensation,
/// then check what happened after sitting with it. Fills
/// `body_location_tapped`, `sensation_words`, `stage4_response`.
const String embodimentLocationTitle = 'Where it lives';
const String embodimentLocationPrompt =
    'Close your eyes and find where this pattern lives in your body right '
    'now. Where is it?';

const String embodimentSensationTitle = 'Name the sensation';
const String embodimentSensationPrompt =
    'What words describe it — tight, hot, heavy, hollow? Use your own '
    'words.';

const String embodimentStage4Title = 'After sitting with it';
const String embodimentStage4Prompt =
    'You held your attention there for a moment. What happened?';

class Stage4ResponseOption {
  const Stage4ResponseOption(this.label, this.response);

  final String label;
  final Stage4Response response;
}

const List<Stage4ResponseOption> embodimentStage4Options = [
  Stage4ResponseOption('Something moved or loosened', Stage4Response.shifted),
  Stage4ResponseOption(
    'It got stronger, more present',
    Stage4Response.intensified,
  ),
  Stage4ResponseOption('No change either way', Stage4Response.same),
];

/// The seven daily identity statements shown one per `day_number`
/// (index 0 = day 1 … index 6 = day 7), read aloud or sat with each day of
/// the embodiment loop. Fills `identity_statement_shown`.
const List<String> embodimentDailyIdentityStatements = [
  'I notice this pattern without needing to fix it right away.', // day 1
  'I can feel this and still choose my next move.', // day 2
  'This reaction is old. I am not.', // day 3
  'I get to decide what this means, not the pattern.', // day 4
  "I've done the harder thing before. I can do it again.", // day 5
  'This is loosening its grip, one day at a time.', // day 6
  "This isn't running me anymore — I am.", // day 7
];

/// Daily body-response check, every day of the loop. Fills `body_response`.
const String embodimentBodyResponseTitle = 'How did that land';
const String embodimentBodyResponsePrompt =
    'Read the statement once more. How did it land in your body, right '
    'now?';

class BodyResponseOption {
  const BodyResponseOption(this.label, this.response);

  final String label;
  final BodyResponse response;
}

const List<BodyResponseOption> embodimentBodyResponseOptions = [
  BodyResponseOption('True — it opened something in me', BodyResponse.trueOpen),
  BodyResponseOption(
    'Strange, like it belongs to someone else',
    BodyResponse.strangeForeign,
  ),
  BodyResponseOption("False — like I'm lying to myself", BodyResponse.falseLying),
];

/// Day 6 only: compares against day 1. Fills `day6_delta_reported`.
const String embodimentDay6DeltaTitle = 'Compared to day one';
const String embodimentDay6DeltaPrompt =
    'Compared to day one, does this feel any different in your body?';

class EmbodimentDeltaOption {
  const EmbodimentDeltaOption(this.label, this.delta);

  final String label;
  final EmbodimentDelta delta;
}

const List<EmbodimentDeltaOption> embodimentDay6DeltaOptions = [
  EmbodimentDeltaOption('Yes, clearly different', EmbodimentDelta.yesDifferent),
  EmbodimentDeltaOption(
    'A little, but not dramatically',
    EmbodimentDelta.slightly,
  ),
  EmbodimentDeltaOption('No, same as day one', EmbodimentDelta.noSame),
];

/// Day 7 only: names one concrete action, then confirms the commitment.
/// Fills `day7_action_committed` and `day7_action_confirmed`.
const String embodimentDay7ActionTitle = 'One concrete action';
const String embodimentDay7ActionPrompt =
    'Name one small, specific action this version of you would take this '
    'week.';

const String embodimentDay7ConfirmTitle = 'Confirm it';
const String embodimentDay7ConfirmPrompt = 'Will you actually do it?';

// ---------------------------------------------------------------------------
// commitment
// ---------------------------------------------------------------------------

/// Fills `declaration_text`.
const String commitmentDeclarationTitle = 'Say it plainly';
const String commitmentDeclarationPrompt =
    "State exactly what you're committing to — specific enough that you'll "
    'know if you did it.';

/// Fills `constraint_chosen`.
const String commitmentConstraintTitle = 'Pick your constraint';
const String commitmentConstraintPrompt =
    'A commitment with no real constraint rarely survives a normal week. '
    'Which kind will hold you to it?';

class ConstraintTypeOption {
  const ConstraintTypeOption(this.label, this.constraint);

  final String label;
  final ConstraintType constraint;
}

const List<ConstraintTypeOption> commitmentConstraintOptions = [
  ConstraintTypeOption(
    "A hard deadline — a specific day and time it's done by",
    ConstraintType.time,
  ),
  ConstraintTypeOption(
    'Something real on the line — money, a favor, a forfeit',
    ConstraintType.resource,
  ),
  ConstraintTypeOption(
    'Someone else knows, and will ask',
    ConstraintType.audience,
  ),
];

/// Check-in, roughly 72 hours later (`checkin_scheduled_at`). Fills
/// `checkin_response` and, for anything short of a full yes,
/// `checkin_blocker_text`.
const String commitmentCheckinTitle = 'Check-in';
const String commitmentCheckinPrompt =
    'A few days ago you committed to something specific. Did it happen?';

class CheckinResponseOption {
  const CheckinResponseOption(this.label, this.response);

  final String label;
  final CheckinResponse response;
}

const List<CheckinResponseOption> commitmentCheckinOptions = [
  CheckinResponseOption('Yes, I did it', CheckinResponse.yes),
  CheckinResponseOption('Partway — some of it happened', CheckinResponse.partially),
  CheckinResponseOption("No, it didn't happen", CheckinResponse.no),
];

const String commitmentBlockerPrompt = 'What actually got in the way?';
