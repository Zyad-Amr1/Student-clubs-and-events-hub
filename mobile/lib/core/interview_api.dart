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

  Future<JsonObject> interviewNotices(String token) =>
      _request('GET', '/api/v1/me/interview-notices', token: token);

  String _interviewDay(String club, String day) =>
      '${_adminDays(club)}/${Uri.encodeComponent(day)}';

  Future<JsonObject> previewInterviewCancellation(
    String token,
    String club,
    String day,
    JsonObject target,
  ) => _request(
    'POST',
    '${_interviewDay(club, day)}/cancellation-preview',
    token: token,
    body: target,
  );

  Future<void> cancelInterview(
    String token,
    String club,
    String day,
    JsonObject target,
    String previewToken,
    String reason,
  ) async {
    await _request(
      'POST',
      '${_interviewDay(club, day)}/cancel',
      token: token,
      body: {'target': target, 'preview_token': previewToken, 'reason': reason},
    );
  }

  Future<void> recordInterviewAttendance(
    String token,
    String club,
    String day,
    String selection,
    String status,
  ) async {
    await _request(
      'PUT',
      '${_interviewDay(club, day)}/appointments/${Uri.encodeComponent(selection)}/attendance',
      token: token,
      body: {'status': status},
    );
  }
}
