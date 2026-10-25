import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

import 'text_overlay_service.dart';
import 'crop_service.dart';

class FFmpegService {
  /// Extracts 2 keyframes for Gemini AI analysis
  static Future<List<String>> extractKeyframes(String videoPath) async {
    final tempDir = await getTemporaryDirectory();
    final f1 = '${tempDir.path}/kframe_1_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final f2 = '${tempDir.path}/kframe_2_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final cmd1 = '-y -ss 0.5 -i "$videoPath" -vframes 1 -q:v 2 "$f1"';
    final cmd2 = '-y -ss 2.0 -i "$videoPath" -vframes 1 -q:v 2 "$f2"';

    await FFmpegKit.execute(cmd1);
    await FFmpegKit.execute(cmd2);

    final results = <String>[];
    if (await File(f1).exists()) results.add(f1);
    if (await File(f2).exists()) results.add(f2);
    return results;
  }

  /// Copies asset template to local file if not exists
  static Future<String> getBundledTemplatePath(String lang) async {
    final docDir = await getApplicationDocumentsDirectory();
    final assetPath = lang == 'ja'
        ? 'assets/templates/template_ja.png'
        : 'assets/templates/template.png';
    final fileName = lang == 'ja' ? 'template_ja.png' : 'template.png';
    final targetFile = File('${docDir.path}/$fileName');

    if (!await targetFile.exists()) {
      final byteData = await rootBundle.load(assetPath);
      await targetFile.writeAsBytes(byteData.buffer.asUint8List());
    }
    return targetFile.path;
  }

  /// Renders complete Instagram 1080x1920 Reel matching the Windows VideoEngine 100%
  static Future<String?> renderReel({
    required String videoPath,
    required String titleText,
    required String lang,
    required String outputFilePath,
    String? customTemplatePath,
    Rect? cropBox,
    bool muteAudio = false,
    bool bypassCopyright = true,
    Function(double progress)? onProgress,
  }) async {
    final isJa = lang.toLowerCase() == 'ja';
    final rand = Random();

    // 1. Template path resolution
    String bgTemplate = customTemplatePath ?? await getBundledTemplatePath(lang);
    if (!await File(bgTemplate).exists()) {
      bgTemplate = await getBundledTemplatePath(lang);
    }

    // 2. Fetch video metadata if not provided
    final meta = await CropService.getVideoMetadata(videoPath);
    final origW = meta.width;
    final origH = meta.height;
    final duration = meta.duration;
    final hasAudio = meta.hasAudio;

    // 3. Generate high-precision 1080x1920 transparent text overlay (Matches Windows PIL)
    final overlayRes = await TextOverlayService.createTextOverlay(
      text: titleText,
      lang: lang,
    );
    final overlayPngPath = overlayRes['path'] as String;
    final titleBottomY = overlayRes['titleBottomY'] as int;

    // 4. Calculate Crop & Effective Dimensions
    String cropFilter = 'null';
    int effectiveW = origW;
    int effectiveH = origH;

    if (cropBox != null) {
      final cx = max(0, cropBox.left.toInt());
      final cy = max(0, cropBox.top.toInt());
      final cw = min(origW - cx, cropBox.width.toInt());
      final ch = min(origH - cy, cropBox.height.toInt());
      if (cw > 10 && ch > 10) {
        cropFilter = 'crop=$cw:$ch:$cx:$cy';
        effectiveW = cw;
        effectiveH = ch;
      }
    }

    // 5. Calculate Dynamic Video Placement & Fit (Matching Windows VideoEngine)
    // Guarantee 45px margin below title, minimum 660px
    final baseVy = 660;
    final vy = max(baseVy, titleBottomY + 45);
    const maxW = 900;
    final maxH = min(960, max(400, 1640 - vy));

    final aspect = effectiveW / max(1, effectiveH);
    int targetW, targetH;
    if (aspect > (maxW / maxH)) {
      targetW = maxW;
      targetH = (targetW / aspect).round();
    } else {
      targetH = maxH;
      targetW = (targetH * aspect).round();
    }

    // Even dimensions for H.264
    targetW = max(2, (targetW ~/ 2) * 2);
    targetH = max(2, (targetH ~/ 2) * 2);

    // Center horizontally on 1080 canvas
    final vx = (1080 - targetW) ~/ 2;

    // 6. Dual-Engine Modulation Parameters (KO vs JA)
    double speed;
    double pitch;
    double tempo;
    String noiseType;
    double noiseVol;
    double zoomRatio;
    String langTag;
    String crfVal;
    List<String> eqFilters = [];

    if (bypassCopyright) {
      if (isJa) {
        // 🇯🇵 Japanese Profile: Subtle Deceleration (0.970 ~ 0.988x) + Brown Noise + Off-center Zoom + Gamma/Unsharp
        speed = 0.970 + rand.nextDouble() * (0.988 - 0.970);
        pitch = 0.985 + rand.nextDouble() * (0.995 - 0.985);
        tempo = speed / pitch;
        noiseType = 'brown';
        noiseVol = 0.006 + rand.nextDouble() * (0.012 - 0.006);
        zoomRatio = 1.018 + rand.nextDouble() * (0.032 - 0.018);
        final gamma = 1.012 + rand.nextDouble() * (1.026 - 1.012);
        final contrast = 0.992 + rand.nextDouble() * (1.012 - 0.992);
        eqFilters = [
          'eq=contrast=${contrast.toStringAsFixed(3)}:gamma=${gamma.toStringAsFixed(3)}:saturation=0.995',
          'unsharp=3:3:0.35:3:3:0.0'
        ];
        langTag = 'jpn';
        crfVal = '22';
      } else {
        // 🇰🇷 Korean Profile: Subtle Acceleration (1.025 ~ 1.050x) + Pink Noise + Center Zoom + Contrast/Saturation
        speed = 1.025 + rand.nextDouble() * (1.050 - 1.025);
        pitch = 1.008 + rand.nextDouble() * (1.018 - 1.008);
        tempo = speed / pitch;
        noiseType = 'pink';
        noiseVol = 0.008 + rand.nextDouble() * (0.015 - 0.008);
        zoomRatio = 1.012 + rand.nextDouble() * (0.024 - 1.012);
        final contrast = 1.012 + rand.nextDouble() * (1.028 - 1.012);
        final sat = 1.015 + rand.nextDouble() * (1.035 - 1.015);
        eqFilters = [
          'eq=contrast=${contrast.toStringAsFixed(3)}:saturation=${sat.toStringAsFixed(3)}:brightness=0.008'
        ];
        langTag = 'kor';
        crfVal = '21';
      }
    } else {
      speed = 1.0;
      pitch = 1.0;
      tempo = 1.0;
      noiseType = 'pink';
      noiseVol = 0.0;
      zoomRatio = 1.0;
      langTag = isJa ? 'jpn' : 'kor';
      crfVal = '22';
    }

    // 7. Video Filter Chain
    final vFilters = <String>[];
    if (cropFilter != 'null') {
      vFilters.add(cropFilter);
    }

    if (bypassCopyright && zoomRatio > 1.0) {
      if (isJa) {
        vFilters.add('crop=iw/$zoomRatio:ih/$zoomRatio:(iw-ow)*0.46:(ih-oh)*0.54');
      } else {
        vFilters.add('crop=iw/$zoomRatio:ih/$zoomRatio');
      }
    }

    vFilters.add('scale=$targetW:$targetH:flags=lanczos,setsar=1');

    if (bypassCopyright && eqFilters.isNotEmpty) {
      vFilters.addAll(eqFilters);
    }

    if (bypassCopyright && speed != 1.0) {
      vFilters.add('setpts=PTS/$speed');
    }

    final videoFilterStr = vFilters.join(',');

    // 8. 3-Layer Filter Complex
    // Input 0: Background Template (1080x1920)
    // Input 1: Source Video
    // Input 2: Transparent PNG Title Overlay (1080x1920)
    final filterComplexParts = [
      '[1:v]$videoFilterStr[vid]',
      '[0:v][vid]overlay=x=$vx:y=$vy:shortest=1[comp]',
      '[comp][2:v]overlay=0:0:shortest=1[outv]'
    ];

    // 9. Audio Stream Detection & Filter
    final bool enableAudio = !muteAudio && hasAudio;
    final cmdAudioArgs = <String>[];

    if (enableAudio) {
      if (bypassCopyright) {
        final safeD = duration > 0 ? (duration / speed).toInt() + 15 : 90;
        String audioFilter;
        if (isJa) {
          audioFilter =
              'anoisesrc=d=$safeD:c=brown:r=44100:a=${noiseVol.toStringAsFixed(4)}[bg];'
              '[1:a]asetrate=44100*${pitch.toStringAsFixed(4)},aresample=44100,atempo=${tempo.toStringAsFixed(4)},highpass=f=55,lowpass=f=14800,bass=g=0.8:f=120[main];'
              '[main][bg]amix=inputs=2:duration=first:dropout_transition=0[outa]';
        } else {
          audioFilter =
              'anoisesrc=d=$safeD:c=pink:r=44100:a=${noiseVol.toStringAsFixed(4)}[bg];'
              '[1:a]asetrate=44100*${pitch.toStringAsFixed(4)},aresample=44100,atempo=${tempo.toStringAsFixed(4)},highpass=f=45,lowpass=f=15500[main];'
              '[main][bg]amix=inputs=2:duration=first:dropout_transition=0[outa]';
        }
        filterComplexParts.add(audioFilter);
        cmdAudioArgs.addAll(['-map', '[outa]', '-c:a', 'aac', '-b:a', '192k']);
      } else {
        cmdAudioArgs.addAll(['-map', '1:a', '-c:a', 'aac', '-b:a', '192k']);
      }
    } else {
      cmdAudioArgs.add('-an');
    }

    final cmdArgs = <String>[
      '-y',
      '-loop', '1', '-i', bgTemplate,
      '-i', videoPath,
      '-i', overlayPngPath,
      '-filter_complex', filterComplexParts.join(';'),
      '-map', '[outv]',
      ...cmdAudioArgs,
      '-map_metadata', '-1',
      '-metadata:s:v:0', 'language=$langTag',
      '-c:v', 'libx264',
      '-preset', 'veryfast',
      '-crf', crfVal,
      '-pix_fmt', 'yuv420p',
      outputFilePath,
    ];

    final cmd = cmdArgs.join(' ');
    final session = await FFmpegKit.execute(cmd);
    final returnCode = await session.getReturnCode();

    // Clean up temporary overlay PNG
    try {
      await File(overlayPngPath).delete();
    } catch (_) {}

    if (ReturnCode.isSuccess(returnCode)) {
      return outputFilePath;
    } else {
      final logs = await session.getAllLogsAsString();
      print('FFmpeg Error: $logs');
      return null;
    }
  }
}
