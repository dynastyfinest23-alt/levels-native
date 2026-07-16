/// Phase 3 origin-drill content: three structured diagnostic questions
/// (origin type, domain, coping mechanism), each paired with a free-text
/// elaboration.
///
/// Options are behavioral descriptions, never emotion labels or raw enum
/// names — the token mapping stays invisible to the user, matching
/// `lib/features/assessment/questions.dart`. `origin_type`/`origin_domain`/
/// `coping_mechanism` are this app's own diagnostic taxonomy, not Dodson
/// mechanics — the CLAUDE.md book canon hierarchy does not gate this content
/// (no book numbers/scales are in play here; voice register still matches
/// `fallback.ts`).
///
/// Q1's free-text capture is the Phase 2→3 hand-off seam: the user answers
/// their own `bridge_question_shown` (dynamic, rendered from the Phase 2 row,
/// not authored here) and that answer becomes `q1_free_text`. Q2 and Q3 use
/// the static free-text prompts below.
library;

import 'drill_tokens.dart';

/// One selectable answer mapped to an `origin_type` token.
class OriginTypeOption {
  const OriginTypeOption(this.label, this.type);

  final String label;
  final OriginType type;
}

/// One selectable answer mapped to an `origin_domain` token.
class OriginDomainOption {
  const OriginDomainOption(this.label, this.domain);

  final String label;
  final OriginDomain domain;
}

/// One selectable answer mapped to a `coping_mechanism` token.
class CopingMechanismOption {
  const CopingMechanismOption(this.label, this.mechanism);

  final String label;
  final CopingMechanism mechanism;
}

/// Q1 — Origin type: which story shape underlies the block. Free text here
/// is the user's answer to their own bridge question, not authored below.
const String originTypeTitle = 'Where it started';
const String originTypePrompt =
    'Think about the pattern you keep running into. If you trace it back, '
    'where does it actually come from?';
const List<OriginTypeOption> originTypeOptions = [
  OriginTypeOption(
    'A way of being treated that started so early it just felt like the '
    'rules of the world',
    OriginType.childhoodConditioning,
  ),
  OriginTypeOption(
    'One sharp moment I can still point to — before it, and after it',
    OriginType.acuteTrauma,
  ),
  OriginTypeOption(
    'Something I was taught to believe, never something I decided for '
    'myself',
    OriginType.inheritedBelief,
  ),
  OriginTypeOption(
    'It stopped being a habit a long time ago — now it feels like who I am',
    OriginType.identityFusion,
  ),
  OriginTypeOption(
    'I learned early that being wanted depended on performing a certain '
    'way',
    OriginType.conditionalApproval,
  ),
  OriginTypeOption(
    'One specific moment of being humiliated that I never fully put down',
    OriginType.humiliationImprint,
  ),
  OriginTypeOption(
    'I watched someone close to me live this exact pattern and absorbed it '
    'whole',
    OriginType.modeledIdentity,
  ),
  OriginTypeOption(
    'Someone I trusted let me down in a way that changed what I expect '
    'from people',
    OriginType.betrayalWound,
  ),
  OriginTypeOption(
    'At some point, getting ready became safer than being judged on the '
    'result — and I never left that mode',
    OriginType.preparationLoop,
  ),
  OriginTypeOption(
    'One past failure still quietly runs the decisions I make now',
    OriginType.pastFailureImprint,
  ),
  OriginTypeOption(
    'Somewhere along the way, keeping every option open started to feel '
    'safer than committing to one',
    OriginType.optionalityPreservation,
  ),
  OriginTypeOption(
    'Underneath it is a plain sense that I am not enough, and never was',
    OriginType.worthinessGap,
  ),
];

/// Q2 — Origin domain: where the pattern actually shows up.
const String originDomainTitle = 'Where it shows up';
const String originDomainPrompt =
    'Same pattern — where does it actually show up the most?';
const String originDomainFreeTextPrompt =
    'Say more about where this shows up, in your own words.';
const List<OriginDomainOption> originDomainOptions = [
  OriginDomainOption(
    'Getting and staying close to people',
    OriginDomain.relationalAttachment,
  ),
  OriginDomainOption(
    'A quiet fear of being found out as not good enough',
    OriginDomain.adequacyImpostor,
  ),
  OriginDomainOption(
    'Big-picture dread — the sense something is fundamentally wrong with '
    'the world',
    OriginDomain.existentialCatastrophic,
  ),
  OriginDomainOption(
    'Feeling like my own life is not fully in my own hands',
    OriginDomain.autonomySovereignty,
  ),
  OriginDomainOption(
    'Achievement and status — needing the win to matter',
    OriginDomain.statusAchievement,
  ),
  OriginDomainOption(
    'Keeping score in relationships — what I give versus what comes back',
    OriginDomain.relationalReciprocity,
  ),
  OriginDomainOption(
    'How I see systems and institutions — rigged, not built for people '
    'like me',
    OriginDomain.ideologicalSystemic,
  ),
  OriginDomainOption(
    'The voice in my own head — how I talk to myself when no one is '
    'listening',
    OriginDomain.internalSelfDirected,
  ),
  OriginDomainOption(
    'How I relate to anyone in charge — bosses, parents, rules',
    OriginDomain.internalizedAuthority,
  ),
  OriginDomainOption(
    "Comparing my life to everyone else's",
    OriginDomain.societalComparative,
  ),
  OriginDomainOption(
    'The standard I hold myself to — never quite clearing the bar I set',
    OriginDomain.selfPerfectionism,
  ),
  OriginDomainOption(
    'Being seen or noticed at all',
    OriginDomain.visibilityFear,
  ),
];

/// Q3 — Coping mechanism: what the user actually does when the pattern
/// triggers.
const String copingMechanismTitle = 'How you cope with it';
const String copingMechanismPrompt =
    'When that pattern gets triggered, what do you actually do about it?';
const String copingMechanismFreeTextPrompt =
    'Say more about how you handle it, in your own words.';
const List<CopingMechanismOption> copingMechanismOptions = [
  CopingMechanismOption(
    'I distract myself until the feeling passes',
    CopingMechanism.distractionAvoidance,
  ),
  CopingMechanismOption(
    'I look for someone or something outside me to settle me down',
    CopingMechanism.externalRegulation,
  ),
  CopingMechanismOption(
    'I shut down — go quiet and wait it out',
    CopingMechanism.collapseShutdown,
  ),
  CopingMechanismOption(
    'I think my way out of it — analyze until the feeling loses its grip',
    CopingMechanism.cognitiveOverride,
  ),
  CopingMechanismOption(
    'I get stuck arguing with myself about whether it is even fair',
    CopingMechanism.justiceConfusion,
  ),
  CopingMechanismOption(
    'I tighten my grip and control everything I can reach',
    CopingMechanism.controlDependency,
  ),
  CopingMechanismOption(
    'I take care of everyone else in the room until my own thing quiets '
    'down',
    CopingMechanism.appointedGuardian,
  ),
  CopingMechanismOption(
    'I stay the course, because I have already put too much into it to '
    'stop now',
    CopingMechanism.sunkCostIdentity,
  ),
  CopingMechanismOption(
    'I keep the idea of what I could do alive, and never actually test it',
    CopingMechanism.preservedPotential,
  ),
  CopingMechanismOption(
    'I retreat to whatever keeps things comfortable and familiar',
    CopingMechanism.comfortPreservation,
  ),
  CopingMechanismOption(
    'I let the responsibility land on someone else if I can',
    CopingMechanism.responsibilityAvoidance,
  ),
  CopingMechanismOption(
    'I keep doing it because stopping would mean I am not who I thought I '
    'was',
    CopingMechanism.identityContinuity,
  ),
];
