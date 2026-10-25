import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/settings_service.dart';
import '../services/ffmpeg_service.dart';

class TemplateSettingsScreen extends StatefulWidget {
  final SettingsService settings;

  const TemplateSettingsScreen({super.key, required this.settings});

  @override
  State<TemplateSettingsScreen> createState() => _TemplateSettingsScreenState();
}

class _TemplateSettingsScreenState extends State<TemplateSettingsScreen> {
  String _activeLang = 'ko'; // 'ko' or 'ja'
  String? _currentKoPath;
  String? _currentJaPath;

  @override
  void initState() {
    super.initState();
    _currentKoPath = widget.settings.templateKo;
    _currentJaPath = widget.settings.templateJa;
    _loadDefaultsIfEmpty();
  }

  Future<void> _loadDefaultsIfEmpty() async {
    if (_currentKoPath == null) {
      _currentKoPath = await FFmpegService.getBundledTemplatePath('ko');
    }
    if (_currentJaPath == null) {
      _currentJaPath = await FFmpegService.getBundledTemplatePath('ja');
    }
    setState(() {});
  }

  Future<void> _pickNewTemplate() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      setState(() {
        if (_activeLang == 'ja') {
          _currentJaPath = path;
        } else {
          _currentKoPath = path;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_activeLang == 'ja' ? '일본어' : '한국어'} 템플릿 이미지가 선택되었습니다.')),
      );
    }
  }

  Future<void> _resetToDefault() async {
    final defaultPath = await FFmpegService.getBundledTemplatePath(_activeLang);
    setState(() {
      if (_activeLang == 'ja') {
        _currentJaPath = defaultPath;
      } else {
        _currentKoPath = defaultPath;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_activeLang == 'ja' ? '일본어' : '한국어'} 기본 템플릿으로 복원되었습니다.')),
    );
  }

  void _saveSettings() {
    widget.settings.templateKo = _currentKoPath;
    widget.settings.templateJa = _currentJaPath;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('한·일 배경 템플릿이 성공적으로 저장되었습니다!')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isJa = _activeLang == 'ja';
    final currentPath = isJa ? _currentJaPath : _currentKoPath;

    return Scaffold(
      backgroundColor: const Color(0xFF0E1626),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131D31),
        title: const Text('🎨 배경 템플릿 설정 (1080x1920)'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '* 한국어(KR)와 일본어(JP) 릴스 배경으로 사용될 템플릿 이미지(1080x1920)를 각각 독립적으로 설정합니다.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Bilingual Tabs
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !isJa ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => setState(() => _activeLang = 'ko'),
                    child: const Text('🇰🇷 한국어 템플릿', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isJa ? const Color(0xFFBE185D) : const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => setState(() => _activeLang = 'ja'),
                    child: const Text('🇯🇵 일본어 템플릿', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Preview Card
            Center(
              child: Container(
                width: 180,
                height: 320,
                decoration: BoxDecoration(
                  color: const Color(0xFF131D31),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.parse(
                    '1px solid ${isJa ? '#F472B6' : '#38BDF8'}',
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: currentPath != null && File(currentPath).existsSync()
                    ? Image.file(File(currentPath), fit: BoxFit.cover)
                    : const Center(
                        child: Text(
                          '템플릿 미리보기',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 14),

            Center(
              child: Text(
                '📐 표준 규격: 1080 x 1920 (${isJa ? '일본어 모드' : '한국어 모드'})',
                style: const TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),

            Center(
              child: Text(
                currentPath ?? '기본 템플릿',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2DD4BF),
                      side: const BorderSide(color: Color(0xFF0D9488)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _pickNewTemplate,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('갤러리에서 선택'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Color(0xFF334155)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _resetToDefault,
                    icon: const Icon(Icons.refresh),
                    label: const Text('기본 템플릿 복원'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Save All Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _saveSettings,
                child: const Text('한·일 템플릿 일괄 저장', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
