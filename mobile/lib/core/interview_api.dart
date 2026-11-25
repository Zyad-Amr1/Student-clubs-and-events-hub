part of 'api_client.dart';

extension InterviewApi on CampusApi {
  String _adminDays(String club) =>
      '/api/v1/club-admin/clubs/${Uri.encodeComponent(club)}/interview-days';

  String _studentInterview(String application) =>
      '/api/v1/me/applications/${Uri.encodeComponent(application)}/interview';

  Future<JsonObject> interviewDays(String token, String club) =>
      _request('GET', _adminDays(club), token: token);

  Future<JsonObject> saveInterviewDay(
    String token,
    String club,
    String day,
    JsonObject setup,
  ) => _request(
    'PUT',
    '${_adminDays(club)}/by-date/$day',
    token: token,
    body: setup,
  );

  Future<JsonObject> interviewSchedule(String token, String club, String day) =>
      _request(
        'GET',
        '${_adminDays(club)}/${Uri.encodeComponent(day)}/schedule',
        token: token,
      );

  Future<void> publishInterviews(
    String token,
    String club,
    String day,
    List<JsonObject> slots,
  ) async {
    await _request(
      'POST',
      '${_adminDays(club)}/${Uri.encodeComponent(day)}/schedule',
      token: token,
      body: {'appointments': slots},
    );
  }

  Future<JsonObject> studentInterview(String token, String application) =>
      _request('GET', _studentInterview(application), token: token);

  Future<void> selectInterviewDay(
    String token,
    String application,
    String day,
  ) async {
    await _request(
      'PUT',
      _studentInterview(application),
      token: token,
      body: {'day_id': day},
    );
  }

  Future<void> withdrawInterviewDay(String token, String application) async {
    await _request('DELETE', _studentInterview(application), token: token);
  }

  Future<JsonObject> interviewAppointments(String token) =>
      _request('GET', '/api/v1/me/interview-appointments', token: token);
}
