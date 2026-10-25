import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../models/directions_info.dart';
import 'roads_service.dart';
import 'routes_service.dart';

class DirectionsService {
  final String apiKey;
  final RoutesService _routesService;
  final RoadsService _roadsService;

  DirectionsService({required this.apiKey})
      : _routesService = RoutesService(apiKey: apiKey),
        _roadsService = RoadsService(apiKey: apiKey);

  Future<DirectionsInfo?> getDirections({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
    bool optimizeWaypoints = true,
  }) async {
    final String originStr = '${origin.latitude},${origin.longitude}';
    final String destStr = '${destination.latitude},${destination.longitude}';

    final buffer = StringBuffer(
        'https://maps.googleapis.com/maps/api/directions/json?origin=$originStr&destination=$destStr');

    if (waypoints.isNotEmpty) {
      final waypointsStr = waypoints.map((p) => '${p.latitude},${p.longitude}').join('|');
      final optimize = optimizeWaypoints ? 'optimize:true|' : '';
      buffer.write('&waypoints=$optimize$waypointsStr');
    }

    buffer.write('&alternatives=true');
    buffer.write('&language=pt-BR');
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

      final route = _pickShortestRoute(routes);
      final overviewPolyline = route['overview_polyline']['points'] as String;
      var points = PolylinePoints()
          .decodePolyline(overviewPolyline)
          .map((PointLatLng p) => LatLng(p.latitude, p.longitude))
          .toList();

      final legsJson = route['legs'] as List<dynamic>? ?? [];
      num totalDistanceMeters = 0;
      num totalDurationSeconds = 0;
      final routeSteps = <RouteStepInfo>[];
      // Polyline detalhada (por passo), mais fiel às ruas que a overview.
      final detailedPoints = <LatLng>[];
      final legs = legsJson.map((leg) {
        final stepsJson = leg['steps'] as List<dynamic>? ?? [];
        final steps = stepsJson
            .map((step) => _stripHtml(step['html_instructions'] as String? ?? ''))
            .where((text) => text.isNotEmpty)
            .toList();
        for (final rawStep in stepsJson) {
          final step = rawStep as Map<String, dynamic>;
          final stepPolyline = step['polyline']?['points'] as String?;
          if (stepPolyline != null && stepPolyline.isNotEmpty) {
            final decoded = PolylinePoints()
                .decodePolyline(stepPolyline)
                .map((PointLatLng p) => LatLng(p.latitude, p.longitude));
            for (final point in decoded) {
              if (detailedPoints.isEmpty || detailedPoints.last != point) {
                detailedPoints.add(point);
              }
            }
          }
          final instruction = _stripHtml(step['html_instructions'] as String? ?? '');
          if (instruction.isEmpty) continue;
          final endLocation = step['end_location'] as Map<String, dynamic>?;
          final endLat = _parseDouble(endLocation?['lat']);
          final endLng = _parseDouble(endLocation?['lng']);
          if (endLat == null || endLng == null) continue;
          final distanceMeters =
              _parseInt(step['distance']?['value']);
          routeSteps.add(RouteStepInfo(
            endLocation: LatLng(endLat, endLng),
            instruction: instruction,
            distanceMeters: distanceMeters,
            maneuver: step['maneuver'] as String?,
          ));
        }
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
      var isTrafficAware = false;
      if (totalDistanceMeters > 0) {
        totalDistanceText = _formatDistance(totalDistanceMeters);
      }
      if (totalDurationSeconds > 0) {
        totalDurationText = _formatDurationSeconds(totalDurationSeconds);
      }

      final waypointOrder = (route['waypoint_order'] as List<dynamic>?)
              ?.map((index) => index as int)
              .toList() ??
          List.generate(waypoints.length, (i) => i);
      final orderedWaypoints = _applyWaypointOrder(waypoints, waypointOrder);

      final trafficMetrics = await _routesService.computeMetrics(
        origin: origin,
        destination: destination,
        waypoints: orderedWaypoints,
      );
      if (trafficMetrics != null) {
        final trafficDistance = trafficMetrics.distanceMeters;
        final trafficDuration = trafficMetrics.durationSeconds;
        if (trafficDistance != null) {
          totalDistanceText = _formatDistance(trafficDistance);
        }
        if (trafficDuration != null) {
          totalDurationText = _formatDurationSeconds(trafficDuration);
        }
        isTrafficAware = true;
      }

      if (detailedPoints.length >= 2) {
        points = detailedPoints;
      } else {
        final snappedPoints = await _roadsService.snapToRoads(points);
        if (snappedPoints != null && snappedPoints.isNotEmpty) {
          points = snappedPoints;
        }
      }

      return DirectionsInfo(
        polylinePoints: points,
        totalDistance: totalDistanceText,
        totalDuration: totalDurationText,
        legs: legs,
        steps: routeSteps,
        waypointOrder: waypointOrder,
        isTrafficAware: isTrafficAware,
      );
    } catch (e) {
      debugPrint("Error getting directions: $e");
      return null;
    }
  }

  String _stripHtml(String htmlText) {
    return htmlText.replaceAll(RegExp(r'<[^>]*>'), '');
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

  Map<String, dynamic> _pickShortestRoute(List<dynamic> routes) {
    Map<String, dynamic> selected = routes.first as Map<String, dynamic>;
    var bestDistance = _routeDistanceMeters(selected);
    var bestDuration = _routeDurationSeconds(selected);

    for (final item in routes.skip(1)) {
      final route = item as Map<String, dynamic>;
      final distance = _routeDistanceMeters(route);
      final duration = _routeDurationSeconds(route);

      if (distance == null) continue;
      if (bestDistance == null || distance < bestDistance) {
        selected = route;
        bestDistance = distance;
        bestDuration = duration;
        continue;
      }
      if (distance == bestDistance &&
          duration != null &&
          (bestDuration == null || duration < bestDuration)) {
        selected = route;
        bestDuration = duration;
      }
    }

    return selected;
  }

  int? _routeDistanceMeters(Map<String, dynamic> route) {
    final legs = route['legs'] as List<dynamic>?;
    if (legs == null || legs.isEmpty) return null;
    var total = 0;
    for (final leg in legs) {
      total += (leg['distance']?['value'] as num?)?.round() ?? 0;
    }
    return total > 0 ? total : null;
  }

  int? _routeDurationSeconds(Map<String, dynamic> route) {
    final legs = route['legs'] as List<dynamic>?;
    if (legs == null || legs.isEmpty) return null;
    var total = 0;
    for (final leg in legs) {
      total += (leg['duration']?['value'] as num?)?.round() ?? 0;
    }
    return total > 0 ? total : null;
  }

  List<LatLng> _applyWaypointOrder(
    List<LatLng> waypoints,
    List<int>? waypointOrder,
  ) {
    if (waypointOrder == null || waypointOrder.length != waypoints.length) {
      return waypoints;
    }

    final ordered = <LatLng>[];
    for (final index in waypointOrder) {
      if (index < 0 || index >= waypoints.length) {
        return waypoints;
      }
      ordered.add(waypoints[index]);
    }
    return ordered;
  }

  String? _formatDistance(num meters) {
    if (meters <= 0) return null;
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  String? _formatDurationSeconds(num seconds) {
    if (seconds <= 0) return null;
    final duration = Duration(seconds: seconds.round());
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '$hours h $minutes m';
    }
    return '$minutes min';
  }
}
