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
      AttendanceStatusScreen(
        onCellTap: (cellId) {
          setState(() {
            _autoSelectedCell = cellId;
            _selectedIndex = 1;
            _buildScreens();
          });
        },
      ),
      AttendanceInputScreen(teacherCell: defaultCell),
      // ✅ 수정됨: 권한 판단을 위해 필요한 정보 3가지를 전달합니다.
      StudentManagementScreen(
        teacherName: widget.teacherName,
        teacherCell: widget.cell,
        teacherRole: widget.role,
      ),
      PrayerScreen(
        teacherName: widget.teacherName,
        cell: widget.cell,
        role: widget.role,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    Color themeColor = Colors.teal;
    if (_selectedIndex == 2) themeColor = Colors.indigo;
    if (_selectedIndex == 3) themeColor = Colors.pinkAccent;

    String appBarTitle = '출석 현황';
    if (_selectedIndex == 1) appBarTitle = '출석 입력';
    if (_selectedIndex == 2) appBarTitle = '학생 관리';
    if (_selectedIndex == 3) appBarTitle = '중보기도';

    bool isSuperAdmin =
        widget.role == 'admin' ||
        widget.role == '개발자' ||
        widget.role == '부장' ||
        widget.role == '강도사';
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
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            if (index != 1) _autoSelectedCell = null;
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
          BottomNavigationBarItem(
            icon: Icon(Icons.volunteer_activism),
            label: '중보기도',
          ),
        ],
      ),
    );
  }
}
