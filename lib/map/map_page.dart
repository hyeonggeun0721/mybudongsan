// lib/map/map_page.dart
// 지도 기반 Firestore 데이터 시각화 및 geoFire 반경 검색 + 상세페이지 이동 기능

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../geoFire/geoflutterfire.dart';
import '../geoFire/models/point.dart';

import 'map_filter.dart';
import 'map_filter_dialog.dart';
import 'apt_page.dart';
import '../myFavorite/my_favorite_page.dart';
import '../settings/setting_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPage();
}

class _MapPage extends State<MapPage> {
  int currentItem = 0;
  MapFilter mapFilter = MapFilter();

  late Completer<GoogleMapController> _controller =
  Completer<GoogleMapController>();

  Map<MarkerId, Marker> markers = <MarkerId, Marker>{};
  MarkerId? selectedMarker;
  BitmapDescriptor markerIcon = BitmapDescriptor.defaultMarker;
  late List<DocumentSnapshot> allDocuments =
  List<DocumentSnapshot>.empty(growable: true);
  late List<DocumentSnapshot> documentList =
  List<DocumentSnapshot>.empty(growable: true);
  MapType _currentMapType = MapType.normal; // 기본값 normal

  static const CameraPosition _googleMapCamera = CameraPosition(
    target: LatLng(37.571320, 127.029043),
    zoom: 15.0,
  );

  @override
  void initState() {
    super.initState();
    addCustomIcon();
    _loadMapType(); // 👈 페이지 시작 시 저장된 지도 타입 불러오기
  }

  Future<void> _loadMapType() async {
    final prefs = await SharedPreferences.getInstance();
    final int mapTypeIndex = prefs.getInt('mapType') ?? 0;
    setState(() {
      _currentMapType = MapType.values[mapTypeIndex];
    });
  }

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

    const double radius = 50;
    const String field = 'position';

    final Stream<List<DocumentSnapshot>> stream = geo
        .collection(collectionRef: aptRef)
        .within(center: center, radius: radius, field: field);

    stream.listen((List<DocumentSnapshot> documentList) {
      allDocuments = documentList;
      _applyFilterAndRedraw();
    }, onError: (error) {
      debugPrint("Firestore Stream Error: $error");
    });
  }

  void _applyFilterAndRedraw() {
    final Map<MarkerId, Marker> newMarkers = {};
    final List<DocumentSnapshot> filteredList = [];

    for (final DocumentSnapshot doc in allDocuments) {
      final Map<String, dynamic> info = doc.data() as Map<String, dynamic>;

      if (selectedCheck(
        info,
        mapFilter.peopleString,
        mapFilter.carString,
        mapFilter.buildingString,
      )) {
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
        filteredList.add(doc);
      }
    }
    setState(() {
      markers = newMarkers;
      documentList = filteredList;
    });
  }

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
                setState(() {
                  mapFilter = result as MapFilter;
                });
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
          children: [
            const DrawerHeader(
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
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('내가 선택한 아파트'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MyFavoritePage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('설정'),
              onTap: () async { // 👈 'async' 추가
                Navigator.pop(context); // Drawer 닫기

                // 👈 'await' 추가: SettingsPage가 닫힐 때까지 기다림
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsPage()),
                );

                // 👈 SettingsPage가 닫히면, 저장된 값을 다시 불러옴!
                _loadMapType();
              },
            ),
          ],
        ),
      ),

      body: currentItem == 0
          ? GoogleMap(
        mapType: _currentMapType,
        initialCameraPosition: _googleMapCamera,
        onMapCreated: (GoogleMapController controller) {
          if (!_controller.isCompleted) {
            _controller.complete(controller);
          }
        },
        markers: Set<Marker>.of(markers.values),
        myLocationButtonEnabled: false, // '내 위치' 버튼 숨기기
      )
          : documentList.isEmpty
          ? const Center(
        child: Text(
          '필터 조건에 맞는 매매 데이터가 없습니다.',
          style: TextStyle(fontSize: 16),
        ),
      )
          : ListView.builder(
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
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AptPage(
                    aptHash: item['position']['geohash'],
                    aptInfo: item,
                  ),
                ),
              );
            },
          );
        },
        itemCount: documentList.length,
      ),

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

      floatingActionButton: currentItem == 0
          ? FloatingActionButton.extended(
        onPressed: _searchApt,
        label: const Text('이 위치로 검색하기'),
        //backgroundColor: Colors.blue,
      )
          : null,
    );
  }
}