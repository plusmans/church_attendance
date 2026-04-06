import 'package:flutter/material.dart';
import 'attendance/attendance_status.dart';
import 'attendance/attendance_input.dart';
import 'management/student_management.dart';

class HomeNavigation extends StatefulWidget {
  final String teacherName;
  final String cell; // ✅ teacherCell에서 cell로 이름을 변경하여 main.dart와 일치시킴
  final String role;

  const HomeNavigation({
    super.key,
    required this.teacherName,
    required this.cell, // ✅ 생성자 매개변수 이름 수정
    required this.role,
  });

  @override
  State<HomeNavigation> createState() => _HomeNavigationState();
}

class _HomeNavigationState extends State<HomeNavigation> {
  int _selectedIndex = 0;
  String? _autoSelectedCell;

  // 표시할 화면 리스트
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _buildScreens();
  }

  void _buildScreens() {
    // 현재 선택된 셀이 없으면 로그인한 사용자의 기본 셀 정보를 사용
    String defaultCell = _autoSelectedCell ?? widget.cell;

    _screens = [
      // 1. 출석 현황 (통계/대시보드)
      AttendanceStatusScreen(
        onCellTap: (cellId) {
          setState(() {
            _autoSelectedCell = cellId;
            _selectedIndex = 1; // '입력' 탭으로 인덱스 전환
            _buildScreens(); // 화면 리스트 재생성하여 인자 전달
          });
        },
      ),
      // 2. 출석 입력
      AttendanceInputScreen(teacherCell: defaultCell),
      // 3. 학생 관리 (새친구 등반 및 학생 명단 관리)
      const StudentManagementScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // 현재 탭에 따른 테마 색상 설정 (학생 관리는 indigo, 나머지는 teal)
    Color themeColor = _selectedIndex == 2 ? Colors.indigo : Colors.teal;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0
              ? '출석 현황'
              : _selectedIndex == 1
              ? '출석 입력'
              : '학생 관리',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${widget.teacherName} 선생님',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${widget.role} (${widget.cell == '담당' ? '본부' : '${widget.cell}셀'})',
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            // 입력 탭이 아닌 다른 탭을 직접 눌러 이동할 때는 자동 선택값 초기화
            if (index != 1) {
              _autoSelectedCell = null;
            }
            _buildScreens();
          });
        },
        selectedItemColor: themeColor,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: '출석 현황',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit_calendar_rounded),
            label: '출석 입력',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.manage_accounts_rounded),
            label: '학생 관리',
          ),
        ],
      ),
    );
  }
}
