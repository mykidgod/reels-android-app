import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';

class AIService {
  static Future<Map<String, String>> generateTitleAndCaption({
    required String apiKey,
    required String prompt,
    required String lang,
    required String videoTitleContext,
    List<String> keyframePaths = const [],
  }) async {
    if (apiKey.trim().isEmpty) {
      throw Exception('Gemini API 키가 설정되지 않았습니다. 환경설정에서 API 키를 입력해주세요.');
    }

    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey.trim(),
    );

    final contentParts = <Part>[];

    // Add keyframe images if available
    for (final kPath in keyframePaths) {
      final f = File(kPath);
      if (await f.exists()) {
        final bytes = await f.readAsBytes();
        contentParts.add(DataPart('image/jpeg', bytes));
      }
    }

    // Add prompt text
    final fullTextPrompt = """$prompt

[분석할 원본 영상 힌트 / 파일명 / 자막 텍스트]
$videoTitleContext
""";
    contentParts.add(TextPart(fullTextPrompt));

    final response = await model.generateContent([
      Content.multi(contentParts),
    ]);

    final raw = response.text ?? '';
    return parseAIResponse(raw);
  }

  static Map<String, String> parseAIResponse(String raw) {
    String title = '';
    String caption = '';

    final lines = raw.split('\n');
    bool inTitle = false;
    bool inBody = false;
    final bodyLines = <String>[];

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.contains('[타이틀]') || trimmed.contains('[タイトル]') || trimmed.contains('[TITLE]')) {
        inTitle = true;
        inBody = false;
        continue;
      }
      if (trimmed.contains('[본문]') || trimmed.contains('[本文]') || trimmed.contains('[CAPTION]')) {
        inTitle = false;
        inBody = true;
        continue;
      }

      if (inTitle) {
        if (trimmed.isNotEmpty && title.isEmpty) {
          title = trimmed.replaceAll('"', '').replaceAll("'", '');
        }
      } else if (inBody) {
        bodyLines.add(line);
      }
    }

    caption = bodyLines.join('\n').trim();

    // Fallback if formatting was slightly missed
    if (title.isEmpty) {
      final firstLine = lines.firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
      title = firstLine.replaceAll('"', '').replaceAll("'", '');
    }
    if (caption.isEmpty && bodyLines.isEmpty) {
      caption = raw;
    }

    return {
      'title': title,
      'caption': caption,
    };
  }
}
