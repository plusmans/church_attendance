import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // [추가됨] 자물쇠 도구 꺼내기
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SungmoonApp());
}

class SungmoonApp extends StatelessWidget {
  const SungmoonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '부천성문교회 중등부',
      theme: ThemeData(
        primaryColor: const Color(0xFF1A237E),
        scaffoldBackgroundColor: const Color(0xFFFDFBF7),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A237E)),
      ),
      home: const LoginScreen(),
    );
  }
}

// ==========================================
// [1] 로그인 화면 UI (진짜 로그인 기능 탑재)
// ==========================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();

  // [추가됨] 진짜 로그인을 시도하는 마법의 함수
  Future<void> _tryLogin() async {
    // 1. 사용자가 입력한 번호 가져오기 (양쪽 공백 제거)
    String inputPhone = _idController.text.trim();
    String inputPassword = _pwController.text.trim();

    // 2. 입력값이 비어있는지 확인
    if (inputPhone.isEmpty || inputPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아이디(전화번호)와 비밀번호를 모두 입력해주세요.')),
      );
      return;
    }

    // 3. 선생님의 아이디어 적용! 뒤에 자동으로 @sungmoon.com 붙여주기
    String finalEmail = "$inputPhone@sungmoon.com";

    try {
      // 4. 파이어베이스 서버에 문 열어달라고 요청하기!
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: finalEmail,
        password: inputPassword,
      );

      // 5. 성공하면 출석부 화면으로 넘어가기
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AttendanceScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      // 6. 비밀번호가 틀렸거나 없는 아이디일 때 에러 메시지 띄우기
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('아이디 또는 비밀번호가 일치하지 않습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.church, size: 80, color: Color(0xFF1A237E)),
              const SizedBox(height: 16),
              const Text(
                '부천성문교회\n중등부 사역 관리',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 48),

              // 아이디(전화번호) 입력칸
              TextField(
                controller: _idController,
                keyboardType: TextInputType.number, // 숫자 키패드만 나오게 설정
                decoration: InputDecoration(
                  labelText: '아이디 (전화번호 숫자만)',
                  hintText: '예: 01011112222',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),

              // 비밀번호 입력칸
              TextField(
                controller: _pwController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: '비밀번호',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _tryLogin, // 버튼을 누르면 위에서 만든 로그인 함수 실행!
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '로그인',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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

// ==========================================
// [2] 출석부 화면 UI (진짜 Firestore 연동 완성본!)
// ==========================================
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  // [1] 엑셀에서 추출한 새친구 상세 정보 매칭 사전!
  final Map<String, Map<String, dynamic>> newFriendsExtraInfo = {
    '이지훈': {
      'school': '삼산중',
      'address': '인천부평 후정도로 12 벽산블루밍',
      'parentName': '모(이지연)',
      'parentPhone': '010-5261-7191',
      'notes': '이서유(중3) 동생, 할머니댁(상동)에 올때만 교회출석',
    },
    '이혜율': {
      'school': '부인중',
      'address': '부천 상동',
      'parentName': '모',
      'parentPhone': '010-9190-3752',
      'notes': '전하율 학교친구',
    },
    '이소율': {
      'school': '상일중',
      'address': '',
      'parentName': '',
      'parentPhone': '',
      'notes': '',
    },
    '이윤서': {
      'school': '상도중',
      'address': '사랑마을',
      'parentName': '모',
      'parentPhone': '010-3136-1567',
      'notes': '사촌형제. 교회경험 없으나 자진해서 나옴',
    },
    '임현후': {
      'school': '상일중',
      'address': '소향로18',
      'parentName': '모(홍지원)',
      'parentPhone': '010-6366-7912',
      'notes': '부모님 중동교회 다니심, 둘이 친구. 함께 교회 나옴',
    },
    '오건': {
      'school': '상일중',
      'address': '한양수자인',
      'parentName': '모(김정임)',
      'parentPhone': '010-2732-6774',
      'notes': '부모님 성문교회 다니심',
    },
    '길나현': {
      'school': '부천여중',
      'address': '중동로19 래미안어반비스타',
      'parentName': '모',
      'parentPhone': '010-9367-5619',
      'notes': '',
    },
    '신연호': {
      'school': '상동중',
      'address': '세종그랑시아 2016-108',
      'parentName': '모(이문선)',
      'parentPhone': '010-8555-3221',
      'notes': '',
    },
    '김예나': {
      'school': '부천여중',
      'address': '심곡본동',
      'parentName': '모',
      'parentPhone': '010-6426-6828',
      'notes': '부모님 안양(개척)교회 다니심. 지현이 따라 교회옴',
    },
    '최가온': {
      'school': '상도중',
      'address': '',
      'parentName': '',
      'parentPhone': '',
      'notes': '박수빈 교사 사촌동생',
    },
  };

  // [2] 전체 학생에게 6개의 새로운 필드를 일괄 추가하는 일괄 처리(Batch) 함수
  Future<void> _updateAllStudentsWithNewFields() async {
    try {
      var db = FirebaseFirestore.instance;

      // 1. 서버에 있는 학생 명단을 일단 싹 다 가져옵니다.
      var snapshot = await db.collection('students').get();

      // 2. 한 번에 포장해서 보낼 '택배 상자(batch)' 준비
      var batch = db.batch();
      int updateCount = 0;

      // 3. 학생 1명씩 꺼내서 빈칸을 달아줍니다.
      for (var doc in snapshot.docs) {
        String studentName = doc.data()['name'] ?? '';

        // 새친구 정보 사전에 이름이 있으면 그 데이터를, 없으면 다 빈칸으로!
        var extraInfo = newFriendsExtraInfo[studentName];

        // update()를 쓰면 기존 데이터(이름, 학년, 셀 등)는 그대로 두고 추가만 합니다.
        batch.update(doc.reference, {
          'address': extraInfo?['address'] ?? '', // 집주소
          'parentName': extraInfo?['parentName'] ?? '', // 학부모이름
          'parentPhone': extraInfo?['parentPhone'] ?? '', // 학부모 연락처
          'school': extraInfo?['school'] ?? '', // 학교
          'isBaptized': false, // 세례유무 (기본값: X)
          'notes': extraInfo?['notes'] ?? '', // 특이사항
        });

        updateCount++;
      }

      // 4. 상자 통째로 전송! (0.1초 컷)
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 완벽합니다! 학생 $updateCount명에게 6개 항목 일괄 추가 완료!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('업데이트 에러: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '학생 상세정보 일괄 업데이트',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.brown,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '기존 DB를 지우지 않고,\n학생 전원에게 6가지 새로운 필드를 추가합니다!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _updateAllStudentsWithNewFields,
              icon: const Icon(Icons.system_update_alt, color: Colors.white),
              label: const Text(
                '빈칸 추가 업데이트 실행!',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
