import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
// 폰트 적용을 위한 패키지 임포트
import 'package:google_fonts/google_fonts.dart';

// 실제 프로젝트의 파일 경로입니다. 파일명이 다르면 수정해주세요.
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 💡 웹 환경에서 폰트 렌더링 문제를 방지하기 위해 런타임 페칭 허용 설정
  GoogleFonts.config.allowRuntimeFetching = true;

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
      // 한국어 로컬라이징 설정
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', 'KR')],
      locale: const Locale('ko', 'KR'),
      
      // 💡 앱 전체 테마 설정 (copyWith 대신 생성자에서 직접 설정)
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        
        // 1. 전역 폰트 패밀리 지정 (ThemeData 생성자에서 직접 설정)
        fontFamily: GoogleFonts.notoSansKr().fontFamily,
        
        // 2. 모든 텍스트 테마에 Noto Sans KR 적용
        textTheme: GoogleFonts.notoSansKrTextTheme(),
        primaryTextTheme: GoogleFonts.notoSansKrTextTheme(),
      ),
      
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (authSnapshot.hasData && authSnapshot.data != null) {
            final String phoneNumber = authSnapshot.data!.email!.split('@')[0];

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('teachers')
                  .where('phone', isEqualTo: phoneNumber)
                  .snapshots(),
              builder: (context, teacherSnapshot) {
                if (teacherSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (teacherSnapshot.hasData && teacherSnapshot.data!.docs.isNotEmpty) {
                  var doc = teacherSnapshot.data!.docs.first;
                  var data = doc.data() as Map<String, dynamic>;

                  bool isFirstLogin = data['isFirstLogin'] ?? false;

                  if (isFirstLogin) {
                    return ChangePasswordScreen(
                      user: authSnapshot.data!,
                      docId: doc.id,
                      isMandatory: true,
                    );
                  }

                  return HomeNavigation(
                    teacherName: data['name'] ?? '교사',
                    role: data['role'] ?? '교사',
                    cell: data['cell'] ?? '1',
                    docId: doc.id,
                  );
                }
                return _ErrorScreen(phoneNumber: phoneNumber);
              },
            );
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

/// 📱 비밀번호 변경 화면
class ChangePasswordScreen extends StatefulWidget {
  final User user;
  final String docId;
  final bool isMandatory;

  const ChangePasswordScreen({
    super.key,
    required this.user,
    required this.docId,
    this.isMandatory = false,
  });

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldPwController = TextEditingController();
  final _pwController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;

  Future<void> _updatePassword() async {
    final oldPassword = _oldPwController.text.trim();
    final password = _pwController.text.trim();
    final confirm = _confirmController.text.trim();

    if (oldPassword.isEmpty || password.length < 6 || password != confirm) {
      _showMsg('입력 정보를 다시 확인해주세요.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: widget.user.email!,
        password: oldPassword,
      );
      await widget.user.reauthenticateWithCredential(credential);
      await widget.user.updatePassword(password);

      if (widget.isMandatory) {
        await FirebaseFirestore.instance
            .collection('teachers')
            .doc(widget.docId)
            .update({'isFirstLogin': false});
      }

      if (!mounted) return;
      _showMsg('비밀번호가 변경되었습니다.');
      if (!widget.isMandatory) Navigator.of(context).pop();
    } catch (e) {
      _showMsg('오류가 발생했습니다: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.isMandatory ? null : AppBar(title: const Text('비밀번호 변경')),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.lock_reset_rounded, size: 80, color: Colors.teal),
            const SizedBox(height: 24),
            const Text('안전한 이용을 위해 비밀번호를 변경해주세요.', textAlign: TextAlign.center),
            const SizedBox(height: 40),
            TextField(controller: _oldPwController, obscureText: true, decoration: const InputDecoration(labelText: '현재 비밀번호')),
            TextField(controller: _pwController, obscureText: true, decoration: const InputDecoration(labelText: '새 비밀번호')),
            TextField(controller: _confirmController, obscureText: true, decoration: const InputDecoration(labelText: '새 비밀번호 확인')),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updatePassword,
                child: _isLoading ? const CircularProgressIndicator() : const Text('변경 완료'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String phoneNumber;
  const _ErrorScreen({required this.phoneNumber});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text('사용자($phoneNumber) 정보를 찾을 수 없습니다.'),
            TextButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('로그아웃')),
          ],
        ),
      ),
    );
  }
}