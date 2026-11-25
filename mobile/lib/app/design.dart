import 'package:material_ui/material_ui.dart';

abstract final class CampusColors {
  static const purple = Color(0xFF681DB4);
  static const purpleDark = Color(0xFF38085C);
  static const purpleLight = Color(0xFF8B3FD6);
  static const ink = Color(0xFF1E1035);
  static const inkMuted = Color(0xFF6E5F80);
  static const canvas = Color(0xFFF7F4FA);
  static const line = Color(0xFFEADBFA);
  static const lavender = Color(0xFFF0E5FA);
  static const lavenderActive = Color(0xFFE9D6FA);
  static const greenBg = Color(0xFFDDF4E6);
  static const greenFg = Color(0xFF14552F);
  static const amberBg = Color(0xFFFFF0D4);
  static const amberFg = Color(0xFF8A5400);
  static const redBg = Color(0xFFFFE4EA);
  static const redFg = Color(0xFF8F2243);

  static const gradient = LinearGradient(
    colors: [Color(0xFF390D5E), Color(0xFF601BA0), Color(0xFF4A127B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const cardGradient = LinearGradient(
    colors: [Color(0xFF280747), Color(0xFF4A117C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

IconData categoryIcon(String category) {
  final lower = category.toLowerCase();
  if (lower.contains('tech') ||
      lower.contains('code') ||
      lower.contains('software')) {
    return Icons.code_rounded;
  }
  if (lower.contains('eng')) {
    return Icons.settings_suggest_rounded;
  }
  if (lower.contains('art') ||
      lower.contains('photo') ||
      lower.contains('music')) {
    return Icons.palette_outlined;
  }
  if (lower.contains('sport') || lower.contains('fit')) {
    return Icons.sports_basketball_outlined;
  }
  if (lower.contains('entrepreneur') ||
      lower.contains('busin') ||
      lower.contains('innovat')) {
    return Icons.trending_up_rounded;
  }
  if (lower.contains('game')) {
    return Icons.sports_esports_outlined;
  }
  if (lower.contains('media')) {
    return Icons.camera_alt_outlined;
  }
  if (lower.contains('robot')) {
    return Icons.precision_manufacturing_outlined;
  }
  if (lower.contains('ai') || lower.contains('chip')) {
    return Icons.memory_rounded;
  }
  return Icons.groups_outlined;
}

class CampusVerifiedBadge extends StatelessWidget {
  const CampusVerifiedBadge({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: CampusColors.purple,
      shape: BoxShape.circle,
    ),
    child: Icon(Icons.check, size: size * 0.7, color: Colors.white),
  );
}

class CampusHeader extends StatelessWidget {
  const CampusHeader(
    this.title,
    this.subtitle, {
    this.icon = Icons.school_outlined,
    this.trailing,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;

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
                letterSpacing: 0.2,
              ),
            ),
            const Spacer(),
            ?trailing,
          ],
        ),
        const SizedBox(height: 22),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFFF0DFFA),
            height: 1.45,
            fontSize: 14,
          ),
        ),
      ],
    ),
  );
}

class CampusStatCard extends StatelessWidget {
  const CampusStatCard({
    required this.icon,
    required this.value,
    required this.label,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: CampusColors.line),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C391B50),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: CampusColors.lavender,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: CampusColors.purple, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: CampusColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: CampusColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class CampusSectionHeader extends StatelessWidget {
  const CampusSectionHeader({
    required this.title,
    this.icon,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: CampusColors.purple, size: 22),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: CampusColors.ink,
          ),
        ),
        const Spacer(),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionLabel!,
                  style: const TextStyle(
                    color: CampusColors.purple,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: CampusColors.purple,
                ),
              ],
            ),
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
    final (background, foreground, icon) = switch (label) {
      'Open' || 'Approved' || 'Confirmed' || 'Active' => (
        CampusColors.greenBg,
        CampusColors.greenFg,
        Icons.check_circle_outline,
      ),
      'Locked' || 'Pending' || 'Waitlisted' || 'Waiting List' => (
        CampusColors.amberBg,
        CampusColors.amberFg,
        Icons.hourglass_top_outlined,
      ),
      'Rejected' || 'Cancelled' => (
        CampusColors.redBg,
        CampusColors.redFg,
        Icons.cancel_outlined,
      ),
      'Archived' => (
        const Color(0xFFEDE9F2),
        const Color(0xFF554466),
        Icons.archive_outlined,
      ),
      _ => (const Color(0xFFEFDEFA), const Color(0xFF54158E), null),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
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
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: CampusColors.line, width: 1)),
      boxShadow: [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 10,
          offset: Offset(0, -2),
        ),
      ],
    ),
    child: NavigationBar(
      elevation: 0,
      backgroundColor: Colors.white,
      indicatorColor: CampusColors.lavenderActive,
      selectedIndex: index,
      onDestinationSelected: onSelect,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home, color: CampusColors.purple),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.groups_outlined),
          selectedIcon: Icon(Icons.groups, color: CampusColors.purple),
          label: 'Clubs',
        ),
        NavigationDestination(
          key: ValueKey('open-calendar'),
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month, color: CampusColors.purple),
          label: 'Calendar',
        ),
        NavigationDestination(
          key: ValueKey('open-profile'),
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person, color: CampusColors.purple),
          label: 'Profile',
        ),
      ],
    ),
  );
}
