import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase 초기화 로직이 여기에 포함되어 있어야 합니다.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '성문교회 중등부 출석부',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
      ),
      // ✅ AuthGate를 통해 로그인 상태에 따라 안전하게 화면을 분기합니다.
      home: const AuthGate(),
    );
  }
}

/// 🛡️ 로그인 상태 및 유저 정보를 안전하게 확인하여 화면을 결정하는 게이트
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. 연결 대기 중일 때 (로딩 화면)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // 2. 로그인되지 않았을 때 -> 로그인 화면으로
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }

        // 3. 로그인되었을 때 -> 유저 정보 확인 (비밀번호 변경 대상인지 체크)
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('teachers')
              .doc(snapshot.data!.uid)
              .get(),
          builder: (context, teacherSnap) {
            // 정보 로딩 중
            if (teacherSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            // 에러 발생 시 (빈 화면 방지를 위해 로그인 화면으로 튕기거나 에러 표시)
            if (teacherSnap.hasError || !teacherSnap.hasData) {
              return const LoginScreen();
            }

            final data = teacherSnap.data!.data() as Map<String, dynamic>?;
            
            // ✅ 여기서 비밀번호 변경 여부를 체크하는 로직 (예: isInitialPassword 가 true인지)
            bool mustChangePassword = data?['mustChangePassword'] ?? false;

            if (mustChangePassword) {
              return const PasswordChangeScreen();
            }

            // 모든 체크 통과 -> 메인 화면으로 (여기서는 임시로 Scaffold 표시)
            return const Scaffold(body: Center(child: Text("메인 화면 (출석부)")));
          },
        );
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  Future<void> _login() async {
    final String phoneNumber = _phoneController.text.trim();
    final String password = _passwordController.text.trim();

    if (phoneNumber.isEmpty || password.isEmpty) {
      _showSnackBar('전화번호와 비밀번호를 입력해주세요.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String emailFormat = phoneNumber.contains('@')
          ? phoneNumber
          : '$phoneNumber@sungmoon.com';

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailFormat,
        password: password,
      );
      // ✅ 로그인이 성공하면 AuthGate의 StreamBuilder가 자동으로 화면을 전환합니다.
    } on FirebaseAuthException catch (e) {
      String message = '로그인에 실패했습니다.';
      if (e.code == 'user-not-found') {
        message = '등록되지 않은 사용자입니다.';
      } else if (e.code == 'wrong-password') {
        message = '비밀번호가 일치하지 않습니다.';
      } else if (e.code == 'invalid-email') {
        message = '이메일 형식이 올바르지 않습니다.';
      }
      _showSnackBar(message);
    } catch (e) {
      _showSnackBar('오류가 발생했습니다. 다시 시도해주세요.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.church_rounded, size: size.height * 0.08, color: Colors.teal),
                const SizedBox(height: 16),
                const Text(
                  '성문교회 중등부',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal, letterSpacing: -0.5),
                ),
                const Text('스마트 출석부 시스템', style: TextStyle(fontSize: 13, color: Colors.blueGrey)),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: '전화번호',
                          hintText: '01012345678',
                          prefixIcon: const Icon(Icons.phone_android, size: 20),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                          labelText: '비밀번호',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility, size: 18),
                            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: size.width * 0.5,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shadowColor: Colors.teal.withValues(alpha: 0.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('로그인하기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  '계정 정보가 기억나지 않으시면\n부장선생님께 문의해주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500, height: 1.5),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 🔐 패스워드 변경 화면 (방어적으로 구성)
class PasswordChangeScreen extends StatelessWidget {
  const PasswordChangeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("비밀번호 변경"), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 60, color: Colors.orange),
            const SizedBox(height: 20),
            const Text(
              "안전한 이용을 위해\n비밀번호를 변경해주세요.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            // 여기에 비밀번호 변경 폼 추가...
            ElevatedButton(
              onPressed: () {
                // 로그아웃 시키기 예시
                FirebaseAuth.instance.signOut();
              },
              child: const Text("로그아웃"),
            )
          ],
        ),
      ),
    );
  }
}