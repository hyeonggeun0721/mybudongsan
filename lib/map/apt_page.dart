// lib/map/apt_page.dart
// 아파트 상세 페이지 및 거래 내역 표시 예제

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ui_firestore/firebase_ui_firestore.dart';
import 'package:flutter/material.dart';

class AptPage extends StatefulWidget {
  final String aptHash;
  final Map<String, dynamic> aptInfo;

  const AptPage({
    super.key,
    required this.aptHash,
    required this.aptInfo
  });

  @override
  State<AptPage> createState() => _AptPageState();
}

class _AptPageState extends State<AptPage> {
  late final CollectionReference<Map<String, dynamic>> _aptRef;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // 추가
  int _startYear = 2006; // 시작 연도
  bool _isFavorite = false; // 찜 상태 관리

  @override
  void initState() {
    super.initState();
    _aptRef = FirebaseFirestore.instance.collection('wydmu17me');
    _checkFavorite(); // 찜 여부 확인
  }

  // 찜 상태 확인 함수
  Future<void> _checkFavorite() async {
    final doc = await _firestore
        .collection('favorites')
        .doc(widget.aptHash)
        .get();
    if (doc.exists) {
      setState(() {
        _isFavorite = true;
      });
    }
  }

  // 찜 상태 변경 함수
  Future<void> _toggleFavorite() async {
    if (_isFavorite) {
      // 이미 즐겨찾기 상태면 -> Firestore에서 삭제
      await _firestore.collection('favorites').doc(widget.aptHash).delete();
    } else {
      // 즐겨찾기가 아니면 -> Firestore에 추가
      // favorites 컬렉션에 aptId를 문서 ID로, aptData를 내용으로 저장
      await _firestore.collection('favorites').doc(widget.aptHash).set({
        ...widget.aptInfo, // 👈 ★★★ 여기에 ... (점 3개)가 필요합니다.
        'timestamp': FieldValue.serverTimestamp(), // 👈 현재 시간 저장
      });
    }

    // 아이콘 상태를 즉시 업데이트
    setState(() {
      _isFavorite = !_isFavorite;
    });
  }

  @override
  Widget build(BuildContext context) {
    final usersQuery = _aptRef
        .orderBy('deal_ymd')
        .where('deal_ymd', isGreaterThanOrEqualTo: '${_startYear}0000');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.aptInfo['name']),
        actions: [
          IconButton(
            onPressed: _toggleFavorite,
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : Colors.grey, // 즐겨찾기 하트 버튼 기능 추가
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          _buildAptInfo(widget.aptInfo),

          Container(
            color: Colors.black,
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 5),
          ),

          Text('검색 시작 연도: $_startYear년'),

          Slider(
            value: _startYear.toDouble(),
            onChanged: (value) {
              setState(() {
                _startYear = value.toInt();
              });
            },
            min: 2006,
            max: 2023,
          ),

          Expanded(
            child: FirestoreListView<Map<String, dynamic>>(
              query: usersQuery,
              pageSize: 20,
              itemBuilder: (context, snapshot) {
                if (!snapshot.exists) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                Map<String, dynamic> apt = snapshot.data();
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('계약 일자: ${apt['deal_ymd']}'),
                              Text('계약 층수: ${apt['floor']}층'),
                              Text(
                                '계약 가격: ${(double.parse(apt['obj_amt']) / 10000).toStringAsFixed(1)}억',
                              ),
                              Text('전용 면적: ${apt['bldg_area']}㎡'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },

              emptyBuilder: (context) =>
              const Center(child: Text('매매 데이터가 없습니다.')),

              errorBuilder: (context, err, stack) =>
              const Center(child: Text('데이터를 불러오는 중 오류가 발생했습니다.')),
            ),
          ),
        ],
      ),
    );
  }

  // 아파트 기본 정보 표시 위젯
  Widget _buildAptInfo(Map<String, dynamic> aptInfo) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('아파트 이름: ${aptInfo['name']}'),
          Text('아파트 주소: ${aptInfo['address']}'),
          Text('아파트 동 수: ${aptInfo['ALL_DONG_CO']}'),
          Text('아파트 세대 수: ${aptInfo['ALL_HSHLD_CO']}'),
          Text('아파트 주차 수: ${aptInfo['CNT_PA']}'),
          Text('60㎡~85㎡ 이하 평형 세대 수: ${aptInfo['KAPTMPAREA68']}'),
          Text('85㎡~135㎡ 이하 평형 세대 수: ${aptInfo['KAPTMPAREA85']}'),
        ],
      ),
    );
  }
}
