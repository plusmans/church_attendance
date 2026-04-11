import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 📱 입력 컨트롤러
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false; // 비밀번호 숨김/표시 상태

  Future<void> _login() async {
    final String phoneNumber = _phoneController.text.trim();
    final String password = _passwordController.text.trim();

    if (phoneNumber.isEmpty || password.isEmpty) {
      _showSnackBar('전화번호와 비밀번호를 입력해주세요.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 💡 입력받은 전화번호 뒤에 @sungmoon.com 자동 결합
      final String emailFormat = phoneNumber.contains('@')
          ? phoneNumber
          : '$phoneNumber@sungmoon.com';

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailFormat,
        password: password,
      );
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
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating, // 모바일에서 보기 편한 플로팅 스타일
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 모바일 화면 크기에 따른 유동적인 디자인을 위한 미디어 쿼리
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      // 모바일 앱 느낌을 주는 부드러운 배경색
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. 상단 로고 영역
                Icon(
                  Icons.church_rounded,
                  size: size.height * 0.08,
                  color: Colors.teal,
                ),
                const SizedBox(height: 16),
                const Text(
                  '성문교회 중등부',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                    letterSpacing: -0.5,
                  ),
                ),
                const Text(
                  '스마트 출석부 시스템',
                  style: TextStyle(fontSize: 13, color: Colors.blueGrey),
                ),
                const SizedBox(height: 40),

                // 2. 로그인 폼 (카드형 디자인)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        // ✅ Lint: withOpacity -> withValues 대체
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // 전화번호 입력
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
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 비밀번호 입력
                      TextField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                          labelText: '비밀번호',
                          prefixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            size: 20,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 18,
                            ),
                            onPressed: () {
                              setState(
                                () => _isPasswordVisible = !_isPasswordVisible,
                              );
                            },
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // 3. ✅ 로그인 버튼 (크기 최소화: 너비 50%, 높이 46)
                SizedBox(
                  width: size.width * 0.5,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      elevation: 1,
                      // ✅ Lint: withOpacity -> withValues 대체
                      shadowColor: Colors.teal.withValues(alpha: 0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(23),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            '로그인하기',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 40),
                // 4. 하단 도움말
                Text(
                  '계정 정보가 기억나지 않으시면\n부장선생님께 문의해주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    height: 1.5,
                  ),
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