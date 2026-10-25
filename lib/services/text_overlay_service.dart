import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class TextOverlayService {
  static const int canvasWidth = 1080;
  static const int canvasHeight = 1920;
  static const double leftMargin = 120.0;
  static const double titleY = 450.0;
  static const double titleMaxWidth = 840.0;
  static const double titleFontSize = 64.0;
  static const double titleLineSpacing = 18.0;

  /// Generates a transparent 1080x1920 PNG overlay identical to Windows PIL text overlay.
  /// Preserves exact user line breaks, 64px font size, and calculates dynamic bottom Y.
  static Future<Map<String, dynamic>> createTextOverlay({
    required String text,
    required String lang,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final overlayPath = '${tempDir.path}/overlay_${DateTime.now().millisecondsSinceEpoch}.png';

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 1080, 1920));

    // Handle user line breaks & whitespace
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      final picture = recorder.endRecording();
      final img = await picture.toImage(canvasWidth, canvasHeight);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final file = File(overlayPath);
      await file.writeAsBytes(byteData!.buffer.asUint8List());
      return {
        'path': overlayPath,
        'titleBottomY': titleY.toInt(),
      };
    }

    final rawLines = trimmed.split('\n');
    final lines = <String>[];
    for (final raw in rawLines) {
      final line = raw.trim();
      if (line.isNotEmpty) {
        lines.add(line);
      }
    }

    final textSpan = TextSpan(
      text: lines.join('\n'),
      style: const TextStyle(
        fontFamily: 'MalgunGothic',
        fontSize: titleFontSize,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        height: 1.28, // Matches titleLineSpacing
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: 4,
    );

    textPainter.layout(maxWidth: titleMaxWidth);
    textPainter.paint(canvas, const Offset(leftMargin, titleY));

    final titleBottomY = (titleY + textPainter.height).toInt() + 10;

    final picture = recorder.endRecording();
    final img = await picture.toImage(canvasWidth, canvasHeight);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final file = File(overlayPath);
    await file.writeAsBytes(byteData!.buffer.asUint8List());

    return {
      'path': overlayPath,
      'titleBottomY': titleBottomY,
    };
  }
}
