part of 'api_client.dart';

class MembershipApplication {
  MembershipApplication.fromJson(JsonObject data)
    : id = data['id'] as String,
      clubId = data['club_id'] as String,
      clubName = data['club_name'] as String,
      applicantName = data['applicant_name'] as String,
      status = data['status'] as String,
      submittedAt = DateTime.parse(data['submitted_at'] as String);

  final String id, clubId, clubName, applicantName, status;
  final DateTime submittedAt;

  String get statusLabel => switch (status) {
    'interview_required' => 'Interview Required',
    'accepted' => 'Accepted',
    _ => 'Pending',
  };
}

extension MembershipApi on CampusApi {
  Future<void> applyToClub(String token, String clubId) async {
    await _request(
      'POST',
      '/api/v1/clubs/${Uri.encodeComponent(clubId)}/applications',
      token: token,
    );
  }

  String _clubApplications(String clubId) =>
      '/api/v1/club-admin/clubs/${Uri.encodeComponent(clubId)}/applications';

  Future<({List<MembershipApplication> items, bool more})> applications(
    String token, {
    String? clubId,
    bool memberships = false,
    required int page,
  }) async {
    final path = clubId != null
        ? _clubApplications(clubId)
        : memberships
        ? '/api/v1/me/memberships'
        : '/api/v1/me/applications';
    final data = await _request(
      'GET',
      path,
      token: token,
      query: {'page': '$page'},
    );
    return (
      items: (data['applications'] as List)
          .cast<JsonObject>()
          .map(MembershipApplication.fromJson)
          .toList(),
      more: data['has_more'] as bool,
    );
  }

  Future<void> reviewApplication(
    String token,
    String clubId,
    String applicationId,
    String decision,
  ) async {
    await _request(
      'POST',
      '${_clubApplications(clubId)}/${Uri.encodeComponent(applicationId)}/decision',
      token: token,
      body: {'decision': decision},
    );
  }
}
