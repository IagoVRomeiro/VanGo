import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Posição do motorista projetada sobre a rota.
class RouteSnapshot {
  /// Índice do segmento (points[i] -> points[i + 1]) onde o motorista está.
  final int segmentIndex;

  /// Ponto mais próximo sobre a rota.
  final LatLng projected;

  /// Distância (m) entre a posição real e a rota.
  final double distanceFromRoute;

  /// Distância (m) já percorrida ao longo da rota.
  final double distanceAlongRoute;

  /// Direção (graus) do segmento atual.
  final double segmentBearing;

  const RouteSnapshot({
    required this.segmentIndex,
    required this.projected,
    required this.distanceFromRoute,
    required this.distanceAlongRoute,
    required this.segmentBearing,
  });
}

/// Acompanha o progresso do motorista ao longo de uma polyline,
/// no estilo dos apps de navegação (Waze/Google Maps).
class RouteProgressTracker {
  static const double _earthRadius = 6378137.0;
  static const int _searchBehind = 3;
  static const int _searchAhead = 80;
  static const double _fullSearchThresholdMeters = 50;

  final List<LatLng> points;
  final List<double> _cumulative;
  final List<double> _stepEndAlong;
  int _segmentIndex = 0;

  RouteProgressTracker._(this.points, this._cumulative, this._stepEndAlong);

  factory RouteProgressTracker(List<LatLng> points, List<LatLng> stepEnds) {
    final cumulative = <double>[0];
    for (var i = 1; i < points.length; i++) {
      cumulative
          .add(cumulative.last + distanceMeters(points[i - 1], points[i]));
    }

    // Cada fim de passo é associado ao vértice mais próximo, sempre
    // avançando, para que os passos fiquem em ordem ao longo da rota.
    final stepEndAlong = <double>[];
    var searchFrom = 0;
    for (final end in stepEnds) {
      var bestIndex = searchFrom;
      var bestDistance = double.infinity;
      for (var i = searchFrom; i < points.length; i++) {
        final d = distanceMeters(points[i], end);
        if (d < bestDistance) {
          bestDistance = d;
          bestIndex = i;
        }
      }
      stepEndAlong.add(points.isEmpty ? 0 : cumulative[bestIndex]);
      searchFrom = bestIndex;
    }

    return RouteProgressTracker._(points, cumulative, stepEndAlong);
  }

  double get totalLength => _cumulative.isEmpty ? 0 : _cumulative.last;

  RouteSnapshot? update(LatLng position) {
    if (points.length < 2) return null;

    final lastSegment = points.length - 2;
    var best = _closestInRange(
      position,
      math.max(0, _segmentIndex - _searchBehind),
      math.min(lastSegment, _segmentIndex + _searchAhead),
    );
    if (best.distanceFromRoute > _fullSearchThresholdMeters) {
      final full = _closestInRange(position, 0, lastSegment);
      if (full.distanceFromRoute < best.distanceFromRoute) best = full;
    }
    _segmentIndex = best.segmentIndex;
    return best;
  }

  /// Índice do passo em andamento para a distância percorrida informada.
  int stepIndexFor(double distanceAlong) {
    for (var i = 0; i < _stepEndAlong.length; i++) {
      if (_stepEndAlong[i] > distanceAlong) return i;
    }
    return _stepEndAlong.length;
  }

  /// Distância (m) até o fim do passo [stepIndex].
  double distanceToStepEnd(int stepIndex, double distanceAlong) {
    if (stepIndex >= _stepEndAlong.length) return 0;
    return math.max(0, _stepEndAlong[stepIndex] - distanceAlong);
  }

  /// Trecho da rota que ainda falta percorrer.
  List<LatLng> remainingPoints(RouteSnapshot snapshot) {
    return [snapshot.projected, ...points.skip(snapshot.segmentIndex + 1)];
  }

  RouteSnapshot _closestInRange(LatLng position, int from, int to) {
    RouteSnapshot? best;
    for (var i = from; i <= to; i++) {
      final a = points[i];
      final b = points[i + 1];
      final projection = _project(position, a, b);
      if (best == null || projection.distance < best.distanceFromRoute) {
        best = RouteSnapshot(
          segmentIndex: i,
          projected: projection.point,
          distanceFromRoute: projection.distance,
          distanceAlongRoute: _cumulative[i] +
              (_cumulative[i + 1] - _cumulative[i]) * projection.t,
          segmentBearing: bearingDegrees(a, b),
        );
      }
    }
    return best!;
  }

  /// Projeta [p] no segmento [a]-[b] usando uma aproximação plana local.
  static ({LatLng point, double distance, double t}) _project(
      LatLng p, LatLng a, LatLng b) {
    final cosLat = math.cos(a.latitude * math.pi / 180);
    double x(LatLng v) =>
        (v.longitude - a.longitude) * math.pi / 180 * cosLat * _earthRadius;
    double y(LatLng v) =>
        (v.latitude - a.latitude) * math.pi / 180 * _earthRadius;

    final bx = x(b), by = y(b), px = x(p), py = y(p);
    final lengthSquared = bx * bx + by * by;
    final t = lengthSquared == 0
        ? 0.0
        : ((px * bx + py * by) / lengthSquared).clamp(0.0, 1.0);
    final point = LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
    final dx = px - bx * t, dy = py - by * t;
    return (point: point, distance: math.sqrt(dx * dx + dy * dy), t: t);
  }

  static double distanceMeters(LatLng a, LatLng b) {
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLat = lat2 - lat1;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * _earthRadius * math.asin(math.min(1, math.sqrt(h)));
  }

  static double bearingDegrees(LatLng start, LatLng end) {
    final lat1 = start.latitude * math.pi / 180;
    final lat2 = end.latitude * math.pi / 180;
    final dLon = (end.longitude - start.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }
}
