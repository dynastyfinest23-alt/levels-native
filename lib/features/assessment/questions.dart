import 'scoring.dart';

/// One selectable answer: behavioral copy mapped to a `p1_answer` token.
class AnswerOption {
  const AnswerOption(this.label, this.answer);

  final String label;
  final P1Answer answer;
}

/// One of the seven Phase 1 behavioral questions.
class AssessmentQuestion {
  const AssessmentQuestion({
    required this.title,
    required this.prompt,
    required this.options,
  });

  final String title;
  final String prompt;
  final List<AnswerOption> options;
}

/// The seven-question Phase 1 assessment, in canonical q1–q7 order.
///
/// Options are behavioral descriptions, never emotion labels — the user
/// self-reports a reaction, and the token mapping stays invisible. Each
/// question spans low-to-high tokens so every zone is reachable from any
/// single question; across the set all 11 v1.1 tokens appear.
const List<AssessmentQuestion> assessmentQuestions = [
  // Q1 — Opportunity Mirror
  AssessmentQuestion(
    title: 'Opportunity',
    prompt:
        'A genuinely big opportunity lands in your lap — bigger than you '
        'asked for. What is your first honest reaction?',
    options: [
      AnswerOption(
        'Someone like me would only mess it up',
        P1Answer.shameApathy,
      ),
      AnswerOption(
        'Excitement, then a wave of everything that could go wrong',
        P1Answer.fear,
      ),
      AnswerOption(
        'I want it badly — I keep replaying having already won',
        P1Answer.desire,
      ),
      AnswerOption(
        'Finally — proof for everyone who doubted me',
        P1Answer.pride,
      ),
      AnswerOption(
        'Nervous, but I say yes and figure it out as I go',
        P1Answer.courage,
      ),
      AnswerOption(
        'Interesting. If it works, great; if not, something else will',
        P1Answer.neutrality,
      ),
      AnswerOption(
        'Gratitude — it feels like life handing me the next step',
        P1Answer.loveFlow,
      ),
    ],
  ),
  // Q2 — Conflict Trigger
  AssessmentQuestion(
    title: 'Conflict',
    prompt:
        'Someone criticizes you unfairly in front of other people. '
        'What actually happens inside you?',
    options: [
      AnswerOption(
        'I collapse inward — part of me believes they are right',
        P1Answer.shameApathy,
      ),
      AnswerOption(
        'A heavy sadness settles in; I replay it for days',
        P1Answer.apathyGrief,
      ),
      AnswerOption(
        'My chest tightens — I want to disappear from the room',
        P1Answer.fear,
      ),
      AnswerOption(
        'Heat rises — I want to put them in their place',
        P1Answer.anger,
      ),
      AnswerOption(
        'I stay composed and privately write them off as beneath it',
        P1Answer.pride,
      ),
      AnswerOption(
        'I look for the grain of truth and let the rest go',
        P1Answer.willingness,
      ),
      AnswerOption(
        'I feel for them — attacks like that come from pain',
        P1Answer.loveFlow,
      ),
    ],
  ),
  // Q3 — Inertia Test
  AssessmentQuestion(
    title: 'A free day',
    prompt:
        'A completely free Saturday, nothing scheduled and no one waiting '
        'on you. What does the day actually look like?',
    options: [
      AnswerOption(
        'Hours dissolve into scrolling; the day just evaporates',
        P1Answer.apathyGrief,
      ),
      AnswerOption(
        'I keep busy with small tasks to avoid the big ones',
        P1Answer.fear,
      ),
      AnswerOption(
        'I chase whatever feels good in the moment',
        P1Answer.desire,
      ),
      AnswerOption(
        'Easy and pleasant — real rest, no guilt about it',
        P1Answer.contentment,
      ),
      AnswerOption(
        'I gravitate toward a project I care about, unprompted',
        P1Answer.willingness,
      ),
      AnswerOption(
        'I lose track of time doing what I love',
        P1Answer.loveFlow,
      ),
    ],
  ),
  // Q4 — Scarcity/Abundance Probe
  AssessmentQuestion(
    title: 'Money',
    prompt:
        'An unexpected large expense hits this month. '
        'What is your gut response?',
    options: [
      AnswerOption(
        'Of course. Things never work out for me',
        P1Answer.shameApathy,
      ),
      AnswerOption(
        'Panic — I run the numbers over and over at night',
        P1Answer.fear,
      ),
      AnswerOption(
        'I fixate on the money I now need to claw back',
        P1Answer.desire,
      ),
      AnswerOption(
        'Frustration — why does this always happen to me?',
        P1Answer.anger,
      ),
      AnswerOption(
        'It is handled or it will be — money comes and goes',
        P1Answer.neutrality,
      ),
      AnswerOption(
        'Calm trust — resources have always shown up when needed',
        P1Answer.loveFlow,
      ),
    ],
  ),
  // Q5 — Locus of Control (most critical input for Phase 2)
  AssessmentQuestion(
    title: 'Your position',
    prompt:
        'Looking honestly at where your life is right now, '
        'what put you here?',
    options: [
      AnswerOption(
        'My own defects — I have sabotaged everything good',
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
        'My grit — I made it here despite everyone',
        P1Answer.pride,
      ),
      AnswerOption(
        'My choices — including the bad ones, which I own',
        P1Answer.courage,
      ),
      AnswerOption(
        'A mix of choice and circumstance, and both are workable',
        P1Answer.neutrality,
      ),
    ],
  ),
  // Q6 — Body-State Scan
  AssessmentQuestion(
    title: 'Body check',
    prompt:
        'Close your eyes for three seconds and scan your body. '
        'What is the dominant signal?',
    options: [
      AnswerOption(
        'Heaviness — like moving through wet sand',
        P1Answer.apathyGrief,
      ),
      AnswerOption(
        'A tight chest or knotted stomach that never fully unwinds',
        P1Answer.fear,
      ),
      AnswerOption(
        'Restless craving — reaching for the next thing',
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
        'Quiet and open — nothing gripping',
        P1Answer.neutrality,
      ),
      AnswerOption(
        'Lightness — energy moving freely',
        P1Answer.loveFlow,
      ),
    ],
  ),
  // Q7 — Meaning Probe
  AssessmentQuestion(
    title: 'Meaning',
    prompt: 'Finish the sentence honestly: "Life is…"',
    options: [
      AnswerOption(
        '…something I endure',
        P1Answer.shameApathy,
      ),
      AnswerOption(
        '…mostly loss, with pauses in between',
        P1Answer.apathyGrief,
      ),
      AnswerOption(
        '…a threat you have to stay ahead of',
        P1Answer.fear,
      ),
      AnswerOption(
        '…a game of getting what you want',
        P1Answer.desire,
      ),
      AnswerOption(
        '…a competition, and I intend to win it',
        P1Answer.pride,
      ),
      AnswerOption(
        '…a series of challenges that grow you',
        P1Answer.courage,
      ),
      AnswerOption(
        '…a gift that keeps unfolding',
        P1Answer.loveFlow,
      ),
    ],
  ),
];
