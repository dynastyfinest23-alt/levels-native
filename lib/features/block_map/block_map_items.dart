// Purpose: the 48-statement block-map question bank (4 per origin_domain), plus
// intro primer and low-confidence caption. Source: design section 4 of
// docs/superpowers/specs/2026-11-08-block-map-brainstorm-notes.md. Text lives
// here (like drill_questions.dart); the DB seed will hold key/domain/reverse/
// pair only. Likert 0..4; reverse items score 4 - value. Original wording.
import '../drill/drill_tokens.dart';

class BlockMapItem {
  const BlockMapItem(
    this.key,
    this.domain,
    this.text, {
    this.reverse = false,
    this.pairKey,
  });

  /// `<origin_domain token>_<1..4>`; stable, seeded into `block_map_items`.
  final String key;
  final OriginDomain domain;
  final String text;

  /// Agreement means "this does NOT hold me"; effective value = 4 - value.
  final bool reverse;

  /// Shared by one forward item and the reverse item that asks the same thing
  /// from the other side. Drives the contradiction check.
  final String? pairKey;
}

const String blockMapPrimerTitle = 'Before you start';
const String blockMapPrimer =
    'Read each statement and choose how much it sounds like you. Go with '
    'your first read, and answer for how you are most days. Stop whenever '
    'you like. Your answers save as you go.';

const String blockMapLowConfidenceCaption =
    'Check this against what you know about yourself.';

/// Canonical order: `OriginDomain` enum order, then _1.._4. _4 is reverse and
/// pairs with _1, except relational_attachment_4, which pairs with _3 (Noah's
/// call on the judge finding, 2026-11-08). Reverse items are worded so
/// agreeing carries a small cost, not the flattering answer (same decision).
const List<BlockMapItem> blockMapItems = [
  // relational_attachment
  BlockMapItem(
    'relational_attachment_1',
    OriginDomain.relationalAttachment,
    'I reread messages from people close to me, looking for signs '
    "they're pulling away.",
  ),
  BlockMapItem(
    'relational_attachment_2',
    OriginDomain.relationalAttachment,
    "I hold on to relationships I know aren't working.",
  ),
  BlockMapItem(
    'relational_attachment_3',
    OriginDomain.relationalAttachment,
    'When someone close goes quiet, I assume I did something wrong.',
    pairKey: 'relational_attachment_pair',
  ),
  BlockMapItem(
    'relational_attachment_4',
    OriginDomain.relationalAttachment,
    "When someone close goes quiet, I figure it has nothing to do with me.",
    reverse: true,
    pairKey: 'relational_attachment_pair',
  ),

  // adequacy_impostor
  BlockMapItem(
    'adequacy_impostor_1',
    OriginDomain.adequacyImpostor,
    "When things go well, I wait for someone to find out I'm less capable.",
    pairKey: 'adequacy_impostor_pair',
  ),
  BlockMapItem(
    'adequacy_impostor_2',
    OriginDomain.adequacyImpostor,
    "When someone praises my work, I assume they're being generous.",
  ),
  BlockMapItem(
    'adequacy_impostor_3',
    OriginDomain.adequacyImpostor,
    "I over-prepare so no one sees what I don't know.",
  ),
  BlockMapItem(
    'adequacy_impostor_4',
    OriginDomain.adequacyImpostor,
    'When things go well, I take the credit, even when others helped.',
    reverse: true,
    pairKey: 'adequacy_impostor_pair',
  ),

  // existential_catastrophic
  BlockMapItem(
    'existential_catastrophic_1',
    OriginDomain.existentialCatastrophic,
    "I picture the world getting worse in ways I can't do anything about.",
    pairKey: 'existential_catastrophic_pair',
  ),
  BlockMapItem(
    'existential_catastrophic_2',
    OriginDomain.existentialCatastrophic,
    'News about large-scale problems stays on my mind for days.',
  ),
  BlockMapItem(
    'existential_catastrophic_3',
    OriginDomain.existentialCatastrophic,
    "I hold off on long-term plans when the world feels unstable.",
  ),
  BlockMapItem(
    'existential_catastrophic_4',
    OriginDomain.existentialCatastrophic,
    "When I think about the world's future, I shrug and get on with my day.",
    reverse: true,
    pairKey: 'existential_catastrophic_pair',
  ),

  // autonomy_sovereignty
  BlockMapItem(
    'autonomy_sovereignty_1',
    OriginDomain.autonomySovereignty,
    'I let other people decide how my days go.',
    pairKey: 'autonomy_sovereignty_pair',
  ),
  BlockMapItem(
    'autonomy_sovereignty_2',
    OriginDomain.autonomySovereignty,
    "I drop my own plans when someone else wants something.",
  ),
  BlockMapItem(
    'autonomy_sovereignty_3',
    OriginDomain.autonomySovereignty,
    "I put up with situations I didn't choose instead of trying to change them.",
  ),
  BlockMapItem(
    'autonomy_sovereignty_4',
    OriginDomain.autonomySovereignty,
    'I hold to my own plans, even when it annoys other people.',
    reverse: true,
    pairKey: 'autonomy_sovereignty_pair',
  ),

  // status_achievement
  BlockMapItem(
    'status_achievement_1',
    OriginDomain.statusAchievement,
    "I make sure people know about what I've achieved.",
    pairKey: 'status_achievement_pair',
  ),
  BlockMapItem(
    'status_achievement_2',
    OriginDomain.statusAchievement,
    "I wait for someone else to notice a win before I let myself enjoy it.",
  ),
  BlockMapItem(
    'status_achievement_3',
    OriginDomain.statusAchievement,
    'I judge a day as good or bad by what I accomplished.',
  ),
  BlockMapItem(
    'status_achievement_4',
    OriginDomain.statusAchievement,
    'I let my wins go unmentioned unless someone asks me directly.',
    reverse: true,
    pairKey: 'status_achievement_pair',
  ),

  // relational_reciprocity
  BlockMapItem(
    'relational_reciprocity_1',
    OriginDomain.relationalReciprocity,
    'I keep track of who has done what for whom.',
    pairKey: 'relational_reciprocity_pair',
  ),
  BlockMapItem(
    'relational_reciprocity_2',
    OriginDomain.relationalReciprocity,
    'When I give more than I get, I start to pull back.',
  ),
  BlockMapItem(
    'relational_reciprocity_3',
    OriginDomain.relationalReciprocity,
    "I avoid accepting help I can't pay back.",
  ),
  BlockMapItem(
    'relational_reciprocity_4',
    OriginDomain.relationalReciprocity,
    'I lose track of who has done what for whom.',
    reverse: true,
    pairKey: 'relational_reciprocity_pair',
  ),

  // ideological_systemic
  BlockMapItem(
    'ideological_systemic_1',
    OriginDomain.ideologicalSystemic,
    'When I deal with institutions, I brace for being treated unfairly.',
    pairKey: 'ideological_systemic_pair',
  ),
  BlockMapItem(
    'ideological_systemic_2',
    OriginDomain.ideologicalSystemic,
    'I read official rules and forms looking for the catch.',
  ),
  BlockMapItem(
    'ideological_systemic_3',
    OriginDomain.ideologicalSystemic,
    'I skip applying for things when I assume the odds are stacked.',
  ),
  BlockMapItem(
    'ideological_systemic_4',
    OriginDomain.ideologicalSystemic,
    'When I deal with institutions, I take what they tell me at face value.',
    reverse: true,
    pairKey: 'ideological_systemic_pair',
  ),

  // internal_self_directed
  BlockMapItem(
    'internal_self_directed_1',
    OriginDomain.internalSelfDirected,
    "I talk to myself in ways I'd never talk to a friend.",
    pairKey: 'internal_self_directed_pair',
  ),
  BlockMapItem(
    'internal_self_directed_2',
    OriginDomain.internalSelfDirected,
    'When I make a mistake, the voice in my head turns harsh.',
  ),
  BlockMapItem(
    'internal_self_directed_3',
    OriginDomain.internalSelfDirected,
    'I replay things I said or did and criticize myself for them.',
  ),
  BlockMapItem(
    'internal_self_directed_4',
    OriginDomain.internalSelfDirected,
    'I brush off my own mistakes without much thought.',
    reverse: true,
    pairKey: 'internal_self_directed_pair',
  ),

  // internalized_authority
  BlockMapItem(
    'internalized_authority_1',
    OriginDomain.internalizedAuthority,
    'Around bosses or authority figures, I get quieter and more careful.',
    pairKey: 'internalized_authority_pair',
  ),
  BlockMapItem(
    'internalized_authority_2',
    OriginDomain.internalizedAuthority,
    'I follow rules I disagree with rather than risk disapproval.',
  ),
  BlockMapItem(
    'internalized_authority_3',
    OriginDomain.internalizedAuthority,
    "Before I decide, I think about what the people in charge would want.",
  ),
  BlockMapItem(
    'internalized_authority_4',
    OriginDomain.internalizedAuthority,
    'I tell bosses what I think, even when keeping quiet would be smarter.',
    reverse: true,
    pairKey: 'internalized_authority_pair',
  ),

  // societal_comparative
  BlockMapItem(
    'societal_comparative_1',
    OriginDomain.societalComparative,
    "I compare my life to other people's lives, even strangers'.",
    pairKey: 'societal_comparative_pair',
  ),
  BlockMapItem(
    'societal_comparative_2',
    OriginDomain.societalComparative,
    'I measure myself against where other people my age are.',
  ),
  BlockMapItem(
    'societal_comparative_3',
    OriginDomain.societalComparative,
    "After scrolling through other people's lives, I think less of my own.",
  ),
  BlockMapItem(
    'societal_comparative_4',
    OriginDomain.societalComparative,
    'I ignore how others are doing when I size up my own life.',
    reverse: true,
    pairKey: 'societal_comparative_pair',
  ),

  // self_perfectionism
  BlockMapItem(
    'self_perfectionism_1',
    OriginDomain.selfPerfectionism,
    "I keep reworking things long after others would call them finished.",
    pairKey: 'self_perfectionism_pair',
  ),
  BlockMapItem(
    'self_perfectionism_2',
    OriginDomain.selfPerfectionism,
    "I hold my own work to a higher standard than I'd hold anyone else's.",
  ),
  BlockMapItem(
    'self_perfectionism_3',
    OriginDomain.selfPerfectionism,
    "Even when it's done well, I notice only what could be better.",
  ),
  BlockMapItem(
    'self_perfectionism_4',
    OriginDomain.selfPerfectionism,
    "I hand things in once they're good enough, even if they're a bit rough.",
    reverse: true,
    pairKey: 'self_perfectionism_pair',
  ),

  // visibility_fear
  BlockMapItem(
    'visibility_fear_1',
    OriginDomain.visibilityFear,
    "In groups, I hold back my ideas so I don't stand out.",
    pairKey: 'visibility_fear_pair',
  ),
  BlockMapItem(
    'visibility_fear_2',
    OriginDomain.visibilityFear,
    'I avoid being the center of attention whenever I can.',
  ),
  BlockMapItem(
    'visibility_fear_3',
    OriginDomain.visibilityFear,
    'I let others take credit rather than put myself forward.',
  ),
  BlockMapItem(
    'visibility_fear_4',
    OriginDomain.visibilityFear,
    "In groups, I voice ideas before I've fully thought them through.",
    reverse: true,
    pairKey: 'visibility_fear_pair',
  ),
];
