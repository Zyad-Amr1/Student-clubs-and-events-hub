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
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 520,
                    minHeight: (constraints.maxHeight - 32).clamp(
                      0,
                      double.infinity,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SafeArea(
                        top: false,
                        bottom: false,
                        minimum: const EdgeInsets.symmetric(horizontal: 24),
                        child: _WelcomeBrand(
                          compact: constraints.maxHeight < 660,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _WelcomeHero(
                        compact: constraints.maxHeight < 660,
                        minHeight: (constraints.maxHeight * 0.44).clamp(
                          208,
                          440,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FilledButton(
                              key: const ValueKey('open-auth'),
                              onPressed: () =>
                                  Navigator.of(context)
                                      .pushNamed(AppRoutes.authentication),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: CampusColors.purpleDark,
                                minimumSize: const Size.fromHeight(50),
                                shape: const StadiumBorder(),
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
                                side: const BorderSide(color: Colors.white70),
                                minimumSize: const Size.fromHeight(50),
                                shape: const StadiumBorder(),
                              ),
                              child: const Text('Create Account'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _WelcomeBrand extends StatelessWidget {
  const _WelcomeBrand({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(Icons.school_rounded, color: Colors.white, size: compact ? 36 : 50),
      const SizedBox(height: 6),
      Text(
        'CampusConnect',
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 9),
      const Text(
        'YOUR CAMPUS COMMUNITY',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFFF5EBFF),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 2.3,
        ),
      ),
    ],
  );
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({required this.minHeight, required this.compact});

  final double minHeight;
  final bool compact;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned.fill(
        child: ShaderMask(
          shaderCallback: _photoMask,
          blendMode: BlendMode.dstIn,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image(
                image: AssetImage('assets/images/campus-hero.png'),
                alignment: Alignment.centerRight,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xF33B126F),
                      Color(0xAE3B126F),
                      Color(0x503B126F),
                    ],
                    stops: [0, 0.64, 1],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            compact ? 10 : 26,
            24,
            compact ? 10 : 18,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Discover Clubs,\nJoin Events,\nGet Involved',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontSize: compact ? 28 : 35,
                  height: 1.08,
                ),
              ),
              SizedBox(height: compact ? 14 : 36),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 254),
                child: const DefaultTextStyle(
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your campus community starts here.'),
                      Text(
                        'Explore clubs, events, and opportunities to get involved.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  static Shader _photoMask(Rect bounds) => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Colors.white,
      Colors.white,
      Colors.transparent,
    ],
    stops: [0, 0.23, 0.75, 1],
  ).createShader(bounds);
}
