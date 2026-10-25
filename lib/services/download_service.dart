import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class DownloadService {
  final ImagePicker _picker = ImagePicker();

  /// Pick multiple videos directly from Galaxy Phone Gallery
  Future<List<File>> pickVideosFromGallery() async {
    final pickedList = await _picker.pickMultipleMedia();
    final videoFiles = <File>[];

    for (final xFile in pickedList) {
      final ext = xFile.path.split('.').last.toLowerCase();
      if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext)) {
        videoFiles.add(File(xFile.path));
      }
    }
    return videoFiles;
  }

  /// Pick single video from Galaxy Phone Gallery
  Future<File?> pickSingleVideo() async {
    final xFile = await _picker.pickVideo(source: ImageSource.gallery);
    if (xFile != null) {
      return File(xFile.path);
    }
    return null;
  }

  /// Downloads video from direct URL or video link
  Future<File?> downloadVideoFromUrl(String url, int slotIndex) async {
    try {
      final uri = Uri.parse(url.trim());
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/reel_input_${slotIndex}_${DateTime.now().millisecondsSinceEpoch}.mp4');
        await file.writeAsBytes(res.bodyBytes);
        return file;
      }
    } catch (e) {
      print('Download error ($url): $e');
    }
    return null;
  }
}
