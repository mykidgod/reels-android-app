import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/reel_slot.dart';

class SlotCard extends StatelessWidget {
  final ReelSlot slot;
  final String currentLang;
  final VoidCallback onPickVideo;
  final VoidCallback onOpenEditor;
  final VoidCallback onGenerateAI;
  final VoidCallback onRender;
  final Function(String) onTitleChanged;
  final Function(String) onCaptionChanged;

  const SlotCard({
    super.key,
    required this.slot,
    required this.currentLang,
    required this.onPickVideo,
    required this.onOpenEditor,
    required this.onGenerateAI,
    required this.onRender,
    required this.onTitleChanged,
    required this.onCaptionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final title = slot.getTitle(currentLang);
    final caption = slot.getCaption(currentLang);
    final isJa = currentLang == 'ja';
    final hasCrop = slot.effectiveCropBox != null;

    return Card(
      color: const Color(0xFF131D31),
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: slot.hasVideo ? const Color(0xFF2DD4BF) : const Color(0xFF1E293B),
          width: slot.hasVideo ? 1.2 : 0.8,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Index Badge & Status & Crop Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '[ ${slot.index.toString().padLeft(2, '0')}번 ]',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    slot.videoName ?? '영상이 등록되지 않았습니다',
                    style: TextStyle(
                      color: slot.hasVideo ? Colors.white : Colors.white54,
                      fontSize: 13,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (hasCrop)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.2),
                      border: Border.all(color: const Color(0xFF818CF8), width: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.crop, size: 11, color: Color(0xFF818CF8)),
                        const SizedBox(width: 3),
                        Text(
                          '${slot.effectiveCropBox!.width.toInt()}x${slot.effectiveCropBox!.height.toInt()}',
                          style: const TextStyle(color: Color(0xFF818CF8), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                if (slot.isProcessing)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2DD4BF)),
                  )
                else if (slot.isRendered)
                  const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
              ],
            ),
            const SizedBox(height: 10),

            // Middle Row: Title Input Field (2-line preservation)
            TextField(
              controller: TextEditingController(text: title)
                ..selection = TextSelection.collapsed(offset: title.length),
              onChanged: onTitleChanged,
              maxLines: 2,
              minLines: 1,
              style: const TextStyle(
                fontFamily: 'MalgunGothic',
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0E1626),
                hintText: isJa ? '推奨タイトル（14〜18文字）' : '추천 영상 제목 (14~18자 내외, 엔터로 줄바꿈)',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isJa ? const Color(0xFFF472B6) : const Color(0xFF38BDF8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Bottom Action Row
            Row(
              children: [
                // Pick Video Button
                OutlinedButton.icon(
                  onPressed: onPickVideo,
                  icon: const Icon(Icons.video_library, size: 15),
                  label: Text(slot.hasVideo ? '변경' : '선택', style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF38BDF8),
                    side: const BorderSide(color: Color(0xFF0284C7)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                ),
                const SizedBox(width: 6),

                // Crop & Video Editor Button
                ElevatedButton.icon(
                  onPressed: slot.hasVideo ? onOpenEditor : null,
                  icon: const Icon(Icons.crop, size: 15),
                  label: const Text('크롭&편집', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                ),
                const SizedBox(width: 6),

                // AI Generate Button
                OutlinedButton.icon(
                  onPressed: slot.hasVideo ? onGenerateAI : null,
                  icon: const Icon(Icons.auto_awesome, size: 15),
                  label: const Text('AI', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC084FC),
                    side: const BorderSide(color: Color(0xFF7E22CE)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                ),
                const SizedBox(width: 6),

                // Caption Dialog Button
                IconButton(
                  tooltip: '피드 본문 보기',
                  icon: const Icon(Icons.article_outlined, color: Colors.white70, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _showCaptionDialog(context, caption),
                ),

                const Spacer(),

                // Share Button (if rendered)
                if (slot.isRendered) ...[
                  IconButton(
                    tooltip: '인스타 공유',
                    icon: const Icon(Icons.share, color: Color(0xFF10B981), size: 20),
                    onPressed: () {
                      final outPath = isJa ? slot.outputJaPath : slot.outputKoPath;
                      if (outPath != null && File(outPath).existsSync()) {
                        Share.shareXFiles([XFile(outPath)], text: caption);
                      }
                    },
                  ),
                ],

                // Render Button
                ElevatedButton(
                  onPressed: slot.hasVideo && !slot.isProcessing ? onRender : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(slot.isRendered ? '재렌더링' : '렌더링', style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCaptionDialog(BuildContext context, String initialText) {
    final controller = TextEditingController(text: initialText);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131D31),
        title: Row(
          children: [
            const Icon(Icons.article, color: Color(0xFFC084FC)),
            const SizedBox(width: 8),
            Text(
              '${slot.index}번 피드 본문 (${currentLang == 'ja' ? '일본어' : '한국어'})',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 12,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF0E1626),
              hintText: '5단계 매거진 피드 본문이 여기에 표시됩니다.',
              hintStyle: const TextStyle(color: Colors.white38),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
            onPressed: () {
              onCaptionChanged(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('본문 저장', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
