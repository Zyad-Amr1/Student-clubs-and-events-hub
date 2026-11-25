import 'package:material_ui/material_ui.dart';

abstract final class CampusColors {
  static const purple = Color(0xFF681DB4);
  static const ink = Color(0xFF201234);
  static const canvas = Color(0xFFF6F0FC);
  static const line = Color(0xFFE6D9F0);
  static const gradient = LinearGradient(
    colors: [Color(0xFF421768), Color(0xFF7429BC), Color(0xFF59218D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class CampusHeader extends StatelessWidget {
  const CampusHeader(
    this.title,
    this.subtitle, {
    this.icon = Icons.school_outlined,
    super.key,
  });
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: CampusColors.gradient,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            const Text(
              'CampusConnect',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFFF0DFFA), height: 1.45),
        ),
      ],
    ),
  );
}

class CampusStatus extends StatelessWidget {
  const CampusStatus(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (label) {
      'Open' ||
      'Approved' => (const Color(0xFFDDF4E6), const Color(0xFF14552F)),
      'Locked' ||
      'Pending' => (const Color(0xFFFFEDCA), const Color(0xFF794500)),
      'Rejected' => (const Color(0xFFFFE4EA), const Color(0xFF8F2243)),
      _ => (const Color(0xFFEFDEFA), const Color(0xFF54158E)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Text(
        label,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class CampusFeedback extends StatelessWidget {
  const CampusFeedback(
    this.message, {
    this.icon = Icons.info_outline,
    this.retry,
    super.key,
  });
  final String message;
  final IconData icon;
  final VoidCallback? retry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: CampusColors.purple),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
          if (retry != null)
            TextButton(onPressed: retry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

class CampusBottomNavigation extends StatelessWidget {
  const CampusBottomNavigation({
    required this.index,
    required this.onSelect,
    super.key,
  });
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: index,
    onDestinationSelected: onSelect,
    destinations: const [
      NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
      NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'Clubs'),
      NavigationDestination(
        icon: Icon(Icons.calendar_month_outlined),
        label: 'Calendar',
      ),
      NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
    ],
  );
}
