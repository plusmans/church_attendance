import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../widgets/student_registration_dialog.dart';

class AttendanceInputScreen extends StatefulWidget {
  final String teacherCell;
  final String teacherRole;
  final String teacherGrade;
  final DateTime? selectedDate;

  const AttendanceInputScreen({
    super.key,
    required this.teacherCell,
    required this.teacherRole,
    required this.teacherGrade,
    this.selectedDate,
  });

  @override
  State<AttendanceInputScreen> createState() => _AttendanceInputScreenState();
}

class _AttendanceInputScreenState extends State<AttendanceInputScreen> {
  bool _isLoading = true;
  DateTime _targetDate = DateTime.now();
  String _currentCell = '1';
  Map<String, Map<String, dynamic>> _attendanceData = {};
  Map<String, String> _initialStatusMap = {};
  List<String> _memberNames = [];
  Map<String, TextEditingController> _customReasonControllers = {};

  // 학년별 셀 매핑 데이터 (학년담당 권한용)
  final Map<String, List<String>> gradeCellMap = {
    '1': ['1', '2'],
    '2': ['3', '4', '5', '6'],
    '3': ['7', '8', '9', '10'],
    '1학년': ['1', '2'],
    '2학년': ['3', '4', '5', '6'],
    '3학년': ['7', '8', '9', '10'],
    '1학년담당': ['1', '2'],
    '2학년담당': ['3', '4', '5', '6'],
    '3학년담당': ['7', '8', '9', '10'],
  };

  final List<String> _absenceReasons = [
    '연락x', '장기결석', '늦잠', '질병', '여행', '친척방문', '타교회', '본당예배', '학원', '기타',
  ];

  @override
  void initState() {
    super.initState();
    _targetDate = widget.selectedDate ?? _getRecentSunday();
    
    final String role = widget.teacherRole.trim();
    
    // 권한 그룹 판별
    final bool isAdmin = role == 'admin';
    final bool isFullAccess = isAdmin || role == '강도사' || role == '부장';
    final bool isGradeManager = role.contains('학년담당');
    
    // 초기 셀 설정 로직
    if (isFullAccess) {
      if (isAdmin) {
        // admin: 자신의 cell이 우선 (담당 위젯이면 teachers)
        _currentCell = widget.teacherCell == '담당' ? 'teachers' : widget.teacherCell;
      } else {
        // 강도사, 부장: 기본적으로 '교사전체' 선택
        _currentCell = 'teachers';
      }
    } else if (isGradeManager) {
      // 학년담당: 해당 학년의 첫 번째 셀로 초기화 (또는 본인 셀이 범위 내에 있으면 유지)
      List<String> allowed = gradeCellMap[role] ?? gradeCellMap[widget.teacherGrade.trim()] ?? [];
      if (allowed.contains(widget.teacherCell)) {
        _currentCell = widget.teacherCell;
      } else {
        _currentCell = allowed.isNotEmpty ? allowed.first : '1';
      }
    } else {
      // 일반 교사: 자신의 셀로 고정
      _currentCell = widget.teacherCell == '담당' ? 'teachers' : widget.teacherCell;
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadData();
    });
  }

  // --- 데이터 처리 로직 (기존 유지) ---
  DateTime _getRecentSunday() {
    DateTime now = DateTime.now();
    int daysToSubtract = now.weekday % 7;
    return DateTime(now.year, now.month, now.day).subtract(Duration(days: daysToSubtract));
  }

  String _extractGroup(Map<String, dynamic> data) {
    if (data.containsKey('group') && data['group'] != null && data['group'].toString().trim().isNotEmpty) {
      return data['group'].toString().trim().toUpperCase();
    }
    if (data.containsKey('isRegular') && data['isRegular'] != null) {
      return data['isRegular'] == true ? 'A' : 'B';
    }
    return 'A';
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      String dateStr = DateFormat('yyyy-MM-dd').format(_targetDate);
      String cleanCellNum = _currentCell == 'teachers' ? 'teachers' : (int.tryParse(_currentCell) ?? _currentCell).toString();
      String docId = _currentCell == 'teachers' ? 'teachers_$dateStr' : '${cleanCellNum}셀_$dateStr';

      var doc = await FirebaseFirestore.instance.collection('attendance').doc(docId).get();
      QuerySnapshot masterSnap;
      if (_currentCell == 'teachers') {
        masterSnap = await FirebaseFirestore.instance.collection('teachers').get();
      } else {
        masterSnap = await FirebaseFirestore.instance.collection('students').where('cell', isEqualTo: cleanCellNum).get();
      }

      Map<String, String> masterGroupMap = {};
      Map<String, String> masterIdMap = {};
      for (var mDoc in masterSnap.docs) {
        var mData = mDoc.data() as Map<String, dynamic>;
        String name = (mData['name'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          masterGroupMap[name] = _extractGroup(mData);
          masterIdMap[name] = mDoc.id;
        }
      }

      _customReasonControllers.values.forEach((c) => c.dispose());
      _customReasonControllers.clear();
      _initialStatusMap.clear();
      if (!mounted) return;

      if (doc.exists) {
        Map<String, dynamic> records = Map<String, dynamic>.from(doc.data()?['records'] ?? {});
        var sortedNames = records.keys.toList()..sort((a, b) {
          if (_currentCell == 'teachers') return a.compareTo(b);
          String gA = masterGroupMap[a.trim()] ?? _extractGroup(Map<String, dynamic>.from(records[a]));
          String gB = masterGroupMap[b.trim()] ?? _extractGroup(Map<String, dynamic>.from(records[b]));
          if (gA == 'A' && gB != 'A') return -1;
          if (gA != 'A' && gB == 'A') return 1;
          return a.compareTo(b);
        });

        setState(() {
          _memberNames = sortedNames;
          _attendanceData = records.map((key, value) {
            var valMap = Map<String, dynamic>.from(value);
            String cleanName = key.toString().trim();
            valMap['group'] = masterGroupMap[cleanName] ?? _extractGroup(valMap);
            valMap['docId'] = masterIdMap[cleanName];
            _initialStatusMap[key] = valMap['status'] ?? '결석';
            _customReasonControllers[key] = TextEditingController(text: valMap['customReason'] ?? '');
            return MapEntry(key, valMap);
          });
        });
      } else {
        List<String> loadedNames = [];
        Map<String, Map<String, dynamic>> tempAttendanceData = {};
        String defaultStatus = _currentCell == 'teachers' ? '출석' : '결석';
        for (var mDoc in masterSnap.docs) {
          Map<String, dynamic> mData = mDoc.data() as Map<String, dynamic>;
          String name = mData['name'] ?? '이름없음';
          loadedNames.add(name);
          String resGroup = _extractGroup(mData);
          _initialStatusMap[name] = defaultStatus;
          _customReasonControllers[name] = TextEditingController();
          tempAttendanceData[name] = {
            'status': defaultStatus, 'reason': '연락x', 'customReason': '', 'gender': mData['gender'] ?? '모름',
            'grade': mData['grade'] ?? '', 'birth': mData['birthDate'] ?? '', 'phone': mData['phone'] ?? '',
            'school': mData['school'] ?? '', 'address': mData['address'] ?? '', 'memo': mData['notes'] ?? '',
            'role': mData['role'] ?? (_currentCell == 'teachers' ? '교사' : '학생'), 'group': resGroup, 'isRegular': resGroup == 'A', 'docId': mDoc.id,
          };
        }
        loadedNames.sort((a, b) {
          if (_currentCell == 'teachers') return a.compareTo(b);
          String gA = tempAttendanceData[a]!['group'] ?? 'A';
          String gB = tempAttendanceData[b]!['group'] ?? 'A';
          if (gA == 'A' && gB != 'A') return -1;
          if (gA != 'A' && gB == 'A') return 1;
          return a.compareTo(b);
        });
        setState(() { _memberNames = loadedNames; _attendanceData = tempAttendanceData; });
      }
    } catch (e) { debugPrint("❌ 로드 에러: $e"); } finally { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _saveAttendance() async {
    if (_memberNames.isEmpty || !mounted) return;
    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      String dateStr = DateFormat('yyyy-MM-dd').format(_targetDate);
      String cleanCellNum = _currentCell == 'teachers' ? 'teachers' : (int.tryParse(_currentCell) ?? _currentCell).toString();
      String docId = _currentCell == 'teachers' ? 'teachers_$dateStr' : '${cleanCellNum}셀_$dateStr';

      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var name in _memberNames) {
        if (_attendanceData.containsKey(name)) {
          _attendanceData[name]!['customReason'] = _customReasonControllers[name]?.text ?? '';
          String oldStatus = _initialStatusMap[name] ?? '결석';
          String newStatus = _attendanceData[name]!['status'];
          String? masterId = _attendanceData[name]!['docId'];
          if (masterId != null) {
            DocumentReference masterRef = FirebaseFirestore.instance.collection(_currentCell == 'teachers' ? 'teachers' : 'students').doc(masterId);
            if (oldStatus != '출석' && newStatus == '출석') batch.update(masterRef, {'attendanceCount': FieldValue.increment(1)});
            else if (oldStatus == '출석' && newStatus != '출석') batch.update(masterRef, {'attendanceCount': FieldValue.increment(-1)});
          }
        }
      }
      batch.set(FirebaseFirestore.instance.collection('attendance').doc(docId), {
        'cell': cleanCellNum, 'date': dateStr, 'records': _attendanceData, 'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await batch.commit();
      if (mounted) { messenger.showSnackBar(const SnackBar(content: Text("💾 저장되었습니다."))); if (navigator.canPop()) navigator.pop(true); }
    } catch (e) { if (mounted) messenger.showSnackBar(const SnackBar(content: Text("❌ 저장 오류"))); } finally { if (mounted) setState(() => _isLoading = false); }
  }

  void _addNewStudent() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StudentRegistrationDialog(
        initialCell: _currentCell, teacherRole: widget.teacherRole, teacherGrade: widget.teacherGrade,
        onRegistered: (docId, finalName) {
          if (!mounted) return;
          setState(() {
            _memberNames.add(finalName);
            _attendanceData[finalName] = { 'status': '출석', 'reason': '연락x', 'customReason': '', 'docId': docId, 'group': 'B', 'isRegular': false, 'role': '새친구' };
            _initialStatusMap[finalName] = '결석'; _customReasonControllers[finalName] = TextEditingController();
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isTMode = _currentCell == 'teachers';
    Color mainColor = isTMode ? Colors.orange : Colors.teal;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildTopSelector(mainColor),
          if (!_isLoading && _memberNames.isNotEmpty) _buildSummaryArea(mainColor),
          Expanded(
            child: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 30),
              itemCount: _memberNames.length + 1,
              itemBuilder: (context, index) {
                if (index == _memberNames.length) return _buildActionButtons(mainColor, isTMode);
                String name = _memberNames[index]; var data = _attendanceData[name]!; bool isP = data['status'] == '출석';
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(color: isP ? Colors.white : Colors.red.withOpacity(0.02), borderRadius: BorderRadius.circular(10), border: Border.all(color: isP ? Colors.grey.shade100 : Colors.red.shade50)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Column(
                      children: [
                        Row(children: [SizedBox(width: 18, child: Text('${index + 1}', style: TextStyle(fontSize: 11, color: Colors.grey.shade400))), Expanded(child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))), _miniStatusToggle(name, isP, mainColor)]),
                        if (!isP) ...[const SizedBox(height: 6), isTMode ? _buildCustomReasonField(name) : _buildReasonDropdown(name, data)],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- 핵심 수정: 상단 셀 선택기 ---
  Widget _buildTopSelector(Color mainColor) {
    final String role = widget.teacherRole.trim();
    
    // 권한 판별 로직
    final bool isAdmin = role == 'admin';
    final bool isFullAccess = isAdmin || role == '강도사' || role == '부장';
    final bool isGradeManager = role.contains('학년담당');
    final bool canSelectCell = isFullAccess || isGradeManager;

    List<String> allowedCellNumbers = [];
    if (isFullAccess) {
      allowedCellNumbers = List.generate(10, (i) => '${i + 1}');
    } else if (isGradeManager) {
      // 1학년담당, 2학년담당 등 학년 키워드로 매핑 데이터 가져옴
      allowedCellNumbers = gradeCellMap[role] ?? gradeCellMap[widget.teacherGrade.trim()] ?? [];
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _selectDate(),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 12, color: mainColor),
                  const SizedBox(width: 6),
                  Text(DateFormat('yyyy. MM. dd').format(_targetDate), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  Icon(Icons.arrow_drop_down, size: 18, color: mainColor),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8), height: 28,
            decoration: BoxDecoration(color: mainColor.withOpacity(0.05), borderRadius: BorderRadius.circular(6)),
            child: DropdownButtonHideUnderline(
              child: canSelectCell
                  ? DropdownButton<String>(
                      value: _currentCell, iconSize: 16,
                      items: [
                        // fullAccess(admin, 강도사, 부장)만 교사전체 선택 가능
                        if (isFullAccess) 
                          const DropdownMenuItem(value: 'teachers', child: Text('교사전체', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        ...allowedCellNumbers.map((val) => DropdownMenuItem(value: val, child: Text('${val.padLeft(2, '0')}셀', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))),
                      ],
                      onChanged: (val) { if (val != null) setState(() { _currentCell = val; _loadData(); }); },
                    )
                  : Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(_currentCell == 'teachers' ? '교사전체' : '${_currentCell.padLeft(2, '0')}셀', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Helper 위젯들 (기존 유지) ---
  Widget _buildSummaryArea(Color mainColor) {
    int pC = _attendanceData.values.where((e) => e['status'] == '출석').length;
    int aC = _attendanceData.values.where((e) => e['status'] != '출석').length;
    return Container(padding: const EdgeInsets.symmetric(vertical: 6), color: Colors.grey.shade50, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_sumItem('전체', _memberNames.length, Colors.blueGrey), _sumItem('출석', pC, mainColor), _sumItem('결석', aC, Colors.red.shade400)]));
  }
  Widget _sumItem(String label, int count, Color color) { return Column(children: [Text(label, style: TextStyle(fontSize: 9, color: color)), Text('$count명', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color))]); }
  Widget _buildReasonDropdown(String name, Map<String, dynamic> data) { return Container(height: 32, padding: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.red.shade100)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(isExpanded: true, value: _absenceReasons.contains(data['reason']) ? data['reason'] : '기타', items: _absenceReasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12)))).toList(), onChanged: (val) { if (val != null) setState(() => _attendanceData[name]!['reason'] = val); }))); }
  Widget _buildCustomReasonField(String name) { return SizedBox(height: 32, child: TextField(controller: _customReasonControllers[name], decoration: InputDecoration(hintText: "결석 사유 입력", isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)), filled: true, fillColor: Colors.white), style: const TextStyle(fontSize: 12))); }
  Widget _buildActionButtons(Color mainColor, bool isTMode) { return Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [if (!isTMode) OutlinedButton.icon(onPressed: _addNewStudent, icon: const Icon(Icons.person_add, size: 14), label: const Text("새친구 등록", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), style: OutlinedButton.styleFrom(foregroundColor: mainColor, side: BorderSide(color: mainColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))), if (!isTMode) const SizedBox(width: 10), ElevatedButton.icon(onPressed: _isLoading ? null : _saveAttendance, icon: const Icon(Icons.save, size: 14), label: const Text("출석 저장", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), style: ElevatedButton.styleFrom(backgroundColor: mainColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))])); }
  Widget _miniStatusToggle(String name, bool isP, Color mainColor) { return Row(mainAxisSize: MainAxisSize.min, children: [_miniButton(name, '출석', isP, mainColor), const SizedBox(width: 3), _miniButton(name, '결석', !isP, Colors.red.shade400)]); }
  Widget _miniButton(String name, String label, bool isSelected, Color color) { return GestureDetector(onTap: () { if (mounted) setState(() => _attendanceData[name]!['status'] = label); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: isSelected ? color : Colors.grey.shade100, borderRadius: BorderRadius.circular(6)), child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 11)))); }
  Future<void> _selectDate() async { final DateTime? picked = await showDatePicker(context: context, initialDate: _targetDate, firstDate: DateTime(2025, 1, 1), lastDate: DateTime.now(), locale: const Locale('ko', 'KR'), selectableDayPredicate: (day) => day.weekday == DateTime.sunday); if (picked != null && mounted) { setState(() { _targetDate = picked; _loadData(); }); } }
  @override void dispose() { _customReasonControllers.values.forEach((c) => c.dispose()); super.dispose(); }
}