import 'dart:convert';

import 'package:campusconnect/core/network/api_client.dart';
import 'package:campusconnect/features/clubs/data/clubs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'club browsing sends auth, pagination, and CAMP-9 filter parameters',
    () async {
      late http.Request captured;
      final repository = ClubsRepository(
        apiClient: ApiClient(
          baseUrl: 'https://campus.example.test',
          client: MockClient((request) async {
            captured = request;
            return http.Response(
              jsonEncode({
                'clubs': [clubJson],
                'page': 1,
                'page_size': 100,
                'total': 1,
              }),
              200,
            );
          }),
        ),
      );

      final page = await repository.browse(
        accessToken: 'student-jwt',
        search: ' robotics ',
        category: 'Technology',
      );

      expect(captured.headers['authorization'], 'Bearer student-jwt');
      expect(captured.url.queryParameters, {
        'page': '1',
        'page_size': '100',
        'search': 'robotics',
        'category': 'Technology',
      });
      expect(page.clubs.single.name, 'Robotics Club');
    },
  );

  test(
    'club details deserialize the club and upcoming event contract',
    () async {
      final repository = ClubsRepository(
        apiClient: ApiClient(
          baseUrl: 'https://campus.example.test',
          client: MockClient((request) async {
            expect(request.url.path, '/api/v1/clubs/club-uuid');
            expect(request.headers['authorization'], 'Bearer student-jwt');
            return http.Response(
              jsonEncode({
                'club': clubJson,
                'events': [
                  {
                    'id': 'event-uuid',
                    'title': 'Build Night',
                    'description': 'An evening workshop.',
                    'venue': 'Engineering Hall',
                    'starts_at': '2027-03-01T18:00:00Z',
                    'ends_at': '2027-03-01T20:00:00Z',
                    'seat_capacity': 30,
                  },
                ],
                'page': 1,
                'page_size': 20,
                'total': 1,
              }),
              200,
            );
          }),
        ),
      );

      final details = await repository.details(
        clubId: 'club-uuid',
        accessToken: 'student-jwt',
      );

      expect(details.club.name, 'Robotics Club');
      expect(details.events.single.title, 'Build Night');
      expect(details.events.single.startsAt.isUtc, isTrue);
      expect(details.events.single.seatCapacity, 30);
    },
  );
}

const clubJson = <String, Object?>{
  'id': 'club-uuid',
  'name': 'Robotics Club',
  'description': 'Build and learn together.',
  'category': 'Technology',
  'logo_url': null,
};
