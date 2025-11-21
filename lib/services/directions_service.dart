import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
    
    String waypointsStr = waypoints
        .map((p) => '${p.latitude},${p.longitude}')
        .join('|');
    
    if (waypoints.isNotEmpty) {
      waypointsStr = 'optimize:true|$waypointsStr';
    }

    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=$originStr&destination=$destStr&waypoints=$waypointsStr&key=$apiKey');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        if (jsonResponse['routes'] != null && jsonResponse['routes'].isNotEmpty) {
          final route = jsonResponse['routes'][0];
          final leg = route['legs'][0]; // Assuming one leg for simplicity
          
          final overviewPolyline = route['overview_polyline']['points'];
          final points = PolylinePoints().decodePolyline(overviewPolyline).map((PointLatLng p) => LatLng(p.latitude, p.longitude)).toList();
          
          return DirectionsInfo(
            polylinePoints: points,
            totalDistance: leg['distance']['text'],
            totalDuration: leg['duration']['text'],
          );
        } else {
          print("Directions API Error: ${jsonResponse['error_message']}");
          return null;
        }
      } else {
        print("HTTP Error: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error getting directions: $e");
      return null;
    }
  }
}
