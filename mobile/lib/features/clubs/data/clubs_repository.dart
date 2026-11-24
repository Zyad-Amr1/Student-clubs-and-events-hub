import 'package:campusconnect/core/network/api_client.dart';
import 'package:campusconnect/features/clubs/models/club.dart';

class ClubsRepository {
  const ClubsRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<ClubPage> browse({
    required String accessToken,
    int page = 1,
    int pageSize = 100,
    String search = '',
    String category = '',
  }) async {
    final response = await apiClient.getJson(
      '/clubs',
      accessToken: accessToken,
      queryParameters: {
        'page': '$page',
        'page_size': '$pageSize',
        'search': search.trim(),
        'category': category.trim(),
      },
    );
    return ClubPage.fromJson(response);
  }

  Future<ClubDetails> details({
    required String clubId,
    required String accessToken,
  }) async {
    final response = await apiClient.getJson(
      '/clubs/${Uri.encodeComponent(clubId)}',
      accessToken: accessToken,
    );
    return ClubDetails.fromJson(response);
  }
}
