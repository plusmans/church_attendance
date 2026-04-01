import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_navigation.dart'; // 방금 만든 하단 탭 바 파일을 불러옵니다!

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();

  Future<void> _tryLogin() async {
    String inputPhone = _idController.text.trim();
    String inputPassword = _pwController.text.trim();

    if (inputPhone.isEmpty || inputPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아이디(전화번호)와 비밀번호를 모두 입력해주세요.')),
      );
      return;
    }

    String finalEmail = "$inputPhone@sungmoon.com";

    try {
      // 1. 파이어베이스 Auth 로그인
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: finalEmail,
        password: inputPassword,
      );

      // 2. DB에서 교사 정보 찾기
      var teacherQuery = await FirebaseFirestore.instance
          .collection('teachers')
          .where('phone', isEqualTo: inputPhone)
          .get();

      if (teacherQuery.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('DB에 등록된 교사 정보가 없습니다.')));
        }
        return;
      }

      // 3. 교사 정보 획득!
      var teacherData = teacherQuery.docs.first.data();
      String cell = teacherData['cell'] ?? '';
      String role = teacherData['role'] ?? '';
      String teacherName = teacherData['name'] ?? '';

      if (mounted) {
        // 4. [핵심] 권한별 분기 없이, 무조건 'HomeNavigation'으로 이동시킵니다!
        // (화면 쪼개기는 HomeNavigation 안에서 알아서 해줍니다)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeNavigation(
              teacherName: teacherName,
              role: role,
              cell: cell,
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('아이디 또는 비밀번호가 일치하지 않습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.church, size: 80, color: Colors.teal),
              const SizedBox(height: 20),
              const Text(
                '부천성문교회 중등부',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _idController,
                decoration: const InputDecoration(
                  labelText: '아이디 (전화번호)',
                  hintText: '예: 01012345678',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pwController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '비밀번호',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _tryLogin,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  child: const Text(
                    '로그인',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
