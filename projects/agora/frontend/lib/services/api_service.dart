import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../utils/constants.dart';
import '../utils/helpers.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  static final String baseUrl = AppConstants.apiBaseUrl;
  final http.Client _client = http.Client();
  String? _authToken;

  factory ApiService() => _instance;
  ApiService._internal();

  set authToken(String? token) {
    _authToken = token;
  }

  Map<String, String> get _headers {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (_authToken != null) 'Authorization': 'Bearer $_authToken',
    };
  }

  // Sessions
  Future<List<SessionModel>> getSessions() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/sessions'),
      headers: _headers,
    );
    return _handleResponse<List<SessionModel>>(response, (json) {
      return (json as List)
          .map((e) => SessionModel.fromJson(e as Map))
          .toList();
    });
  }

  Future<SessionModel> createSession(Map<String, dynamic> data) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/sessions'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleResponse<SessionModel>(response, (json) {
      return SessionModel.fromJson(json as Map);
    });
  }

  Future<SessionModel> updateSession(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _client.patch(
      Uri.parse('$baseUrl/sessions/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleResponse<SessionModel>(response, (json) {
      return SessionModel.fromJson(json as Map);
    });
  }

  Future<void> deleteSession(String id) async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/sessions/$id'),
      headers: _headers,
    );
    _handleResponse<void>(response, (_) => null);
  }

  // Agents
  Future<List<AgentModel>> getAgents() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/agents'),
      headers: _headers,
    );
    return _handleResponse<List<AgentModel>>(response, (json) {
      return (json as List).map((e) => AgentModel.fromJson(e as Map)).toList();
    });
  }

  Future<AgentModel> createAgent(Map<String, dynamic> data) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/agents'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleResponse<AgentModel>(response, (json) {
      return AgentModel.fromJson(json as Map);
    });
  }

  Future<AgentModel> updateAgent(String id, Map<String, dynamic> data) async {
    final response = await _client.patch(
      Uri.parse('$baseUrl/agents/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleResponse<AgentModel>(response, (json) {
      return AgentModel.fromJson(json as Map);
    });
  }

  // Chat
  Future<Map<String, dynamic>> sendMessage(
    String sessionId,
    Map<String, dynamic> message,
  ) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/chat/$sessionId'),
      headers: _headers,
      body: jsonEncode(message),
    );
    return _handleResponse<Map<String, dynamic>>(response, (json) {
      return Map<String, dynamic>.from(json);
    });
  }

  // Auth
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _handleResponse<Map<String, dynamic>>(response, (json) {
      _authToken = json['token'] as String?;
      return Map<String, dynamic>.from(json);
    });
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleResponse<Map<String, dynamic>>(response, (json) {
      return Map<String, dynamic>.from(json);
    });
  }

  // Health check
  Future<bool> checkHealth() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/health'),
        timeout: const Duration(seconds: 5),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> dispose() async {
    await _client.close();
  }

  Future<T> _handleResponse<T>(
    http.Response response,
    T Function(dynamic) parser,
  ) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return parser(jsonDecode(response.body));
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: jsonDecode(response.body)['message'] ?? 'Unknown error',
      );
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
