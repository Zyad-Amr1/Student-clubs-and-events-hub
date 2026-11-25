part of 'api_client.dart';

extension ClubHeadApi on CampusApi {
  static const _review = '/api/v1/student-affairs/club-head-requests';

  Future<String> headVacancy(String token, String clubId) async {
    final data = await _request(
      'GET',
      '/api/v1/clubs/${Uri.encodeComponent(clubId)}/head-vacancy',
      token: token,
    );
    return data['availability'] as String;
  }

  Future<void> applyAsHead(String token, String clubId) async {
    await _request(
      'POST',
      '/api/v1/clubs/${Uri.encodeComponent(clubId)}/head-requests',
      token: token,
    );
  }

  Future<List<JsonObject>> headRequests(
    String token, {
    required bool review,
  }) async {
    final data = await _request(
      'GET',
      review ? _review : '/api/v1/me/club-head-requests',
      token: token,
    );
    return (data['requests'] as List).cast<JsonObject>();
  }

  Future<void> decideHeadRequest(
    String token,
    String requestId, {
    String? rejectionReason,
  }) async {
    await _request(
      'POST',
      '$_review/${Uri.encodeComponent(requestId)}/decision',
      token: token,
      body: {
        'decision': rejectionReason == null ? 'approve' : 'reject',
        'reason': ?rejectionReason,
      },
    );
  }
}
