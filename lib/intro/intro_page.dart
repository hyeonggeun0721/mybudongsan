import 'package:flutter/material.dart';
import '../map/map_page.dart'; // MapPage import

class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {

      // --- 💡 [수정된 부분] ---
      // 2초 후에 이 코드가 실행될 때,
      // 페이지가 여전히 화면에 있는지(mounted) 확인합니다.
      if (!mounted) return;
      // --- 여기까지 수정 ---

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) {
          return const MapPage();
        }),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'My 부동산',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
