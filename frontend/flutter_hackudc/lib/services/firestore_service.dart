import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_session.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _sessionsRef(String uid) =>
      _db.collection('users').doc(uid).collection('sessions');

  static Future<List<ChatSession>> loadSessions(
      String uid, String database) async {
    final snapshot = await _sessionsRef(uid)
        .where('database', isEqualTo: database)
        .orderBy('updatedAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => ChatSession.fromJson(doc.id, doc.data()))
        .toList();
  }

  static Future<void> saveSession(String uid, ChatSession session) async {
    await _sessionsRef(uid).doc(session.id).set(session.toJson());
  }

  static Future<void> deleteSession(String uid, String sessionId) async {
    await _sessionsRef(uid).doc(sessionId).delete();
  }
}
