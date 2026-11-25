import 'package:campusconnect/app/design.dart';
import 'package:campusconnect/app/routes.dart';
import 'package:material_ui/material_ui.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              const CampusHeader(
                'Your campus community starts here.',
                'Discover clubs, find campus events, and take your next step.',
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('open-auth'),
                        onPressed: () =>
                            Navigator.of(context)
                                .pushNamed(AppRoutes.authentication),
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Sign in'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        key: const ValueKey('open-registration'),
                        onPressed: () =>
                            Navigator.of(context)
                                .pushNamed(AppRoutes.registration),
                        child: const Text('Create student account'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
