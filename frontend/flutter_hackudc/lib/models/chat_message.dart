import '../services/denodo_service.dart';

class ChatMessage {
  final String content;
  final bool isUser;
  final ApiResponse? apiResponse;

  const ChatMessage({
    required this.content,
    required this.isUser,
    this.apiResponse,
  });

  factory ChatMessage.fromApiResponse(ApiResponse response) {
    return ChatMessage(
      content: response.answer,
      isUser: false,
      apiResponse: response,
    );
  }
}
