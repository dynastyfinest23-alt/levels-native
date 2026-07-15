/// Client-side mirrors of the deployed Phase 3 enums (`origin_type`,
/// `origin_domain`, `coping_mechanism`, `ascension_track`), verified against
/// production 2026-07-08 (`docs/PRD.md` §2). Tokens are wire values sent to
/// Postgres; `fromToken` throws on unknown rather than silently defaulting,
/// matching `EnergyZone.fromToken` in `lib/features/assessment/scoring.dart`.
library;

/// Mirror of the `origin_type` enum (12 values).
enum OriginType {
  childhoodConditioning('childhood_conditioning'),
  acuteTrauma('acute_trauma'),
  inheritedBelief('inherited_belief'),
  identityFusion('identity_fusion'),
  conditionalApproval('conditional_approval'),
  humiliationImprint('humiliation_imprint'),
  modeledIdentity('modeled_identity'),
  betrayalWound('betrayal_wound'),
  preparationLoop('preparation_loop'),
  pastFailureImprint('past_failure_imprint'),
  optionalityPreservation('optionality_preservation'),
  worthinessGap('worthiness_gap');

  const OriginType(this.token);

  final String token;

  static OriginType fromToken(String token) => values.firstWhere(
        (value) => value.token == token,
        orElse: () =>
            throw ArgumentError.value(token, 'token', 'unknown origin_type'),
      );
}

/// Mirror of the `origin_domain` enum (12 values).
enum OriginDomain {
  relationalAttachment('relational_attachment'),
  adequacyImpostor('adequacy_impostor'),
  existentialCatastrophic('existential_catastrophic'),
  autonomySovereignty('autonomy_sovereignty'),
  statusAchievement('status_achievement'),
  relationalReciprocity('relational_reciprocity'),
  ideologicalSystemic('ideological_systemic'),
  internalSelfDirected('internal_self_directed'),
  internalizedAuthority('internalized_authority'),
  societalComparative('societal_comparative'),
  selfPerfectionism('self_perfectionism'),
  visibilityFear('visibility_fear');

  const OriginDomain(this.token);

  final String token;

  static OriginDomain fromToken(String token) => values.firstWhere(
        (value) => value.token == token,
        orElse: () => throw ArgumentError.value(
            token, 'token', 'unknown origin_domain'),
      );
}

/// Mirror of the `coping_mechanism` enum (12 values).
enum CopingMechanism {
  distractionAvoidance('distraction_avoidance'),
  externalRegulation('external_regulation'),
  collapseShutdown('collapse_shutdown'),
  cognitiveOverride('cognitive_override'),
  justiceConfusion('justice_confusion'),
  controlDependency('control_dependency'),
  appointedGuardian('appointed_guardian'),
  sunkCostIdentity('sunk_cost_identity'),
  preservedPotential('preserved_potential'),
  comfortPreservation('comfort_preservation'),
  responsibilityAvoidance('responsibility_avoidance'),
  identityContinuity('identity_continuity');

  const CopingMechanism(this.token);

  final String token;

  static CopingMechanism fromToken(String token) => values.firstWhere(
        (value) => value.token == token,
        orElse: () => throw ArgumentError.value(
            token, 'token', 'unknown coping_mechanism'),
      );
}

/// Mirror of the `ascension_track` enum (4 values).
enum AscensionTrack {
  completion('completion'),
  beliefAudit('belief_audit'),
  embodiment('embodiment'),
  commitment('commitment');

  const AscensionTrack(this.token);

  final String token;

  static AscensionTrack fromToken(String token) => values.firstWhere(
        (value) => value.token == token,
        orElse: () => throw ArgumentError.value(
            token, 'token', 'unknown ascension_track'),
      );
}
