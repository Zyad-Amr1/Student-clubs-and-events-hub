import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/app/routes.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:material_ui/material_ui.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _universityId = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  bool _register = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _universityId.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required' : null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final session = StudentSessionScope.of(context);
    try {
      if (_register) {
        await session.registerAndSignIn(
          fullName: _name.text,
          email: _email.text,
          universityId: _universityId.text,
          password: _password.text,
          confirmPassword: _confirmation.text,
        );
      } else {
        await session.signIn(_email.text, _password.text);
      }
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.clubs, (route) => false);
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Sign-in failed. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_register ? 'Create student account' : 'Student login'),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _register ? 'Join CampusConnect' : 'Welcome back',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 20),
                  if (_register) ...[
                    TextFormField(
                      key: const ValueKey('register-name'),
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final required = _required(value);
                        if (required != null) return required;
                        return value!.trim().length < 2
                            ? 'Enter your full name'
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    key: const ValueKey('auth-email'),
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'University email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final required = _required(value);
                      if (required != null) return required;
                      return !value!.contains('@')
                          ? 'Enter a valid email'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_register) ...[
                    TextFormField(
                      key: const ValueKey('register-university-id'),
                      controller: _universityId,
                      decoration: const InputDecoration(
                        labelText: 'University ID',
                        border: OutlineInputBorder(),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    key: const ValueKey('auth-password'),
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final required = _required(value);
                      if (required != null) return required;
                      if (_register && value!.length < 8) {
                        return 'Use at least 8 characters';
                      }
                      return null;
                    },
                  ),
                  if (_register) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('register-confirm-password'),
                      controller: _confirmation,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value != _password.text) {
                          return 'Passwords do not match';
                        }
                        return _required(value);
                      },
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      key: const ValueKey('auth-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const ValueKey('auth-submit'),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_register ? 'Register and sign in' : 'Sign in'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    key: const ValueKey('auth-toggle'),
                    onPressed: _submitting
                        ? null
                        : () => setState(() {
                            _register = !_register;
                            _error = null;
                            _formKey.currentState?.reset();
                          }),
                    child: Text(
                      _register
                          ? 'Already have an account? Sign in'
                          : 'New student? Create an account',
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
