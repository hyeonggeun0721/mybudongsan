// lib/map/map_page.dart
// 지도 기반 Firestore 데이터 시각화 및 geoFire 반경 검색 + 상세페이지 이동 기능

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ✅ Firestore 및 geoFire 관련 패키지 임포트
import 'package:cloud_firestore/cloud_firestore.dart';
import '../geoFire/geoflutterfire.dart';
import '../geoFire/models/point.dart';

import 'map_filter.dart';
import 'map_filter_dialog.dart';
import 'apt_page.dart'; // ✅ 추가: 상세페이지 이동용 import

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPage();
}

class _MapPage extends State<MapPage> {
  int currentItem = 0; // 현재 하단 탭 상태
  MapFilter mapFilter = MapFilter(); // 필터 정보 저장 객체

  late Completer<GoogleMapController> _controller =
  Completer<GoogleMapController>(); // ✅ late로 재생성 가능

  Map<MarkerId, Marker> markers = <MarkerId, Marker>{}; // 지도 마커 집합
  MarkerId? selectedMarker;
  BitmapDescriptor markerIcon = BitmapDescriptor.defaultMarker;
  late List<DocumentSnapshot> allDocuments =
  List<DocumentSnapshot>.empty(growable: true); // Firestore 원본 데이터 (400개)
  late List<DocumentSnapshot> documentList =
  List<DocumentSnapshot>.empty(growable: true); // 필터링된 데이터 (260개)

  static const CameraPosition _googleMapCamera = CameraPosition(
    target: LatLng(37.571320, 127.029043), // 서울 성북구 중심
    zoom: 15.0,
  );

  @override
  void initState() {
    super.initState();
    addCustomIcon();
  }

  // ✅ 사용자 정의 마커 아이콘 생성
  void addCustomIcon() {
    BitmapDescriptor.asset(
      const ImageConfiguration(),
      'res/images/apartment.png',
      width: 50,
      height: 50,
    ).then((icon) {
      setState(() {
        markerIcon = icon;
      });
    });
  }

  // ✅ Firestore + geoFire 기반 지도 반경 검색 (print문 제거)
  Future<void> _searchApt() async {
    final GoogleMapController controller = await _controller.future;
    final bounds = await controller.getVisibleRegion();

    final LatLng centerBounds = LatLng(
      (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
      (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
    );

    final aptRef = FirebaseFirestore.instance.collection('cities');
    final geo = Geoflutterfire();

    final GeoFirePoint center = geo.point(
      latitude: centerBounds.latitude,
      longitude: centerBounds.longitude,
    );

    const double radius = 50; // 🔍 반경 확장
    const String field = 'position';

    final Stream<List<DocumentSnapshot>> stream = geo
        .collection(collectionRef: aptRef)
        .within(center: center, radius: radius, field: field);

    stream.listen((List<DocumentSnapshot> documentList) {
      // 1. 원본 400개를 allDocuments에 저장
      this.allDocuments = documentList;
      // 2. 필터링 및 그리기 함수를 '최초 1회' 호출
      _applyFilterAndRedraw();
    }, onError: (error) {
      debugPrint("Firestore Stream Error: $error");
    });
  }

  // ✅ (새로운 함수) 원본 데이터를 현재 필터로 거르고 화면을 갱신합니다.
  void _applyFilterAndRedraw() {

    // 1. '임시 마커 바구니' (지도용)
    final Map<MarkerId, Marker> newMarkers = {};
    // 2. '임시 리스트 바구니' (목록용)
    final List<DocumentSnapshot> filteredList = [];

    // 3. 260개 리스트가 아닌 '원본 400개' 리스트(allDocuments)를 순회
    for (final DocumentSnapshot doc in allDocuments) {
      final Map<String, dynamic> info = doc.data() as Map<String, dynamic>;

      // 4. 현재 'mapFilter' 값으로 필터링 실행
      if (selectedCheck(
        info,
        mapFilter.peopleString,
        mapFilter.carString,
        mapFilter.buildingString,
      )) {

        // 5. 필터 통과시, 마커 바구니에 추가
        final MarkerId markerId = MarkerId(info['position']['geohash']);
        final Marker marker = Marker(
          markerId: markerId,
          position: LatLng(
            (info['position']['geopoint'] as GeoPoint).latitude,
            (info['position']['geopoint'] as GeoPoint).longitude,
          ),
          icon: markerIcon,
          infoWindow: InfoWindow(
            title: info['name'],
            snippet: info['address'],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AptPage(
                    aptHash: info['position']['geohash'],
                    aptInfo: info,
                  ),
                ),
              );
            },
          ),
        );
        newMarkers[markerId] = marker;

        // 6. 필터 통과시, 리스트 바구니에도 추가
        filteredList.add(doc);
      }
    }

    // 7. '단 한 번'의 setState로 지도와 리스트를 동시에 갱신
    setState(() {
      markers = newMarkers;        // 👈 1. 맵 갱신
      this.documentList = filteredList; // 👈 2. 리스트 갱신
    });
  }

  // ✅ 필터 조건 비교 (print문 제거)
  bool selectedCheck(
      Map<String, dynamic> info,
      String? peopleString,
      String? carString,
      String? buildingString,
      ) {
    try {
      final double dong = (info['ALL_DONG_CO'] ?? 0.0).toDouble();
      final double people = (info['ALL_HSHLD_CO'] ?? 0.0).toDouble();
      final double parkingCount = (info['CNT_PA'] ?? 0.0).toDouble();

      final int buildFilter = int.parse(buildingString ?? '0');
      final int peopleFilter = int.parse(peopleString ?? '0');

      final double parking;
      if (parkingCount == 0.0) {
        parking = 0.0;
      } else {
        parking = people / parkingCount;
      }

      if (dong < buildFilter) return false;
      if (people < peopleFilter) return false;

      if (carString == '1') {
        return parking < 1;
      } else {
        return parking >= 1;
      }
    } catch (e) {
      // 오류가 발생하면 콘솔에만 조용히 기록합니다.
      debugPrint("Filter Error: $e, Data: $info");
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My 부동산'),
        actions: [
          IconButton(
            onPressed: () async {
              var result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => MapFilterDialog(mapFilter),
                ),
              );
              if (result != null) {
                // 1. 바뀐 필터 값을 저장하고
                setState(() {
                  mapFilter = result as MapFilter;
                });

                // 2. ★★★ 지도와 상관없는 '필터링 함수'를 호출! ★★★
                _applyFilterAndRedraw();
              }
            },
            icon: const Icon(Icons.search),
          ),
        ],
      ),

      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: const [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('김형근',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  Text('polkmn0517@pusan.ac.kr',
                      style: TextStyle(fontSize: 16, color: Colors.white)),
                ],
              ),
            ),
            ListTile(title: Text('내가 선택한 아파트')),
            ListTile(title: Text('설정')),
          ],
        ),
      ),

      // ✅ 지도 ↔ 목록 전환 (Stack/테스트 코드 제거 + emptyBuilder 로직 추가)
      body: currentItem == 0
          ? GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: _googleMapCamera,
        onMapCreated: (GoogleMapController controller) {
          if (!_controller.isCompleted) {
            _controller.complete(controller);
          }
        },
        markers: Set<Marker>.of(markers.values),
      )

      // 👇👇👇 'list' 탭 코드가 여기서부터 바뀝니다 👇👇👇
          : documentList.isEmpty // 1. 먼저 리스트가 비어있는지 확인
          ? const Center(
        child: Text( // 2. 비어있다면 이 메시지를 표시
          '필터 조건에 맞는 매매 데이터가 없습니다.',
          style: TextStyle(fontSize: 16),
        ),
      )
          : ListView.builder( // 3. 비어있지 않다면, 원래의 리스트를 표시
        itemBuilder: (context, value) {
          Map<String, dynamic> item =
          documentList[value].data() as Map<String, dynamic>;
          return InkWell(
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.apartment),
                title: Text(item['name']),
                subtitle: Text(item['address']),
                trailing: const Icon(Icons.arrow_circle_right_sharp),
              ),
            ),
            // ✅ 목록 클릭 시 상세 페이지로 이동
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AptPage(
                    aptHash: item['position']['geohash'], // 오타 수정: geohash
                    aptInfo: item,
                  ),
                ),
              );
            },
          );
        },
        itemCount: documentList.length,
      ),

      // ✅ 지도 복원 로직
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentItem,
        onTap: (value) {
          if (value == 0) {
            _controller = Completer<GoogleMapController>();
          }
          setState(() {
            currentItem = value;
          });
        },
        items: const [
          BottomNavigationBarItem(label: 'map', icon: Icon(Icons.map)),
          BottomNavigationBarItem(label: 'list', icon: Icon(Icons.list)),
        ],
      ),

      floatingActionButton: currentItem == 0 // 👈 1. 'map' 탭일 때만
          ? FloatingActionButton.extended(
        onPressed: _searchApt,
        label: const Text('이 위치로 검색하기'),
      )
          : null, // 👈 2. 'list' 탭일 때는 버튼을 숨김(null)
    );
  }
}
