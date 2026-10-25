import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

class VideoMetadata {
  final int width;
  final int height;
  final double duration;
  final bool hasAudio;

  VideoMetadata({
    required this.width,
    required this.height,
    required this.duration,
    required this.hasAudio,
  });
}

class CropService {
  /// Extracts width, height, duration, and audio stream info
  static Future<VideoMetadata> getVideoMetadata(String videoPath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(videoPath);
      final info = await session.getMediaInformation();

      if (info != null) {
        int width = 1080;
        int height = 1920;
        bool hasAudio = false;

        final streams = info.getStreams();
        for (final stream in streams) {
          if (stream.getType() == 'video') {
            final w = stream.getWidth();
            final h = stream.getHeight();
            if (w != null && h != null && w > 0 && h > 0) {
              width = w;
              height = h;
            }
          } else if (stream.getType() == 'audio') {
            hasAudio = true;
          }
        }

        double duration = 0.0;
        final durStr = info.getDuration();
        if (durStr != null) {
          duration = double.tryParse(durStr) ?? 0.0;
        }

        return VideoMetadata(
          width: width,
          height: height,
          duration: duration,
          hasAudio: hasAudio,
        );
      }
    } catch (e) {
      print('FFprobe error: $e');
    }

    // Default fallback
    return VideoMetadata(
      width: 1080,
      height: 1920,
      duration: 5.0,
      hasAudio: true,
    );
  }

  /// Automatically detects foreign meme text cards, black bars, and white headers
  /// and returns the clean active video bounding box.
  static Future<Rect?> autoDetectCrop(String videoPath, int origW, int origH) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final samplePath = '${tempDir.path}/crop_sample_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Capture 1.0s frame
      await FFmpegKit.execute('-y -ss 1.0 -i "$videoPath" -vframes 1 -q:v 3 "$samplePath"');
      final file = File(samplePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      final w = decoded.width;
      final h = decoded.height;

      // Scan rows from top to bottom
      int topBound = 0;
      int bottomBound = h - 1;

      // Scan top downward
      for (int y = 0; y < (h * 0.40).toInt(); y++) {
        double rowLuminance = 0;
        int darkCount = 0;
        int whiteCount = 0;

        for (int x = 0; x < w; x += 4) {
          final pixel = decoded.getPixel(x, y);
          final r = pixel.r.toDouble();
          final g = pixel.g.toDouble();
          final b = pixel.b.toDouble();
          final lum = 0.299 * r + 0.587 * g + 0.114 * b;
          rowLuminance += lum;
          if (lum < 28) darkCount++;
          if (lum > 225) whiteCount++;
        }

        final samples = w ~/ 4;
        final avgLum = rowLuminance / samples;
        final darkPct = darkCount / samples;
        final whitePct = whiteCount / samples;

        // Black bar or White meme card banner
        if (darkPct > 0.85 || whitePct > 0.70 || avgLum > 235 || avgLum < 20) {
          topBound = y + 1;
        } else {
          // Content encountered
          if (y > 10) break;
        }
      }

      // Scan bottom upward
      for (int y = h - 1; y > (h * 0.60).toInt(); y--) {
        double rowLuminance = 0;
        int darkCount = 0;
        int whiteCount = 0;

        for (int x = 0; x < w; x += 4) {
          final pixel = decoded.getPixel(x, y);
          final r = pixel.r.toDouble();
          final g = pixel.g.toDouble();
          final b = pixel.b.toDouble();
          final lum = 0.299 * r + 0.587 * g + 0.114 * b;
          rowLuminance += lum;
          if (lum < 28) darkCount++;
          if (lum > 225) whiteCount++;
        }

        final samples = w ~/ 4;
        final avgLum = rowLuminance / samples;
        final darkPct = darkCount / samples;
        final whitePct = whiteCount / samples;

        if (darkPct > 0.85 || whitePct > 0.70 || avgLum > 235 || avgLum < 20) {
          bottomBound = y - 1;
        } else {
          if (h - 1 - y > 10) break;
        }
      }

      // Cleanup sample
      try {
        await file.delete();
      } catch (_) {}

      final cropH = bottomBound - topBound + 1;
      // If detected crop differs meaningfully (> 4% of height)
      if (topBound > (h * 0.03) || (h - 1 - bottomBound) > (h * 0.03)) {
        if (cropH >= (h * 0.35)) {
          // Scale to original video dimensions if sample was scaled
          final scaleX = origW / w;
          final scaleY = origH / h;
          return Rect.fromLTWH(
            0,
            topBound * scaleY,
            origW.toDouble(),
            cropH * scaleY,
          );
        }
      }
    } catch (e) {
      print('Auto crop detection error: $e');
    }
    return null;
  }
}
