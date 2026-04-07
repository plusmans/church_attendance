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
  // ✅ 1. 앱 시작 시 무조건 '출석 입력' 탭이 뜨도록 설정합니다.
  // (주의: 코드 적용 후 반드시 앱을 '완전히 재시작(Hot Restart)' 해야 반영됩니다!)
  int _selectedIndex = 1;
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
      // 0. 출석 현황
      AttendanceStatusScreen(
        onCellTap: (cellId) {
          setState(() {
            _autoSelectedCell = cellId;
            _selectedIndex = 1;
            _buildScreens();
          });
        },
      ),
      // 1. 출석 입력 (기본 시작 화면)
      AttendanceInputScreen(teacherCell: defaultCell),
      // 2. 학생 관리
      const StudentManagementScreen(),
      // 3. 중보기도
      PrayerScreen(
        teacherName: widget.teacherName,
        cell: widget.cell,
        role: widget.role,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // 페이지별 테마 색상 설정
    Color themeColor = Colors.teal;
    if (_selectedIndex == 2) themeColor = Colors.indigo;
    if (_selectedIndex == 3) themeColor = Colors.pinkAccent;

    // 앱바 타이틀 설정
    String appBarTitle = '출석 현황';
    if (_selectedIndex == 1) appBarTitle = '출석 입력';
    if (_selectedIndex == 2) appBarTitle = '학생 관리';
    if (_selectedIndex == 3) appBarTitle = '중보기도';

    // ✅ 2. 관리자(admin) 계정 직분 처리
    bool isSuperAdmin = widget.role == 'admin' || widget.role == '개발자';
    String displayRole = isSuperAdmin
        ? '👑 시스템 관리자'
        : '${widget.role} (${widget.cell == '담당' ? '본부' : '${widget.cell}셀'})';

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
                    '${widget.teacherName} ${isSuperAdmin ? '님' : '선생님'}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    displayRole,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSuperAdmin
                          ? Colors.yellowAccent
                          : Colors.white70,
                      fontWeight: isSuperAdmin
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      // ✅ 3. 핵심 해결! IndexedStack을 완전히 지우고 아래 코드로 대체했습니다.
      // 이제 탭을 누를 때마다 이전 화면을 완전히 끄고 새 화면을 불러와서 항상 100% 최신화됩니다.
      body: _screens[_selectedIndex],

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
        type: BottomNavigationBarType.fixed, // 탭 4개 이상일 때 아이콘 고정
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
