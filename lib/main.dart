import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// 실제 프로젝트의 파일 경로입니다. 파일명이 다르면 수정해주세요.
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
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
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
                if (teacherSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (teacherSnapshot.hasData &&
                    teacherSnapshot.data!.docs.isNotEmpty) {
                  var doc = teacherSnapshot.data!.docs.first;
                  var data = doc.data() as Map<String, dynamic>;

                  bool isFirstLogin = data['isFirstLogin'] ?? false;

                  // 💡 첫 로그인(강제 변경) 상태 체크
                  if (isFirstLogin) {
                    return ChangePasswordScreen(
                      user: authSnapshot.data!,
                      docId: doc.id,
                      isMandatory: true,
                    );
                  }

                  // 💡 일반 메인 화면으로 이동할 때 docId를 함께 전달합니다.
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

/// 📱 비밀번호 변경 화면 (첫 로그인 강제 변경 및 일반 변경 겸용)
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

    if (oldPassword.isEmpty) {
      _showMsg('현재 비밀번호를 입력해주세요.');
      return;
    }
    if (password.length < 6) {
      _showMsg('새 비밀번호는 최소 6자리 이상이어야 합니다.');
      return;
    }

    // 💡 [추가] 새 비밀번호가 현재 비밀번호와 동일한지 체크
    if (oldPassword == password) {
      _showMsg('새 비밀번호는 현재 비밀번호와 다르게 설정해야 합니다.');
      return;
    }

    if (password != confirm) {
      _showMsg('새 비밀번호 확인이 일치하지 않습니다.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. 현재 비밀번호로 재인증
      AuthCredential credential = EmailAuthProvider.credential(
        email: widget.user.email!,
        password: oldPassword,
      );
      await widget.user.reauthenticateWithCredential(credential);

      // 2. Auth 비밀번호 업데이트
      await widget.user.updatePassword(password);

      // 3. Firestore 필드 업데이트 (첫 로그인인 경우에만)
      if (widget.isMandatory) {
        await FirebaseFirestore.instance
            .collection('teachers')
            .doc(widget.docId)
            .update({'isFirstLogin': false});
      }

      if (!mounted) return;
      _showMsg('비밀번호가 성공적으로 변경되었습니다!');

      if (!widget.isMandatory) {
        Navigator.of(context).pop(); // 일반 모드면 이전 화면으로
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        _showMsg('현재 비밀번호가 일치하지 않습니다.');
      } else {
        _showMsg('오류: ${e.message}');
      }
    } catch (e) {
      _showMsg('오류가 발생했습니다: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: widget.isMandatory
          ? null
          : AppBar(
              title: const Text(
                '비밀번호 변경',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              centerTitle: true,
              elevation: 0,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Icon(
                Icons.lock_reset_rounded,
                size: 80,
                color: Colors.teal,
              ),
              const SizedBox(height: 24),
              Text(
                widget.isMandatory
                    ? '첫 로그인을 환영합니다!\n비밀번호를 변경해주세요.'
                    : '비밀번호를 안전하게\n변경합니다.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _oldPwController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: '현재 비밀번호',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 32),
              TextField(
                controller: _pwController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: '새 비밀번호',
                  hintText: '6자리 이상 입력',
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: '새 비밀번호 확인',
                  prefixIcon: const Icon(Icons.check_circle_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updatePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          '변경 완료',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  if (widget.isMandatory) {
                    FirebaseAuth.instance.signOut();
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(
                  widget.isMandatory ? '취소 및 로그아웃' : '돌아가기',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
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
            TextButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: const Text('로그아웃'),
            ),
          ],
        ),
      ),
    );
  }
}
