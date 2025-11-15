// lib/myFavorite/my_favorite_page.dart
// 내가 선택한 아파트를 보여주는 즐겨찾기 페이지

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../map/apt_page.dart';

class MyFavoritePage extends StatelessWidget {
  const MyFavoritePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내가 선택한 아파트'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // favorites 컬렉션의 문서를 timestamp 기준으로 정렬
        stream: FirebaseFirestore.instance
            .collection('favorites')
            .orderBy('timestamp', descending: true) // 👈 (주의) apt_page.dart에서 timestamp 저장을 추가했어야 합니다.
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('즐겨찾기한 아파트가 없습니다.'));
          }

          var favorites = snapshot.data!.docs;

          return ListView.builder(
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              var doc = favorites[index]; // DocumentSnapshot
              var data = doc.data() as Map<String, dynamic>; // 아파트 정보 (aptInfo)
              var aptHash = doc.id; // 문서 ID (aptHash)

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(data['name'] ?? '이름 없음'),
                  subtitle: Text(data['address'] ?? '주소 없음'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AptPage(
                          aptHash: aptHash, // 👈 ID(hash) 전달
                          aptInfo: data,    // 👈 정보(info) 전달
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}