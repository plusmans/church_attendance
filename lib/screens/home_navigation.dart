import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'attendance/attendance_input.dart';
import 'attendance/attendance_status.dart';

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
  String? _selectedCell; // 💡 선택된 셀을 저장할 변수

  @override
  void initState() {
    super.initState();
    // 초기 진입 설정
    if (widget.role == '회계') {
      _selectedIndex = 1;
    } else if (widget.role == '부장' ||
        widget.role == '강도사' ||
        widget.role.contains('담당')) {
      _selectedIndex = 0; // 통계/입력 탭
    }
    _selectedCell = widget.cell; // 기본값은 내 셀
  }

  // 💡 [핵심] 이 함수가 호출되면 화면을 강제로 '입력창'으로 바꿉니다.
  void _jumpToInput(String cellName) {
    setState(() {
      _selectedCell = cellName;
      // 탭을 이동시키는 게 아니라, '화면 구성' 자체를 다시 하도록 유도합니다.
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
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
              '성문교회 중등부 사역을 응원합니다 💖',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Colors.teal,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      // 💡 IndexedStack 대신 직접 조건문을 써서 화면을 교체합니다 (가장 확실한 방법)
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            // 탭을 바꿀 때 선택된 셀 정보를 초기화(내 셀로 복귀) 하거나
            // 통계 화면으로 돌아가게 설정합니다.
            if (index == 0) _selectedCell = null;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '출석'),
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

  // 💡 화면을 그려주는 핵심 로직
  Widget _buildBody() {
    if (_selectedIndex == 0) {
      // 💡 선택된 셀이 있다면 '입력창'을, 없다면 '통계창'을 보여줍니다.
      if (_selectedCell != null) {
        return AttendanceInputScreen(teacherCell: _selectedCell!);
      } else {
        return AttendanceStatusScreen(onCellTap: _jumpToInput);
      }
    }

    // 나머지 탭들
    switch (_selectedIndex) {
      case 1:
        return const Center(child: Text('헌금 현황 (준비 중)'));
      case 2:
        return const Center(child: Text('중보기도 (준비 중)'));
      case 3:
        return const Center(child: Text('학생 관리 (준비 중)'));
      default:
        return const Center(child: Text('화면을 찾을 수 없습니다.'));
    }
  }
}
