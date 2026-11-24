import 'package:campusconnect/shared/widgets/feature_placeholder_screen.dart';
import 'package:material_ui/material_ui.dart';

class AuthPlaceholderScreen extends StatelessWidget {
  const AuthPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderScreen(
      title: 'Authentication',
      message: 'Sign-in and registration will be added in the next milestone.',
      icon: Icons.lock_outline_rounded,
    );
  }
}
