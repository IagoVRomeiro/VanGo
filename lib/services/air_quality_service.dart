import 'dart:convert';

import 'package:http/http.dart' as http;

class AirQualitySnapshot {
  final int? aqi;
  final String? category;
  final String? dominantPollutant;

  const AirQualitySnapshot({
    required this.aqi,
    required this.category,
    required this.dominantPollutant,
  });
}

class AirQualityService {
  final String apiKey;

  AirQualityService({required this.apiKey});

  Future<AirQualitySnapshot?> fetchCurrent({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.https(
      'airquality.googleapis.com',
      '/v1/currentConditions:lookup',
      {'key': apiKey},
    );

    final body = {
      'location': {
        'latitude': latitude,
        'longitude': longitude,
      },
      'languageCode': 'pt-BR',
      'extraComputations': [
        'HEALTH_RECOMMENDATIONS',
        'DOMINANT_POLLUTANT_CONCENTRATION',
        'LOCAL_AQI',
      ],
    };

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final payload = json.decode(response.body) as Map<String, dynamic>;
      final indexes = payload['indexes'] as List<dynamic>?;
      final index = _pickIndex(indexes);
      final aqi = _parseInt(index?['aqi']) ?? _parseInt(index?['aqiDisplay']);
      final category = index?['category'] as String?;
      final dominant = payload['dominantPollutant'] as String?;

      return AirQualitySnapshot(
        aqi: aqi,
        category: category,
        dominantPollutant: dominant,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _pickIndex(List<dynamic>? indexes) {
    if (indexes == null || indexes.isEmpty) return null;
    for (final item in indexes) {
      final map = item as Map<String, dynamic>;
      final code = map['code'] as String?;
      if (code == 'uaqi' || code == 'local_aqi') {
        return map;
      }
    }
    return indexes.first as Map<String, dynamic>;
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
