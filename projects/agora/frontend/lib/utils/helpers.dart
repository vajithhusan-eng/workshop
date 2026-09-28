import 'dart:convert';

import 'package:intl/intl.dart';

import '../utils/constants.dart';

class Helpers {
  static String formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }

  static String formatDateTime(DateTime date) {
    return '${formatDate(date)} ${formatTime(date)}';
  }

  static String formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return formatDate(date);
  }

  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return '${text[0].toUpperCase()}${text.substring(1)}';
  }

  static String generateSessionTitle(List<String> agentNames) {
    final now = DateTime.now();
    final dateStr = DateFormat('MMM d').format(now);
    final timeStr = DateFormat('h:mm a').format(now);
    return 'Session - $dateStr $timeStr';
  }

  static Map<String, dynamic> jsonDecodeMap(String jsonString) {
    try {
      return Map<String, dynamic>.from(jsonDecode(jsonString));
    } catch (e) {
      return {};
    }
  }

  static List<dynamic> jsonDecodeList(String jsonString) {
    try {
      return jsonDecode(jsonString) as List<dynamic>;
    } catch (e) {
      return [];
    }
  }

  static String jsonEncodeMap(Map<String, dynamic> map) {
    return jsonEncode(map);
  }

  static Color getAgentColor(int index) {
    return AppConstants.agentColors[index % AppConstants.agentColors.length];
  }

  static String getAgentEmoji(String type) {
    switch (type) {
      case AppConstants.agentTypePlanner:
        return '📋';
      case AppConstants.agentTypeWriter:
        return '✍️';
      case AppConstants.agentTypeEditor:
        return '📝';
      case AppConstants.agentTypeReviewer:
        return '🔍';
      case AppConstants.agentTypeIllustrator:
        return '🎨';
      default:
        return '🤖';
    }
  }

  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  static String sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(' ', '_');
  }
}
