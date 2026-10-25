import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:path_provider/path_provider.dart';

class FFmpegService {
  /// Extracts 2 keyframes for Gemini AI analysis
  static Future<List<String>> extractKeyframes(String videoPath) async {
    final tempDir = await getTemporaryDirectory();
    final f1 = '${tempDir.path}/kframe_1_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final f2 = '${tempDir.path}/kframe_2_${DateTime.now().millisecondsSinceEpoch}.jpg';

    // 0.5s & 2.0s frame capture
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

  /// Extracts bundled font to local file
  static Future<String> getBundledFontPath() async {
    final docDir = await getApplicationDocumentsDirectory();
    final fontFile = File('${docDir.path}/title_font.ttf');
    if (!await fontFile.exists()) {
      try {
        final byteData = await rootBundle.load('assets/fonts/KoPubWorldDotumBold.ttf');
        await fontFile.writeAsBytes(byteData.buffer.asUint8List());
      } catch (_) {
        // Fallback default system font path
        return '/system/fonts/NotoSansCJK-Regular.ttc';
      }
    }
    return fontFile.path;
  }

  /// Formats title text with max 3 words per line
  static String formatTitleLines(String title) {
    final words = title.trim().split(RegExp(r'\s+'));
    if (words.length <= 3) return title.trim();

    final lines = <String>[];
    for (int i = 0; i < words.length; i += 3) {
      final chunk = words.sublist(i, min(i + 3, words.length));
      lines.add(chunk.join(' '));
    }
    return lines.join('\n');
  }

  /// Renders complete Instagram 1080x1920 Reel with Dual-Engine Modulation
  static Future<String?> renderReel({
    required String videoPath,
    required String titleText,
    required String lang,
    required String outputFilePath,
    String? customTemplatePath,
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

    // 2. Dual-Engine Modulation Parameters (KO vs JA)
    double speed;
    double pitch;
    double tempo;
    String noiseType;
    double noiseVol;
    double zoomRatio;
    String eqFilter;
    String langTag;
    String crfVal;

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
        eqFilter = 'eq=contrast=${contrast.toStringAsFixed(3)}:gamma=${gamma.toStringAsFixed(3)}:saturation=0.995,unsharp=3:3:0.35:3:3:0.0';
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
        eqFilter = 'eq=contrast=${contrast.toStringAsFixed(3)}:saturation=${sat.toStringAsFixed(3)}:brightness=0.008';
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
      eqFilter = 'null';
      langTag = isJa ? 'jpn' : 'kor';
      crfVal = '22';
    }

    // 3. Construct Video Filter Chain
    final vFilters = <String>[];

    // Crop / Micro-zoom
    if (bypassCopyright && zoomRatio > 1.0) {
      if (isJa) {
        // Asymmetric off-center crop
        vFilters.add('crop=iw/$zoomRatio:ih/$zoomRatio:(iw-ow)*0.46:(ih-oh)*0.54');
      } else {
        // Centered crop
        vFilters.add('crop=iw/$zoomRatio:ih/$zoomRatio');
      }
    }

    // Dynamic Scale to Reels Width (Max 900x960 inside 1080x1920)
    vFilters.add('scale=900:960:force_original_aspect_ratio=decrease:flags=lanczos,setsar=1');

    // Visual Modulation (Color/Clarity)
    if (bypassCopyright && eqFilter != 'null') {
      vFilters.add(eqFilter);
    }

    // PTS Speed
    if (bypassCopyright && speed != 1.0) {
      vFilters.add('setpts=PTS/$speed');
    }

    final videoFilterStr = vFilters.join(',');

    // 4. Font & Typography Overlay
    final fontPath = await getBundledFontPath();
    final formattedTitle = formatTitleLines(titleText).replaceAll("'", "\\'").replaceAll(':', '\\:');

    // 5. Complete Filter Complex
    final filterComplex = [
      '[1:v]$videoFilterStr[vid]',
      '[0:v][vid]overlay=x=(W-w)/2:y=660:shortest=1[comp]',
      '[comp]drawtext=fontfile=\'$fontPath\':text=\'$formattedTitle\':fontsize=52:fontcolor=white:x=90:y=380:line_spacing=18[outv]'
    ].join(';');

    // 6. Audio Filter Chain
    final audioFilter = bypassCopyright && !muteAudio
        ? ';anoisesrc=d=90:c=$noiseType:r=44100:a=${noiseVol.toStringAsFixed(4)}[bg];[1:a]asetrate=44100*${pitch.toStringAsFixed(4)},aresample=44100,atempo=${tempo.toStringAsFixed(4)},highpass=f=45,lowpass=f=15000[main];[main][bg]amix=inputs=2:duration=first[outa]'
        : '';

    final cmdArgs = <String>[
      '-y',
      '-loop', '1', '-i', bgTemplate,
      '-i', videoPath,
      '-filter_complex', filterComplex + audioFilter,
      '-map', '[outv]',
    ];

    if (!muteAudio) {
      if (bypassCopyright) {
        cmdArgs.addAll(['-map', '[outa]', '-c:a', 'aac', '-b:a', '192k']);
      } else {
        cmdArgs.addAll(['-map', '1:a', '-c:a', 'aac', '-b:a', '192k']);
      }
    } else {
      cmdArgs.add('-an');
    }

    // Strip metadata and set language tag
    cmdArgs.addAll([
      '-map_metadata', '-1',
      '-metadata:s:v:0', 'language=$langTag',
      '-c:v', 'libx264',
      '-preset', 'veryfast',
      '-crf', crfVal,
      '-pix_fmt', 'yuv420p',
      outputFilePath,
    ]);

    final cmd = cmdArgs.join(' ');
    final session = await FFmpegKit.execute(cmd);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      return outputFilePath;
    } else {
      final logs = await session.getAllLogsAsString();
      print('FFmpeg Error: $logs');
      return null;
    }
  }
}
