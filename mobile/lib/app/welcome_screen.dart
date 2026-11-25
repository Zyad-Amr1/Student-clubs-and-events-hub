import 'package:campusconnect/app/design.dart';
import 'package:campusconnect/app/routes.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: CampusColors.gradient),
        child: Stack(
          children: [
            Positioned(top: -120, right: -110, child: _GlowCircle(size: 280)),
            Positioned(bottom: 100, left: -165, child: _GlowCircle(size: 300)),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 34,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                const CampusBrandLockup(
                                  inverse: true,
                                  logoSize: 50,
                                  fontSize: 25,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'U N I V E R S I T Y   S T U D E N T   H U B',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.78),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Discover Clubs,\nJoin Events,\nGet Involved',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontSize: 29,
                                  height: 1.08,
                                  letterSpacing: -0.8,
                                ),
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(26),
                            child: SizedBox(
                              height: constraints.maxHeight < 700 ? 150 : 226,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.asset(
                                    'assets/images/campus-hero.png',
                                    fit: BoxFit.cover,
                                    alignment: Alignment.center,
                                  ),
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          CampusColors.purpleDark.withValues(
                                            alpha: 0.05,
                                          ),
                                          CampusColors.purpleDark.withValues(
                                            alpha: 0.62,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 16,
                                    right: 16,
                                    bottom: 16,
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.groups_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Clubs  �  Events  �  Community',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelLarge
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your campus community starts here.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  height: 1.4,
                                ),
                              ),
                              Text(
                                'Explore clubs, events, and opportunities to get involved.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          FilledButton(
                            key: const ValueKey('open-auth'),
                            onPressed: () =>
                                Navigator.of(context)
                                    .pushNamed(AppRoutes.authentication),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: CampusColors.purpleDark,
                              minimumSize: const Size.fromHeight(52),
                            ),
                            child: const Text('Log In'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            key: const ValueKey('open-registration'),
                            onPressed: () =>
                                Navigator.of(context)
                                    .pushNamed(AppRoutes.registration),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              minimumSize: const Size.fromHeight(52),
                            ),
                            child: const Text('Create Account'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0),
        ],
      ),
    ),
  );
}
