import 'dart:io';
import 'dart:typed_data';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';


class ImageActions {
  /// Lưu list ảnh vào gallery, trả về số ảnh lưu thành công
  static Future<int> saveImages(List<String> urls) async {
    int savedCount = 0;
    final tempDir = await getTemporaryDirectory();

    // Yêu cầu quyền lưu ảnh
    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) return 0;

    for (final url in urls) {
      try {
        final resp = await http.get(Uri.parse(url));

        // Ép kết quả contains(...) thành bool thuần (false nếu null)
        final bool isImage = resp.headers['content-type']?.contains('image') ?? false;

        if (resp.statusCode == 200 && isImage) {
          final fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final filePath = '${tempDir.path}/$fileName';

          // Ghi nhị phân ảnh ra file tạm
          await File(filePath).writeAsBytes(resp.bodyBytes);

          // Đọc lại thành Uint8List để truyền vào saveImage
          final Uint8List bytes = await File(filePath).readAsBytes();

          // Gọi saveImage và lấy thuộc tính isSuccess từ SaveResult
          final SaveResult result = await SaverGallery.saveImage(
            bytes,
            fileName: fileName,
            skipIfExists: false,
          );
          final bool success = result.isSuccess; // Lấy giá trị bool từ isSuccess

          if (success) {
            savedCount++;
          }

          // Xóa file tạm
          await File(filePath).delete();
        }
      } catch (e) {
        print('Lỗi khi lưu ảnh $url: $e');
      }
    }
    return savedCount;
  }

  /// Yêu cầu quyền lưu ảnh trên Android/iOS
  static Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.photos.request();
      return status.isGranted;
    } else if (Platform.isIOS) {
      final status = await Permission.photosAddOnly.request();
      return status.isGranted;
    }
    return false;
  }

  static Future<void> shareImages(List<String> urls, String prompt) async {
    final tempDir = await getTemporaryDirectory();
    final List<XFile> files = [];

    try {
      for (var i = 0; i < urls.length; i++) {
        try {
          final resp = await http.get(Uri.parse(urls[i]));
          if (resp.statusCode == 200 &&
              resp.headers['content-type']?.contains('image') == true) {
            final file = File('${tempDir.path}/image_$i.jpg');
            await file.writeAsBytes(resp.bodyBytes);
            files.add(XFile(file.path));
          }
        } catch (e) {
          print('Lỗi khi tải ảnh ${urls[i]} để chia sẻ: $e');
        }
      }

      if (files.isNotEmpty) {
        await Share.shareXFiles(
          files,
          text: 'Ảnh được tạo bởi AI từ prompt: $prompt',
        );
      }
    } finally {
      for (var file in files) {
        try {
          await File(file.path).delete();
        } catch (_) {}
      }
    }
  }

}
    