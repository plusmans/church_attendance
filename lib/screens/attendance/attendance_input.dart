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
    '연락x', '장기결석', '늦잠', '질병', '여행', '친척방문', '타교회', '본당예배', '학원', '기타',
  ];

  @override
  void initState() {
    super.initState();
    _targetDate = widget.selectedDate ?? _getRecentSunday();
    _currentCell = widget.teacherCell == '담당' ? '1' : widget.teacherCell;
    _loadData();
  }

  DateTime _getRecentSunday() {
    DateTime now = DateTime.now();
    int daysToSubtract = now.weekday % 7;
    return DateTime(now.year, now.month, now.day).subtract(Duration(days: daysToSubtract));
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      String dateStr = DateFormat('yyyy-MM-dd').format(_targetDate);
      String cleanCellNum = _currentCell == 'teachers' ? 'teachers' : (int.tryParse(_currentCell) ?? _currentCell).toString();
      String docId = _currentCell == 'teachers' ? 'teachers_$dateStr' : '${cleanCellNum}셀_$dateStr';

      var doc = await FirebaseFirestore.instance.collection('attendance').doc(docId).get();

      if (doc.exists) {
        Map<String, dynamic> records = Map<String, dynamic>.from(doc.data()?['records'] ?? {});
        var sortedNames = records.keys.toList()..sort();

        _customReasonControllers.values.forEach((c) => c.dispose());
        _customReasonControllers.clear();

        for (var name in sortedNames) {
          _customReasonControllers[name] = TextEditingController(text: records[name]['customReason'] ?? '');
        }

        setState(() {
          _memberNames = sortedNames;
          _attendanceData = records.map((key, value) => MapEntry(key, Map<String, dynamic>.from(value)));
        });
      } else {
        setState(() {
          _memberNames = [];
          _attendanceData = {};
        });
      }
    } catch (e) {
      debugPrint("❌ 로드 에러: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ [복원] 새친구 상세 등록 다이얼로그
  void _addNewMember() {
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
    String grade = '중1';
    String parentChurchAttendance = '출석(본교회)';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('🎉 새친구 상세 등록', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _SectionTitle(title: "📍 학생 기본 정보", color: Colors.teal),
                      const SizedBox(height: 10),
                      TextField(controller: nameController, decoration: const InputDecoration(labelText: '이름 (필수)', border: OutlineInputBorder(), isDense: true)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _buildDropdown('성별', gender, ['남자', '여자'], (val) => setStateDialog(() => gender = val!))),
                          const SizedBox(width: 10),
                          Expanded(child: _buildDropdown('학년', grade, ['중1', '중2', '중3'], (val) => setStateDialog(() => grade = val!))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: birthController, decoration: const InputDecoration(labelText: '생일 (예: 0514)', border: OutlineInputBorder(), isDense: true))),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: '연락처', border: OutlineInputBorder(), isDense: true))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(controller: schoolController, decoration: const InputDecoration(labelText: '학교', border: OutlineInputBorder(), isDense: true)),
                      const SizedBox(height: 10),
                      TextField(controller: addressController, decoration: const InputDecoration(labelText: '주소', border: OutlineInputBorder(), isDense: true)),
                      const SizedBox(height: 10),
                      TextField(controller: memoController, maxLines: 2, decoration: const InputDecoration(labelText: '인도자 및 비고', border: OutlineInputBorder(), isDense: true)),
                      const SizedBox(height: 20),
                      const _SectionTitle(title: "👨‍👩‍👧 부모님 정보", color: Colors.blueGrey),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blueGrey.shade100)),
                        child: Column(
                          children: [
                            TextField(controller: parentNameController, decoration: const InputDecoration(labelText: '부모님 성함', border: OutlineInputBorder(), isDense: true, filled: true, fillColor: Colors.white)),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(flex: 3, child: _buildDropdown('교회 출석', parentChurchAttendance, ['출석(본교회)', '출석(타교회)', '미출석', '모름'], (val) => setStateDialog(() => parentChurchAttendance = val!))),
                                const SizedBox(width: 8),
                                Expanded(flex: 2, child: TextField(controller: parentRoleController, decoration: const InputDecoration(labelText: '직분', border: OutlineInputBorder(), isDense: true, filled: true, fillColor: Colors.white))),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(controller: parentPhoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: '부모님 연락처', border: OutlineInputBorder(), isDense: true, filled: true, fillColor: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
                ElevatedButton(
                  onPressed: () {
                    String newName = nameController.text.trim();
                    if (newName.isEmpty) return;
                    setState(() {
                      if (!_memberNames.contains(newName)) {
                        _memberNames.add(newName);
                        _memberNames.sort();
                        _attendanceData[newName] = {
                          'status': '출석', 'reason': '연락x', 'customReason': '',
                          'gender': gender, 'grade': grade, 'birth': birthController.text.trim(),
                          'phone': phoneController.text.trim(), 'school': schoolController.text.trim(),
                          'address': addressController.text.trim(), 'memo': memoController.text.trim(),
                          'parentName': parentNameController.text.trim(), 'parentChurchAttendance': parentChurchAttendance,
                          'parentRole': parentRoleController.text.trim(), 'parentPhone': parentPhoneController.text.trim(),
                          'role': '새친구',
                        };
                        _customReasonControllers[newName] = TextEditingController();
                      }
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  child: const Text('리스트에 추가'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
      value: value,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
      onChanged: onChanged,
    );
  }

  Future<void> _saveAttendance() async {
    if (_memberNames.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      String dateStr = DateFormat('yyyy-MM-dd').format(_targetDate);
      String cleanCellNum = _currentCell == 'teachers' ? 'teachers' : (int.tryParse(_currentCell) ?? _currentCell).toString();
      String docId = _currentCell == 'teachers' ? 'teachers_$dateStr' : '${cleanCellNum}셀_$dateStr';

      for (var name in _memberNames) {
        if (_attendanceData.containsKey(name)) {
          _attendanceData[name]!['customReason'] = _customReasonControllers[name]?.text ?? '';
        }
      }

      await FirebaseFirestore.instance.collection('attendance').doc(docId).set({
        'cell': cleanCellNum, 'date': dateStr, 'records': _attendanceData, 'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("💾 출석 정보가 저장되었습니다.")),
  );

  // 현재 화면이 Push로 들어온 화면인지 확인하고 pop
  if (Navigator.of(context).canPop()) {
    Navigator.pop(context, true); // true를 던져서 통계 페이지 새로고침 유도
  } 
}
/*
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("💾 출석 정보가 저장되었습니다.")));
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context, true);
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AttendanceStatusScreen()));
        }
      } */
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
        title: Text(isTeacherMode ? "교사 출석 입력" : "학생 출석 입력", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: isTeacherMode ? Colors.orange : Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildTopSelector(),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Text('${index + 1}. $name', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                                      const Spacer(),
                                      _statusButton(name, '출석', isPresent, Colors.teal),
                                      const SizedBox(width: 8),
                                      _statusButton(name, '결석', !isPresent, Colors.red.shade400),
                                    ],
                                  ),
                                  if (!isPresent) ...[
                                    const SizedBox(height: 12),
                                    _buildReasonDropdown(name, data),
                                    if (data['reason'] == '기타') ...[
                                      const SizedBox(height: 8),
                                      TextField(controller: _customReasonControllers[name], decoration: const InputDecoration(hintText: "상세 사유 입력", isDense: true, border: OutlineInputBorder(), filled: true, fillColor: Colors.white), style: const TextStyle(fontSize: 14)),
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
            FloatingActionButton(heroTag: "addBtn", onPressed: _addNewMember, backgroundColor: Colors.white, child: Icon(Icons.person_add, color: isTeacherMode ? Colors.orange : Colors.teal)),
            const SizedBox(width: 12),
            Expanded(
              child: FloatingActionButton.extended(heroTag: "saveBtn", onPressed: _isLoading ? null : _saveAttendance, backgroundColor: isTeacherMode ? Colors.orange : Colors.teal, label: const Text("출석 정보 저장하기", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)), icon: const Icon(Icons.save, color: Colors.white)),
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
              const Text('📅 기준일:', style: TextStyle(fontWeight: FontWeight.bold)),
              TextButton(onPressed: () => _selectDate(context), child: Text(DateFormat('yyyy. MM. dd').format(_targetDate), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal))),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('✅ 선택 반:', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: _currentCell,
                items: [
                  const DropdownMenuItem(value: 'teachers', child: Text('교사전체')),
                  ...List.generate(10, (i) => '${i + 1}').map((val) => DropdownMenuItem(value: val, child: Text('${val.padLeft(2, '0')}셀'))).toList(),
                ],
                onChanged: (val) { if (val != null) setState(() { _currentCell = val; _loadData(); }); },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReasonDropdown(String name, Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _absenceReasons.contains(data['reason']) ? data['reason'] : '기타',
          items: _absenceReasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
          onChanged: (val) { setState(() { _attendanceData[name]!['reason'] = val; if (val != '기타') _customReasonControllers[name]?.clear(); }); },
        ),
      ),
    );
  }

  Widget _statusButton(String name, String label, bool isSelected, Color activeColor) {
    return GestureDetector(
      onTap: () { setState(() { _attendanceData[name]!['status'] = label; if (label == '출석') { _attendanceData[name]!['reason'] = '연락x'; _customReasonControllers[name]?.clear(); } }); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? activeColor : Colors.grey.shade100, borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? activeColor : Colors.grey.shade300)),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 13)),
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
      selectableDayPredicate: (DateTime day) => day.weekday == DateTime.sunday, // 일요일만
    );
    if (picked != null && picked != _targetDate) { setState(() { _targetDate = picked; _loadData(); }); }
  }

  @override
  void dispose() { _customReasonControllers.values.forEach((c) => c.dispose()); super.dispose(); }
}

// 헬퍼 위젯: 섹션 타이틀
class _SectionTitle extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionTitle({required this.title, required this.color});
  @override
  Widget build(BuildContext context) {
    return Row(children: [Container(width: 4, height: 16, color: color), const SizedBox(width: 8), Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color))]);
  }
}