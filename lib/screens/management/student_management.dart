import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

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

  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _allTeachers = [];

  int _selectedBirthMonth = DateTime.now().month;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // 렌더링 전 데이터 로딩 안정성 확보
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
      if (myInfo.isNotEmpty) myGrade = myInfo['grade'] ?? '공통';

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

  String _getThisSunday() {
    DateTime now = DateTime.now();
    int difference = now.weekday % 7;
    DateTime lastSunday = now.subtract(Duration(days: difference));
    return DateFormat('yyyy-MM-dd').format(lastSunday);
  }

  // ✅ 등반 처리: role은 변경하지 않고 기존 값(새친구) 유지
  Future<void> _promoteStudent(Map<String, dynamic> s) async {
    int attendance = s['attendanceCount'] ?? 0;
    String autoDate = _getThisSunday();

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
              "등반 주일: $autoDate",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "해당 학생을 정규 리스트(A그룹)로 이동하시겠습니까?\n(역할은 기존 대로 유지됩니다.)",
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
              'promotionDate': autoDate,
              'updatedAt': FieldValue.serverTimestamp(),
            });
        await _loadInitialData(); // 데이터 새로고침
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("${s['name']} 학생이 $autoDate부로 등반되었습니다! 🎉")),
          );
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("오류 발생: $e")));
      }
    }
  }

  Map<String, int>? _parseBirthDate(dynamic birth) {
    if (birth == null) return null;
    String b = birth.toString();
    RegExp type1 = RegExp(r'(\d{1,2})월\s*(\d{1,2})일');
    RegExp type2 = RegExp(r'\d{2}\.(\d{1,2})\.(\d{1,2})');
    var match1 = type1.firstMatch(b);
    if (match1 != null)
      return {
        'month': int.tryParse(match1.group(1) ?? '') ?? 0,
        'day': int.tryParse(match1.group(2) ?? '') ?? 0,
      };
    var match2 = type2.firstMatch(b);
    if (match2 != null)
      return {
        'month': int.tryParse(match2.group(1) ?? '') ?? 0,
        'day': int.tryParse(match2.group(2) ?? '') ?? 0,
      };
    return null;
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

  @override
  Widget build(BuildContext context) {
    bool isSuperAdmin = [
      '강도사',
      '부장',
      'admin',
      '개발자',
    ].contains(widget.teacherRole);

    return DefaultTabController(
      key: ValueKey(isSuperAdmin), // 탭 개수 변경 시 강제 리빌드로 에러 방지
      length: isSuperAdmin ? 2 : 1,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          toolbarHeight: 0,
          bottom: TabBar(
            labelColor: Colors.indigo,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.indigo,
            tabs: [
              const Tab(text: "전체 명단"),
              if (isSuperAdmin) const Tab(text: "등반/행정 관리"),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildListViewSection(),
                  if (isSuperAdmin) _buildAdminActionSection(),
                ],
              ),
      ),
    );
  }

  // --- 탭 1: 전체 명단 (role 기반 구분 및 셀 번호 표시) ---
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
    // ✅ role 필드('새친구' vs '학생')로 구분
    List<Map<String, dynamic>> groupBNew = filteredList
        .where((s) => s['group'] == 'B' && s['role'] == '새친구')
        .toList();
    List<Map<String, dynamic>> groupBOld = filteredList
        .where((s) => s['group'] == 'B' && s['role'] != '새친구')
        .toList();

    return Column(
      children: [
        _buildControlBar(filteredList.length),
        _buildBirthdayBanner(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              if (groupBNew.isNotEmpty) ...[
                _buildGroupHeader("🐣 신규 등록 (새친구)", Colors.orange),
                ...groupBNew.map((s) => _buildStudentOneLineRow(s)),
              ],
              if (groupBOld.isNotEmpty) ...[
                _buildGroupHeader("🔍 장기 결석 및 특별 관리", Colors.redAccent),
                ...groupBOld.map((s) => _buildStudentOneLineRow(s)),
              ],
              if (groupA.isNotEmpty) ...[
                _buildGroupHeader("💎 정규 명단 (A그룹)", Colors.indigo),
                ...groupA.map((s) => _buildStudentOneLineRow(s)),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
      ],
    );
  }

  // --- 탭 2: 등반 관리 (role 기반 구분) ---
  Widget _buildAdminActionSection() {
    List<Map<String, dynamic>> groupBTotal = _allStudents
        .where((s) => s['group'] == 'B')
        .toList();

    // 등반 대기: B그룹 중 role이 '새친구'이면서 출석 4회 이상
    List<Map<String, dynamic>> readyToPromote = groupBTotal
        .where((s) => (s['attendanceCount'] ?? 0) >= 4 && s['role'] == '새친구')
        .toList();
    // B그룹 관리: 그 외 모든 B그룹 인원
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
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ...readyToPromote.map((s) => _buildPromotionCard(s, isReady: true)),
        const SizedBox(height: 30),
        _buildAdminSectionTitle("🔍 B그룹 관리 대상 (새친구 포함)", Colors.orange),
        if (managementTarget.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: Text(
                "관리 중인 B그룹 인원이 없습니다.",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ...managementTarget.map(
            (s) => _buildPromotionCard(s, isReady: false),
          ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildAdminSectionTitle(String title, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: color.withOpacity(0.3))),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
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
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isReady ? Colors.green.shade200 : Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 55,
          height: 55,
          decoration: BoxDecoration(
            color: isNew
                ? Colors.orange.shade50
                : (isReady ? Colors.green.shade50 : Colors.grey.shade50),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              "${s['cell']}셀", // ✅ "1" -> "1셀" 수정
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isNew
                    ? Colors.orange
                    : (isReady ? Colors.green : Colors.blueGrey),
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              s['name'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            if (isNew)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "새친구",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          "출석 $count회 | ${s['grade']} | ${isNew ? '신규등록' : '기존학생'}",
        ),
        trailing: ElevatedButton(
          onPressed: () => _promoteStudent(s),
          style: ElevatedButton.styleFrom(
            backgroundColor: isReady ? Colors.green : Colors.grey.shade400,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            isReady ? "등반 승인" : "강제 등반",
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text(
                "학생 리스트",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Text(
                "(총 $totalCount명)",
                style: const TextStyle(fontSize: 14, color: Colors.blueGrey),
              ),
            ],
          ),
          if (_availableCells.length > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCell,
                  items: _availableCells
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(
                            c == '전체' ? '전체보기' : '$c셀',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                              fontSize: 13,
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
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade400, Colors.indigo.shade700],
        ),
        borderRadius: BorderRadius.circular(15),
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
                  fontSize: 14,
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedBirthMonth,
                  dropdownColor: Colors.indigo.shade700,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                  items: List.generate(12, (i) => i + 1)
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text(
                            "$m월",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedBirthMonth = v!),
                ),
              ),
            ],
          ),
          if (list.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: list
                    .map(
                      (p) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "${p['name']} (${_selectedBirthMonth}/${p['birthDay']})",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
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

  // ✅ 한 줄 명단: 소속 셀 배지 추가
  Widget _buildStudentOneLineRow(Map<String, dynamic> s) {
    bool isMale = s['gender'] == '남자';
    String phone = s['phone'] ?? '-';
    String pName = s['parentName'] ?? '-';
    String pPhone = (s['parentPhone'] ?? '-').toString();
    bool isNewFriend = s['role'] == '새친구';
    String cellBadge = "${s['cell']}셀";

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Row(
              children: [
                Icon(
                  isMale ? Icons.male : Icons.female,
                  color: isMale ? Colors.blue : Colors.pink,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    s['name'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isNewFriend
                          ? Colors.orange.shade800
                          : Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
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
                      fontSize: 8,
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: GestureDetector(
              onTap: () => _makeCall(phone),
              child: Text(
                phone,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 6,
            child: GestureDetector(
              onTap: () => _makeCall(pPhone),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: 11,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      "$pName($pPhone)",
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.assignment_ind_outlined,
              size: 20,
              color: Colors.indigo,
            ),
            onPressed: () => _showStudentDetails(s),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "학생 상세 정보",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showEditDialog(s);
                    },
                    icon: const Icon(Icons.edit_note, size: 20),
                    label: const Text("정보 수정"),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                children: [
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: s['gender'] == '남자'
                              ? Colors.blue.shade50
                              : Colors.pink.shade50,
                          child: Icon(
                            s['gender'] == '남자' ? Icons.face : Icons.face_3,
                            color: s['gender'] == '남자'
                                ? Colors.blue
                                : Colors.pink,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          s['name'],
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
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
                  const SizedBox(height: 32),
                  _detailGroup("📍 기본 인적 사항", [
                    _detailItem("📱 본인전화", s['phone'], isPhone: true),
                    _detailItem("🎂 생년월일", s['birthDate']),
                    _detailItem("🏫 중학교", s['school']),
                    _detailItem("🏠 거주주소", s['address']),
                  ]),
                  _detailGroup("👨‍👩‍👧 가족 및 보호자 정보", [
                    _detailItem("👤 학부모 성함", s['parentName']),
                    _detailItem("📞 학부모 전화", s['parentPhone'], isPhone: true),
                    _detailItem("🎖️ 학부모 직분", s['parentRole']),
                    _detailItem("⛪ 출석교회", s['churchName']),
                    _detailItem("🧬 형제관계", s['siblings']),
                  ]),
                  _detailGroup("🌱 신앙 및 성향", [
                    _detailItem("🛡️ 세례상태", s['baptismStatus']),
                    _detailItem("🧠 MBTI", s['mbti']),
                    _detailItem("🤝 교회친구", s['churchFriends']),
                    _detailItem("📊 누적출석", "${s['attendanceCount'] ?? 0}회"),
                  ]),
                  if (s['remarks'] != null)
                    _detailGroup("📝 관리 및 비고", [
                      Text(
                        s['remarks'] ?? "",
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ]),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("닫기"),
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

  void _showEditDialog(Map<String, dynamic> s) {
    final nameController = TextEditingController(text: s['name']);
    final phoneController = TextEditingController(text: s['phone']);
    final schoolController = TextEditingController(text: s['school']);
    final addressController = TextEditingController(text: s['address']);
    final parentNameController = TextEditingController(text: s['parentName']);
    final parentPhoneController = TextEditingController(text: s['parentPhone']);
    final parentRoleController = TextEditingController(text: s['parentRole']);
    final churchNameController = TextEditingController(text: s['churchName']);
    final mbtiController = TextEditingController(text: s['mbti']);
    final siblingsController = TextEditingController(text: s['siblings']);
    final friendsController = TextEditingController(text: s['churchFriends']);
    final remarksController = TextEditingController(text: s['remarks']);

    final List<String> genderOptions = ['남자', '여자'];
    final List<String> roleOptions = ['학생', '새친구']; // ✅ 역할 목록
    final List<String> baptismOptions = ['모름', '학습', '세례', '입교', '해당없음'];

    String currentGender = s['gender'] ?? '남자';
    String currentRole = s['role'] ?? '학생';
    String currentBaptism = s['baptismStatus'] ?? '해당없음';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            "${s['name']} 정보 수정",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

                  // ✅ 역할 선택 (학생/새친구)
                  _dropdownField(
                    "역할 (학생/새친구)",
                    currentRole,
                    roleOptions,
                    (val) => setDialogState(() => currentRole = val!),
                  ),

                  _editField("학교", schoolController),
                  _editField("주소", addressController),
                  const Divider(height: 32),
                  _editField("학부모 성함", parentNameController),
                  _editField("학부모 전화", parentPhoneController),
                  _editField("학부모 직분", parentRoleController),
                  _editField("출석 교회", churchNameController),
                  const Divider(height: 32),
                  _dropdownField(
                    "세례 상태",
                    currentBaptism,
                    baptismOptions,
                    (val) => setDialogState(() => currentBaptism = val!),
                  ),
                  _editField("MBTI", mbtiController),
                  _editField("형제관계", siblingsController),
                  _editField("친한친구", friendsController),
                  _editField("비고", remarksController, maxLines: 3),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("취소"),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('students')
                      .doc(s['docId'])
                      .update({
                        'name': nameController.text,
                        'phone': phoneController.text,
                        'gender': currentGender,
                        'role': currentRole,
                        'school': schoolController.text,
                        'address': addressController.text,
                        'parentName': parentNameController.text,
                        'parentPhone': parentPhoneController.text,
                        'parentRole': parentRoleController.text,
                        'churchName': churchNameController.text,
                        'baptismStatus': currentBaptism,
                        'mbti': mbtiController.text,
                        'siblings': siblingsController.text,
                        'churchFriends': friendsController.text,
                        'remarks': remarksController.text,
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                  if (!mounted) return;
                  Navigator.pop(context);
                  await _loadInitialData();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text("저장되었습니다.")));
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("오류: $e")));
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
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
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
      padding: const EdgeInsets.only(bottom: 12.0),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: onChanged == null,
          fillColor: onChanged == null ? Colors.grey.shade100 : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        items: options
            .map(
              (opt) => DropdownMenuItem(
                value: opt,
                child: Text(opt, style: const TextStyle(fontSize: 14)),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _detailGroup(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const Divider(height: 24, thickness: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _detailItem(String label, dynamic value, {bool isPhone = false}) {
    String val = (value == null || value.toString().isEmpty || value == "-")
        ? "정보 없음"
        : value.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: isPhone && val != "정보 없음" ? () => _makeCall(val) : null,
              child: Text(
                val,
                style: TextStyle(
                  fontSize: 14,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
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
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    } catch (e) {
      debugPrint("전화 걸기 오류: $e");
    }
  }
}
