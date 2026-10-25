import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  final SettingsService settings;

  const SettingsScreen({super.key, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _apiKeyController;
  late TextEditingController _promptController;
  late bool _muteAudio;
  late bool _bypassCopyright;
  String _activePromptLang = 'ko';

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: widget.settings.geminiApiKey);
    _promptController = TextEditingController(text: widget.settings.promptKo);
    _muteAudio = widget.settings.muteAudio;
    _bypassCopyright = widget.settings.bypassCopyright;
  }

  void _switchPromptTab(String lang) {
    if (_activePromptLang == 'ko') {
      widget.settings.promptKo = _promptController.text;
    } else {
      widget.settings.promptJa = _promptController.text;
    }

    setState(() {
      _activePromptLang = lang;
      _promptController.text = lang == 'ja' ? widget.settings.promptJa : widget.settings.promptKo;
    });
  }

  void _resetPrompt() {
    setState(() {
      if (_activePromptLang == 'ja') {
        _promptController.text = SettingsService.defaultPromptJa;
      } else {
        _promptController.text = SettingsService.defaultPromptKo;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_activePromptLang == 'ja' ? '일본어' : '한국어'} 기본 프롬프트로 복원되었습니다.')),
    );
  }

  void _saveAll() {
    widget.settings.geminiApiKey = _apiKeyController.text.trim();
    if (_activePromptLang == 'ja') {
      widget.settings.promptJa = _promptController.text;
    } else {
      widget.settings.promptKo = _promptController.text;
    }
    widget.settings.muteAudio = _muteAudio;
    widget.settings.bypassCopyright = _bypassCopyright;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('환경 설정이 성공적으로 저장되었습니다!')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isJa = _activePromptLang == 'ja';

    return Scaffold(
      backgroundColor: const Color(0xFF0E1626),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131D31),
        title: const Text('⚙️ 환경 설정'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Gemini API Key Section
            const Text(
              '🔑 Google Gemini API 키',
              style: TextStyle(color: Color(0xFF38BDF8), fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _apiKeyController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              obscureText: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF131D31),
                hintText: 'AI Studio에서 발급받은 API 키를 입력하세요',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 20),

            // 2. Options (Mute & Copyright Bypass)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF131D31),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('🛡️ 인스타 알고리즘 우회 이원화 변조', style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: const Text('한·일 영상 간 배속, 편향줌, 노이즈, 색감 차별화', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    value: _bypassCopyright,
                    activeColor: const Color(0xFF2DD4BF),
                    onChanged: (val) => setState(() => _bypassCopyright = val),
                  ),
                  const Divider(color: Color(0xFF1E293B)),
                  SwitchListTile(
                    title: const Text('🔇 원본 오디오 음소거 (Mute)', style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: const Text('인스타 BGM 음원 추가를 위해 원본 소리를 제거합니다', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    value: _muteAudio,
                    activeColor: const Color(0xFF2DD4BF),
                    onChanged: (val) => setState(() => _muteAudio = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. Custom AI Prompt Section
            Row(
              children: [
                const Text(
                  '📝 AI 제목/피드 프롬프트 편집',
                  style: TextStyle(color: Color(0xFFC084FC), fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _resetPrompt,
                  icon: const Icon(Icons.refresh, size: 14, color: Color(0xFFC084FC)),
                  label: const Text('기본 복원', style: TextStyle(color: Color(0xFFC084FC), fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Prompt Tabs
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !isJa ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _switchPromptTab('ko'),
                    child: const Text('🇰🇷 한국어 프롬프트'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isJa ? const Color(0xFFBE185D) : const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _switchPromptTab('ja'),
                    child: const Text('🇯🇵 일본어 프롬프트'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _promptController,
              maxLines: 8,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF131D31),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _saveAll,
                child: const Text('설정 저장', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
