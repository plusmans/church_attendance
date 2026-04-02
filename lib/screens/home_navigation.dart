import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'attendance/attendance_input.dart';

class HomeNavigation extends StatefulWidget {
  final String teacherName;
  final String role;
  final String cell;

  const HomeNavigation({
    super.key,
    required this.teacherName,
    required this.role,
    required this.cell,
  });

  @override
  State<HomeNavigation> createState() => _HomeNavigationState();
}

class _HomeNavigationState extends State<HomeNavigation> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    bool isAccountant = widget.role == '회계';
    bool isCellTeacher =
        !(widget.role.contains('담당') ||
            widget.role == '부장' ||
            widget.role == '강도사' ||
            widget.role == '회계');

    final List<Widget> screens = [
      isCellTeacher
          ? AttendanceInputScreen(teacherCell: widget.cell)
          : const Center(
              child: Text(
                '전체 출석 현황 (개발 예정 📊)',
                style: TextStyle(fontSize: 20),
              ),
            ),

      isAccountant
          ? const Center(
              child: Text(
                '헌금 입력 화면 (개발 예정 💰)',
                style: TextStyle(fontSize: 20),
              ),
            )
          : const Center(
              child: Text(
                '헌금 현황 조회 (개발 예정 🔍)',
                style: TextStyle(fontSize: 20),
              ),
            ),

      isCellTeacher
          ? const Center(
              child: Text(
                '우리반 기도제목 입력 (개발 예정 🙏)',
                style: TextStyle(fontSize: 20),
              ),
            )
          : const Center(
              child: Text(
                '전체 중보기도 현황 (개발 예정 📖)',
                style: TextStyle(fontSize: 20),
              ),
            ),

      const Center(
        child: Text('학생 관리 및 명부 (개발 예정 🧑‍🎓)', style: TextStyle(fontSize: 20)),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75, // 💡 두 줄이 예쁘게 들어가도록 높이를 살짝 키웠습니다!
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.teacherName} ${widget.role}님, 축복합니다! ✨',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '오늘도 사랑으로 아이들을 섬겨주셔서 감사합니다 💖',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Colors.white70,
              ), // 살짝 연한 색으로 세련되게!
            ),
          ],
        ),
        backgroundColor: Colors.teal,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: () {
              FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.check_circle), label: '출석'),
          BottomNavigationBarItem(
            icon: Icon(Icons.monetization_on),
            label: '헌금',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: '기도'),
          BottomNavigationBarItem(icon: Icon(Icons.people_alt), label: '학생관리'),
        ],
      ),
    );
  }
}
