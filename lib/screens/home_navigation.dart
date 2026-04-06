import 'package:flutter/material.dart';
import 'attendance/attendance_status.dart';
import 'attendance/attendance_input.dart';
import 'management/student_management.dart';
import 'prayer/prayer_screen.dart';

class HomeNavigation extends StatefulWidget {
  final String teacherName;
  final String cell; 
  final String role;

  const HomeNavigation({
    super.key, 
    required this.teacherName, 
    required this.cell, 
    required this.role,
  });

  @override
  State<HomeNavigation> createState() => _HomeNavigationState();
}

class _HomeNavigationState extends State<HomeNavigation> {
  int _selectedIndex = 0;
  String? _autoSelectedCell; 

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _buildScreens();
  }

  void _buildScreens() {
    String defaultCell = _autoSelectedCell ?? widget.cell;

    _screens = [
      // 1. 출석 현황
      AttendanceStatusScreen(
        onCellTap: (cellId) {
          setState(() {
            _autoSelectedCell = cellId;
            _selectedIndex = 1; 
            _buildScreens(); 
          });
        },
      ),
      // 2. 출석 입력
      AttendanceInputScreen(
        teacherCell: defaultCell,
      ),
      // 3. 학생 관리
      const StudentManagementScreen(),
      
      // 4. 중보기도
      // ✅ 실제 PrayerScreen의 요구사항에 맞게 필수 파라미터 3가지를 모두 전달합니다.
      PrayerScreen(
        teacherName: widget.teacherName,
        cell: widget.cell,
        role: widget.role,
      ), 
    ];
  }

  @override
  Widget build(BuildContext context) {
    // 페이지별 테마 색상 설정 (현황/입력: teal, 학생관리: indigo, 중보기도: pink)
    Color themeColor = Colors.teal;
    if (_selectedIndex == 2) themeColor = Colors.indigo;
    if (_selectedIndex == 3) themeColor = Colors.pinkAccent;

    // 앱바 타이틀 설정
    String appBarTitle = '출석 현황';
    if (_selectedIndex == 1) appBarTitle = '출석 입력';
    if (_selectedIndex == 2) appBarTitle = '학생 관리';
    if (_selectedIndex == 3) appBarTitle = '중보기도';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          appBarTitle,
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
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            // '출석 입력' 탭이 아닌 다른 메뉴를 누를 때는 자동 선택된 셀 정보를 초기화
            if (index != 1) {
              _autoSelectedCell = null;
            }
            _buildScreens();
          });
        },
        selectedItemColor: themeColor,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        type: BottomNavigationBarType.fixed, // 탭이 4개 이상일 때 아이콘 고정
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
          BottomNavigationBarItem(
            icon: Icon(Icons.volunteer_activism), 
            label: '중보기도',
          ),
        ],
      ),
    );
  }
}