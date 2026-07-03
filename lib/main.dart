import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env.dart';

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
    return MaterialApp(
      title: 'Levels',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF5B4FD9),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(child: Text('Levels')),
      ),
    );
  }
}
