import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../services/denodo_service.dart';
import '../services/firestore_service.dart';

enum QueryStatus { idle, loading, done, error }

class QueryProvider extends ChangeNotifier {
  final List<ChatSession> _sessions = [];
  ChatSession? _currentSession;
  String? _userId;

  QueryStatus status = QueryStatus.idle;
  String loadingPhase = '';
  String selectedModel = 'Turbo';
  String selectedDatabase = '';
  bool showOptions = false;
  bool loadingDatabases = false;
  String? databasesError;

  final List<String> models = ['Turbo', 'Deep'];
  List<String> databases = [];

  List<ChatSession> get sessions =>
      _sessions.where((s) => s.database == selectedDatabase).toList().reversed.toList();

  ChatSession? get currentSession => _currentSession;

  List<ChatMessage> get messages => _currentSession?.messages ?? const [];

  bool get isLoading => status == QueryStatus.loading;

  Future<void> setUser(String? userId) async {
    if (_userId == userId) return;
    _userId = userId;
    if (userId == null) {
      _sessions.clear();
      _currentSession = null;
      notifyListeners();
      return;
    }
    await _loadSessionsFromFirestore();
  }

  Future<void> _loadSessionsFromFirestore() async {
    if (_userId == null || selectedDatabase.isEmpty) return;
    try {
      final fetched =
          await FirestoreService.loadSessions(_userId!, selectedDatabase);
      if (fetched.isEmpty) return; // keep in-memory sessions if Firestore has none
      final fetchedIds = fetched.map((s) => s.id).toSet();
      _sessions.removeWhere(
          (s) => s.database == selectedDatabase && fetchedIds.contains(s.id));
      _sessions.addAll(fetched);
      notifyListeners();
    } catch (_) {
      // Sessions simply won't load — app still works in-memory
    }
  }

  Future<void> loadDatabases() async {
    loadingDatabases = true;
    databasesError = null;
    notifyListeners();
    try {
      final dbs = await DenodoService.fetchDatabases();
      databases = dbs;
      if (dbs.isNotEmpty) selectedDatabase = dbs.first;
      await _loadSessionsFromFirestore();
    } catch (e) {
      databasesError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      loadingDatabases = false;
      notifyListeners();
    }
  }

  void newChat() {
    final session = ChatSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      database: selectedDatabase,
    );
    _sessions.add(session);
    _currentSession = session;
    showOptions = false;
    notifyListeners();
  }

  void loadSession(ChatSession session) {
    _currentSession = session;
    showOptions = false;
    notifyListeners();
  }

  void renameSession(String id, String newTitle) {
    final session = _sessions.firstWhere((s) => s.id == id);
    session.customTitle = newTitle.trim().isEmpty ? null : newTitle.trim();
    notifyListeners();
    if (_userId != null) {
      FirestoreService.saveSession(_userId!, session).ignore();
    }
  }

  void deleteSession(String id) {
    final session = _sessions.firstWhere((s) => s.id == id);
    _sessions.remove(session);
    if (_currentSession?.id == id) _currentSession = null;
    notifyListeners();
    if (_userId != null) {
      FirestoreService.deleteSession(_userId!, id).ignore();
    }
  }

  void selectModel(String model) {
    selectedModel = model;
    notifyListeners();
  }

  Future<void> selectDatabase(String db) async {
    selectedDatabase = db;
    _currentSession = null;
    showOptions = false;
    notifyListeners();
    await _loadSessionsFromFirestore();
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

    if (_currentSession == null) newChat();

    _currentSession!.messages.add(ChatMessage(content: text.trim(), isUser: true));
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
      database: selectedDatabase,
      plot: wantsPlot,
      onPhaseChange: (phase) {
        loadingPhase = phase;
        notifyListeners();
      },
    );

    _currentSession!.messages.add(ChatMessage.fromApiResponse(response));
    status = QueryStatus.done;
    loadingPhase = '';
    notifyListeners();

    if (_userId != null) {
      FirestoreService.saveSession(_userId!, _currentSession!).ignore();
    }
  }
}
