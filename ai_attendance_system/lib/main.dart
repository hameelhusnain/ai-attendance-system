import 'package:flutter/material.dart';
import 'app.dart';
import 'shared/services/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  SessionStore.apiBaseUrl = prefs.getString('api_base_url');
  SessionStore.apiKey = prefs.getString('api_key');
  SessionStore.token = prefs.getString('auth_token');
  runApp(const AiAttendanceApp());
}
