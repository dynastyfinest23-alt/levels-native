/// Compile-time environment configuration.
///
/// Values are injected via `--dart-define-from-file=env.json` (see
/// `env.example.json`). They are compile-time constants, so a rebuild is
/// required after changing them.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// Fails fast at startup instead of letting Supabase calls fail obscurely
  /// later.
  static void validate() {
    if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL and/or SUPABASE_PUBLISHABLE_KEY are not set. '
        'Copy env.example.json to env.json, fill in the values, and run with '
        '--dart-define-from-file=env.json',
      );
    }
  }
}
