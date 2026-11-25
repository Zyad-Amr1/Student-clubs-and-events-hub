import 'package:campusconnect/core/api_client.dart';

const affairsEmail = String.fromEnvironment('ACCEPTANCE_AFFAIRS_EMAIL');
const affairsPassword = String.fromEnvironment('ACCEPTANCE_AFFAIRS_PASSWORD');

class AcceptanceStudent {
  const AcceptanceStudent(this.email, this.password, this.token);
  final String email;
  final String password;
  final String token;
}

class AcceptanceFixture {
  AcceptanceFixture(this.api);

  final CampusApi api;

  Future<String> affairsToken() async {
    if (affairsEmail.isEmpty || affairsPassword.isEmpty) {
      throw StateError(
        'Set disposable ACCEPTANCE_AFFAIRS_EMAIL and ACCEPTANCE_AFFAIRS_PASSWORD.',
      );
    }
    return api.login(affairsEmail, affairsPassword);
  }

  Future<AcceptanceStudent> student(String label) async {
    final id = DateTime.now().microsecondsSinceEpoch;
    final email = 'acceptance-$label-$id@example.edu';
    final password = 'Acceptance#$id';
    await api.register(
      fullName: 'Acceptance $label',
      email: email,
      universityId: 'ACCEPT-$label-$id',
      password: password,
      confirmPassword: password,
    );
    return AcceptanceStudent(email, password, await api.login(email, password));
  }

  Future<ManagedClub> approveClub({
    required String studentToken,
    required String affairsToken,
    required String name,
    String category = 'Science',
  }) async {
    await api.saveClubRequest(studentToken, {
      'name': name,
      'description': 'Acceptance test club for university students.',
      'category': category,
    });
    final requests = await api.clubRequests(
      studentToken,
      review: false,
      page: 1,
    );
    final request = requests.requests.singleWhere(
      (item) => item.name == name && item.pending,
    );
    await api.decideClubRequest(affairsToken, request.id, 'approve');
    final managed = await api.myManagedClubs(studentToken);
    return managed.singleWhere((item) => item.name == name);
  }

  Future<ManagedEvent> publishEvent({
    required String clubId,
    required String creatorToken,
    required String affairsToken,
    required String title,
    int capacity = 1,
  }) async {
    final draft = await api.createDraftEvent(
      token: creatorToken,
      clubId: clubId,
      title: title,
      description: 'An upcoming university acceptance event.',
      venue: 'Campus Hall',
      startsAt: DateTime.now().toUtc().add(const Duration(days: 7)),
      seatCapacity: capacity,
    );
    final submitted = await api.submitDraftEvent(
      creatorToken,
      clubId,
      draft.id,
    );
    if (submitted.approvalStatus != 'pending') {
      throw StateError('Event submission did not enter review.');
    }
    final approved = await api.reviewEvent(
      affairsToken,
      draft.id,
      decision: 'approve',
    );
    if (!approved.isPublished) {
      throw StateError('Event approval did not publish the event.');
    }
    return approved;
  }
}
