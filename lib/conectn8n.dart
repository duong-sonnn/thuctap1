import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String n8nWebhookUrl =
      "https://champion-beloved-tiger.ngrok-free.app/webhook-test/639f5088-1875-4ba9-b72e-3fadeef63934";

  Future<String> sendDataToN8n(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse(n8nWebhookUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}'); // Để debug

      if (response.statusCode == 200) {
        return response.body; // Trả về chuỗi JSON thô
      } else {
        return "❌ Lỗi khi gửi dữ liệu: ${response.statusCode}";
      }
    } catch (e) {
      return "❗ Lỗi kết nối: $e";
    }
  }
}