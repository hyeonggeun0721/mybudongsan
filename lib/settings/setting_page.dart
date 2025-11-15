// lib/settings/setting_page.dart
// 지도 타입 선택 및 상태 유지를 위한 설정 페이지

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // 현재 선택된 지도 타입을 저장하는 변수, 기본값은 'normal'
  MapType _selectedMapType = MapType.normal;

  @override
  void initState() {
    super.initState();
    // 페이지가 로드될 때 저장된 설정을 불러옵니다.
    _loadMapType();
  }

  /// SharedPreferences에서 저장된 지도 타입 불러오기
  Future<void> _loadMapType() async {
    final prefs = await SharedPreferences.getInstance();
    // 'mapType' 키로 저장된 int 값을 불러옵니다.
    // 저장된 값이 없으면 (??) 0 (MapType.normal의 인덱스)을 기본값으로 사용합니다.
    final int mapTypeIndex = prefs.getInt('mapType') ?? 0;
    setState(() {
      _selectedMapType = MapType.values[mapTypeIndex];
    });
  }

  /// SharedPreferences에 지도 타입 저장하기
  Future<void> _saveMapType(MapType mapType) async {
    final prefs = await SharedPreferences.getInstance();
    // MapType(enum)을 int(인덱스)로 변환하여 'mapType' 키로 저장합니다.
    await prefs.setInt('mapType', mapType.index);
    setState(() {
      _selectedMapType = mapType;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('지도 설정'),
      ),
      body: ListView(
        children: [
          // RadioListTile: 탭하기 편한 라디오 버튼
          RadioListTile<MapType>(
            title: const Text('일반 지도'),
            subtitle: const Text('표준 도로 지도입니다.'),
            value: MapType.normal,
            groupValue: _selectedMapType, // 현재 선택된 값
            onChanged: (value) {
              // 값이 변경되면 _saveMapType 함수를 호출해 저장
              if (value != null) _saveMapType(value);
            },
          ),
          RadioListTile<MapType>(
            title: const Text('위성 지도'),
            subtitle: const Text('위성 사진 지도입니다.'),
            value: MapType.satellite,
            groupValue: _selectedMapType,
            onChanged: (value) {
              if (value != null) _saveMapType(value);
            },
          ),
          RadioListTile<MapType>(
            title: const Text('하이브리드 지도'),
            subtitle: const Text('위성 사진에 도로명, 지명이 표시됩니다.'),
            value: MapType.hybrid,
            groupValue: _selectedMapType,
            onChanged: (value) {
              if (value != null) _saveMapType(value);
            },
          ),
        ],
      ),
    );
  }
}