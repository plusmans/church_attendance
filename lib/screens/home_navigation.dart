import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    // 🔐 권한 확인 로직! (일반 교사인가? 회계인가?)
    bool isAccountant = widget.role == '회계';
    // 담당, 부장, 강도사, 회계가 아니면 무조건 일반 셀 담당 교사로 봅니다.
    bool isCellTeacher =
        !(widget.role.contains('담당') ||
            widget.role == '부장' ||
            widget.role == '강도사' ||
            widget.role == '회계');

    // 📱 하단 탭을 눌렀을 때 보여줄 3개의 화면을 권한에 맞게 장착합니다.
    final List<Widget> screens = [
      // 1. 출석 탭: 일반 교사면 [출석 체크], 관리자/회계면 [출석 현황]
      isCellTeacher
          ? const Center(
              child: Text(
                '출석 체크 화면 (개발 예정 🚀)',
                style: TextStyle(fontSize: 20),
              ),
            )
          : const Center(
              child: Text(
                '전체 출석 현황 (개발 예정 📊)',
                style: TextStyle(fontSize: 20),
              ),
            ),

      // 2. 헌금 탭: 회계면 [헌금 입력], 나머지는 [헌금 현황]
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

      // 3. 기도 탭: 일반 교사면 [기도제목 입력], 관리자면 [기도제목 현황]
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
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.teacherName} ${widget.role}님',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // 로그아웃 버튼 (나중에 로그인 화면으로 돌아가는 코드 추가 예정)
              FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: screens[_selectedIndex], // 사용자가 누른 탭의 화면을 보여줌
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.teal,
        onTap: (index) {
          setState(() {
            _selectedIndex = index; // 탭을 누르면 화면 전환!
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.check_circle), label: '출석'),
          BottomNavigationBarItem(
            icon: Icon(Icons.monetization_on),
            label: '헌금',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: '중보기도'),
        ],
      ),
    );
  }
}
