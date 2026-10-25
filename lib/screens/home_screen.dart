import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/reel_slot.dart';
import '../services/settings_service.dart';
import '../services/ai_service.dart';
import '../services/ffmpeg_service.dart';
import '../services/download_service.dart';
import '../services/crop_service.dart';
import '../widgets/slot_card.dart';
import 'template_settings_screen.dart';
import 'settings_screen.dart';
import 'video_editor_screen.dart';

class HomeScreen extends StatefulWidget {
  final SettingsService settings;

  const HomeScreen({super.key, required this.settings});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DownloadService _downloadService = DownloadService();
  String _currentLang = 'ko'; // 'ko' or 'ja'
  bool _isBusy = false;
  String _statusMessage = '준비 완료: 영상을 등록해주세요.';

  late List<ReelSlot> _slots;

  @override
  void initState() {
    super.initState();
    _slots = List.generate(
      10,
      (i) => ReelSlot(index: i + 1),
    );
  }

  // --- Import Multiple Videos from Galaxy Phone Gallery ---
  Future<void> _pickMultipleVideosFromGallery() async {
    setState(() {
      _isBusy = true;
      _statusMessage = '갤럭시 갤러리에서 영상 불러오는 중...';
    });

    try {
      final pickedFiles = await _downloadService.pickVideosFromGallery();
      if (pickedFiles.isNotEmpty) {
        for (int i = 0; i < pickedFiles.length && i < _slots.length; i++) {
          final f = pickedFiles[i];
          final slot = _slots[i];
          slot.videoPath = f.path;
          slot.videoName = f.path.split('/').last;
          slot.isRendered = false;

          // Auto-detect metadata & clean video bounds
          final meta = await CropService.getVideoMetadata(f.path);
          slot.origWidth = meta.width;
          slot.origHeight = meta.height;
          slot.duration = meta.duration;
          slot.hasAudio = meta.hasAudio;

          final detected = await CropService.autoDetectCrop(f.path, meta.width, meta.height);
          if (detected != null) {
            slot.cropBox = detected;
          }
        }
        _statusMessage = '총 ${pickedFiles.length}개의 영상 등록 및 자동 크롭 감지 완료!';
      } else {
        _statusMessage = '영상이 선택되지 않았습니다.';
      }
    } catch (e) {
      _statusMessage = '영상 불러오기 오류: $e';
    } finally {
      setState(() => _isBusy = false);
    }
  }

  // --- Pick Single Video for Specific Slot ---
  Future<void> _pickSingleVideoForSlot(int slotIdx) async {
    final file = await _downloadService.pickSingleVideo();
    if (file != null) {
      final slot = _slots[slotIdx];
      slot.videoPath = file.path;
      slot.videoName = file.path.split('/').last;
      slot.isRendered = false;

      final meta = await CropService.getVideoMetadata(file.path);
      slot.origWidth = meta.width;
      slot.origHeight = meta.height;
      slot.duration = meta.duration;
      slot.hasAudio = meta.hasAudio;

      final detected = await CropService.autoDetectCrop(file.path, meta.width, meta.height);
      if (detected != null) {
        slot.cropBox = detected;
      }

      setState(() {
        _statusMessage = '${slotIdx + 1}번 슬롯에 영상이 등록되었습니다.';
      });
    }
  }

  // --- Open Full Dual-Panel Video Editor & Crop Dialog ---
  void _openVideoEditor(int slotIdx) {
    final slot = _slots[slotIdx];
    if (!slot.hasVideo) {
      _pickSingleVideoForSlot(slotIdx);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoEditorScreen(
          slots: _slots,
          initialIndex: slotIdx,
          activeLang: _currentLang,
          settings: widget.settings,
          onSlotUpdated: (updated) {
            setState(() {
              _slots[updated.index - 1] = updated;
            });
          },
        ),
      ),
    ).then((_) => setState(() {}));
  }

  // --- AI Generate Title & Caption for Single Slot ---
  Future<void> _generateAIForSlot(int slotIdx) async {
    final slot = _slots[slotIdx];
    if (!slot.hasVideo) return;

    setState(() {
      slot.isProcessing = true;
      _statusMessage = '${slot.index}번 영상 AI 분석 및 제목 추천 중...';
    });

    try {
      final prompt = _currentLang == 'ja' ? widget.settings.promptJa : widget.settings.promptKo;
      final keyframes = await FFmpegService.extractKeyframes(slot.videoPath!);

      final result = await AIService.generateTitleAndCaption(
        apiKey: widget.settings.geminiApiKey,
        prompt: prompt,
        lang: _currentLang,
        videoTitleContext: slot.videoName ?? '해외 인기 영상',
        keyframePaths: keyframes,
      );

      setState(() {
        slot.setTitle(_currentLang, result['title'] ?? '');
        slot.setCaption(_currentLang, result['caption'] ?? '');
        _statusMessage = '${slot.index}번 AI 추천 완료!';
      });
    } catch (e) {
      setState(() => _statusMessage = 'AI 추천 실패 (${slot.index}번): $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI 오류: $e')));
    } finally {
      setState(() => slot.isProcessing = false);
    }
  }

  // --- AI Batch Recommendation for All Available Slots ---
  Future<void> _generateAIBatch() async {
    final targets = _slots.where((s) => s.hasVideo).toList();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 영상을 등록해주세요.')),
      );
      return;
    }

    setState(() {
      _isBusy = true;
      _statusMessage = 'AI 일괄 추천 분석 시작...';
    });

    for (int i = 0; i < targets.length; i++) {
      final slot = targets[i];
      final idx = _slots.indexOf(slot);
      await _generateAIForSlot(idx);
    }

    setState(() {
      _isBusy = false;
      _statusMessage = '🎉 모든 영상의 AI 제목 및 피드 추천이 완료되었습니다!';
    });
  }

  // --- Render Single Reel Slot ---
  Future<void> _renderSingleSlot(int slotIdx) async {
    final slot = _slots[slotIdx];
    if (!slot.hasVideo) return;

    setState(() {
      slot.isProcessing = true;
      _statusMessage = '🎬 ${slot.index}번 릴스 렌더링 중 (${_currentLang == 'ja' ? '일본판' : '한국판'})...';
    });

    try {
      final title = slot.getTitle(_currentLang);
      final template = _currentLang == 'ja' ? widget.settings.templateJa : widget.settings.templateKo;

      final extDir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final outDir = Directory('${extDir.path}/Reels_${_currentLang.toUpperCase()}');
      await outDir.create(recursive: true);

      final outPath = '${outDir.path}/reel_${slot.index.toString().padLeft(2, '0')}_${_currentLang.toUpperCase()}.mp4';

      final res = await FFmpegService.renderReel(
        videoPath: slot.videoPath!,
        titleText: title.isNotEmpty ? title : (slot.videoName ?? '화제의 영상'),
        lang: _currentLang,
        outputFilePath: outPath,
        customTemplatePath: template,
        cropBox: slot.effectiveCropBox,
        muteAudio: widget.settings.muteAudio,
        bypassCopyright: widget.settings.bypassCopyright,
      );

      if (res != null) {
        setState(() {
          slot.isRendered = true;
          if (_currentLang == 'ja') {
            slot.outputJaPath = outPath;
          } else {
            slot.outputKoPath = outPath;
          }
          _statusMessage = '🎉 ${slot.index}번 릴스 렌더링 완성!';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${slot.index}번 영상 완성: ${File(outPath).path}')),
        );
      } else {
        setState(() => _statusMessage = '❌ ${slot.index}번 렌더링 실패');
      }
    } catch (e) {
      setState(() => _statusMessage = '❌ 렌더링 오류 (${slot.index}번): $e');
    } finally {
      setState(() => slot.isProcessing = false);
    }
  }

  // --- Render All Slots Batch ---
  Future<void> _renderBatchAll() async {
    final targets = _slots.where((s) => s.hasVideo).toList();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('렌더링할 영상이 없습니다.')),
      );
      return;
    }

    setState(() {
      _isBusy = true;
      _statusMessage = '릴스 일괄 렌더링 시작...';
    });

    int count = 0;
    for (int i = 0; i < targets.length; i++) {
      final slot = targets[i];
      final idx = _slots.indexOf(slot);
      await _renderSingleSlot(idx);
      if (slot.isRendered) count++;
    }

    setState(() {
      _isBusy = false;
      _statusMessage = '🎉 총 $count개의 릴스 영상 제작이 완료되었습니다!';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isJa = _currentLang == 'ja';

    return Scaffold(
      backgroundColor: const Color(0xFF0E1626),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1626),
        elevation: 0,
        title: Row(
          children: [
            const Text(
              'RAYWORKS',
              style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const Text(
              ' REELS STUDIO',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        actions: [
          // Language Switcher (KO / JA)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _currentLang = 'ko'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: !isJa ? const Color(0xFF0284C7) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('🇰🇷 KO', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _currentLang = 'ja'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isJa ? const Color(0xFFBE185D) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('🇯🇵 JA', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          // Template Settings
          IconButton(
            tooltip: '배경 템플릿 설정',
            icon: const Icon(Icons.palette_outlined, color: Color(0xFF2DD4BF)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TemplateSettingsScreen(settings: widget.settings)),
              ).then((_) => setState(() {}));
            },
          ),
          // Settings
          IconButton(
            tooltip: '환경 설정',
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SettingsScreen(settings: widget.settings)),
              ).then((_) => setState(() {}));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: const Color(0xFF131D31),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isBusy ? null : _pickMultipleVideosFromGallery,
                    icon: const Icon(Icons.video_library, size: 16),
                    label: const Text('갤러리 불러오기', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7E22CE),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isBusy ? null : _generateAIBatch,
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('AI 일괄 추천', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isBusy ? null : _renderBatchAll,
                    icon: const Icon(Icons.movie_creation_outlined, size: 16),
                    label: Text(
                      isJa ? '일괄 렌더 (JA)' : '일괄 렌더 (KR)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Status Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF090E17),
            child: Row(
              children: [
                if (_isBusy)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2DD4BF)),
                    ),
                  ),
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // 10 Slot Cards List
          Expanded(
            child: ListView.builder(
              itemCount: _slots.length,
              itemBuilder: (ctx, idx) => SlotCard(
                slot: _slots[idx],
                currentLang: _currentLang,
                onPickVideo: () => _pickSingleVideoForSlot(idx),
                onOpenEditor: () => _openVideoEditor(idx),
                onGenerateAI: () => _generateAIForSlot(idx),
                onRender: () => _renderSingleSlot(idx),
                onTitleChanged: (val) => _slots[idx].setTitle(_currentLang, val),
                onCaptionChanged: (val) => _slots[idx].setCaption(_currentLang, val),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
