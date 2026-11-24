import 'package:campusconnect/app/routes.dart';
import 'package:material_ui/material_ui.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

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
              const SizedBox(height: 54),
              Text(
                'Your campus community starts here.',
                style: textTheme.headlineLarge?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                  height: 1.12,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Meet people, explore interests, and find events happening across your university.',
                style: textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Card(
                color: colors.surfaceContainerLow,
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
                              'A place for every interest',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Live club data is not connected yet.',
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
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey<String>('open-auth'),
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.authentication),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Get started'),
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
                  label: const Text('Club discovery'),
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
