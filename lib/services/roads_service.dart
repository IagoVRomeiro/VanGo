import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class RoadsService {
  final String apiKey;

  RoadsService({required this.apiKey});

  Future<List<LatLng>?> snapToRoads(List<LatLng> points) async {
    if (points.length < 2) return null;

    final sampled = _samplePoints(points, 100);
    final path = sampled
        .map((p) => '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}')
        .join('|');

    final uri = Uri.https(
      'roads.googleapis.com',
      '/v1/snapToRoads',
      {
        'interpolate': 'true',
        'path': path,
        'key': apiKey,
      },
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        return null;
      }

      final payload = json.decode(response.body) as Map<String, dynamic>;
      final snappedPoints = payload['snappedPoints'] as List<dynamic>?;
      if (snappedPoints == null || snappedPoints.isEmpty) {
        return null;
      }

      final parsed = snappedPoints
          .map((item) {
            final map = item as Map<String, dynamic>;
            final location = map['location'] as Map<String, dynamic>?;
            if (location == null) return null;
            final lat = _parseDouble(location['latitude']);
            final lng = _parseDouble(location['longitude']);
            if (lat == null || lng == null) return null;
            return _SnappedPoint(
              position: LatLng(lat, lng),
              originalIndex: _parseInt(map['originalIndex']),
            );
          })
          .whereType<_SnappedPoint>()
          .toList();

      if (parsed.isEmpty) {
        return null;
      }

      final hasIndex = parsed.every((p) => p.originalIndex != null);
      if (hasIndex) {
        parsed.sort((a, b) => a.originalIndex!.compareTo(b.originalIndex!));
      }

      return parsed.map((p) => p.position).toList();
    } catch (_) {
      return null;
    }
  }

  List<LatLng> _samplePoints(List<LatLng> points, int maxPoints) {
    if (points.length <= maxPoints) return points;

    final step = (points.length / maxPoints).ceil();
    final sampled = <LatLng>[];
    for (var i = 0; i < points.length; i += step) {
      sampled.add(points[i]);
    }
    if (sampled.last != points.last) {
      sampled.add(points.last);
    }
    return sampled;
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
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

class _SnappedPoint {
  final LatLng position;
  final int? originalIndex;

  const _SnappedPoint({required this.position, required this.originalIndex});
}
