import 'dart:math';
import 'package:flutter/material.dart';
import 'attendance/attendance_status.dart';
import 'attendance/attendance_input.dart';
import 'management/student_management.dart';
import 'prayer/prayer_screen.dart';

class HomeNavigation extends StatefulWidget {
  final String teacherName;
  final String cell;
  final String role;
  final String grade;

  const HomeNavigation({
    super.key,
    required this.teacherName,
    required this.cell,
    required this.role,
    this.grade = '1학년',
  });

  @override
  State<HomeNavigation> createState() => _HomeNavigationState();
}

class _HomeNavigationState extends State<HomeNavigation> {
  int _selectedIndex = 1;
  String? _autoSelectedCell;
  late String _cheerMessage;

  final List<String> _cheerMessages = [
    "오늘도 사랑으로 축복합니다! 🙏",
    "선생님의 수고를 응원해요! ✨",
    "우리 아이들의 소중한 목자님! 🌱",
    "기쁨이 가득한 하루 되세요! 😊",
    "기도로 함께하는 동역자입니다! ❤️",
  ];

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _cheerMessage = _cheerMessages[Random().nextInt(_cheerMessages.length)];
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
      AttendanceInputScreen(
        teacherCell: defaultCell,
        teacherRole: widget.role,
        teacherGrade: widget.grade,
      ),
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

    bool isGradeAdmin = widget.role.contains('학년담당');

    String displayRole = isSuperAdmin
        ? '관리자'
        : isGradeAdmin
        ? widget.role
        : '${widget.role}(${widget.cell == '담당' ? '학년담당' : '${widget.cell}셀'})';

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 42,
        title: Text(
          appBarTitle,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: -0.8,
          ),
        ),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _cheerMessage,
                    style: TextStyle(
                      fontSize: 7.5,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w300,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ✅ [수정] '님' 대신 '사역자님' 표현으로 변경
                      Text(
                        '${widget.teacherName} ${isSuperAdmin ? '사역자님' : '교사'}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          displayRole,
                          style: const TextStyle(
                            fontSize: 7,
                            color: Colors.white,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.shade200, width: 0.5),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 46,
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                  if (index != 1) _autoSelectedCell = null;
                  _buildScreens();
                });
              },
              selectedItemColor: themeColor,
              unselectedItemColor: Colors.grey.shade400,
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 9,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 9,
              ),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              elevation: 0,
              iconSize: 18,
              items: [
                BottomNavigationBarItem(
                  icon: Icon(
                    _selectedIndex == 0
                        ? Icons.bar_chart_rounded
                        : Icons.bar_chart_outlined,
                  ),
                  label: '현황',
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    _selectedIndex == 1
                        ? Icons.edit_calendar_rounded
                        : Icons.edit_calendar_outlined,
                  ),
                  label: '출석',
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    _selectedIndex == 2
                        ? Icons.manage_accounts_rounded
                        : Icons.manage_accounts_outlined,
                  ),
                  label: '관리',
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    _selectedIndex == 3
                        ? Icons.volunteer_activism
                        : Icons.volunteer_activism_outlined,
                  ),
                  label: '기도',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
