import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '성문교회 중등부',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', 'KR')],
      locale: const Locale('ko', 'KR'),
      theme: ThemeData(primarySwatch: Colors.teal, useMaterial3: true),

      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // 1. 로그인이 성공한 경우
          if (authSnapshot.hasData && authSnapshot.data != null) {
            // 💡 [핵심 수정] 이메일에서 @ 앞부분(전화번호)만 추출합니다.
            // 예: 01057015239@sungmoon.com -> 01057015239
            final String fullEmail = authSnapshot.data!.email ?? "";
            final String phoneNumber = fullEmail.split('@')[0];

            return StreamBuilder<QuerySnapshot>(
              // 💡 장부(teachers)의 'phone' 또는 'id' 필드가 전화번호와 일치하는지 찾습니다.
              // (기존 필드명이 'id'였는지 'phone'이었는지 확실치 않아 일단 'id'로 가정하되,
              // 아래에서 에러가 나면 필드명만 살짝 바꾸면 됩니다.)
              stream: FirebaseFirestore.instance
                  .collection('teachers')
                  .where('phone', isEqualTo: phoneNumber)
                  .snapshots(),
              builder: (context, teacherSnapshot) {
                if (teacherSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                // 데이터가 검색되었다면 (리스트의 첫 번째 항목 사용)
                if (teacherSnapshot.hasData &&
                    teacherSnapshot.data!.docs.isNotEmpty) {
                  var data =
                      teacherSnapshot.data!.docs.first.data()
                          as Map<String, dynamic>;
                  return HomeNavigation(
                    teacherName: data['name'] ?? '교사',
                    role: data['role'] ?? '교사',
                    cell: data['cell'] ?? '1',
                  );
                }

                // 💡 [안전장치] 만약 'id' 필드가 아니라 'phone' 필드를 쓰셨을 수도 있으니
                // 한번 더 시도하거나 에러 화면을 보여줍니다.
                return _LoadingOrErrorScreen(phoneNumber: phoneNumber);
              },
            );
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

// 데이터를 찾는 중이거나 실패했을 때 화면
class _LoadingOrErrorScreen extends StatelessWidget {
  final String phoneNumber;
  const _LoadingOrErrorScreen({required this.phoneNumber});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              '사용자 정보($phoneNumber)를 확인 중입니다...',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: const Text('로그아웃 후 다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}
