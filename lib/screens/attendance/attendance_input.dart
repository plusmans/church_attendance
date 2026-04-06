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
    // 👇 담당자 로그인 시 기본 셀을 '1'에서 'teachers'(교사전체)로 변경합니다.
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

      var doc = await FirebaseFirestore.instance
          .collection('attendance')
          .doc(docId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> records = Map<String, dynamic>.from(
          doc.data()?['records'] ?? {},
        );
        var sortedNames = records.keys.toList()..sort();

        _customReasonControllers.values.forEach((c) => c.dispose());
        _customReasonControllers.clear();

        for (var name in sortedNames) {
          _customReasonControllers[name] = TextEditingController(
            text: records[name]['customReason'] ?? '',
          );
        }

        setState(() {
          _memberNames = sortedNames;
          _attendanceData = records.map(
            (key, value) => MapEntry(key, Map<String, dynamic>.from(value)),
          );
        });
      } else {
        // 👇👇 이번 주 명단이 없을 때 마스터 DB(students/teachers)에서 최신 명단 불러오기 👇👇
        try {
          QuerySnapshot snapshot;

          if (_currentCell == 'teachers') {
            // 교사 전체 명단 가져오기
            snapshot = await FirebaseFirestore.instance
                .collection('teachers')
                .get();
          } else {
            // 선택된 셀(반)의 학생 명단 가져오기
            snapshot = await FirebaseFirestore.instance
                .collection('students')
                .where('cell', isEqualTo: cleanCellNum)
                .get();
          }

          _customReasonControllers.values.forEach((c) => c.dispose());
          _customReasonControllers.clear();
          _attendanceData.clear();
          List<String> loadedNames = [];

          for (var doc in snapshot.docs) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            String name = data['name'] ?? '이름없음';
            loadedNames.add(name);
            _customReasonControllers[name] = TextEditingController();

            // 학생/교사 기본 정보 매핑 및 출석 상태를 기본값(결석)으로 세팅
            _attendanceData[name] = {
              'status': '결석',
              'reason': '연락x',
              'customReason': '',
              // 마스터 DB의 필드명을 기존 코드에 맞게 매핑
              'gender': data['gender'] ?? '모름',
              'grade': data['grade'] ?? '',
              'birth': data['birthDate'] ?? '', // DB의 birthDate를 birth로 사용
              'phone': data['phone'] ?? '',
              'school': data['school'] ?? '',
              'address': data['address'] ?? '',
              'memo': data['notes'] ?? '', // DB의 notes를 memo로 사용
              'parentName': data['parentName'] ?? '',
              'parentChurchAttendance': data['parentChurchAttendance'] ?? '모름',
              'parentRole': data['parentRole'] ?? '',
              'parentPhone': data['parentPhone'] ?? '',
              'role':
                  data['role'] ?? (_currentCell == 'teachers' ? '교사' : '학생'),
            };
          }

          loadedNames.sort(); // 이름 가나다순 정렬

          setState(() {
            _memberNames = loadedNames;
          });
        } catch (error) {
          debugPrint("❌ 마스터 DB 명단 로드 에러: $error");
          setState(() {
            _memberNames = [];
            _attendanceData = {};
          });
        }
        // 👆👆 로직 수정 끝 👆👆
      }
    } catch (e) {
      debugPrint("❌ 로드 에러: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ [분리 및 수정] 새친구 상세 등록 다이얼로그 (students 컬렉션에 DB 직접 저장)
  void _addNewStudent() {
    final nameController = TextEditingController();
    final birthController = TextEditingController();
    final phoneController = TextEditingController();
    final schoolController = TextEditingController();
    final addressController = TextEditingController();
    final memoController = TextEditingController();
    final parentNameController = TextEditingController();
    final parentRoleController = TextEditingController();
    final parentPhoneController = TextEditingController();

    String gender = '남자';
    String grade = '1학년'; // DB 포맷에 맞춤
    String parentChurchAttendance = '출석(본교회)';
    bool isSavingDialog = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                '🎉 새친구 상세 등록',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _SectionTitle(
                        title: "📍 학생 기본 정보",
                        color: Colors.teal,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: nameController,
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
                              '성별',
                              gender,
                              ['남자', '여자'],
                              (val) => setStateDialog(() => gender = val!),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // DB grade 포맷인 1학년, 2학년, 3학년으로 변경
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
                              controller: birthController,
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
                              controller: phoneController,
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
                        controller: schoolController,
                        decoration: const InputDecoration(
                          labelText: '학교',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: addressController,
                        decoration: const InputDecoration(
                          labelText: '주소',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: memoController,
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
                              controller: parentNameController,
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
                                    parentChurchAttendance,
                                    ['출석(본교회)', '출석(타교회)', '미출석', '모름'],
                                    (val) => setStateDialog(
                                      () => parentChurchAttendance = val!,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: parentRoleController,
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
                              controller: parentPhoneController,
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
                  onPressed: isSavingDialog
                      ? null
                      : () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: isSavingDialog
                      ? null
                      : () async {
                          String newName = nameController.text.trim();
                          if (newName.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('이름을 입력해주세요.')),
                            );
                            return;
                          }

                          setStateDialog(() => isSavingDialog = true);

                          try {
                            String cleanCellNum =
                                (int.tryParse(_currentCell) ?? _currentCell)
                                    .toString();
                            String paddedCell = cleanCellNum.padLeft(2, '0');

                            // 💡 요청하신 문서 ID 포맷: 01셀_1학년_김라현
                            String docId = '${paddedCell}셀_${grade}_$newName';

                            // 💡 students 컬렉션에 데이터 저장 (기존 포맷 적용)
                            await FirebaseFirestore.instance
                                .collection('students')
                                .doc(docId)
                                .set({
                                  'address': addressController.text.trim(),
                                  'birthDate': birthController.text.trim(),
                                  'cell': cleanCellNum,
                                  'grade': grade,
                                  'isBaptized': false,
                                  'name': newName,
                                  'notes': memoController.text.trim(),
                                  'parentName': parentNameController.text
                                      .trim(),
                                  'parentPhone': parentPhoneController.text
                                      .trim(),
                                  'phone': phoneController.text.trim(),
                                  'role': '학생',
                                  'school': schoolController.text.trim(),
                                  'gender': gender, // 화면 입력을 위해 추가
                                  'parentChurchAttendance':
                                      parentChurchAttendance, // 화면 입력을 위해 추가
                                  'parentRole': parentRoleController.text
                                      .trim(), // 화면 입력을 위해 추가
                                }, SetOptions(merge: true));

                            // 현재 화면 리스트(출석부)에도 바로 추가
                            setState(() {
                              if (!_memberNames.contains(newName)) {
                                _memberNames.add(newName);
                                _memberNames.sort();
                                _attendanceData[newName] = {
                                  'status': '출석',
                                  'reason': '연락x',
                                  'customReason': '',
                                  'gender': gender,
                                  'grade': grade,
                                  'birth': birthController.text.trim(),
                                  'phone': phoneController.text.trim(),
                                  'school': schoolController.text.trim(),
                                  'address': addressController.text.trim(),
                                  'memo': memoController.text.trim(),
                                  'parentName': parentNameController.text
                                      .trim(),
                                  'parentChurchAttendance':
                                      parentChurchAttendance,
                                  'parentRole': parentRoleController.text
                                      .trim(),
                                  'parentPhone': parentPhoneController.text
                                      .trim(),
                                  'role': '학생',
                                };
                                _customReasonControllers[newName] =
                                    TextEditingController();
                              }
                            });

                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('🎉 새친구가 DB 명단에 등록되었습니다!'),
                                ),
                              );
                            }
                          } catch (e) {
                            debugPrint("❌ 새친구 등록 에러: $e");
                            if (mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('저장 중 오류가 발생했습니다.'),
                                ),
                              );
                          } finally {
                            setStateDialog(() => isSavingDialog = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  child: isSavingDialog
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
            );
          },
        );
      },
    );
  }

  // ✅ [수정 완료] 신규교사 등록 다이얼로그 (새로운 교사 문서 포맷 반영)
  void _addNewTeacher() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final birthController = TextEditingController();

    String selectedCell = '1';
    String selectedGrade = '1학년';
    bool isSavingDialog = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                '🎉 신규교사 등록',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
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
                            selectedCell,
                            List.generate(10, (i) => '${i + 1}')..add('담당'),
                            (val) => setStateDialog(() => selectedCell = val!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildDropdown(
                            '담당 학년',
                            selectedGrade,
                            ['1학년', '2학년', '3학년', '공통'],
                            (val) => setStateDialog(() => selectedGrade = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: birthController,
                      decoration: const InputDecoration(
                        labelText: '생일 (예: 19900402)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneController,
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
                  onPressed: isSavingDialog
                      ? null
                      : () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: isSavingDialog
                      ? null
                      : () async {
                          String newName = nameController.text.trim();
                          if (newName.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('이름을 입력해주세요.')),
                            );
                            return;
                          }

                          setStateDialog(() => isSavingDialog = true);

                          try {
                            String paddedCell = selectedCell == '담당'
                                ? '담당'
                                : selectedCell.padLeft(2, '0');

                            // 💡 요청하신 교사 문서 ID 포맷: 03_2학년_이해영
                            String docId = selectedCell == '담당'
                                ? '담당_$newName'
                                : '${paddedCell}_${selectedGrade}_$newName';

                            // 💡 교사 컬렉션(teachers)에 지정된 필드 구조로 데이터 저장
                            await FirebaseFirestore.instance
                                .collection('teachers')
                                .doc(docId)
                                .set({
                                  'birthDate': birthController.text.trim(),
                                  'cell': selectedCell, // 예: "3"
                                  'grade': selectedGrade, // 예: "2학년"
                                  'name': newName,
                                  'phone': phoneController.text.trim(),
                                  'role': '교사',
                                }, SetOptions(merge: true));

                            // 현재 화면이 '교사전체(teachers)' 출석 모드라면 리스트에 바로 추가되도록 함
                            if (_currentCell == 'teachers') {
                              setState(() {
                                if (!_memberNames.contains(newName)) {
                                  _memberNames.add(newName);
                                  _memberNames.sort();
                                  _attendanceData[newName] = {
                                    'status': '출석',
                                    'reason': '연락x',
                                    'customReason': '',
                                    'birth': birthController.text.trim(),
                                    'phone': phoneController.text.trim(),
                                    'grade': selectedGrade,
                                    'role': '교사',
                                  };
                                  _customReasonControllers[newName] =
                                      TextEditingController();
                                }
                              });
                            }

                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('👨‍🏫 신규 교사가 DB 명단에 등록되었습니다!'),
                                ),
                              );
                            }
                          } catch (e) {
                            debugPrint("❌ 교사 등록 에러: $e");
                            if (mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('저장 중 오류가 발생했습니다.'),
                                ),
                              );
                          } finally {
                            setStateDialog(() => isSavingDialog = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: isSavingDialog
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
            );
          },
        );
      },
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

      for (var name in _memberNames) {
        if (_attendanceData.containsKey(name)) {
          _attendanceData[name]!['customReason'] =
              _customReasonControllers[name]?.text ?? '';
        }
      }

      await FirebaseFirestore.instance.collection('attendance').doc(docId).set({
        'cell': cleanCellNum,
        'date': dateStr,
        'records': _attendanceData,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("💾 출석 정보가 저장되었습니다.")));

        if (Navigator.of(context).canPop()) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      debugPrint("❌ 저장 에러: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isTeacherMode = _currentCell == 'teachers';
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          isTeacherMode ? "교사 출석 입력" : "학생 출석 입력",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: isTeacherMode ? Colors.orange : Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildTopSelector(),
          if (!_isLoading && _memberNames.isNotEmpty)
            _buildSummaryArea(), // 💡 요약 영역 추가
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
                      bool isPresent = data['status'] == '출석';
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
                                  const Spacer(),
                                  _statusButton(
                                    name,
                                    '출석',
                                    isPresent,
                                    Colors.teal,
                                  ),
                                  const SizedBox(width: 8),
                                  _statusButton(
                                    name,
                                    '결석',
                                    !isPresent,
                                    Colors.red.shade400,
                                  ),
                                ],
                              ),
                              if (!isPresent) ...[
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
              // 💡 모드에 따라 함수를 분리 호출
              onPressed: isTeacherMode ? _addNewTeacher : _addNewStudent,
              backgroundColor: Colors.white,
              icon: Icon(
                Icons.person_add,
                color: isTeacherMode ? Colors.orange : Colors.teal,
              ),
              label: Text(
                isTeacherMode ? "신규교사" : "새친구",
                style: TextStyle(
                  color: isTeacherMode ? Colors.orange : Colors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FloatingActionButton.extended(
                heroTag: "saveBtn",
                onPressed: _isLoading ? null : _saveAttendance,
                backgroundColor: isTeacherMode ? Colors.orange : Colors.teal,
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

  // 💡 실시간 출석 요약 위젯
  Widget _buildSummaryArea() {
    int presentCount = _attendanceData.values
        .where((e) => e['status'] == '출석')
        .length;
    int absentCount = _attendanceData.values
        .where((e) => e['status'] != '출석')
        .length;
    int totalCount = _memberNames.length;

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
          _summaryChip('총원', totalCount, Colors.blueGrey),
          _summaryChip('출석', presentCount, Colors.teal),
          _summaryChip('결석', absentCount, Colors.red.shade400),
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
      selectableDayPredicate: (DateTime day) =>
          day.weekday == DateTime.sunday, // 일요일만
    );
    if (picked != null && picked != _targetDate) {
      setState(() {
        _targetDate = picked;
        _loadData();
      });
    }
  }

  @override
  void dispose() {
    _customReasonControllers.values.forEach((c) => c.dispose());
    super.dispose();
  }
}

// 헬퍼 위젯: 섹션 타이틀
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
