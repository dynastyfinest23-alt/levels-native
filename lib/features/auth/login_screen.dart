import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/design_tokens.dart';
import '../../core/widgets/aurora_backdrop.dart';
import '../../core/widgets/breathing_dot.dart';

/// Visual treatment: design-system/MASTER.md §1, §2. No zone context yet —
/// `neutralAccent` throughout, no glow.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // On success the router redirects home via the auth state change.
    } on AuthException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('Sign-in failed: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(LevelsSpace.screenGutter),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: LevelsSpace.contentMaxWidth),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Levels',
                        textAlign: TextAlign.center,
                        style: LevelsType.displayTitle,
                      ),
                      const SizedBox(height: LevelsSpace.space8),
                      Text(
                        'Log in to continue your climb',
                        textAlign: TextAlign.center,
                        style: LevelsType.body.copyWith(color: LevelsColors.textSecondary),
                      ),
                      const SizedBox(height: LevelsSpace.space32),
                      TextFormField(
                        controller: _emailController,
                        style: LevelsType.body,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty || !email.contains('@')) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: LevelsSpace.space16),
                      TextFormField(
                        controller: _passwordController,
                        style: LevelsType.body,
                        decoration: const InputDecoration(labelText: 'Password'),
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _signIn(),
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Enter your password'
                            : null,
                      ),
                      const SizedBox(height: LevelsSpace.space24),
                      FilledButton(
                        onPressed: _submitting ? null : _signIn,
                        child: _submitting
                            ? const BreathingDot(color: LevelsColors.voidColor)
                            : const Text('Log in'),
                      ),
                      const SizedBox(height: LevelsSpace.space12),
                      TextButton(
                        onPressed:
                            _submitting ? null : () => context.go('/signup'),
                        child: const Text('New here? Create an account'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
