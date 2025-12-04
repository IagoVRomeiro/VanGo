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

class DirectionsInfo {
  final List<LatLng> polylinePoints;
  final String? totalDistance;
  final String? totalDuration;
  final List<RouteLegInfo> legs;
  final List<int>? waypointOrder;

  DirectionsInfo({
    required this.polylinePoints,
    this.totalDistance,
    this.totalDuration,
    required this.legs,
    this.waypointOrder,
  });
}
