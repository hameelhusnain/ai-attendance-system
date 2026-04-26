import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SessionStore {
  static const _currentSessionIdKey = 'current_session_id';
  static const _currentSessionKey = 'current_session_payload';

  static String? token;
  static String? displayName;
  static String? apiBaseUrl;
  static Map<String, dynamic>? selectedClass;
  static String? currentSessionId;
  static Map<String, dynamic>? currentSession;

  static Future<void> loadPersistedSession() async {
    final prefs = await SharedPreferences.getInstance();
    currentSessionId = prefs.getString(_currentSessionIdKey);

    final storedSession = prefs.getString(_currentSessionKey);
    if (storedSession == null || storedSession.trim().isEmpty) {
      currentSession = null;
      return;
    }

    try {
      final decoded = jsonDecode(storedSession);
      currentSession = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : null;
    } catch (_) {
      currentSession = null;
    }
  }

  static Future<void> saveCurrentSession({
    required String? sessionId,
    required Map<String, dynamic>? session,
  }) async {
    currentSessionId = sessionId;
    currentSession = session == null || session.isEmpty ? null : session;

    final prefs = await SharedPreferences.getInstance();

    if (sessionId == null || sessionId.trim().isEmpty) {
      await prefs.remove(_currentSessionIdKey);
    } else {
      await prefs.setString(_currentSessionIdKey, sessionId);
    }

    if (currentSession == null) {
      await prefs.remove(_currentSessionKey);
    } else {
      await prefs.setString(_currentSessionKey, jsonEncode(currentSession));
    }
  }

  static Future<void> clearCurrentSession() async {
    await saveCurrentSession(sessionId: null, session: null);
  }
}
