import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/design_tokens.dart';
import '../../core/widgets/aurora_backdrop.dart';
import '../../core/widgets/breathing_dot.dart';

/// Visual treatment: design-system/MASTER.md §1, §2. No zone context yet —
/// `neutralAccent` throughout, no glow.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // With a session the router redirects home via the auth state change.
      // Without one, email confirmation is enabled on the project.
      if (response.session == null) {
        _showMessage(
          'Account created. Confirm your email, then log in.',
        );
      }
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage('Sign-up failed: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String message) {
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
                        'Create your account',
                        textAlign: TextAlign.center,
                        style: LevelsType.displayTitle,
                      ),
                      const SizedBox(height: LevelsSpace.space8),
                      Text(
                        'Start tracking your energy state',
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
                        autofillHints: const [AutofillHints.newPassword],
                        validator: (value) => (value == null || value.length < 6)
                            ? 'Password must be at least 6 characters'
                            : null,
                      ),
                      const SizedBox(height: LevelsSpace.space16),
                      TextFormField(
                        controller: _confirmController,
                        style: LevelsType.body,
                        decoration: const InputDecoration(labelText: 'Confirm password'),
                        obscureText: true,
                        onFieldSubmitted: (_) => _signUp(),
                        validator: (value) => (value != _passwordController.text)
                            ? 'Passwords do not match'
                            : null,
                      ),
                      const SizedBox(height: LevelsSpace.space24),
                      FilledButton(
                        onPressed: _submitting ? null : _signUp,
                        child: _submitting
                            ? const BreathingDot(color: LevelsColors.voidColor)
                            : const Text('Sign up'),
                      ),
                      const SizedBox(height: LevelsSpace.space12),
                      TextButton(
                        onPressed: _submitting ? null : () => context.go('/login'),
                        child: const Text('Already have an account? Log in'),
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
