import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/design_tokens.dart';
import 'core/env.dart';
import 'core/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.validate();
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );
  runApp(const LevelsApp());
}

class LevelsApp extends StatelessWidget {
  const LevelsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Levels',
      theme: _levelsTheme,
      routerConfig: appRouter,
    );
  }
}

/// Dark-only theme (design-system/MASTER.md §1: "Light mode: none in v1"),
/// built entirely from `lib/core/design_tokens.dart` — no seed-generated
/// Material colors, so no Material-default purple leaks into secondary/
/// tertiary/error slots.
final ThemeData _levelsTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: LevelsColors.voidColor,
  fontFamily: 'Inter',
  colorScheme: const ColorScheme.dark(
    surface: LevelsColors.surface,
    onSurface: LevelsColors.textPrimary,
    primary: LevelsColors.neutralAccent,
    onPrimary: LevelsColors.voidColor,
    secondary: LevelsColors.neutralAccent,
    onSecondary: LevelsColors.voidColor,
  ),
  textTheme: const TextTheme(
    displayLarge: LevelsType.displayScore,
    displayMedium: LevelsType.displayTitle,
    titleSmall: LevelsType.zoneName,
    labelLarge: LevelsType.panelTitle,
    bodyLarge: LevelsType.body,
    bodyMedium: LevelsType.body,
    labelMedium: LevelsType.button,
    bodySmall: LevelsType.caption,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: LevelsColors.voidColor,
    foregroundColor: LevelsColors.textPrimary,
    elevation: 0,
  ),
  cardTheme: CardThemeData(
    color: LevelsColors.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LevelsSpace.radiusPanel),
      side: const BorderSide(color: LevelsColors.glassStroke),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: LevelsColors.neutralAccent,
      foregroundColor: LevelsColors.voidColor,
      textStyle: LevelsType.button,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LevelsSpace.radiusButton),
      ),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: LevelsColors.surface,
    contentTextStyle: LevelsType.body.copyWith(color: LevelsColors.textPrimary),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LevelsSpace.radiusPanel),
      side: const BorderSide(color: LevelsColors.glassStroke),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: LevelsColors.surface,
    labelStyle: LevelsType.body.copyWith(color: LevelsColors.textSecondary),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(LevelsSpace.radiusPanel),
      borderSide: const BorderSide(color: LevelsColors.glassStroke),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(LevelsSpace.radiusPanel),
      borderSide: const BorderSide(color: LevelsColors.glassStroke),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(LevelsSpace.radiusPanel),
      borderSide: const BorderSide(color: LevelsColors.neutralAccent, width: 2),
    ),
  ),
);
