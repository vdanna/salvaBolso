import '../../../core/network/api_client.dart';
import 'chat_models.dart';

class ChatApi {
  ChatApi({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<ChatSession> createSession({
    String? title,
  }) async {
    final response = await _apiClient.dio.post(
      '/chat/sessions',
      data: {
        'title': title,
      },
    );

    return ChatSession.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<List<ChatSession>> getSessions() async {
    final response = await _apiClient.dio.get('/chat/sessions');

    final data = response.data;

    if (data is! List) {
      return [];
    }

    return data
        .map(
          (item) => ChatSession.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<List<ChatMessage>> getMessages({
    required int sessionId,
  }) async {
    final response = await _apiClient.dio.get(
      '/chat/sessions/$sessionId/messages',
    );

    final data = response.data;

    if (data is! List) {
      return [];
    }

    return data
        .map(
          (item) => ChatMessage.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<SendChatMessageResponse> sendMessage({
    required int sessionId,
    required String message,
  }) async {
    final response = await _apiClient.dio.post(
      '/chat/sessions/$sessionId/messages',
      data: {
        'message': message,
      },
    );

    return SendChatMessageResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> deleteSession({
    required int sessionId,
  }) async {
    await _apiClient.dio.delete('/chat/sessions/$sessionId');
  }
}