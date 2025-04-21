import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'image_actions.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Bạn chưa đăng nhập'));
    }
    final histRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('history')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử tạo ảnh')),
      body: StreamBuilder<QuerySnapshot>(
        stream: histRef.snapshots(),
        builder: (ctx, snap) {
          if (snap.hasError) return Center(child: Text('Lỗi: ${snap.error}'));
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('Chưa có lịch sử'));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final urls = List<String>.from(data['imageUrls'] ?? []);
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: ExpansionTile(
                  title: Text(data['prompt'] ?? ''),
                  subtitle: Text((data['createdAt'] as Timestamp?)
                          ?.toDate()
                          .toLocal()
                          .toString() ??
                      ''),
                  children: [
                    SizedBox(
                        height: 200,
                        child: GridView.count(
                          crossAxisCount: urls.length == 4 ? 2 : 1,
                          children: urls
                              .map((u) => Image.network(u, fit: BoxFit.cover))
                              .toList(),
                        )),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.save_alt),
                            label: const Text('Lưu'),
                            onPressed: () async {
                              final count = await ImageActions.saveImages(urls);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Đã lưu $count/${urls.length} ảnh')),
                              );
                            },
                          ),
                          const SizedBox(width: 16),
                          TextButton.icon(
                            icon: const Icon(Icons.share),
                            label: const Text('Chia sẻ'),
                            onPressed: () {
                              ImageActions.shareImages(
                                  urls, data['prompt'] ?? '');
                            },
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
