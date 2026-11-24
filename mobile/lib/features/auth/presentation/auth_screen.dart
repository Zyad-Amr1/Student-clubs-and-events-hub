import 'package:campusconnect/core/network/api_client.dart';
import 'package:campusconnect/features/auth/presentation/auth_controller.dart';
import 'package:material_ui/material_ui.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _universityIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _registering = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _universityIdController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (_registering) {
        await widget.controller.register(
          fullName: _nameController.text.trim(),
          email: _emailController.text.trim(),
          universityId: _universityIdController.text.trim(),
          password: _passwordController.text,
          confirmPassword: _confirmationController.text,
        );
        if (!mounted) return;
        setState(() {
          _registering = false;
          _passwordController.clear();
          _confirmationController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created. Please sign in to continue.'),
          ),
        );
      } else {
        await widget.controller.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email address.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    if (email.length > 254) return 'Email address is too long.';
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Enter your password.';
    if (password.length < 8 || password.length > 128) {
      return 'Password must be between 8 and 128 characters.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('CampusConnect')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _registering ? 'Create your account' : 'Welcome back',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _registering
                          ? 'Register as a student to explore your campus community.'
                          : 'Sign in with your student account to continue.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (_registering) ...[
                      TextFormField(
                        key: const ValueKey<String>('registration-full-name'),
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 120,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          prefixIcon: Icon(Icons.person_outline),
                          counterText: '',
                        ),
                        validator: (value) {
                          final name = value?.trim() ?? '';
                          if (name.length < 2 || name.length > 120) {
                            return 'Name must be between 2 and 120 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      key: const ValueKey<String>('auth-email'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: _validateEmail,
                    ),
                    if (_registering) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey<String>(
                          'registration-university-id',
                        ),
                        controller: _universityIdController,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 64,
                        decoration: const InputDecoration(
                          labelText: 'University ID',
                          prefixIcon: Icon(Icons.badge_outlined),
                          counterText: '',
                        ),
                        validator: (value) {
                          final id = value?.trim() ?? '';
                          if (id.isEmpty || id.length > 64) {
                            return 'Enter a university ID of at most 64 characters.';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey<String>('auth-password'),
                      controller: _passwordController,
                      obscureText: true,
                      maxLength: 128,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                        counterText: '',
                      ),
                      validator: _validatePassword,
                    ),
                    if (_registering) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey<String>(
                          'registration-confirm-password',
                        ),
                        controller: _confirmationController,
                        obscureText: true,
                        maxLength: 128,
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                          prefixIcon: Icon(Icons.lock_outline),
                          counterText: '',
                        ),
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return 'Passwords do not match.';
                          }
                          return null;
                        },
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        key: const ValueKey<String>('auth-error'),
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const ValueKey<String>('auth-submit'),
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_registering ? 'Create account' : 'Sign in'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      key: const ValueKey<String>('auth-toggle-mode'),
                      onPressed: _submitting
                          ? null
                          : () => setState(() {
                              _registering = !_registering;
                              _error = null;
                            }),
                      child: Text(
                        _registering
                            ? 'Already have an account? Sign in'
                            : 'New here? Create a student account',
                      ),
                    ),
                    if (_registering)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Account access is assigned by the university. Registration creates a student account.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
