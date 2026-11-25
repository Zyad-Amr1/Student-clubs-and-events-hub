import 'package:campusconnect/app/design.dart';
import 'package:campusconnect/features/auth/presentation/profile_screen.dart';
import 'package:campusconnect/features/clubs/presentation/clubs_screen.dart';
import 'package:campusconnect/features/events/presentation/my_events_screen.dart';
import 'package:material_ui/material_ui.dart';

class StudentHome extends StatefulWidget {
  const StudentHome({super.key});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  int _tab = 1;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: switch (_tab) {
      0 => Scaffold(
        appBar: AppBar(title: const Text('CampusConnect')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              title: const Text('Discover clubs'),
              onTap: () => setState(() => _tab = 1),
            ),
            ListTile(
              title: const Text('My Events Calendar'),
              onTap: () => setState(() => _tab = 2),
            ),
          ],
        ),
      ),
      1 => const ClubsScreen(),
      2 => const MyEventsScreen(),
      _ => const ProfileScreen(),
    },
    bottomNavigationBar: CampusBottomNavigation(
      index: _tab,
      onSelect: (index) => setState(() => _tab = index),
    ),
  );
}
