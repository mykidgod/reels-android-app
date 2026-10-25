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
}
