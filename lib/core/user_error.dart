/// Purpose: one rule for how failures reach the user (design review 2026-11-09,
/// issue 27). Plain copy always; the raw exception text only in debug builds,
/// so CLAUDE.md client rule 3 ("errors must surface") still holds for
/// developers while a person never reads a Postgres error.
library;

import 'package:flutter/foundation.dart';

/// True only in debug builds. Error views gate their raw-detail line on this.
bool get showErrorDetail => kDebugMode;

/// [friendly] always; `friendly (raw error)` when detail is shown.
/// [showDetail] defaults to [showErrorDetail]; tests pass it explicitly.
String friendlyError(String friendly, Object error, {bool? showDetail}) {
  return (showDetail ?? showErrorDetail) ? '$friendly ($error)' : friendly;
}

/// Shared copy for a failed write, so every screen says the same thing.
const String saveFailedCopy =
    'That did not save. Check your connection and try again.';
