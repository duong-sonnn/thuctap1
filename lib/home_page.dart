import 'package:flutter/material.dart';
import 'dart:convert';
import 'conectn8n.dart'; // Import API service

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _promptController = TextEditingController();
  List<String> _generatedImageUrls = [];
  bool _isLoading = false;
  int _numberOfImages = 1;
  String? _selectedStyle;
  final ApiService _apiService = ApiService();

  final List<String> _styleOptions = [
    'Realistic',
    'Cartoon',
    'Abstract',
    'Minimalist',
    'Cyberpunk',
  ];

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

 Future<void> _generateImage() async {
  if (_promptController.text.isEmpty || _selectedStyle == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vui lòng nhập mô tả và chọn kiểu ảnh')),
    );
    return;
  }

  setState(() {
    _isLoading = true;
    _generatedImageUrls = [];
  });

  try {
    // Chuẩn bị dữ liệu để gửi đến n8n
    final Map<String, dynamic> requestData = {
      'prompt': _promptController.text,
      'style': _selectedStyle,
      'numberOfImages': _numberOfImages,
    };

    // Hiển thị thông báo đang gửi yêu cầu
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang gửi yêu cầu tạo ảnh...')),
      );
    }

    // Gọi API n8n
    final response = await _apiService.sendDataToN8n(requestData);

    // Xử lý phản hồi từ n8n
    if (!mounted) return;

    setState(() {
      try {
        // Kiểm tra xem response có phải lỗi không
        if (response.startsWith('❌') || response.startsWith('❗')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response)),
          );
          _isLoading = false;
          return;
        }

        // Phân tích JSON từ response
        final jsonData = jsonDecode(response);

        // Kiểm tra nếu JSON là một object chứa key 'data'
        if (jsonData is Map<String, dynamic> && jsonData.containsKey('data')) {
          List<String> urls = [];
          var dataList = jsonData['data'];

          // Kiểm tra nếu 'data' là một mảng
          if (dataList is List && dataList.isNotEmpty) {
            for (var item in dataList) {
              if (item is Map<String, dynamic> && item.containsKey('imageURL')) {
                String url = item['imageURL'];
                if (url.isNotEmpty && url.startsWith('http')) {
                  urls.add(url);
                }
              }
            }

            if (urls.isNotEmpty) {
              _generatedImageUrls = urls;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã tạo ${urls.length} ảnh thành công')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Không tìm thấy URL ảnh trong phản hồi')),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Mảng data rỗng hoặc không hợp lệ')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Định dạng phản hồi không hỗ trợ: $response')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xử lý phản hồi: $e')),
        );
      }

      _isLoading = false;
    });
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lỗi: $e')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Generator'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _promptController,
              decoration: const InputDecoration(
                hintText: 'Enter a description for the image...',
                border: OutlineInputBorder(),
                labelText: 'Image Prompt',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Style and Number Selection
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedStyle,
                    decoration: const InputDecoration(
                      labelText: 'Select Style',
                      border: OutlineInputBorder(),
                    ),
                    items: _styleOptions
                        .map((style) => DropdownMenuItem(
                              value: style,
                              child: Text(style),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => _selectedStyle = value),
                    hint: const Text('Choose a style'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _numberOfImages,
                    decoration: const InputDecoration(
                      labelText: 'Number of Images',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1 Image')),
                      DropdownMenuItem(value: 4, child: Text('4 Images')),
                    ],
                    onChanged: (value) => setState(() => _numberOfImages = value!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _promptController.text.isNotEmpty &&
                      _selectedStyle != null
                  ? _generateImage
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Text(_isLoading ? 'Generating...' : 'Generate Image'),
              ),
            ),
            const SizedBox(height: 24),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_generatedImageUrls.isNotEmpty)
              Column(
                children: [
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: _numberOfImages == 4 ? 2 : 1,
                    childAspectRatio: 1,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: _generatedImageUrls.map((url) => ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.error, size: 50),
                          ),
                        )).toList(),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      SizedBox(
                        width: 150,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // TODO: Implement save all
                          },
                          icon: const Icon(Icons.save),
                          label: const Text('Save All'),
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // TODO: Implement share all
                          },
                          icon: const Icon(Icons.share),
                          label: const Text('Share All'),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Generated images will appear here',
                    style: TextStyle(color: Colors.grey),
                    
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}