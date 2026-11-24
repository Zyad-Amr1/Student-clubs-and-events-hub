import 'package:campusconnect/shared/widgets/feature_placeholder_screen.dart';
import 'package:material_ui/material_ui.dart';

class ClubsPlaceholderScreen extends StatelessWidget {
  const ClubsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderScreen(
      title: 'Club discovery',
      message: 'Club listings will appear here after API integration.',
      icon: Icons.groups_outlined,
    );
  }
}
