import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:vango/services/route_progress.dart';

void main() {
  // Rota em "L": ~1,1 km para o norte e depois ~1 km para o leste.
  const route = [
    LatLng(-19.9300, -43.9400),
    LatLng(-19.9250, -43.9400),
    LatLng(-19.9200, -43.9400),
    LatLng(-19.9200, -43.9350),
    LatLng(-19.9200, -43.9300),
  ];
  const stepEnds = [LatLng(-19.9200, -43.9400), LatLng(-19.9200, -43.9300)];

  test('projeta a posição na rota e calcula o progresso', () {
    final tracker = RouteProgressTracker(route, stepEnds);
    final snapshot = tracker.update(const LatLng(-19.9250, -43.9399))!;

    expect(snapshot.segmentIndex, anyOf(0, 1));
    expect(snapshot.distanceFromRoute, closeTo(10.5, 1));
    expect(snapshot.distanceAlongRoute, closeTo(556, 5));
    expect(snapshot.segmentBearing, closeTo(0, 1));
  });

  test('avança de passo depois da curva', () {
    final tracker = RouteProgressTracker(route, stepEnds);

    var snapshot = tracker.update(const LatLng(-19.9220, -43.9400))!;
    expect(tracker.stepIndexFor(snapshot.distanceAlongRoute), 0);
    expect(
      tracker.distanceToStepEnd(0, snapshot.distanceAlongRoute),
      closeTo(222, 5),
    );

    snapshot = tracker.update(const LatLng(-19.9200, -43.9370))!;
    expect(tracker.stepIndexFor(snapshot.distanceAlongRoute), 1);
    expect(snapshot.segmentBearing, closeTo(90, 1));
  });

  test('detecta quando o motorista sai da rota', () {
    final tracker = RouteProgressTracker(route, stepEnds);
    final snapshot = tracker.update(const LatLng(-19.9250, -43.9450))!;
    expect(snapshot.distanceFromRoute, greaterThan(400));
  });

  test('trecho restante começa na posição projetada', () {
    final tracker = RouteProgressTracker(route, stepEnds);
    final snapshot = tracker.update(const LatLng(-19.9200, -43.9340))!;
    final remaining = tracker.remainingPoints(snapshot);
    expect(remaining.first, snapshot.projected);
    expect(remaining.last, route.last);
    expect(remaining.length, 2);
  });
}
