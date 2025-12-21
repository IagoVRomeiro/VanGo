import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class RoutesMetrics {
  final int? distanceMeters;
  final int? durationSeconds;

  const RoutesMetrics({
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

class RoutesService {
  final String apiKey;

  RoutesService({required this.apiKey});

  Future<RoutesMetrics?> computeMetrics({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
  }) async {
    final uri = Uri.https(
      'routes.googleapis.com',
      '/directions/v2:computeRoutes',
      {'key': apiKey},
    );

    final body = {
      'origin': _latLngPayload(origin),
      'destination': _latLngPayload(destination),
      if (waypoints.isNotEmpty)
        'intermediates': waypoints.map(_latLngPayload).toList(),
      'travelMode': 'DRIVE',
      'routingPreference': 'TRAFFIC_AWARE',
      'computeAlternativeRoutes': false,
      'languageCode': 'pt-BR',
      'units': 'METRIC',
      'departureTime': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters',
        },
        body: json.encode(body),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final payload = json.decode(response.body) as Map<String, dynamic>;
      final routes = payload['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        return null;
      }

      final route = routes.first as Map<String, dynamic>;
      final distanceMeters = _parseInt(route['distanceMeters']);
      final durationSeconds = _parseDurationSeconds(route['duration']);

      return RoutesMetrics(
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _latLngPayload(LatLng point) {
    return {
      'location': {
        'latLng': {
          'latitude': point.latitude,
          'longitude': point.longitude,
        },
      },
    };
  }

  int? _parseDurationSeconds(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.endsWith('s')) {
        final numeric = trimmed.substring(0, trimmed.length - 1);
        final parsed = double.tryParse(numeric);
        return parsed?.round();
      }
      return int.tryParse(trimmed);
    }
    return null;
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
