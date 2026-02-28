import 'chat_message.dart';

class ChatSession {
  final String id;
  final String database;
  final List<ChatMessage> messages;
  String? customTitle;

  ChatSession({
    required this.id,
    required this.database,
    List<ChatMessage>? messages,
    this.customTitle,
  }) : messages = messages ?? [];

  String get title {
    if (customTitle != null && customTitle!.isNotEmpty) return customTitle!;
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
        'customTitle': customTitle,
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
      customTitle: json['customTitle'] as String?,
      messages: msgs,
    );
  }
}
