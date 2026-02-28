import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../services/denodo_service.dart';

enum QueryStatus { idle, loading, done, error }

class QueryProvider extends ChangeNotifier {
  final List<ChatMessage> messages = [];
  QueryStatus status = QueryStatus.idle;
  String loadingPhase = '';
  String selectedModel = 'Turbo';
  String selectedDatabase = 'BD Mec';
  bool showOptions = false;

  final List<String> models = ['Turbo', 'Pro'];
  final List<String> databases = ['BD Mec', 'BD ENUE', 'BD XXXX', 'BD XXX'];

  bool get isLoading => status == QueryStatus.loading;

  void selectModel(String model) {
    selectedModel = model;
    notifyListeners();
  }

  void selectDatabase(String db) {
    selectedDatabase = db;
    messages.clear();
    showOptions = false;
    notifyListeners();
  }

  void toggleOptions() {
    showOptions = !showOptions;
    notifyListeners();
  }

  void hideOptions() {
    showOptions = false;
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || isLoading) return;

    messages.add(ChatMessage(content: text.trim(), isUser: true));
    status = QueryStatus.loading;
    loadingPhase = 'Iniciando consulta...';
    showOptions = false;
    notifyListeners();

    final wantsPlot = RegExp(
      r'gr[aá]fic|plot|chart|diagrama',
      caseSensitive: false,
    ).hasMatch(text);

    final response = await DenodoService.query(
      question: text.trim(),
      model: selectedModel,
      plot: wantsPlot,
      onPhaseChange: (phase) {
        loadingPhase = phase;
        notifyListeners();
      },
    );

    messages.add(ChatMessage.fromApiResponse(response));
    status = QueryStatus.done;
    loadingPhase = '';
    notifyListeners();
  }
}
