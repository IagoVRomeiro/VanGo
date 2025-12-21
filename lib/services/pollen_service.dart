import 'dart:convert';

import 'package:http/http.dart' as http;

class PollenSnapshot {
  final String? overallCategory;
  final List<String> highTypes;

  const PollenSnapshot({
    required this.overallCategory,
    required this.highTypes,
  });
}

class PollenService {
  final String apiKey;

  PollenService({required this.apiKey});

  Future<PollenSnapshot?> fetchForecast({
    required double latitude,
    required double longitude,
    int days = 1,
  }) async {
    final uri = Uri.https(
      'pollen.googleapis.com',
      '/v1/forecast:lookup',
      {
        'key': apiKey,
        'location.latitude': latitude.toString(),
        'location.longitude': longitude.toString(),
        'days': days.toString(),
        'languageCode': 'pt-BR',
      },
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        return null;
      }

      final payload = json.decode(response.body) as Map<String, dynamic>;
      final dailyInfo = payload['dailyInfo'] as List<dynamic>?;
      if (dailyInfo == null || dailyInfo.isEmpty) {
        return null;
      }

      final today = dailyInfo.first as Map<String, dynamic>;
      final pollenInfo = today['pollenTypeInfo'] as List<dynamic>?;
      if (pollenInfo == null || pollenInfo.isEmpty) {
        return null;
      }

      final highTypes = <String>[];
      String? overallCategory;

      for (final item in pollenInfo) {
        final map = item as Map<String, dynamic>;
        final name = map['displayName'] as String? ?? map['code'] as String?;
        final indexInfo = map['indexInfo'] as Map<String, dynamic>?;
        final category = indexInfo?['category'] as String?;

        overallCategory = _pickHigherCategory(overallCategory, category);

        if (_isHighCategory(category) && name != null) {
          highTypes.add(name);
        }
      }

      return PollenSnapshot(
        overallCategory: overallCategory,
        highTypes: highTypes,
      );
    } catch (_) {
      return null;
    }
  }

  bool _isHighCategory(String? category) {
    if (category == null) return false;
    final normalized = category.toLowerCase();
    return normalized.contains('high') ||
        normalized.contains('very') ||
        normalized.contains('alto') ||
        normalized.contains('elevado');
  }

  String? _pickHigherCategory(String? current, String? candidate) {
    if (candidate == null) return current;
    if (current == null) return candidate;

    final rank = _categoryRank(candidate);
    final currentRank = _categoryRank(current);
    return rank >= currentRank ? candidate : current;
  }

  int _categoryRank(String? category) {
    if (category == null) return 0;
    final normalized = category.toLowerCase();
    if (normalized.contains('very') || normalized.contains('muito')) return 4;
    if (normalized.contains('high') || normalized.contains('alto')) return 3;
    if (normalized.contains('moderate') || normalized.contains('moderado')) return 2;
    if (normalized.contains('low') || normalized.contains('baixo')) return 1;
    return 0;
  }
}
