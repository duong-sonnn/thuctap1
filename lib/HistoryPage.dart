import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'image_actions.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String _selectedCategory = 'all';
  String _sortOrder = 'desc';
  final List<String> _categories = [
    'all',
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
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Bạn chưa đăng nhập'));
    }

    Query<Map<String, dynamic>> histRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('history')
        .orderBy('createdAt', descending: _sortOrder == 'desc');

    if (_selectedCategory != 'all') {
      histRef = histRef.where('style', isEqualTo: _selectedCategory);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử tạo ảnh'),
        actions: [
          DropdownButton<String>(
            value: _sortOrder,
            items: const [
              DropdownMenuItem(value: 'desc', child: Text('Mới nhất')),
              DropdownMenuItem(value: 'asc', child: Text('Cũ nhất')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _sortOrder = value;
                });
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: _categories
                    .map((category) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ChoiceChip(
                            label: Text(category),
                            selected: _selectedCategory == category,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedCategory = category;
                                });
                              }
                            },
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: histRef.snapshots(),
              builder: (ctx, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Lỗi: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('Chưa có lịch sử'));
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final urls = List<String>.from(data['imageUrls'] ?? []);
                    return GestureDetector(
                      onTap: () => _showImageDetails(context, data, urls),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: Image.network(
                          urls.first,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.error),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showImageDetails(BuildContext context, Map<String, dynamic> data, List<String> urls) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['prompt'] ?? '',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  (data['createdAt'] as Timestamp?)?.toDate().toLocal().toString() ?? '',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: GridView.count(
                    crossAxisCount: urls.length == 4 ? 2 : 1,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    children: urls
                        .map((u) => Image.network(u, fit: BoxFit.cover))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.save_alt),
                      label: const Text('Lưu'),
                      onPressed: () async {
                        final count = await ImageActions.saveImages(urls);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Đã lưu $count/${urls.length} ảnh')),
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    TextButton.icon(
                      icon: const Icon(Icons.share),
                      label: const Text('Chia sẻ'),
                      onPressed: () {
                        ImageActions.shareImages(urls, data['prompt'] ?? '');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}