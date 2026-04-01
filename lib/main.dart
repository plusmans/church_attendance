import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart'; // 쪼개놓은 로그인 방을 불러옵니다!

void main() async {
  // 앱이 켜지기 전에 파이어베이스부터 안전하게 준비시킵니다.
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const ChurchApp());
}

class ChurchApp extends StatelessWidget {
  const ChurchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '부천성문교회 중등부',
      debugShowCheckedModeBanner: false, // 오른쪽 위 디버그 띠 제거
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const LoginScreen(), // 🎉 앱을 켜면 무조건 로그인 화면부터 시작!
    );
  }
}
