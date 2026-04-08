import 'package:flutter/material.dart';
import 'app.dart';
import 'shared/services/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  SessionStore.apiBaseUrl = prefs.getString('api_base_url');
  runApp(const AiAttendanceApp());
}
