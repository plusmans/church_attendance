import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
    // ✅ '담당'일 경우 1로, 그 외엔 받은 값 그대로 유지
    _currentCell = widget.teacherCell == '담당' ? '1' : widget.teacherCell;
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

      // ✅ [핵심] Firestore 문서 ID가 '1셀_날짜' 형식이므로 0을 제거한 숫자만 사용
      String cleanCellNum = _currentCell == 'teachers'
          ? 'teachers'
          : (int.tryParse(_currentCell) ?? _currentCell).toString();

      String docId = _currentCell == 'teachers'
          ? 'teachers_$dateStr'
          : '${cleanCellNum}셀_$dateStr';

      debugPrint("🔎 [로드 요청] 문서 ID: $docId");

      var doc = await FirebaseFirestore.instance
          .collection('attendance')
          .doc(docId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> records = Map<String, dynamic>.from(
          doc.data()?['records'] ?? {},
        );
        var sortedNames = records.keys.toList()..sort();

        // 기존 컨트롤러 정리
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

  Future<void> _saveAttendance() async {
    if (_memberNames.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      String dateStr = DateFormat('yyyy-MM-dd').format(_targetDate);

      // ✅ [핵심] 저장할 때도 0이 없는 '1셀_날짜' 형식 유지
      String cleanCellNum = _currentCell == 'teachers'
          ? 'teachers'
          : (int.tryParse(_currentCell) ?? _currentCell).toString();

      String docId = _currentCell == 'teachers'
          ? 'teachers_$dateStr'
          : '${cleanCellNum}셀_$dateStr';

      debugPrint("🔎 [저장하기] 문서 ID: $docId");

      // 텍스트 필드 값 최종 반영
      for (var name in _memberNames) {
        _attendanceData[name]!['customReason'] =
            _customReasonControllers[name]?.text ?? '';
      }

      // ✅ [중요 수정] 실제 데이터 필드를 채워서 저장합니다.
      await FirebaseFirestore.instance.collection('attendance').doc(docId).set({
        'cell': cleanCellNum,
        'date': dateStr,
        'records': _attendanceData,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // attendance_input.dart의 _saveAttendance 내
      if (mounted) {
        // 스낵바를 띄우기 전 미리 화면을 닫는 것도 방법입니다.
        Navigator.pop(context, true);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("💾 출석 정보가 저장되었습니다.")));
      }
    } catch (e) {
      debugPrint("❌ 저장 에러: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("저장 실패: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isTeacherMode = _currentCell == 'teachers';
    // ✅ 입력 화면용 로그 (에러 없음)
    debugPrint(
      "🎨 [입력화면 그리기] 명단 개수: ${_memberNames.length}, 로딩상태: $_isLoading",
    );
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          isTeacherMode ? "교사 출석 입력" : "학생 출석 입력",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: isTeacherMode ? Colors.orange : Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
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
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
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
      floatingActionButton: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: 55,
        child: FloatingActionButton.extended(
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
                          child: Text('${val.padLeft(2, '0')}셀'), // 화면 표시만 01셀로
                        ),
                      )
                      .toList(),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _currentCell = val;
                      _loadData();
                    });
                  }
                },
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
