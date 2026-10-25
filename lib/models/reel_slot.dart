import 'package:flutter/material.dart';

class ReelSlot {
  final int index;
  String? videoPath;
  String? videoName;
  String titleKo;
  String titleJa;
  String captionKo;
  String captionJa;
  bool isProcessing;
  bool isRendered;
  String? outputKoPath;
  String? outputJaPath;

  // Video Metadata & Crop Settings
  int origWidth;
  int origHeight;
  double duration;
  bool hasAudio;
  Rect? cropBox; // Pixel coordinates: Rect.fromLTWH(left, top, width, height)
  bool isCropActive;

  ReelSlot({
    required this.index,
    this.videoPath,
    this.videoName,
    this.titleKo = '',
    this.titleJa = '',
    this.captionKo = '',
    this.captionJa = '',
    this.isProcessing = false,
    this.isRendered = false,
    this.outputKoPath,
    this.outputJaPath,
    this.origWidth = 1080,
    this.origHeight = 1920,
    this.duration = 0.0,
    this.hasAudio = true,
    this.cropBox,
    this.isCropActive = true,
  });

  String getTitle(String lang) => lang == 'ja' ? titleJa : titleKo;
  String getCaption(String lang) => lang == 'ja' ? captionJa : captionKo;

  void setTitle(String lang, String val) {
    if (lang == 'ja') {
      titleJa = val;
    } else {
      titleKo = val;
    }
  }

  void setCaption(String lang, String val) {
    if (lang == 'ja') {
      captionJa = val;
    } else {
      captionKo = val;
    }
  }

  bool get hasVideo => videoPath != null && videoPath!.isNotEmpty;

  /// Effective crop box (returns null if full video or crop disabled)
  Rect? get effectiveCropBox => isCropActive ? cropBox : null;
}
