import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import 'auth_models.dart';

class AuthApi {
  AuthApi({
    required ApiClient apiClient,
    required TokenStorage tokenStorage,
  })  : _apiClient = apiClient,
        _tokenStorage = tokenStorage;

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.dio.post(
      '/auth/login',
      data: {
        'username': email,
        'password': password,
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
      ),
    );

    final data = Map<String, dynamic>.from(response.data as Map);
    final token = data['access_token']?.toString();

    if (token == null || token.isEmpty) {
      throw Exception('Token não retornado pela API.');
    }

    await _tokenStorage.saveToken(token);

    return me();
  }

  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await _apiClient.dio.post(
      '/auth/register',
      data: {
        'name': name,
        'email': email,
        'password': password,
      },
    );

    return login(
      email: email,
      password: password,
    );
  }

  Future<AppUser> me() async {
    final response = await _apiClient.dio.get('/auth/me');

    final data = Map<String, dynamic>.from(response.data as Map);

    return AppUser.fromJson(data);
  }

  Future<void> logout() async {
    await _tokenStorage.clearToken();
  }

  Future<bool> hasToken() async {
    final token = await _tokenStorage.getToken();

    return token != null && token.isNotEmpty;
  }
}