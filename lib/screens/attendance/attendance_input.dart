import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'attendance_status.dart';

class AttendanceInputScreen extends StatefulWidget {
  final String teacherCell;
  final DateTime? selectedDate;

  const AttendanceInputScreen({
    super.key,
    required this.teacherCell,
    this.selectedDate,
  });

  @override
  State<AttendanceInputScreen> createState() => _AttendanceInputScreenState();
}

class _AttendanceInputScreenState extends State<AttendanceInputScreen> {
  bool _isLoading = true;
  late DateTime _targetDate;
  late String _currentCell;

  Map<String, Map<String, dynamic>> _attendanceData = {};
  // ✅ 로드 시점의 출석 상태를 저장 (저장 시 +1, -1 계산용)
  Map<String, String> _initialStatusMap = {};
  List<String> _memberNames = [];
  Map<String, TextEditingController> _customReasonControllers = {};

  final List<String> _absenceReasons = [
    '연락x',
    '장기결석',
    '늦잠',
    '질병',
    '여행',
    '친척방문',
    '타교회',
    '본당예배',
    '학원',
    '기타',
  ];

  @override
  void initState() {
    super.initState();
    _targetDate = widget.selectedDate ?? _getRecentSunday();
    _currentCell = widget.teacherCell == '담당' ? 'teachers' : widget.teacherCell;
    _loadData();
  }

  DateTime _getRecentSunday() {
    DateTime now = DateTime.now();
    int daysToSubtract = now.weekday % 7;
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: daysToSubtract));
  }

  // ✅ 그룹 정보 추출 로직 (group 필드 우선, 없으면 isRegular 참조)
  String _extractGroup(Map<String, dynamic> data) {
    if (data.containsKey('group') &&
        data['group'] != null &&
        data['group'].toString().trim().isNotEmpty) {
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
      String cleanCellNum = _currentCell == 'teachers'
          ? 'teachers'
          : (int.tryParse(_currentCell) ?? _currentCell).toString();
      String docId = _currentCell == 'teachers'
          ? 'teachers_$dateStr'
          : '${cleanCellNum}셀_$dateStr';

      // 1. 해당 날짜 출석 기록 로드
      var doc = await FirebaseFirestore.instance
          .collection('attendance')
          .doc(docId)
          .get();

      // 2. 마스터 데이터 로드 (실시간 그룹 정보 및 문서 ID 매칭용)
      QuerySnapshot masterSnap;
      if (_currentCell == 'teachers') {
        masterSnap = await FirebaseFirestore.instance
            .collection('teachers')
            .get();
      } else {
        masterSnap = await FirebaseFirestore.instance
            .collection('students')
            .where('cell', isEqualTo: cleanCellNum)
            .get();
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

      if (doc.exists) {
        Map<String, dynamic> records = Map<String, dynamic>.from(
          doc.data()?['records'] ?? {},
        );
        var sortedNames = records.keys.toList()
          ..sort((a, b) {
            if (_currentCell == 'teachers') return a.compareTo(b);
            String gA =
                masterGroupMap[a.trim()] ??
                _extractGroup(Map<String, dynamic>.from(records[a]));
            String gB =
                masterGroupMap[b.trim()] ??
                _extractGroup(Map<String, dynamic>.from(records[b]));
            if (gA == 'A' && gB != 'A') return -1;
            if (gA != 'A' && gB == 'A') return 1;
            return a.compareTo(b);
          });

        setState(() {
          _memberNames = sortedNames;
          _attendanceData = records.map((key, value) {
            var valMap = Map<String, dynamic>.from(value);
            String cleanName = key.toString().trim();
            valMap['group'] =
                masterGroupMap[cleanName] ?? _extractGroup(valMap);
            valMap['docId'] = masterIdMap[cleanName];
            _initialStatusMap[key] = valMap['status'] ?? '결석';
            _customReasonControllers[key] = TextEditingController(
              text: valMap['customReason'] ?? '',
            );
            return MapEntry(key, valMap);
          });
        });
      } else {
        List<String> loadedNames = [];
        Map<String, Map<String, dynamic>> tempAttendanceData = {};
        for (var mDoc in masterSnap.docs) {
          Map<String, dynamic> mData = mDoc.data() as Map<String, dynamic>;
          String name = mData['name'] ?? '이름없음';
          loadedNames.add(name);
          String resGroup = _extractGroup(mData);
          _initialStatusMap[name] = '결석';
          _customReasonControllers[name] = TextEditingController();
          tempAttendanceData[name] = {
            'status': '결석',
            'reason': '연락x',
            'customReason': '',
            'gender': mData['gender'] ?? '모름',
            'grade': mData['grade'] ?? '',
            'birth': mData['birthDate'] ?? '',
            'phone': mData['phone'] ?? '',
            'school': mData['school'] ?? '',
            'address': mData['address'] ?? '',
            'memo': mData['notes'] ?? '',
            'role': mData['role'] ?? (_currentCell == 'teachers' ? '교사' : '학생'),
            'group': resGroup,
            'isRegular': resGroup == 'A',
            'docId': mDoc.id,
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
        setState(() {
          _memberNames = loadedNames;
          _attendanceData = tempAttendanceData;
        });
      }
    } catch (e) {
      debugPrint("❌ 데이터 로드 에러: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAttendance() async {
    if (_memberNames.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      String dateStr = DateFormat('yyyy-MM-dd').format(_targetDate);
      String cleanCellNum = _currentCell == 'teachers'
          ? 'teachers'
          : (int.tryParse(_currentCell) ?? _currentCell).toString();
      String docId = _currentCell == 'teachers'
          ? 'teachers_$dateStr'
          : '${cleanCellNum}셀_$dateStr';

      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var name in _memberNames) {
        if (_attendanceData.containsKey(name)) {
          _attendanceData[name]!['customReason'] =
              _customReasonControllers[name]?.text ?? '';
          String oldStatus = _initialStatusMap[name] ?? '결석';
          String newStatus = _attendanceData[name]!['status'];
          String? masterId = _attendanceData[name]!['docId'];

          if (masterId != null) {
            DocumentReference masterRef = FirebaseFirestore.instance
                .collection(
                  _currentCell == 'teachers' ? 'teachers' : 'students',
                )
                .doc(masterId);
            if (oldStatus != '출석' && newStatus == '출석') {
              batch.update(masterRef, {
                'attendanceCount': FieldValue.increment(1),
              });
            } else if (oldStatus == '출석' && newStatus != '출석') {
              batch.update(masterRef, {
                'attendanceCount': FieldValue.increment(-1),
              });
            }
          }
        }
      }

      DocumentReference attRef = FirebaseFirestore.instance
          .collection('attendance')
          .doc(docId);
      batch.set(attRef, {
        'cell': cleanCellNum,
        'date': dateStr,
        'records': _attendanceData,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("💾 출석 정보와 누적 횟수가 저장되었습니다.")),
        );
        if (Navigator.of(context).canPop()) Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("❌ 저장 에러: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ [수정] 선생님 원본 코드의 상세 입력 필드를 모두 포함한 새친구 등록 팝업
  void _addNewStudent() {
    final nC = TextEditingController();
    final bC = TextEditingController();
    final pC = TextEditingController();
    final sC = TextEditingController();
    final aC = TextEditingController();
    final mC = TextEditingController();
    final pnC = TextEditingController();
    final prC = TextEditingController();
    final ppC = TextEditingController();
    String gender = '남자';
    String grade = '1학년';
    String pCA = '출석(본교회)';
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '🎉 새친구 상세 등록',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _SectionTitle(title: "📍 학생 기본 정보", color: Colors.teal),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nC,
                    decoration: const InputDecoration(
                      labelText: '이름 (필수)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown('성별', gender, [
                          '남자',
                          '여자',
                        ], (val) => setStateDialog(() => gender = val!)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDropdown('학년', grade, [
                          '1학년',
                          '2학년',
                          '3학년',
                        ], (val) => setStateDialog(() => grade = val!)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: bC,
                          decoration: const InputDecoration(
                            labelText: '생일 (예: 20110402)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: pC,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: '연락처',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: sC,
                    decoration: const InputDecoration(
                      labelText: '학교',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: aC,
                    decoration: const InputDecoration(
                      labelText: '주소',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: mC,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '인도자 및 비고',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _SectionTitle(
                    title: "👨‍👩‍👧 부모님 정보",
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blueGrey.shade100),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: pnC,
                          decoration: const InputDecoration(
                            labelText: '부모님 성함',
                            border: OutlineInputBorder(),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildDropdown(
                                '교회 출석',
                                pCA,
                                ['출석(본교회)', '출석(타교회)', '미출석', '모름'],
                                (val) => setStateDialog(() => pCA = val!),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: prC,
                                decoration: const InputDecoration(
                                  labelText: '직분',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: ppC,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: '부모님 연락처',
                            border: OutlineInputBorder(),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (nC.text.trim().isEmpty) return;
                      setStateDialog(() => isSaving = true);
                      try {
                        String cleanCell =
                            (int.tryParse(_currentCell) ?? _currentCell)
                                .toString();
                        String docId =
                            '${cleanCell.padLeft(2, '0')}셀_${grade}_${nC.text.trim()}';
                        await FirebaseFirestore.instance
                            .collection('students')
                            .doc(docId)
                            .set({
                              'address': aC.text.trim(),
                              'birthDate': bC.text.trim(),
                              'cell': cleanCell,
                              'grade': grade,
                              'isBaptized': false,
                              'name': nC.text.trim(),
                              'notes': mC.text.trim(),
                              'parentName': pnC.text.trim(),
                              'parentPhone': ppC.text.trim(),
                              'phone': pC.text.trim(),
                              'role': '학생',
                              'school': sC.text.trim(),
                              'gender': gender,
                              'parentChurchAttendance': pCA,
                              'parentRole': prC.text.trim(),
                              'group': 'B',
                              'isRegular': false,
                              'attendanceCount': 0,
                            }, SetOptions(merge: true));

                        setState(() {
                          String newName = nC.text.trim();
                          _memberNames.add(newName);
                          _attendanceData[newName] = {
                            'status': '출석',
                            'reason': '연락x',
                            'customReason': '',
                            'gender': gender,
                            'grade': grade,
                            'birth': bC.text.trim(),
                            'phone': pC.text.trim(),
                            'school': sC.text.trim(),
                            'address': aC.text.trim(),
                            'memo': mC.text.trim(),
                            'role': '학생',
                            'isRegular': false,
                            'group': 'B',
                            'docId': docId,
                          };
                          _initialStatusMap[newName] = '결석';
                          _customReasonControllers[newName] =
                              TextEditingController();
                          _memberNames.sort((a, b) {
                            String grA = _attendanceData[a]!['group'] ?? 'A';
                            String grB = _attendanceData[b]!['group'] ?? 'A';
                            if (grA == 'A' && grB != 'A') return -1;
                            if (grA != 'A' && grB == 'A') return 1;
                            return a.compareTo(b);
                          });
                        });
                        if (mounted) Navigator.pop(context);
                      } finally {
                        setStateDialog(() => isSaving = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('리스트에 추가'),
            ),
          ],
        ),
      ),
    );
  }

  void _addNewTeacher() {
    final nC = TextEditingController();
    final pC = TextEditingController();
    final bC = TextEditingController();
    String sCell = '1';
    String sGrade = '1학년';
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '🎉 신규교사 등록',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nC,
                  decoration: const InputDecoration(
                    labelText: '이름 (필수)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        '담당 반',
                        sCell,
                        List.generate(10, (i) => '${i + 1}')..add('담당'),
                        (val) => setStateDialog(() => sCell = val!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDropdown('담당 학년', sGrade, [
                        '1학년',
                        '2학년',
                        '3학년',
                        '공통',
                      ], (val) => setStateDialog(() => sGrade = val!)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: bC,
                  decoration: const InputDecoration(
                    labelText: '생일 (예: 19900402)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pC,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: '연락처',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (nC.text.trim().isEmpty) return;
                      setStateDialog(() => isSaving = true);
                      try {
                        String pCell = sCell == '담당'
                            ? '담당'
                            : sCell.padLeft(2, '0');
                        String docId = sCell == '담당'
                            ? '담당_${nC.text.trim()}'
                            : '${pCell}_${sGrade}_${nC.text.trim()}';
                        await FirebaseFirestore.instance
                            .collection('teachers')
                            .doc(docId)
                            .set({
                              'birthDate': bC.text.trim(),
                              'cell': sCell,
                              'grade': sGrade,
                              'name': nC.text.trim(),
                              'phone': pC.text.trim(),
                              'role': '교사',
                            }, SetOptions(merge: true));

                        if (_currentCell == 'teachers') {
                          setState(() {
                            String newName = nC.text.trim();
                            _memberNames.add(newName);
                            _memberNames.sort();
                            _attendanceData[newName] = {
                              'status': '출석',
                              'reason': '연락x',
                              'customReason': '',
                              'birth': bC.text.trim(),
                              'phone': pC.text.trim(),
                              'grade': sGrade,
                              'role': '교사',
                              'docId': docId,
                            };
                            _initialStatusMap[newName] = '결석';
                            _customReasonControllers[newName] =
                                TextEditingController();
                          });
                        }
                        if (mounted) Navigator.pop(context);
                      } finally {
                        setStateDialog(() => isSaving = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('등록하기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      value: value,
      items: items
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(e, style: const TextStyle(fontSize: 13)),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isTMode = _currentCell == 'teachers';
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          isTMode ? "교사 출석 입력" : "학생 출석 입력",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: isTMode ? Colors.orange : Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildTopSelector(),
          if (!_isLoading && _memberNames.isNotEmpty) _buildSummaryArea(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _memberNames.isEmpty
                ? const Center(child: Text("해당 날짜에 등록된 명단이 없습니다."))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                    itemCount: _memberNames.length,
                    itemBuilder: (context, index) {
                      String name = _memberNames[index];
                      var data = _attendanceData[name]!;
                      bool isP = data['status'] == '출석';
                      String group = data['group'] ?? 'A';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${index + 1}. $name',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (!isTMode) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: group == 'A'
                                            ? Colors.indigo.shade50
                                            : Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        group == 'A' ? 'A그룹' : 'B그룹',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: group == 'A'
                                              ? Colors.indigo
                                              : Colors.orange,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const Spacer(),
                                  _statusButton(name, '출석', isP, Colors.teal),
                                  const SizedBox(width: 8),
                                  _statusButton(
                                    name,
                                    '결석',
                                    !isP,
                                    Colors.red.shade400,
                                  ),
                                ],
                              ),
                              if (!isP) ...[
                                const SizedBox(height: 12),
                                _buildReasonDropdown(name, data),
                                if (data['reason'] == '기타') ...[
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _customReasonControllers[name],
                                    decoration: const InputDecoration(
                                      hintText: "상세 사유 입력",
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            FloatingActionButton.extended(
              heroTag: "addBtn",
              onPressed: isTMode ? _addNewTeacher : _addNewStudent,
              backgroundColor: Colors.white,
              icon: Icon(
                Icons.person_add,
                color: isTMode ? Colors.orange : Colors.teal,
              ),
              label: Text(
                isTMode ? "신규교사" : "새친구",
                style: TextStyle(
                  color: isTMode ? Colors.orange : Colors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FloatingActionButton.extended(
                heroTag: "saveBtn",
                onPressed: _isLoading ? null : _saveAttendance,
                backgroundColor: isTMode ? Colors.orange : Colors.teal,
                label: const Text(
                  "출석 정보 저장하기",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                icon: const Icon(Icons.save, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '📅 기준일:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () => _selectDate(context),
                child: Text(
                  DateFormat('yyyy. MM. dd').format(_targetDate),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '✅ 선택 반:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              DropdownButton<String>(
                value: _currentCell,
                items: [
                  const DropdownMenuItem(
                    value: 'teachers',
                    child: Text('교사전체'),
                  ),
                  ...List.generate(10, (i) => '${i + 1}')
                      .map(
                        (val) => DropdownMenuItem(
                          value: val,
                          child: Text('${val.padLeft(2, '0')}셀'),
                        ),
                      )
                      .toList(),
                ],
                onChanged: (val) {
                  if (val != null)
                    setState(() {
                      _currentCell = val;
                      _loadData();
                    });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryArea() {
    int pC = _attendanceData.values.where((e) => e['status'] == '출석').length;
    int aC = _attendanceData.values.where((e) => e['status'] != '출석').length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _summaryChip('총원', _memberNames.length, Colors.blueGrey),
          _summaryChip('출석', pC, Colors.teal),
          _summaryChip('결석', aC, Colors.red.shade400),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count명',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonDropdown(String name, Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _absenceReasons.contains(data['reason'])
              ? data['reason']
              : '기타',
          items: _absenceReasons
              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
              .toList(),
          onChanged: (val) {
            setState(() {
              _attendanceData[name]!['reason'] = val;
              if (val != '기타') _customReasonControllers[name]?.clear();
            });
          },
        ),
      ),
    );
  }

  Widget _statusButton(
    String name,
    String label,
    bool isSelected,
    Color activeColor,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _attendanceData[name]!['status'] = label;
          if (label == '출석') {
            _attendanceData[name]!['reason'] = '연락x';
            _customReasonControllers[name]?.clear();
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime(2026, 1, 1),
      lastDate: DateTime.now(),
      locale: const Locale('ko', 'KR'),
      selectableDayPredicate: (DateTime day) => day.weekday == DateTime.sunday,
    );
    if (picked != null && picked != _targetDate)
      setState(() {
        _targetDate = picked;
        _loadData();
      });
  }

  @override
  void dispose() {
    _customReasonControllers.values.forEach((c) => c.dispose());
    super.dispose();
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionTitle({required this.title, required this.color});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 4, height: 16, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
