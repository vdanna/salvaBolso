class ChatSession {
  const ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String title;
  final String? createdAt;
  final String? updatedAt;

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: int.tryParse(json['id'].toString()) ?? 0,
      title: json['title']?.toString() ?? 'Nova conversa financeira',
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  final int id;
  final int sessionId;
  final String role;
  final String content;
  final String? createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: int.tryParse(json['id'].toString()) ?? 0,
      sessionId: int.tryParse(json['session_id'].toString()) ?? 0,
      role: json['role']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt: json['created_at']?.toString(),
    );
  }

  bool get isUser => role == 'user';

  bool get isAssistant => role == 'assistant';
}

class SendChatMessageResponse {
  const SendChatMessageResponse({
    required this.sessionId,
    required this.userMessage,
    required this.assistantMessage,
  });

  final int sessionId;
  final ChatMessage userMessage;
  final ChatMessage assistantMessage;

  factory SendChatMessageResponse.fromJson(Map<String, dynamic> json) {
    return SendChatMessageResponse(
      sessionId: int.tryParse(json['session_id'].toString()) ?? 0,
      userMessage: ChatMessage.fromJson(
        Map<String, dynamic>.from(json['user_message'] as Map),
      ),
      assistantMessage: ChatMessage.fromJson(
        Map<String, dynamic>.from(json['assistant_message'] as Map),
      ),
    );
  }
}