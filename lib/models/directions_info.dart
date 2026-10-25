import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteLegInfo {
  final String? distance;
  final String? duration;
  final String? startAddress;
  final String? endAddress;
  final List<String>? instructions;

  RouteLegInfo({
    this.distance,
    this.duration,
    this.startAddress,
    this.endAddress,
    this.instructions,
  });
}

class RouteStepInfo {
  final LatLng endLocation;
  final String instruction;
  final int? distanceMeters;
  final String? maneuver;

  RouteStepInfo({
    required this.endLocation,
    required this.instruction,
    this.distanceMeters,
    this.maneuver,
  });
}

class DirectionsInfo {
  final List<LatLng> polylinePoints;
  final String? totalDistance;
  final String? totalDuration;
  final List<RouteLegInfo> legs;
  final List<RouteStepInfo> steps;
  final List<int>? waypointOrder;
  final bool isTrafficAware;

  DirectionsInfo({
    required this.polylinePoints,
    this.totalDistance,
    this.totalDuration,
    required this.legs,
    required this.steps,
    this.waypointOrder,
    this.isTrafficAware = false,
  });
}
