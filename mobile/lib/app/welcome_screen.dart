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
                'Create a student account, discover clubs, and see approved upcoming events.',
                style: textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Card(
                color: colors.surfaceContainerLow,
                child: const Padding(
                  padding: EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Icon(Icons.verified_user_outlined),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Club information is loaded from the university backend after sign-in.',
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
                  label: const Text('Student portal'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey<String>('open-club-admin-auth'),
                  onPressed: () => Navigator.of(context).pushNamed(AppRoutes.clubAdminLogin),
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: const Text('Club Admin portal'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey<String>('open-student-affairs-auth'),
                  onPressed: () => Navigator.of(context).pushNamed(AppRoutes.studentAffairsLogin),
                  icon: const Icon(Icons.school_outlined),
                  label: const Text('Student Affairs portal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
