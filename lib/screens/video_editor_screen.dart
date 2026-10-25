import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/reel_slot.dart';
import '../services/ai_service.dart';
import '../services/crop_service.dart';
import '../services/settings_service.dart';
import '../services/ffmpeg_service.dart';

class VideoEditorScreen extends StatefulWidget {
  final List<ReelSlot> slots;
  final int initialIndex;
  final String activeLang;
  final SettingsService settings;
  final Function(ReelSlot updatedSlot) onSlotUpdated;

  const VideoEditorScreen({
    super.key,
    required this.slots,
    required this.initialIndex,
    required this.activeLang,
    required this.settings,
    required this.onSlotUpdated,
  });

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  late int _currentIndex;
  late String _lang;

  VideoPlayerController? _videoController;
  bool _isPlaying = false;
  bool _isPlayerInitialized = false;

  // Title & Caption controllers
  late TextEditingController _titleController;
  late TextEditingController _captionController;

  // Crop Box state in video pixels: left, top, width, height
  double _cropLeft = 0;
  double _cropTop = 0;
  double _cropWidth = 1080;
  double _cropHeight = 1920;
  bool _showCropOverlay = true;

  bool _isAiGenerating = false;
  bool _isAutoCropping = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _lang = widget.activeLang;
    _titleController = TextEditingController();
    _captionController = TextEditingController();

    _loadSlot(_currentIndex);
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _titleController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  ReelSlot get _currentSlot => widget.slots[_currentIndex];

  void _loadSlot(int index) async {
    _currentIndex = index;
    final slot = _currentSlot;

    _titleController.text = slot.getTitle(_lang);
    _captionController.text = slot.getCaption(_lang);

    // Dispose old controller
    await _videoController?.pause();
    await _videoController?.dispose();
    _videoController = null;
    _isPlayerInitialized = false;
    setState(() {});

    if (slot.videoPath != null && await File(slot.videoPath!).exists()) {
      // 1. Fetch metadata
      final meta = await CropService.getVideoMetadata(slot.videoPath!);
      slot.origWidth = meta.width;
      slot.origHeight = meta.height;
      slot.duration = meta.duration;
      slot.hasAudio = meta.hasAudio;

      // 2. Initialize Crop Box
      if (slot.cropBox != null) {
        _cropLeft = slot.cropBox!.left;
        _cropTop = slot.cropBox!.top;
        _cropWidth = slot.cropBox!.width;
        _cropHeight = slot.cropBox!.height;
      } else {
        _cropLeft = 0;
        _cropTop = 0;
        _cropWidth = slot.origWidth.toDouble();
        _cropHeight = slot.origHeight.toDouble();
      }

      // 3. Initialize Video Player
      _videoController = VideoPlayerController.file(File(slot.videoPath!))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _isPlayerInitialized = true;
            });
            _videoController?.setLooping(true);
            _videoController?.play();
            _isPlaying = true;
          }
        });
    }

    if (mounted) setState(() {});
  }

  void _saveCurrentSlot() {
    final slot = _currentSlot;
    slot.setTitle(_lang, _titleController.text.trim());
    slot.setCaption(_lang, _captionController.text.trim());

    // Check if full
    final isFull = _cropLeft <= 1 &&
        _cropTop <= 1 &&
        (_cropWidth - slot.origWidth).abs() <= 2 &&
        (_cropHeight - slot.origHeight).abs() <= 2;

    if (isFull) {
      slot.cropBox = null;
    } else {
      slot.cropBox = Rect.fromLTWH(_cropLeft, _cropTop, _cropWidth, _cropHeight);
    }

    widget.onSlotUpdated(slot);
  }

  void _goPrevSlot() {
    _saveCurrentSlot();
    int next = _currentIndex - 1;
    while (next >= 0 && !widget.slots[next].hasVideo) {
      next--;
    }
    if (next >= 0) {
      _loadSlot(next);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('첫 번째 영상입니다.')),
      );
    }
  }

  void _goNextSlot() {
    _saveCurrentSlot();
    int next = _currentIndex + 1;
    while (next < widget.slots.length && !widget.slots[next].hasVideo) {
      next++;
    }
    if (next < widget.slots.length) {
      _loadSlot(next);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('마지막 영상입니다.')),
      );
    }
  }

  void _resetCropToFull() {
    setState(() {
      _cropLeft = 0;
      _cropTop = 0;
      _cropWidth = _currentSlot.origWidth.toDouble();
      _cropHeight = _currentSlot.origHeight.toDouble();
    });
  }

  void _autoDetectCrop() async {
    final slot = _currentSlot;
    if (slot.videoPath == null) return;

    setState(() => _isAutoCropping = true);
    final detected = await CropService.autoDetectCrop(
      slot.videoPath!,
      slot.origWidth,
      slot.origHeight,
    );
    setState(() => _isAutoCropping = false);

    if (detected != null) {
      setState(() {
        _cropLeft = detected.left;
        _cropTop = detected.top;
        _cropWidth = detected.width;
        _cropHeight = detected.height;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '알맹이 영상 자동 감지 완료! [Y: ${_cropTop.toInt()} ~ ${(_cropTop + _cropHeight).toInt()}px]',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('원본 영상에 별도의 자막/검은 여백이 감지되지 않았습니다.')),
      );
    }
  }

  void _adjustCrop(String edge, double delta) {
    final origH = _currentSlot.origHeight.toDouble();
    setState(() {
      if (edge == 'top') {
        final newTop = max(0.0, min(_cropTop + delta, _cropTop + _cropHeight - 60));
        final diff = newTop - _cropTop;
        _cropTop = newTop;
        _cropHeight -= diff;
      } else if (edge == 'bottom') {
        final newBottom = max(_cropTop + 60, min(origH, _cropTop + _cropHeight + delta));
        _cropHeight = newBottom - _cropTop;
      }
    });
  }

  void _generateAiContent() async {
    final slot = _currentSlot;
    if (slot.videoPath == null) return;

    final apiKey = widget.settings.geminiApiKey;
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gemini API 키가 설정되지 않았습니다. 메인 화면 설정에서 등록해주세요.')),
      );
      return;
    }

    setState(() => _isAiGenerating = true);
    try {
      final prompt = _lang == 'ja' ? widget.settings.promptJa : widget.settings.promptKo;
      final keyframes = await FFmpegService.extractKeyframes(slot.videoPath!);
      final res = await AIService.generateTitleAndCaption(
        apiKey: apiKey,
        prompt: prompt,
        lang: _lang,
        videoTitleContext: slot.videoName ?? '해외 인기 영상',
        keyframePaths: keyframes,
      );
      _titleController.text = res['title'] ?? '';
      _captionController.text = res['caption'] ?? '';
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI 추천 실패: $e')),
      );
    } finally {
      setState(() => _isAiGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slot = _currentSlot;
    final origW = max(1, slot.origWidth);
    final origH = max(1, slot.origHeight);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          '🎬 [슬롯 ${slot.index.toString().padLeft(2, '0')}] 통합 영상&크롭 편집기',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: '이전 슬롯',
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: _goPrevSlot,
          ),
          Center(
            child: Text(
              '${slot.index} / 10',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
            ),
          ),
          IconButton(
            tooltip: '다음 슬롯',
            icon: const Icon(Icons.arrow_forward_ios, size: 18),
            onPressed: _goNextSlot,
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () {
              _saveCurrentSlot();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.check, color: Color(0xFF10B981)),
            label: const Text('완료', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Video Player Area with Crop Guide Overlay
            Container(
              color: Colors.black,
              height: 280,
              width: double.infinity,
              child: _isPlayerInitialized && _videoController != null
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        ),
                        // Viewfinder Crop Overlay
                        if (_showCropOverlay)
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final aspect = _videoController!.value.aspectRatio;
                              double renderW, renderH;
                              if (constraints.maxWidth / constraints.maxHeight > aspect) {
                                renderH = constraints.maxHeight;
                                renderW = renderH * aspect;
                              } else {
                                renderW = constraints.maxWidth;
                                renderH = renderW / aspect;
                              }

                              final scaleX = renderW / origW;
                              final scaleY = renderH / origH;

                              final boxLeft = _cropLeft * scaleX;
                              final boxTop = _cropTop * scaleY;
                              final boxW = _cropWidth * scaleX;
                              final boxH = _cropHeight * scaleY;

                              return SizedBox(
                                width: renderW,
                                height: renderH,
                                child: Stack(
                                  children: [
                                    // Top Shade
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      right: 0,
                                      height: max(0.0, boxTop),
                                      child: Container(color: Colors.black.withOpacity(0.65)),
                                    ),
                                    // Bottom Shade
                                    Positioned(
                                      top: min(renderH, boxTop + boxH),
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      child: Container(color: Colors.black.withOpacity(0.65)),
                                    ),
                                    // Active Crop Box
                                    Positioned(
                                      left: boxLeft,
                                      top: boxTop,
                                      width: boxW,
                                      height: boxH,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(color: const Color(0xFF38BDF8), width: 2),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '크롭 영역 [${_cropWidth.toInt()}x${_cropHeight.toInt()}]',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.85),
                                              fontSize: 11,
                                              backgroundColor: Colors.black54,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        // Play/Pause Overlay Button
                        Positioned(
                          bottom: 12,
                          left: 12,
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              icon: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                setState(() {
                                  if (_isPlaying) {
                                    _videoController?.pause();
                                  } else {
                                    _videoController?.play();
                                  }
                                  _isPlaying = !_isPlaying;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    )
                  : const Center(
                      child: CircularProgressIndicator(),
                    ),
            ),

            // 2. Crop Fine-Tune Toolbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF1E293B),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.crop, color: Color(0xFF38BDF8), size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        '크롭 가이드라인',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                      ),
                      const Spacer(),
                      Switch(
                        value: _showCropOverlay,
                        activeColor: const Color(0xFF38BDF8),
                        onChanged: (val) => setState(() => _showCropOverlay = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isAutoCropping ? null : _autoDetectCrop,
                          icon: _isAutoCropping
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.auto_awesome, size: 16),
                          label: const Text('🤖 자동 크롭', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _resetCropToFull,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('전체 화면 (리셋)', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Top / Bottom Margin Adjusters
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Row(
                        children: [
                          const Text('상단 마진: ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.amber, size: 20),
                            onPressed: () => _adjustCrop('top', -15),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Colors.amber, size: 20),
                            onPressed: () => _adjustCrop('top', 15),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Text('하단 마진: ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.amber, size: 20),
                            onPressed: () => _adjustCrop('bottom', -15),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Colors.amber, size: 20),
                            onPressed: () => _adjustCrop('bottom', 15),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 3. Title & Caption Editing Area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '🏷️ 릴스 타이틀 (2줄 훅)',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _isAiGenerating ? null : _generateAiContent,
                        icon: _isAiGenerating
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.psychology, size: 16),
                        label: const Text('✨ AI 추천', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF38BDF8),
                          foregroundColor: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _titleController,
                    maxLines: 2,
                    style: const TextStyle(
                      fontFamily: 'MalgunGothic',
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      hintText: '임팩트 바이럴 훅 (14~18자 내외, 엔터로 줄바꿈)',
                      hintStyle: const TextStyle(color: Colors.white38),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF38BDF8), width: 2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      const Text(
                        '📰 매거진 피드 본문 (캡션)',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _captionController.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('피드 본문이 클립보드에 복사되었습니다!')),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 14, color: Color(0xFF38BDF8)),
                        label: const Text('복사', style: TextStyle(fontSize: 12, color: Color(0xFF38BDF8))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _captionController,
                    maxLines: 8,
                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      hintText: '인스타그램 피드 본문 (과학/원리/인사이트 설명글)',
                      hintStyle: const TextStyle(color: Colors.white38),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF38BDF8), width: 2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
