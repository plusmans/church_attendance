import 'package:flutter/material.dart';

void main() {
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
        // [디자인 1] 성문교회 느낌의 네이비 블루 메인 컬러 지정
        primaryColor: const Color(0xFF1A237E),
        scaffoldBackgroundColor: const Color(0xFFFDFBF7), // 따뜻한 베이지/화이트 톤 배경
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A237E)),
      ),
      home: const LoginScreen(), // 앱을 켜면 가장 먼저 띄울 화면을 '로그인 화면'으로 설정
    );
  }
}

// ==========================================
// [1] 로그인 화면 UI
// ==========================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();

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
              // [디자인 2] 로고 및 타이틀 영역
              const Icon(
                Icons.church, // 교회 느낌의 십자가/건물 아이콘
                size: 80,
                color: Color(0xFF1A237E),
              ),
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

              // 아이디 입력칸
              TextField(
                controller: _idController,
                decoration: InputDecoration(
                  labelText: '아이디 (사전 발급)',
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
                obscureText: true, // 비밀번호 동그라미로 숨김 처리
                decoration: InputDecoration(
                  labelText: '비밀번호',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 32),

              // [디자인 3] 로그인 버튼 (누르면 출석부로 이동)
              ElevatedButton(
                onPressed: () {
                  // 화면 이동 마법의 코드! 현재 화면을 닫고 출석부 화면을 엽니다.
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AttendanceScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E), // 네이비 색상
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
// [2] 출석부 화면 UI (아까 만든 코드에 디자인만 네이비로 입힘)
// ==========================================
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final List<String> students = ['김민수', '이지은', '박도윤', '최서연', '정하준'];
  final Map<String, bool> attendanceStatus = {};

  @override
  void initState() {
    super.initState();
    for (var student in students) {
      attendanceStatus[student] = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    int presentCount = attendanceStatus.values.where((status) => status).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '1학년 1반 출석부',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A237E), // 네이비 상단바
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20.0),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '정청김 선생님, 환영합니다!',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF1A237E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '2026년 3월 29일 주일',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '오늘의 나눔: 히브리서 4장',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EAF6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '출석 $presentCount / ${students.length}명',
                    style: const TextStyle(
                      color: Color(0xFF1A237E),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: students.length,
              itemBuilder: (context, index) {
                String studentName = students[index];
                bool isPresent = attendanceStatus[studentName]!;

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.grey.shade300, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    title: Text(
                      studentName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Switch(
                      value: isPresent,
                      activeColor: const Color(0xFF4CAF50), // 초록색 포인트 컬러
                      onChanged: (value) {
                        setState(() {
                          attendanceStatus[studentName] = value;
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('출석 데이터가 임시 저장되었습니다!')),
              );
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              backgroundColor: const Color(0xFF1A237E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '출석 저장하기',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
