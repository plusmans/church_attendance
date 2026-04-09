import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
// ✅ 공통 팝업 위젯 임포트
import '../../widgets/student_registration_dialog.dart';

class StudentManagementScreen extends StatefulWidget {
  final String teacherName;
  final String teacherCell;
  final String teacherRole;

  const StudentManagementScreen({
    super.key,
    required this.teacherName,
    required this.teacherCell,
    required this.teacherRole,
  });

  @override
  State<StudentManagementScreen> createState() =>
      _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  bool _isLoading = true;
  String? _selectedCell;
  List<String> _availableCells = [];
  String _myGrade = '1학년';

  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _allTeachers = [];

  int _selectedBirthMonth = DateTime.now().month;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final sSnap = await FirebaseFirestore.instance
          .collection('students')
          .get();
      final tSnap = await FirebaseFirestore.instance
          .collection('teachers')
          .get();

      if (!mounted) return;

      _allStudents = sSnap.docs
          .map((doc) => {...doc.data(), 'docId': doc.id})
          .toList();
      _allTeachers = tSnap.docs.map((doc) => doc.data()).toList();

      String myGrade = '공통';
      final myInfo = _allTeachers.firstWhere(
        (t) => t['name'] == widget.teacherName,
        orElse: () => {},
      );
      if (myInfo.isNotEmpty) {
        myGrade = myInfo['grade'] ?? '공통';
        _myGrade = myGrade;
      }

      _setupCellPermissions(myGrade);
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("❌ 데이터 로드 에러: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupCellPermissions(String myGrade) {
    bool isSuperAdmin = [
      '강도사',
      '부장',
      'admin',
      '개발자',
    ].contains(widget.teacherRole);
    if (isSuperAdmin) {
      _availableCells = ['전체', ...List.generate(10, (i) => (i + 1).toString())];
      if (['강도사', '부장'].contains(widget.teacherRole)) {
        _selectedCell = '1';
      } else if (widget.teacherRole == 'admin' || widget.teacherRole == '개발자') {
        _selectedCell = widget.teacherCell == '담당' ? '1' : widget.teacherCell;
      } else {
        _selectedCell = '전체';
      }
    } else if (widget.teacherCell == '담당') {
      if (myGrade == '1학년')
        _availableCells = ['1', '2'];
      else if (myGrade == '2학년')
        _availableCells = ['3', '4', '5', '6'];
      else if (myGrade == '3학년')
        _availableCells = ['7', '8', '9', '10'];
      else
        _availableCells = [widget.teacherCell];
      _selectedCell = _availableCells.first;
    } else {
      _availableCells = [widget.teacherCell];
      _selectedCell = widget.teacherCell;
    }
  }

  String _getToday() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<void> _promoteStudent(Map<String, dynamic> s) async {
    int attendance = s['attendanceCount'] ?? 0;
    String autoDate = _getToday();
    final messenger = ScaffoldMessenger.of(context);

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("정규 등반 승인"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("학생: ${s['name']}"),
            Text("현재 출석: $attendance회"),
            const SizedBox(height: 10),
            Text(
              "등반 일자: $autoDate",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "해당 학생을 정규 리스트(A그룹)로 이동하시겠습니까?",
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            child: const Text("등반 확정"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('students')
            .doc(s['docId'])
            .update({
              'group': 'A',
              'isRegular': true,
              'promotedAt': autoDate,
              'updatedAt': FieldValue.serverTimestamp(),
            });
        await _loadInitialData();
        messenger.showSnackBar(
          SnackBar(content: Text("${s['name']} 학생이 등반되었습니다!")),
        );
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text("오류 발생: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isSuperAdmin = [
      '강도사',
      '부장',
      'admin',
      '개발자',
    ].contains(widget.teacherRole);
    return DefaultTabController(
      key: ValueKey(isSuperAdmin),
      length: isSuperAdmin ? 2 : 1,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Container(
                    color: Colors.white,
                    child: TabBar(
                      labelColor: Colors.indigo,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.indigo,
                      indicatorWeight: 3,
                      indicatorSize: TabBarIndicatorSize.label,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      tabs: [
                        const Tab(height: 44, text: "학생 명단"),
                        if (isSuperAdmin)
                          const Tab(height: 44, text: "등반/행정 관리"),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 0.5),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildListViewSection(),
                        if (isSuperAdmin) _buildAdminActionSection(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildListViewSection() {
    List<Map<String, dynamic>> filteredList = _allStudents.where((s) {
      if (_selectedCell == '전체') return true;
      String sCell = s['cell']?.toString() ?? '';
      return sCell == _selectedCell ||
          sCell.padLeft(2, '0') == _selectedCell?.padLeft(2, '0');
    }).toList();

    List<Map<String, dynamic>> groupA = filteredList
        .where((s) => s['group'] != 'B')
        .toList();
    List<Map<String, dynamic>> groupBNew = filteredList
        .where((s) => s['group'] == 'B' && s['role'] == '새친구')
        .toList();
    List<Map<String, dynamic>> groupBOld = filteredList
        .where((s) => s['group'] == 'B' && s['role'] != '새친구')
        .toList();

    return Column(
      children: [
        _buildBirthdayBanner(),
        _buildControlBar(filteredList.length),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              if (groupBNew.isNotEmpty) ...[
                _buildGroupHeader("🐣 신규 등록 (새친구)", Colors.orange),
                ...groupBNew.asMap().entries.map(
                  (e) => _buildStudentOneLineRow(e.value, e.key + 1),
                ),
              ],
              if (groupBOld.isNotEmpty) ...[
                _buildGroupHeader("🔍 장기 결석 및 특별 관리", Colors.redAccent),
                ...groupBOld.asMap().entries.map(
                  (e) => _buildStudentOneLineRow(e.value, e.key + 1),
                ),
              ],
              if (groupA.isNotEmpty) ...[
                _buildGroupHeader("💎 정규 명단 (A그룹)", Colors.indigo),
                ...groupA.asMap().entries.map(
                  (e) => _buildStudentOneLineRow(e.value, e.key + 1),
                ),
              ],
              _buildBottomAddButton(),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdminActionSection() {
    List<Map<String, dynamic>> groupBTotal = _allStudents
        .where((s) => s['group'] == 'B')
        .toList();
    List<Map<String, dynamic>> readyToPromote = groupBTotal
        .where((s) => (s['attendanceCount'] ?? 0) >= 4 && s['role'] == '새친구')
        .toList();
    List<Map<String, dynamic>> managementTarget = groupBTotal
        .where((s) => !readyToPromote.contains(s))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildAdminSectionTitle("✅ 등반 대기 (새친구 출석 4회 이상)", Colors.green),
        if (readyToPromote.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: Text(
                "등반 가능한 새친구가 없습니다.",
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          )
        else
          ...readyToPromote.map((s) => _buildPromotionCard(s, isReady: true)),
        const SizedBox(height: 24),
        _buildAdminSectionTitle("🔍 B그룹 관리 대상 (새친구 포함)", Colors.orange),
        if (managementTarget.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: Text(
                "관리 중인 B그룹 인원이 없습니다.",
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          )
        else
          ...managementTarget.map(
            (s) => _buildPromotionCard(s, isReady: false),
          ),
        _buildBottomAddButton(),
        const SizedBox(height: 50),
      ],
    );
  }

  // ✅ [수정] 새친구 등록 버튼 크기 축소 (height 44 -> 34, 패딩 및 폰트 축소)
  Widget _buildBottomAddButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 20,
        horizontal: 40,
      ), // 가로 패딩 늘려서 버튼 폭 줄임
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 34, // 높이 축소
            child: OutlinedButton.icon(
              onPressed: _showAddNewFriendDialog,
              icon: const Icon(
                Icons.person_add_alt_1_rounded,
                size: 14,
              ), // 아이콘 축소
              label: const Text(
                "새친구 등록",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ), // 폰트 축소
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                padding: EdgeInsets.zero,
                side: const BorderSide(color: Colors.orange, width: 1.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "명단의 마지막입니다.",
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminSectionTitle(String title, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: color.withOpacity(0.3), width: 1.5),
        ),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPromotionCard(Map<String, dynamic> s, {required bool isReady}) {
    int count = s['attendanceCount'] ?? 0;
    bool isNew = s['role'] == '새친구';
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isReady ? Colors.green.shade100 : Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isNew
                ? Colors.orange.shade50
                : (isReady ? Colors.green.shade50 : Colors.grey.shade50),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              "${s['cell']}셀",
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: isNew
                    ? Colors.orange.shade800
                    : (isReady ? Colors.green.shade800 : Colors.blueGrey),
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              s['name'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(width: 4),
            if (isNew)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  "새친구",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          "출석 $count회 | ${s['grade']}",
          style: const TextStyle(fontSize: 11),
        ),
        trailing: SizedBox(
          height: 28,
          child: ElevatedButton(
            onPressed: () => _promoteStudent(s),
            style: ElevatedButton.styleFrom(
              backgroundColor: isReady ? Colors.green : Colors.grey.shade300,
              foregroundColor: isReady ? Colors.white : Colors.black54,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text(
              isReady ? "승인" : "강제",
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar(int totalCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text(
                "학생 리스트",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              Text(
                "(총 $totalCount명)",
                style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
              ),
            ],
          ),
          if (_availableCells.length > 1)
            Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCell,
                  iconSize: 14,
                  items: _availableCells
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(
                            c == '전체' ? '전체보기' : '$c셀',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCell = v),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBirthdayBanner() {
    final list = _getBirthdayPeople();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade400, Colors.indigo.shade600],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "$_selectedBirthMonth월 생일 (총 ${list.length}명) 🎂",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              SizedBox(
                height: 18,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedBirthMonth,
                    dropdownColor: Colors.indigo.shade700,
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white,
                      size: 14,
                    ),
                    items: List.generate(12, (i) => i + 1)
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(
                              "$m월",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedBirthMonth = v!),
                  ),
                ),
              ),
            ],
          ),
          if (list.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: list
                    .map(
                      (p) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          "${p['name']} (${_selectedBirthMonth}/${p['birthDay']})",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getBirthdayPeople() {
    List<Map<String, dynamic>> results = [];
    void check(List<Map<String, dynamic>> list, String type) {
      for (var item in list) {
        var parsed = _parseBirthDate(item['birthDate']);
        if (parsed != null && parsed['month'] == _selectedBirthMonth) {
          results.add({...item, 'type': type, 'birthDay': parsed['day']});
        }
      }
    }

    check(_allStudents, '학생');
    check(_allTeachers, '교사');
    results.sort(
      (a, b) => (a['birthDay'] as int).compareTo(b['birthDay'] as int),
    );
    return results;
  }

  // ✅ [수정] 생일 파서 강화: "YYYY.MM.DD", "MM.DD", "MM-DD", "MM/DD" 등 모든 형식 대응
  Map<String, int>? _parseBirthDate(dynamic birth) {
    if (birth == null || birth.toString().trim().isEmpty) return null;
    String b = birth.toString().replaceAll(' ', ''); // 공백 제거

    // 1. "MM월 DD일" 형식
    RegExp type1 = RegExp(r'(\d{1,2})월(\d{1,2})일');
    var match1 = type1.firstMatch(b);
    if (match1 != null) {
      return {
        'month': int.parse(match1.group(1)!),
        'day': int.parse(match1.group(2)!),
      };
    }

    // 2. "YYYY-MM-DD" 또는 "YYYY.MM.DD" 또는 "YYYY/MM/DD" 형식
    RegExp type2 = RegExp(r'(\d{4})[\.\-/](\d{1,2})[\.\-/](\d{1,2})');
    var match2 = type2.firstMatch(b);
    if (match2 != null) {
      return {
        'month': int.parse(match2.group(2)!),
        'day': int.parse(match2.group(3)!),
      };
    }

    // 3. "MM.DD" 또는 "MM-DD" 또는 "MM/DD" 형식 (연도 없음)
    RegExp type3 = RegExp(r'^(\d{1,2})[\.\-/](\d{1,2})$');
    var match3 = type3.firstMatch(b);
    if (match3 != null) {
      return {
        'month': int.parse(match3.group(1)!),
        'day': int.parse(match3.group(2)!),
      };
    }

    return null;
  }

  Widget _buildStudentOneLineRow(Map<String, dynamic> s, int index) {
    String phone = s['phone'] ?? '-';
    String pName = s['parentName'] ?? '-';
    String pPhone = (s['parentPhone'] ?? '-').toString();
    bool isNewFriend = s['role'] == '새친구';
    String cellBadge = "${s['cell']}셀";
    final bool isCrisis =
        (s['attendanceCount'] ?? 0) <= 1 || s['isCrisis'] == true;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    '$index',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          s['name'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isNewFriend
                                ? Colors.orange.shade800
                                : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCrisis)
                        const Padding(
                          padding: EdgeInsets.only(left: 2),
                          child: Text("🔴", style: TextStyle(fontSize: 8)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    cellBadge,
                    style: const TextStyle(
                      fontSize: 7,
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 22,
            child: GestureDetector(
              onTap: () => _makeCall(phone),
              child: Text(
                phone,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
                textAlign: TextAlign.left,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Expanded(
            flex: 38,
            child: GestureDetector(
              onTap: () => _makeCall(pPhone),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const Icon(Icons.people_outline, size: 9, color: Colors.grey),
                  const SizedBox(width: 1),
                  Flexible(
                    child: Text(
                      "$pName($pPhone)",
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.left,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _showStudentDetails(s),
            child: Container(
              padding: const EdgeInsets.only(left: 4),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Colors.indigo,
                  ),
                  Text(
                    "상세",
                    style: TextStyle(
                      fontSize: 6,
                      color: Colors.indigo,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStudentDetails(Map<String, dynamic> s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "학생 상세 정보",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showEditDialog(s);
                    },
                    icon: const Icon(Icons.edit_note, size: 22),
                    label: const Text(
                      "수정",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                children: [
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: s['gender'] == '남자'
                              ? Colors.blue.shade50
                              : Colors.pink.shade50,
                          child: Icon(
                            s['gender'] == '남자' ? Icons.face : Icons.face_3,
                            color: s['gender'] == '남자'
                                ? Colors.blue
                                : Colors.pink,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          s['name'],
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildBadge(
                              s['grade'] ?? "-",
                              Colors.indigo.shade50,
                              Colors.indigo,
                            ),
                            const SizedBox(width: 6),
                            _buildBadge(
                              "${s['cell']}셀",
                              Colors.teal.shade50,
                              Colors.teal,
                            ),
                            const SizedBox(width: 6),
                            _buildBadge(
                              s['group'] == 'B'
                                  ? (s['role'] == '새친구' ? "새친구" : "집중케어")
                                  : "정규학생",
                              s['group'] == 'B'
                                  ? Colors.orange.shade50
                                  : Colors.green.shade50,
                              s['group'] == 'B' ? Colors.orange : Colors.green,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _detailGroup("📅 신앙 관리 현황", [
                    _detailItem(
                      "📅 첫 방문일",
                      s['firstVisitDate'],
                      icon: Icons.calendar_today_rounded,
                    ),
                    _detailItem(
                      "👣 신앙경험",
                      s['churchExperience'],
                      icon: Icons.history_edu_rounded,
                    ),
                    _detailItem(
                      "🛡️ 세례상태",
                      s['baptismStatus'] ??
                          (s['isBaptized'] == true ? '세례' : '미세례'),
                      icon: Icons.verified_user_rounded,
                    ),
                    _detailItem(
                      "📢 인도자",
                      s['evangelist'],
                      icon: Icons.campaign_rounded,
                    ),
                    _detailItem(
                      "📊 누적출석",
                      "${s['attendanceCount'] ?? 0}회",
                      icon: Icons.bar_chart_rounded,
                    ),
                  ]),
                  _detailGroup("📍 기본 인적 사항", [
                    _detailItem(
                      "📱 본인전화",
                      s['phone'],
                      icon: Icons.phone_android,
                      isPhone: true,
                    ),
                    _detailItem(
                      "🎂 생년월일",
                      s['birthDate'],
                      icon: Icons.cake_rounded,
                    ),
                    _detailItem(
                      "🏫 소속학교",
                      s['school'],
                      icon: Icons.school_rounded,
                    ),
                    _detailItem(
                      "🏠 거주주소",
                      s['address'],
                      icon: Icons.home_rounded,
                    ),
                    _detailItem(
                      "🧠 MBTI",
                      s['mbti'],
                      icon: Icons.psychology_rounded,
                    ),
                  ]),
                  _detailGroup("👨‍👩‍👧 가족 및 보호자 정보", [
                    _detailItem(
                      "👤 보호자명",
                      s['parentName'],
                      icon: Icons.person_rounded,
                    ),
                    _detailItem(
                      "📞 보호자번호",
                      s['parentPhone'],
                      icon: Icons.phone_rounded,
                      isPhone: true,
                    ),
                    _detailItem(
                      "⛪ 부모님 출석교회",
                      s['churchName'],
                      icon: Icons.church_rounded,
                    ),
                    _detailItem(
                      "🧬 형제관계",
                      s['siblings'],
                      icon: Icons.family_restroom_rounded,
                    ),
                    _detailItem(
                      "🤝 교회친구",
                      s['churchFriends'],
                      icon: Icons.group_rounded,
                    ),
                  ]),
                  if (s['notes'] != null || s['remarks'] != null)
                    _detailGroup("📝 관리 및 비고", [
                      Text(
                        s['notes'] ?? s['remarks'] ?? "",
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ]),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "닫기",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddNewFriendDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StudentRegistrationDialog(
        initialCell: _selectedCell ?? '1',
        teacherRole: widget.teacherRole,
        teacherGrade: _myGrade,
        onRegistered: (docId, finalName) async {
          await _loadInitialData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("$finalName 새친구가 등록되었습니다! 🎉")),
            );
          }
        },
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> s) {
    final messenger = ScaffoldMessenger.of(context);
    final nameController = TextEditingController(
      text: s['name']?.toString() ?? '',
    );
    final phoneController = TextEditingController(
      text: s['phone']?.toString() ?? '',
    );
    final firstVisitDateController = TextEditingController(
      text: s['firstVisitDate']?.toString() ?? '',
    );
    final evangelistController = TextEditingController(
      text: s['evangelist']?.toString() ?? '',
    );
    final churchNameController = TextEditingController(
      text: s['churchName']?.toString() ?? '',
    );
    final birthDateController = TextEditingController(
      text: s['birthDate']?.toString() ?? '',
    );
    final schoolController = TextEditingController(
      text: s['school']?.toString() ?? '',
    );
    final addressController = TextEditingController(
      text: s['address']?.toString() ?? '',
    );
    final parentNameController = TextEditingController(
      text: s['parentName']?.toString() ?? '',
    );
    final parentPhoneController = TextEditingController(
      text: s['parentPhone']?.toString() ?? '',
    );
    final mbtiController = TextEditingController(
      text: s['mbti']?.toString() ?? '',
    );
    final siblingsController = TextEditingController(
      text: s['siblings']?.toString() ?? '',
    );
    final churchFriendsController = TextEditingController(
      text: s['churchFriends']?.toString() ?? '',
    );
    final notesController = TextEditingController(
      text: (s['notes'] ?? s['remarks'])?.toString() ?? '',
    );

    final List<String> genderOptions = ['남자', '여자'];
    final List<String> roleOptions = ['학생', '새친구'];
    final List<String> baptismOptions = ['모름', '학습', '세례', '입교', '해당없음'];
    final List<String> churchExpOptions = ['유', '무'];

    String currentGender = genderOptions.contains(s['gender'])
        ? s['gender']
        : '남자';
    String currentRole = roleOptions.contains(s['role']) ? s['role'] : '학생';
    String currentBaptism = baptismOptions.contains(s['baptismStatus'])
        ? s['baptismStatus']
        : '해당없음';
    String currentChurchExp = churchExpOptions.contains(s['churchExperience'])
        ? s['churchExperience']
        : '유';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (stfCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(
            "${s['name'] ?? '학생'} 정보 수정",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _editField("이름", nameController),
                  _editField("본인 전화", phoneController),
                  _dropdownField(
                    "성별",
                    currentGender,
                    genderOptions,
                    (val) => setDialogState(() => currentGender = val!),
                  ),
                  _dropdownField(
                    "역할",
                    currentRole,
                    roleOptions,
                    (val) => setDialogState(() => currentRole = val!),
                  ),
                  _editField("첫 방문일", firstVisitDateController),
                  _editField("인도자", evangelistController),
                  _dropdownField(
                    "신앙경험",
                    currentChurchExp,
                    churchExpOptions,
                    (val) => setDialogState(() => currentChurchExp = val!),
                  ),
                  _editField("학교", schoolController),
                  _editField("주소", addressController),
                  const Divider(height: 24),
                  _editField("보호자 성함", parentNameController),
                  _editField("보호자 전화", parentPhoneController),
                  _editField("부모님 출석교회", churchNameController),
                  _dropdownField(
                    "세례 상태",
                    currentBaptism,
                    baptismOptions,
                    (val) => setDialogState(() => currentBaptism = val!),
                  ),
                  _editField("MBTI", mbtiController),
                  _editField("형제관계", siblingsController),
                  _editField("교회친구", churchFriendsController),
                  _editField("비고(메모)", notesController, maxLines: 3),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(stfCtx),
              child: const Text("취소"),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('students')
                      .doc(s['docId'])
                      .update({
                        'name': nameController.text.trim(),
                        'phone': phoneController.text.trim(),
                        'gender': currentGender,
                        'role': currentRole,
                        'firstVisitDate': firstVisitDateController.text.trim(),
                        'evangelist': evangelistController.text.trim(),
                        'churchExperience': currentChurchExp,
                        'school': schoolController.text.trim(),
                        'address': addressController.text.trim(),
                        'parentName': parentNameController.text.trim(),
                        'parentPhone': parentPhoneController.text.trim(),
                        'churchName': churchNameController.text.trim(),
                        'isBaptized': ['세례', '입교'].contains(currentBaptism),
                        'baptismStatus': currentBaptism,
                        'mbti': mbtiController.text.trim(),
                        'siblings': siblingsController.text.trim(),
                        'churchFriends': churchFriendsController.text.trim(),
                        'notes': notesController.text.trim(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                  if (!mounted) return;
                  Navigator.pop(stfCtx);
                  await _loadInitialData();
                  messenger.showSnackBar(
                    const SnackBar(content: Text("저장되었습니다.")),
                  );
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text("오류: $e")));
                }
              },
              child: const Text("저장"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12),
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
        ),
      ),
    );
  }

  Widget _dropdownField(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?>? onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: DropdownButtonFormField<String>(
        value: value,
        style: const TextStyle(fontSize: 13, color: Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12),
          border: const OutlineInputBorder(),
          filled: onChanged == null,
          fillColor: onChanged == null ? Colors.grey.shade100 : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
        ),
        items: options
            .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _detailGroup(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const Divider(height: 16, thickness: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _detailItem(
    String label,
    dynamic value, {
    IconData? icon,
    bool isPhone = false,
  }) {
    String val = (value == null || value.toString().isEmpty || value == "-")
        ? "정보 없음"
        : value.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Colors.indigo.shade300),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: isPhone && val != "정보 없음" ? () => _makeCall(val) : null,
              child: Text(
                val,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isPhone && val != "정보 없음"
                      ? Colors.blue
                      : Colors.black87,
                  decoration: isPhone && val != "정보 없음"
                      ? TextDecoration.underline
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _makeCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber == '-' || phoneNumber.isEmpty)
      return;
    try {
      final String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      final Uri url = Uri.parse('tel:$cleanNumber');
      if (await canLaunchUrl(url)) await launchUrl(url);
    } catch (e) {
      debugPrint("전화 걸기 오류: $e");
    }
  }
}
