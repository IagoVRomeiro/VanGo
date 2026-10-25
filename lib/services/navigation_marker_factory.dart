import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Gera o ícone de seta do motorista usado no modo navegação.
class NavigationMarkerFactory {
  static const double _logicalSize = 56;
  static const double _renderScale = 3;

  static Future<BitmapDescriptor> driverArrow({
    Color fill = const Color(0xFFB5FF2A),
    Color outline = const Color(0xFF101010),
  }) async {
    const size = _logicalSize * _renderScale;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(size / 2, size / 2);

    canvas.drawCircle(
      center.translate(0, size * 0.02),
      size * 0.46,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, size * 0.04),
    );
    canvas.drawCircle(center, size * 0.44, Paint()..color = Colors.white);
    canvas.drawCircle(center, size * 0.40, Paint()..color = outline);

    final arrow = Path()
      ..moveTo(size * 0.50, size * 0.18)
      ..lineTo(size * 0.76, size * 0.78)
      ..lineTo(size * 0.50, size * 0.64)
      ..lineTo(size * 0.24, size * 0.78)
      ..close();
    canvas.drawPath(arrow, Paint()..color = fill);

    final image =
        await recorder.endRecording().toImage(size.round(), size.round());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BytesMapBitmap(
      bytes!.buffer.asUint8List(),
      width: _logicalSize,
      height: _logicalSize,
    );
  }
}
