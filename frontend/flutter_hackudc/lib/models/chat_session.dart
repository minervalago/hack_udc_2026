import 'chat_message.dart';

class ChatSession {
  final String id;
  final String database;
  final List<ChatMessage> messages;

  ChatSession({
    required this.id,
    required this.database,
    List<ChatMessage>? messages,
  }) : messages = messages ?? [];

  String get title {
    try {
      final first = messages.firstWhere((m) => m.isUser);
      final text = first.content;
      return text.length > 32 ? '${text.substring(0, 32)}…' : text;
    } catch (_) {
      return 'Nueva consulta';
    }
  }

  Map<String, dynamic> toJson() => {
        'database': database,
        'messages': messages.map((m) => m.toJson()).toList(),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

  factory ChatSession.fromJson(String id, Map<String, dynamic> json) {
    final msgs = (json['messages'] as List<dynamic>? ?? [])
        .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList();
    return ChatSession(
      id: id,
      database: json['database'] as String? ?? '',
      messages: msgs,
    );
  }
}
