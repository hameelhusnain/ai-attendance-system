import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'session_store.dart';

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  static const String defaultBaseUrl = 'https://flyless-lavern-unstealthy.ngrok-free.dev';
  final http.Client _client;
  String? _token;

  String? get token => _token;

  void setToken(String token) {
    _token = token;
  }

  String get baseUrl {
    final raw = SessionStore.apiBaseUrl;
    final resolved = (raw != null && raw.trim().isNotEmpty) ? raw.trim() : defaultBaseUrl;
    var cleaned = resolved.endsWith('/') ? resolved.substring(0, resolved.length - 1) : resolved;
    if (cleaned.endsWith('/docs')) {
      cleaned = cleaned.substring(0, cleaned.length - 5);
    }
    return cleaned;
  }

  Map<String, String> _headers({bool auth = true}) {
    if (auth && _token == null && SessionStore.token != null) {
      _token = SessionStore.token;
    }
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };
    if (auth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Map<String, String> _authHeaders() {
    if (_token == null && SessionStore.token != null) {
      _token = SessionStore.token;
    }
    final headers = <String, String>{
      'Accept': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Future<dynamic> _handleResponse(http.Response response) async {
    final body = response.body;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body.isEmpty) return null;
      return jsonDecode(body);
    }
    throw HttpException('Request failed: ${response.statusCode} ${response.reasonPhrase} $body');
  }

  Future<String> login(String email, String password) async {
    final uri = Uri.parse('${baseUrl}/auth/login');
    final response = await _client.post(
      uri,
      headers: _headers(auth: false),
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = await _handleResponse(response) as Map<String, dynamic>;
    final token = data['access_token'] as String;
    _token = token;
    return token;
  }

  Future<dynamic> getMe(String token) async {
    setToken(token);
    final uri = Uri.parse('${baseUrl}/auth/me').replace(queryParameters: {'token': token});
    final response = await _client.get(uri, headers: _headers());
    return _handleResponse(response);
  }

  Future<dynamic> getStudents() async {
    final uri = Uri.parse('${baseUrl}/students/');
    final response = await _client.get(uri, headers: _headers());
    return _handleResponse(response);
  }

  Future<dynamic> createStudent(Map<String, dynamic> data) async {
    final uri = Uri.parse('${baseUrl}/students/');
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  Future<void> deleteStudent(String studentId) async {
    final uri = Uri.parse('${baseUrl}/students/$studentId');
    final response = await _client.delete(uri, headers: _headers());
    await _handleResponse(response);
  }

  Future<dynamic> uploadPhoto(File file) async {
    final uri = Uri.parse('${baseUrl}/students/upload-photo');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_authHeaders())
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _handleResponse(response);
  }

  Future<dynamic> getClasses() async {
    final uri = Uri.parse('${baseUrl}/classes/');
    final response = await _client.get(uri, headers: _headers());
    return _handleResponse(response);
  }

  Future<dynamic> createClass(Map<String, dynamic> data) async {
    final uri = Uri.parse('${baseUrl}/classes/');
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  Future<dynamic> getTeachers() async {
    final uri = Uri.parse('${baseUrl}/teachers/');
    final response = await _client.get(uri, headers: _headers());
    return _handleResponse(response);
  }

  Future<dynamic> createTeacher(Map<String, dynamic> data) async {
    final uri = Uri.parse('${baseUrl}/teachers/');
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  Future<dynamic> getSessions() async {
    final uri = Uri.parse('${baseUrl}/sessions/');
    final response = await _client.get(uri, headers: _headers());
    return _handleResponse(response);
  }

  Future<dynamic> startSession(Map<String, dynamic> data) async {
    final uri = Uri.parse('${baseUrl}/sessions/');
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  Future<dynamic> endSession(String sessionId) async {
    final uri = Uri.parse('${baseUrl}/sessions/$sessionId/end');
    final response = await _client.post(uri, headers: _headers());
    return _handleResponse(response);
  }

  Future<dynamic> submitAttendance(String sessionId, Map<String, dynamic> data) async {
    final uri = Uri.parse('${baseUrl}/attendance/sessions/$sessionId/submit');
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }
}
