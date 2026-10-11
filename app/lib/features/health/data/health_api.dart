import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';

class HealthApi {
  HealthApi({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> getHealth() async {
    final Response response = await _apiClient.dio.get('/health');

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getDatabaseHealth() async {
    final Response response = await _apiClient.dio.get('/health/database');

    return Map<String, dynamic>.from(response.data as Map);
  }
}