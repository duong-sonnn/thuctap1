// image_actions.dart
import 'dart:io';
import 'package:flutter_image_gallery_saver/flutter_image_gallery_saver.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

class ImageActions {
  /// Lưu tất cả URLs trong [urls] vào thư viện máy, 
  /// trả về số ảnh đã lưu thành công.
  static Future<int> saveImages(List<String> urls) async {
    int savedCount = 0;

    // Android: xin permission nếu cần
    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
        if (!status.isGranted) return 0;
      }
    }

    for (final url in urls) {
      try {
        final resp = await http.get(Uri.parse(url));
        if (resp.statusCode == 200) {
          await FlutterImageGallerySaver.saveImage(resp.bodyBytes);
          savedCount++;
        }
      } catch (_) { /* bỏ qua lỗi từng ảnh */ }
    }

    return savedCount;
  }

  /// Chia sẻ tất cả URLs trong [urls] kèm text [prompt] qua hệ thống share.
  static Future<void> shareImages(List<String> urls, String prompt) async {
    final tempDir = await getTemporaryDirectory();
    final List<XFile> files = [];

    for (var i = 0; i < urls.length; i++) {
      final resp = await http.get(Uri.parse(urls[i]));
      if (resp.statusCode == 200) {
        final file = File('${tempDir.path}/image_$i.jpg');
        await file.writeAsBytes(resp.bodyBytes);
        files.add(XFile(file.path));
      }
    }

    if (files.isNotEmpty) {
      await Share.shareXFiles(
        files,
        text: 'Ảnh được tạo bởi AI từ prompt: $prompt',
      );
    }
  }
}
