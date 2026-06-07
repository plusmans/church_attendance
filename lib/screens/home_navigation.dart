import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'attendance/attendance_status.dart';
import 'attendance/attendance_input.dart';
import 'management/student_management.dart';
import 'prayer/prayer_screen.dart';
import 'change_password_screen.dart';
import 'teacher_management_screen.dart';
// ✅ 알림 토큰 발급을 위한 패키지 추가
import 'package:firebase_messaging/firebase_messaging.dart';

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

    // ✅ 앱 실행(로그인) 시 교사 실제 기기 토큰 수집 및 업데이트
    _updateTeacherToken();
    // ✅ 푸시 알림 관련 설정 초기화
    _setupPushNotifications();
  }

  // ✅ 푸시 알림 관련 설정
  void _setupPushNotifications() {
    // 1. 앱이 실행 중(Foreground)일 때 푸시 알림 수신 처리
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📳 포그라운드 메시지 수신: ${message.notification?.title}');
      if (message.notification != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🚨 ${message.notification!.title}\n${message.notification!.body}',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    });

    // 2. 알림을 탭하여 앱에 진입했을 때(앱이 백그라운드에 있을 때) 처리
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('알림 탭(백그라운드): ${message.data}');
      _handleNotificationNavigation(message.data);
    });

    // 3. 앱이 종료된 상태에서 알림을 탭하여 실행되었을 때 처리
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        debugPrint('알림 탭(종료): ${message.data}');
        // ✅ 위젯 트리가 모두 렌더링 된 직후에 안전하게 상태 변경
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleNotificationNavigation(message.data);
        });
      }
    });

    // 4. FCM 기기 토큰이 시스템에 의해 갱신(Refresh)될 때 자동 업데이트 처리
    FirebaseMessaging.instance.onTokenRefresh
        .listen((String newToken) async {
          debugPrint('🔄 FCM 토큰 자동 갱신됨: $newToken');
          await FirebaseFirestore.instance
              .collection('departments')
              .doc('중등부')
              .collection('teachers')
              .doc(widget.docId)
              .update({'fcmToken': newToken});
        })
        .onError((err) {
          debugPrint('❌ 토큰 갱신 리스너 오류: $err');
        });
  }

  // ✅ 선생님 FCM 토큰 수집 로직 (알림 발송은 안 함, 주소록만 저장)
  Future<bool> _updateTeacherToken() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // 1. 사용자에게 알림 권한 팝업 띄우기 (최초 1회)
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // 2. 알림을 허용했다면 기기 고유 토큰(fcmToken) 발급
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // ✅ 웹 푸시 알림을 위한 VAPID 키 추가 (파이어베이스 콘솔에서 복사한 키를 넣으세요)
        String? token = await messaging.getToken(
          vapidKey:
              'BE06FNoDlTip6c1gsTv3VbvqYFQk2MPwIPsMotC87Aurguw_oWALfmGvYVM25KkQ_zvDP9N_Yiy0OVD6iyGgJ9M',
        );

        if (token != null) {
          // 3. 앞서 변경한 '중등부' 전용 경로의 선생님 문서에 토큰값만 병합 업데이트
          await FirebaseFirestore.instance
              .collection('departments')
              .doc('중등부')
              .collection('teachers')
              .doc(widget.docId) // 현재 로그인한 선생님의 고유 문서 ID
              .set({
                'fcmToken': token, // 앞서 일괄 생성한 빈칸을 실제 토큰으로 채움
              }, SetOptions(merge: true)); // ✅ update 대신 안전한 병합 저장 사용
          debugPrint("✅ 실제 FCM 토큰 업데이트 완료");
          return true;
        }
      } else {
        debugPrint("❌ 알림 권한이 거부되었습니다.");
      }
    } catch (e) {
      debugPrint("❌ 토큰 업데이트 실패: $e");
    }
    return false;
  }

  // ✅ 알림 데이터에 따라 화면 이동 처리
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    // 'screen' 데이터가 'prayer_screen'이면 기도 페이지로 이동
    if (data['screen'] == 'prayer_screen') {
      if (mounted) {
        setState(() {
          _selectedIndex = 3; // 기도 화면의 인덱스 (0:현황, 1:출석, 2:관리, 3:기도)
          _buildScreens(); // ✅ 탭 이동 시 화면 목록도 안전하게 다시 빌드
        });
      }
    }
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
  // ✅ 매개변수로 BuildContext를 지워 섀도잉(Shadowing) 경고를 해결합니다.
  void _showLogoutDialog() {
    // ✅ 비동기 작업(await) 전에 Navigator 상태를 미리 저장하여 Async gap 에러 방지
    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        // ✅ 변수명 중복(shadowing) 방지를 위해 dialogContext로 변경
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          '로그아웃',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: const Text('정말 로그아웃 하시겠습니까?', style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => navigator.pop(),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              // ✅ 로그아웃 시 해당 교사의 FCM 토큰을 DB에서 삭제 (알림 오발송 방지)
              try {
                await FirebaseFirestore.instance
                    .collection('departments')
                    .doc('중등부')
                    .collection('teachers')
                    .doc(widget.docId)
                    .update({'fcmToken': FieldValue.delete()});
              } catch (e) {
                debugPrint('로그아웃 시 토큰 삭제 실패: $e');
              }

              await FirebaseAuth.instance.signOut();
              navigator.pop(); // ✅ 저장해둔 navigator를 사용하여 안전하게 팝업 닫기
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
              icon: const Icon(
                Icons.people_alt_rounded,
                size: 22,
                color: Colors.white70,
              ),
              tooltip: '교사 관리',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TeacherManagementScreen(),
                  ),
                );
              },
            ),

          IconButton(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.lock_reset_rounded,
              size: 22,
              color: Colors.white70,
            ),
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
          // ✅ 1. 추가된 수동 알림 권한 갱신 버튼 (경고 해결 버전)
          IconButton(
            icon: const Icon(Icons.notification_add, color: Colors.amber),
            tooltip: '알림 수신 설정 갱신',
            onPressed: () async {
              // ✅ 비동기 작업 전에 Messenger를 미리 확보하여 context 에러를 완벽히 차단합니다.
              final messenger = ScaffoldMessenger.of(context);
              bool isSuccess = await _updateTeacherToken(); // 토큰 갱신 성공 여부 확인

              if (isSuccess) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('🔔 알림 수신 설정이 갱신되었습니다.')),
                );
              } else {
                // ✅ 권한이 차단된 경우 스낵바 대신 확실한 팝업(Dialog)으로 안내합니다.
                if (!mounted) return;
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text(
                      '알림 권한 안내',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    content: const Text(
                      '기기 알림 권한이 차단되어 있습니다.\n\n스마트폰의 [설정] > [애플리케이션] > [성문교회 앱]에서 알림을 직접 허용하신 후 다시 시도해주세요.',
                      style: TextStyle(fontSize: 14),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('확인'),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
          IconButton(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.logout_rounded,
              size: 22,
              color: Colors.white70,
            ),
            tooltip: '로그아웃',
            onPressed: _showLogoutDialog, // ✅ 불필요한 context 전달 제거
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
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
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
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              elevation: 0,
              iconSize: 22,
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
