import 'package:campusconnect/features/auth/presentation/auth_controller.dart';
import 'package:material_ui/material_ui.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loggingOut = false;

  Future<void> _logout() async {
    if (_loggingOut) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loggingOut = true);
    await widget.controller.logout();
    if (!mounted) return;
    final warning = widget.controller.logoutWarning;
    if (warning != null) {
      messenger.showSnackBar(SnackBar(content: Text(warning)));
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = widget.controller.profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Your profile')),
      body: profile == null
          ? const Center(child: Text('Profile information is unavailable.'))
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.person_outline,
                      size: 36,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    profile.fullName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _ProfileField(label: 'Email', value: profile.email),
                  _ProfileField(
                    label: 'University ID',
                    value: profile.universityId,
                  ),
                  _ProfileField(
                    label: 'Account type',
                    value: profile.accountType.replaceAll('_', ' '),
                  ),
                  _ProfileField(
                    label: 'Account status',
                    value: profile.isActive ? 'Active' : 'Inactive',
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: const ValueKey<String>('logout-button'),
                    onPressed: _loggingOut ? null : _logout,
                    icon: _loggingOut
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(value, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
