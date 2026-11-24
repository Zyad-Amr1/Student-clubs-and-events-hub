import 'package:campusconnect/app/routes.dart';
import 'package:material_ui/material_ui.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, this.restoreError});

  final String? restoreError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Icon(
                      Icons.groups_rounded,
                      color: colors.onPrimaryContainer,
                      size: 29,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'CampusConnect',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              Text(
                'Find your people on campus.',
                style: textTheme.headlineLarge?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                  height: 1.12,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Discover student clubs, explore your interests, and find upcoming campus events.',
                style: textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Card(
                color: const Color(0xFFFFF4F4),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.explore_outlined, color: colors.primary),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Explore what you love',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Sign in with your student account to view approved clubs and events.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              if (restoreError != null) ...[
                Text(
                  restoreError!,
                  key: const ValueKey<String>('session-restore-error'),
                  style: TextStyle(color: colors.error),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey<String>('open-auth'),
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.authentication),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Sign in or create an account'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey<String>('open-clubs'),
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.clubs),
                  icon: const Icon(Icons.groups_outlined),
                  label: const Text('Explore clubs'),
                ),
              ),
              const SizedBox(height: 22),
              Center(
                child: Text(
                  'A student clubs and events hub',
                  style: textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
