import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'attendance/attendance_status.dart';
import 'attendance/attendance_input.dart';
import 'management/student_management.dart';
import 'prayer/prayer_screen.dart';
import 'change_password_screen.dart';
import 'teacher_management_screen.dart';

class HomeNavigation extends StatefulWidget {
  final String teacherName;
  final String cell;
  final String role;
  final String grade;
  final String docId;

  const HomeNavigation({
    super.key,
    required this.teacherName,
    required this.cell,
    required this.role,
    required this.docId,
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

  // 💡 로그아웃 확인 팝업창
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          '로그아웃',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: const Text(
          '정말 로그아웃 하시겠습니까?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text(
              '로그아웃',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
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
        toolbarHeight: 64,
        // ✅ titleSpacing을 줄여 제목 영역의 가로 공간을 최대한 확보
        titleSpacing: 12,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ FittedBox를 사용하여 내용이 길어도 잘리지 않고 크기를 맞춰 보여줌
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _cheerMessage,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.white.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              appBarTitle,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 19, 
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          // ✅ 아이콘 버튼들의 패딩을 줄여서 공간 확보
          if (widget.role == 'admin')
            IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.people_alt_rounded, size: 22, color: Colors.white70),
              tooltip: '교사 관리',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TeacherManagementScreen()),
                );
              },
            ),

          IconButton(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.lock_reset_rounded, size: 22, color: Colors.white70),
            tooltip: '비밀번호 변경',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChangePasswordScreen(
                    user: FirebaseAuth.instance.currentUser!,
                    docId: widget.docId,
                    isMandatory: false,
                  ),
                ),
              );
            },
          ),

          IconButton(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.logout_rounded, size: 22, color: Colors.white70),
            tooltip: '로그아웃',
            onPressed: () => _showLogoutDialog(context),
          ),

          const SizedBox(width: 4),

          // 우측 끝 사용자 정보 (최소한의 너비만 사용)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${widget.teacherName} ${isSuperAdmin ? '사역자' : '교사'}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    displayRole,
                    style: const TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.w400),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200, width: 0.5)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                  if (index != 1) {
                    _autoSelectedCell = null;
                  }
                  _buildScreens();
                });
              },
              selectedItemColor: themeColor,
              unselectedItemColor: Colors.grey.shade400,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              elevation: 0,
              iconSize: 22,
              items: [
                BottomNavigationBarItem(
                  icon: Icon(_selectedIndex == 0 ? Icons.bar_chart_rounded : Icons.bar_chart_outlined),
                  label: '현황',
                ),
                BottomNavigationBarItem(
                  icon: Icon(_selectedIndex == 1 ? Icons.edit_calendar_rounded : Icons.edit_calendar_outlined),
                  label: '출석',
                ),
                BottomNavigationBarItem(
                  icon: Icon(_selectedIndex == 2 ? Icons.manage_accounts_rounded : Icons.manage_accounts_outlined),
                  label: '관리',
                ),
                BottomNavigationBarItem(
                  icon: Icon(_selectedIndex == 3 ? Icons.volunteer_activism : Icons.volunteer_activism_outlined),
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