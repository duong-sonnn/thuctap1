import 'dart:async'; // Thêm Timer cho timeout
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_gallery_saver/flutter_image_gallery_saver.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'HistoryPage.dart';
import 'conectn8n.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _promptController = TextEditingController();
  List<String> _generatedImageUrls = [];
  bool _isLoading = false;
  bool _isUserMenuOpen = false;
  int _numberOfImages = 1;
  String? _selectedStyle = 'No style';
  final ApiService _apiService = ApiService();

  final int _timeoutSeconds = 60;
  Timer? _timeoutTimer;

  final List<String> _styleOptions = [
    'No style',
    'Cinematic',
    'Disney Character',
    'Digital Art',
    'Photographic',
    'Fantasy art',
    'Neonpunk',
    'Enhance',
    'Comic book',
    'Lowpoly',
    'Line art',
  ];

  @override
  void dispose() {
    _promptController.dispose();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _generateImage() async {
    if (_promptController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập mô tả ảnh')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _generatedImageUrls = [];
    });

    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(Duration(seconds: _timeoutSeconds), () {
      if (_isLoading && mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Quá thời gian chờ (${_timeoutSeconds}s). Vui lòng thử lại.')),
        );
      }
    });

    try {
      final requestData = {
        'prompt': _promptController.text,
        'style': _selectedStyle,
        'numberOfImages': _numberOfImages,
      };

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang gửi yêu cầu tạo ảnh...')),
      );

      final response = await _apiService.sendDataToN8n(requestData);
      _timeoutTimer?.cancel();
      if (!mounted) return;

      // 1) Kiểm tra lỗi từ webhook
      if (response.startsWith('❌') || response.startsWith('❗')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response)),
        );
        setState(() => _isLoading = false);
        return;
      }

      // 2) Parse JSON và thu URL
      final jsonData = jsonDecode(response);
      List<String> urls = [];
      if (jsonData is Map<String, dynamic>) {
        if (jsonData['data'] is List) {
          for (var entry in jsonData['data']) {
            if (entry is Map<String, dynamic> && entry['imageURL'] is String) {
              final url = entry['imageURL'] as String;
              if (url.startsWith('http')) urls.add(url);
            }
          }
        } else if (jsonData['output'] is String) {
          final url = jsonData['output'] as String;
          if (url.startsWith('http')) urls.add(url);
        }
      } else if (jsonData is List) {
        for (var rootItem in jsonData) {
          if (rootItem is Map<String, dynamic>) {
            if (rootItem['data'] is List) {
              for (var entry in rootItem['data']) {
                if (entry is Map<String, dynamic> && entry['imageURL'] is String) {
                  final url = entry['imageURL'] as String;
                  if (url.startsWith('http')) urls.add(url);
                }
              }
            } else if (rootItem['output'] is String) {
              final url = rootItem['output'] as String;
              if (url.startsWith('http')) urls.add(url);
            }
          }
        }
      }

      // 3) Lưu lịch sử vào Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && urls.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('history')
            .add({
          'prompt': _promptController.text.trim(),
          'style': _selectedStyle,
          'numberOfImages': _numberOfImages,
          'imageUrls': urls,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 4) Cập nhật UI
      setState(() {
        _generatedImageUrls = urls;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            urls.isNotEmpty
                ? 'Đã tạo ${urls.length} ảnh thành công'
                : 'Không tìm thấy URL ảnh trong phản hồi',
          ),
        ),
      );
    } catch (e) {
      _timeoutTimer?.cancel();
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }


  Future<void> _saveAllImages() async {
    if (_generatedImageUrls.isEmpty) return;

    // Yêu cầu permission nếu cần
    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
        if (!status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cần cấp quyền lưu ảnh')),
          );
          return;
        }
      }
    }

    setState(() => _isLoading = true);

    int savedCount = 0;
    for (final url in _generatedImageUrls) {
      try {
        final resp = await http.get(Uri.parse(url));
        if (resp.statusCode == 200) {
          // Chỉ truyền vào bodyBytes, không có quality/name
          await FlutterImageGallerySaver.saveImage(resp.bodyBytes);
          savedCount++;
        }
      } catch (e) {
        debugPrint('Lỗi khi lưu ảnh $url: $e');
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('Đã lưu $savedCount/${_generatedImageUrls.length} ảnh')),
    );
    setState(() => _isLoading = false);
  }

  Future<void> _shareAllImages() async {
    if (_generatedImageUrls.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final tempDir = await getTemporaryDirectory();
      final List<XFile> files = [];

      for (var i = 0; i < _generatedImageUrls.length; i++) {
        final resp = await http.get(Uri.parse(_generatedImageUrls[i]));
        if (resp.statusCode == 200) {
          final file = File('${tempDir.path}/image_$i.jpg');
          await file.writeAsBytes(resp.bodyBytes);
          files.add(XFile(file.path));
        }
      }

      if (files.isNotEmpty) {
        await Share.shareXFiles(
          files,
          text: 'Ảnh được tạo bởi AI từ prompt: ${_promptController.text}',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể tải ảnh để chia sẻ')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi chia sẻ ảnh: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Thêm hàm mới để mở menu người dùng
  void _toggleUserMenu() {
    setState(() {
      _isUserMenuOpen = !_isUserMenuOpen;
    });
  }

  // Tạo các trang điều hướng mới
  void _navigateToPage(String pageName) {
    setState(() {
      _isUserMenuOpen = false;
    });

    // Hiển thị thông báo (Sau này sẽ thay bằng điều hướng thật)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đang chuyển đến: $pageName')),
    );

    // TODO: Bổ sung code điều hướng đến các trang khác tại đây
  }

  @override
  Widget build(BuildContext context) {
    // Lấy kích thước màn hình để điều chỉnh giao diện
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Generator'),
        centerTitle: true,
        actions: [
          // Nút avatar người dùng để mở menu
          IconButton(
            icon: const CircleAvatar(
              backgroundColor: Colors.blue,
              child: Icon(Icons.person, color: Colors.white),
            ),
            onPressed: _toggleUserMenu,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Phần nội dung chính
          SingleChildScrollView(
            padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _promptController,
                  decoration: InputDecoration(
                    hintText: 'Mô tả ảnh bạn muốn tạo...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelText: 'Mô tả ảnh',
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                if (isSmallScreen)
                  // Layout dọc cho màn hình nhỏ
                  Column(
                    children: [
                      _buildStyleDropdown(),
                      const SizedBox(height: 12),
                      _buildNumberDropdown(),
                    ],
                  )
                else
                  // Layout ngang cho màn hình thường
                  Row(
                    children: [
                      Expanded(child: _buildStyleDropdown()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumberDropdown()),
                    ],
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _promptController.text.isNotEmpty && !_isLoading
                      ? _generateImage
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text('Đang tạo (${_timeoutSeconds}s)...'),
                          ],
                        )
                      : const Text('Tạo ảnh',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 24),
                if (_isLoading)
                  // Hiển thị loading
                  Column(
                    children: [
                      const SizedBox(height: 40),
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text(
                        'Đang tạo ảnh, vui lòng đợi...\nTối đa $_timeoutSeconds giây',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  )
                else if (_generatedImageUrls.isNotEmpty)
                  // Hiển thị ảnh đã tạo
                  Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: _numberOfImages == 4 ? 2 : 1,
                            childAspectRatio: 1,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4,
                            children: _generatedImageUrls
                                .map((url) => Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.network(
                                          url,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child,
                                              loadingProgress) {
                                            if (loadingProgress == null)
                                              return child;
                                            return Center(
                                              child: CircularProgressIndicator(
                                                value: loadingProgress
                                                            .expectedTotalBytes !=
                                                        null
                                                    ? loadingProgress
                                                            .cumulativeBytesLoaded /
                                                        (loadingProgress
                                                                .expectedTotalBytes ??
                                                            1)
                                                    : null,
                                              ),
                                            );
                                          },
                                          errorBuilder: (c, e, s) =>
                                              const Center(
                                            child: Icon(Icons.error,
                                                size: 50, color: Colors.red),
                                          ),
                                        ),
                                        // Overlay gradient để làm nền cho text
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            height: 40,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                                colors: [
                                                  Colors.black.withOpacity(0.6),
                                                  Colors.transparent,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ))
                                .toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildActionButton(
                            icon: Icons.save_alt,
                            label: 'Lưu ảnh',
                            onPressed: !_isLoading ? _saveAllImages : null,
                            color: Colors.green,
                          ),
                          _buildActionButton(
                            icon: Icons.share,
                            label: 'Chia sẻ',
                            onPressed: !_isLoading ? _shareAllImages : null,
                            color: Colors.orange,
                          ),
                          _buildActionButton(
                            icon: Icons.refresh,
                            label: 'Tạo lại',
                            onPressed: !_isLoading
                                ? () {
                                    _promptController.clear();
                                    setState(() => _generatedImageUrls = []);
                                  }
                                : null,
                            color: Colors.blue,
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  // Container trống khi chưa có ảnh
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_search,
                          size: 60,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nhập mô tả và tạo ảnh',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Overlay menu người dùng
          if (_isUserMenuOpen)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: _toggleUserMenu,
                child: Container(
                  color: Colors.transparent,
                  height: MediaQuery.of(context).size.height,
                  child: Column(
                    children: [
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildMenuOption(
                              icon: Icons.history,
                              title: 'Lịch sử tạo ảnh',
                              onTap: () {
                                _toggleUserMenu();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const HistoryPage()),
                                );
                              },
                            ),
                            _buildMenuOption(
                              icon: Icons.favorite,
                              title: 'Ảnh đã lưu',
                              onTap: () => _navigateToPage('Ảnh đã lưu'),
                            ),
                            _buildMenuOption(
                              icon: Icons.settings,
                              title: 'Cài đặt',
                              onTap: () => _navigateToPage('Cài đặt'),
                            ),
                            _buildMenuOption(
                              icon: Icons.help_outline,
                              title: 'Trợ giúp',
                              onTap: () => _navigateToPage('Trợ giúp'),
                            ),
                            _buildMenuOption(
                              icon: Icons.account_circle,
                              title: 'Thông tin tài khoản',
                              onTap: () => _navigateToPage('Tài khoản'),
                            ),
                            const SizedBox(height: 8),
                            const Divider(),
                            const SizedBox(height: 8),
                            _buildMenuOption(
                              icon: Icons.logout,
                              title: 'Đăng xuất',
                              onTap: () => _navigateToPage('Đăng xuất'),
                              isDestructive: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Widget cho dropdown style
  Widget _buildStyleDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedStyle,
      decoration: InputDecoration(
        labelText: 'Phong cách',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      items: _styleOptions
          .map((style) => DropdownMenuItem(
                value: style,
                child: Text(style),
              ))
          .toList(),
      onChanged: (val) => setState(() => _selectedStyle = val),
    );
  }

  // Widget cho dropdown số lượng
  Widget _buildNumberDropdown() {
    return DropdownButtonFormField<int>(
      value: _numberOfImages,
      decoration: InputDecoration(
        labelText: 'Số lượng ảnh',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      items: const [
        DropdownMenuItem(value: 1, child: Text('1 ảnh')),
        DropdownMenuItem(value: 4, child: Text('4 ảnh')),
      ],
      onChanged: (val) => setState(() => _numberOfImages = val!),
    );
  }

  // Widget cho nút hành động
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // Widget cho tùy chọn menu
  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : Colors.blue,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : Colors.black87,
          fontWeight: isDestructive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: onTap,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }
}
