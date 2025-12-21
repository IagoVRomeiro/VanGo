import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class DistanceMatrixResult {
  final int? distanceMeters;
  final int? durationSeconds;
  final int? durationInTrafficSeconds;

  const DistanceMatrixResult({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.durationInTrafficSeconds,
  });
}

class DistanceMatrixService {
  final String apiKey;

  DistanceMatrixService({required this.apiKey});

  Future<DistanceMatrixResult?> fetchDriveMetrics({
    required LatLng origin,
    required LatLng destination,
  }) async {
    if (apiKey.isEmpty) return null;

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/distancematrix/json',
      {
        'origins': '${origin.latitude},${origin.longitude}',
        'destinations': '${destination.latitude},${destination.longitude}',
        'mode': 'driving',
        'departure_time': 'now',
        'key': apiKey,
      },
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        return null;
      }

      final payload = json.decode(response.body) as Map<String, dynamic>;
      final rows = payload['rows'] as List<dynamic>?;
      final elements =
          rows?.isNotEmpty == true ? rows!.first['elements'] as List<dynamic>? : null;
      final element = elements?.isNotEmpty == true ? elements!.first as Map<String, dynamic> : null;
      if (element == null) return null;
      if ((element['status'] as String?) != 'OK') return null;

      final distanceMeters = _parseInt(element['distance']?['value']);
      final durationSeconds = _parseInt(element['duration']?['value']);
      final durationInTrafficSeconds =
          _parseInt(element['duration_in_traffic']?['value']);

      return DistanceMatrixResult(
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
        durationInTrafficSeconds: durationInTrafficSeconds,
      );
    } catch (_) {
      return null;
    }
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
