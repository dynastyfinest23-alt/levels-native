/// Client-side mirrors of the deployed Phase 4 enums (`prep_duration`,
/// `belief_verdict`, `stage4_response`, `body_response`,
/// `embodiment_delta`, `constraint_type`, `checkin_response`), verified
/// against production 2026-07-16. Tokens are wire values sent to Postgres;
/// `fromToken` throws on unknown rather than silently defaulting, matching
/// `lib/features/drill/drill_tokens.dart`.
library;

/// Mirror of the `prep_duration` enum (4 values) — `completion` track.
enum PrepDuration {
  under3mo('under_3mo'),
  months3to12('3_12mo'),
  years1to3('1_3yr'),
  over3yr('over_3yr');

  const PrepDuration(this.token);

  final String token;

  static PrepDuration fromToken(String token) => values.firstWhere(
        (value) => value.token == token,
        orElse: () =>
            throw ArgumentError.value(token, 'token', 'unknown prep_duration'),
      );
}

/// Mirror of the `belief_verdict` enum (2 values) — `belief_audit` track.
enum BeliefVerdict {
  fact('fact'),
  conclusion('conclusion');

  const BeliefVerdict(this.token);

  final String token;

  static BeliefVerdict fromToken(String token) => values.firstWhere(
        (value) => value.token == token,
        orElse: () => throw ArgumentError.value(
            token, 'token', 'unknown belief_verdict'),
      );
}

/// Mirror of the `stage4_response` enum (3 values) — `embodiment` track
/// session screen.
enum Stage4Response {
  shifted('shifted'),
  intensified('intensified'),
  same('same');

  const Stage4Response(this.token);

  final String token;

  static Stage4Response fromToken(String token) => values.firstWhere(
        (value) => value.token == token,
        orElse: () => throw ArgumentError.value(
            token, 'token', 'unknown stage4_response'),
      );
}

/// Mirror of the `body_response` enum (3 values) — `embodiment` daily logs.
enum BodyResponse {
  trueOpen('true_open'),
  strangeForeign('strange_foreign'),
  falseLying('false_lying');

  const BodyResponse(this.token);

  final String token;

  static BodyResponse fromToken(String token) => values.firstWhere(
        (value) => value.token == token,
        orElse: () => throw ArgumentError.value(
            token, 'token', 'unknown body_response'),
      );
}

/// Mirror of the `embodiment_delta` enum (3 values) — day 6 of the
/// `embodiment` daily loop.
enum EmbodimentDelta {
  yesDifferent('yes_different'),
  slightly('slightly'),
  noSame('no_same');

  const EmbodimentDelta(this.token);

  final String token;

  static EmbodimentDelta fromToken(String token) => values.firstWhere(
        (value) => value.token == token,
        orElse: () => throw ArgumentError.value(
            token, 'token', 'unknown embodiment_delta'),
      );
}

/// Mirror of the `constraint_type` enum (3 values) — `commitment` track.
enum ConstraintType {
  time('time'),
  resource('resource'),
  audience('audience');

  const ConstraintType(this.token);

  final String token;

  static ConstraintType fromToken(String token) => values.firstWhere(
        (value) => value.token == token,
        orElse: () => throw ArgumentError.value(
            token, 'token', 'unknown constraint_type'),
      );
}

/// Mirror of the `checkin_response` enum (3 values) — `commitment` track
/// 72h check-in.
enum CheckinResponse {
  yes('yes'),
  partially('partially'),
  no('no');

  const CheckinResponse(this.token);

  final String token;

  static CheckinResponse fromToken(String token) => values.firstWhere(
        (value) => value.token == token,
        orElse: () => throw ArgumentError.value(
            token, 'token', 'unknown checkin_response'),
      );
}
