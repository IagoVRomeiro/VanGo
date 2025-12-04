import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../models/directions_info.dart';

class DirectionsService {
  final String apiKey;

  DirectionsService({required this.apiKey});

  Future<DirectionsInfo?> getDirections({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
  }) async {
    final String originStr = '${origin.latitude},${origin.longitude}';
    final String destStr = '${destination.latitude},${destination.longitude}';

    final buffer = StringBuffer(
        'https://maps.googleapis.com/maps/api/directions/json?origin=$originStr&destination=$destStr');

    if (waypoints.isNotEmpty) {
      final waypointsStr = waypoints.map((p) => '${p.latitude},${p.longitude}').join('|');
      buffer.write('&waypoints=optimize:true|$waypointsStr');
    }

    buffer.write('&key=$apiKey');
    final url = Uri.parse(buffer.toString());

    try {
      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint("HTTP Error: ${response.statusCode}");
        return null;
      }

      final jsonResponse = json.decode(response.body);
      final routes = jsonResponse['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        debugPrint("Directions API Error: ${jsonResponse['error_message']}");
        return null;
      }

      final route = routes.first as Map<String, dynamic>;
      final overviewPolyline = route['overview_polyline']['points'] as String;
      final points = PolylinePoints()
          .decodePolyline(overviewPolyline)
          .map((PointLatLng p) => LatLng(p.latitude, p.longitude))
          .toList();

      final legsJson = route['legs'] as List<dynamic>? ?? [];
      num totalDistanceMeters = 0;
      num totalDurationSeconds = 0;
      final legs = legsJson.map((leg) {
        final steps = (leg['steps'] as List<dynamic>? ?? [])
            .map((step) => _stripHtml(step['html_instructions'] as String? ?? ''))
            .where((text) => text.isNotEmpty)
            .toList();
        final legDistanceMeters = (leg['distance']?['value'] as num?) ?? 0;
        final legDurationSeconds = (leg['duration']?['value'] as num?) ?? 0;
        totalDistanceMeters += legDistanceMeters;
        totalDurationSeconds += legDurationSeconds;
        return RouteLegInfo(
          startAddress: leg['start_address'] as String? ?? '',
          endAddress: leg['end_address'] as String? ?? '',
          distance: leg['distance']?['text'] as String? ?? '',
          duration: leg['duration']?['text'] as String? ?? '',
          instructions: steps,
        );
      }).toList();
      String? totalDistanceText;
      String? totalDurationText;
      if (totalDistanceMeters > 0) {
        totalDistanceText = totalDistanceMeters >= 1000
            ? '${(totalDistanceMeters / 1000).toStringAsFixed(1)} km'
            : '${totalDistanceMeters.toStringAsFixed(0)} m';
      }
      if (totalDurationSeconds > 0) {
        final duration = Duration(seconds: totalDurationSeconds.round());
        final hours = duration.inHours;
        final minutes = duration.inMinutes % 60;
        if (hours > 0) {
          totalDurationText = '$hours h $minutes m';
        } else {
          totalDurationText = '$minutes min';
        }
      }

      final waypointOrder = (route['waypoint_order'] as List<dynamic>?)
              ?.map((index) => index as int)
              .toList() ??
          List.generate(waypoints.length, (i) => i);

      return DirectionsInfo(
        polylinePoints: points,
        totalDistance: totalDistanceText,
        totalDuration: totalDurationText,
        legs: legs,
        waypointOrder: waypointOrder,
      );
    } catch (e) {
      debugPrint("Error getting directions: $e");
      return null;
    }
  }

  String _stripHtml(String htmlText) {
    return htmlText.replaceAll(RegExp(r'<[^>]*>'), '');
  }
}
