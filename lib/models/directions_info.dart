import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Modelo para guardar as informações da rota
class DirectionsInfo {
  final List<LatLng> polylinePoints;
  final String? totalDistance;
  final String? totalDuration;

  DirectionsInfo({
    required this.polylinePoints,
    this.totalDistance,
    this.totalDuration,
  });
}

// O resto do seu arquivo directions_service.dart
// (incluindo a classe DirectionsService e seu método getDirections)
// ...
