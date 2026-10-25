import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String keyGeminiApiKey = 'gemini_api_key';
  static const String keyPromptKo = 'custom_prompt_ko';
  static const String keyPromptJa = 'custom_prompt_ja';
  static const String keyTemplateKo = 'custom_template_path_ko';
  static const String keyTemplateJa = 'custom_template_path_ja';
  static const String keyMuteAudio = 'mute_audio';
  static const String keyBypassCopyright = 'bypass_copyright';

  static const String defaultPromptKo = """당신은 100만 팔로워를 보유한 과학, 기술, 자연의 원리, 미스터리 전문 인스타그램 지식·교양 매거진의 총괄 편집장입니다.
첨부된 이미지는 해외 영상의 타임라인에서 시간순으로 추출된 결정적 키프레임들입니다.
제공된 원본 영문 캡션이나 자막 텍스트가 있다면 이를 가장 중요한 단서로 분석하세요.
절대로 영어를 그대로 직역하지 말고, 사실과 배경 맥락만을 추출하여 한국 팔로워들이 한눈에 빠져드는 '세련된 잡지 기사'로 완전히 새롭게 재작성(리라이팅)하세요.

[1. 제목 작성 원칙 - 14~18자 내외의 바이럴 킬러 훅]
- 14~18자 내외의 호기심 유발 한 줄 제목 (영상 상단 배치용)
- 반전과 호기심을 유도하되 결론을 미리 스포일러하지 마세요.
- 명사형 종결어미(~이유, ~순간, ~비밀, ~기술, ~원리 등) 권장.

[2. 본문 작성 원칙 - 5단계 매거진 아티클 구조]
1. 첫 줄: 도입 훅 이모지 2개 + 호기심/공감 질문형 한 문장
2. 1번째 문단: 현상 및 배경 설명 (3~5문장)
3. 2번째 문단: 핵심 원리 및 심층 해설 (3~5문장)
4. 마무리 한 줄: 인사이트 한 문장 요약
5. 마지막 줄: 핵심 한국어 해시태그 5~8개

[출력 규칙]
[타이틀]
추천된 영상 제목 한 줄 (14~18자 내외)

[본문]
매거진 형태의 피드 본문 전체 (해시태그 포함)""";

  static const String defaultPromptJa = """あなたは科学、技術、自然の原理、世界の最新トレンドを深掘りする日本のインスタグラム知識・教養マガジン編集長です。
添付された画像は、海外動画のタイムラインから時系列で抽出された決定的なキーフレームです。
元の英語キャプションや字幕テキストがある場合は、それを最重要の手がかりとして活用してください。
絶対に英語を機械翻訳（直訳）しないでください。事実と背景の文脈のみを抽出し、日本のフォロワーが一瞬で引き込まれる「洗練されたマガジン記事」としてリライトします。

【タイトル作成ルール - 14〜18文字のバイラル・キラーフック】
- 14文字〜18文字前後（動画上部に美しく収まる長さ）
- 1行完結の名詞止め（〜理由、〜ワケ、〜秘密、〜瞬間、〜技術、〜原理 など）
- 結論をあらかじめ明かさず強い好奇心を残すこと。

【本文作成ルール - 5段階マガジン記事構成】
1. 最初の1行: 絵文字2個 ＋ 疑問形の1文
2. 第1段落: 状況描写と背景知識の自然な解説
3. 第2段落: 隠された科学的・技術的原理や真の狙い
4. 結びの1行: 深く印象的な1行のまとめ
5. 最後の行: 厳選された日本語ハッシュタグ5〜8個

【出力ルール】
[タイトル]
推奨タイトル1行 (14〜18文字前後)

[本文]
マガジン形式のフィード本文全体 (ハッシュタグ含む)""";

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String get geminiApiKey => _prefs.getString(keyGeminiApiKey) ?? '';
  set geminiApiKey(String val) => _prefs.setString(keyGeminiApiKey, val);

  String get promptKo => _prefs.getString(keyPromptKo) ?? defaultPromptKo;
  set promptKo(String val) => _prefs.setString(keyPromptKo, val);

  String get promptJa => _prefs.getString(keyPromptJa) ?? defaultPromptJa;
  set promptJa(String val) => _prefs.setString(keyPromptJa, val);

  String? get templateKo => _prefs.getString(keyTemplateKo);
  set templateKo(String? val) => val == null ? _prefs.remove(keyTemplateKo) : _prefs.setString(keyTemplateKo, val);

  String? get templateJa => _prefs.getString(keyTemplateJa);
  set templateJa(String? val) => val == null ? _prefs.remove(keyTemplateJa) : _prefs.setString(keyTemplateJa, val);

  bool get muteAudio => _prefs.getBool(keyMuteAudio) ?? false;
  set muteAudio(bool val) => _prefs.setBool(keyMuteAudio, val);

  bool get bypassCopyright => _prefs.getBool(keyBypassCopyright) ?? true;
  set bypassCopyright(bool val) => _prefs.setBool(keyBypassCopyright, val);
}
