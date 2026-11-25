/// UI choice, never an authorization credential.
enum PortalRole { student, clubAdmin, studentAffairs }

extension PortalDescription on PortalRole {
  String get label => switch (this) {
    PortalRole.student => 'Student',
    PortalRole.clubAdmin => 'Club Admin',
    PortalRole.studentAffairs => 'Student Affairs',
  };

  String get loginTitle => switch (this) {
    PortalRole.student => 'Student login',
    PortalRole.clubAdmin => 'Club administrator login',
    PortalRole.studentAffairs => 'Student Affairs login',
  };
}

PortalRole? portalFromStorage(String? name) {
  for (final portal in PortalRole.values) {
    if (portal.name == name) return portal;
  }
  return null;
}
