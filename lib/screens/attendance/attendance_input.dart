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

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadData();
    });
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

      var doc = await FirebaseFirestore.instance
          .collection('attendance')
          .doc(docId)
          .get();

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

        if (mounted) {
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
        }
      } else {
        List<String> loadedNames = [];
        Map<String, Map<String, dynamic>> tempAttendanceData = {};

        // ✅ [수정] 교사전체 선택 시 기본 상태를 '출석'으로, 학생일 경우 '결석'으로 설정
        String defaultStatus = _currentCell == 'teachers' ? '출석' : '결석';

        for (var mDoc in masterSnap.docs) {
          Map<String, dynamic> mData = mDoc.data() as Map<String, dynamic>;
          String name = mData['name'] ?? '이름없음';
          loadedNames.add(name);
          String resGroup = _extractGroup(mData);

          _initialStatusMap[name] = defaultStatus;
          _customReasonControllers[name] = TextEditingController();
          tempAttendanceData[name] = {
            'status': defaultStatus,
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
        if (mounted) {
          setState(() {
            _memberNames = loadedNames;
            _attendanceData = tempAttendanceData;
          });
        }
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
            if (oldStatus != '출석' && newStatus == '출석')
              batch.update(masterRef, {
                'attendanceCount': FieldValue.increment(1),
              });
            else if (oldStatus == '출석' && newStatus != '출석')
              batch.update(masterRef, {
                'attendanceCount': FieldValue.increment(-1),
              });
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("💾 출석 정보가 저장되었습니다.")));
        if (Navigator.of(context).canPop()) Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("❌ 저장 에러: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addNewStudent() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StudentRegistrationDialog(
        initialCell: _currentCell,
        teacherRole: widget.teacherRole,
        teacherGrade: widget.teacherGrade,
        onRegistered: (docId, finalName) {
          setState(() {
            _memberNames.add(finalName);
            _attendanceData[finalName] = {
              'status': '출석',
              'reason': '연락x',
              'customReason': '',
              'docId': docId,
              'group': 'B',
              'isRegular': false,
              'role': '새친구',
            };
            _initialStatusMap[finalName] = '결석';
            _customReasonControllers[finalName] = TextEditingController();
            _memberNames.sort((a, b) {
              String gA = _attendanceData[a]?['group'] ?? 'A';
              String gB = _attendanceData[b]?['group'] ?? 'A';
              if (gA == 'A' && gB != 'A') return -1;
              if (gA != 'A' && gB == 'A') return 1;
              return a.compareTo(b);
            });
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
          if (!_isLoading && _memberNames.isNotEmpty)
            _buildSummaryArea(mainColor),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 30),
                    itemCount: _memberNames.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _memberNames.length) {
                        return _buildActionButtons(mainColor, isTMode);
                      }

                      String name = _memberNames[index];
                      var data = _attendanceData[name]!;
                      bool isP = data['status'] == '출석';
                      String group = data['group'] ?? 'A';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: isP
                              ? Colors.white
                              : Colors.red.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isP
                                ? Colors.grey.shade100
                                : Colors.red.shade50,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  SizedBox(
                                    width: 18,
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (!isTMode) ...[
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: group == 'A'
                                                  ? Colors.indigo.shade50
                                                  : Colors.orange.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                            ),
                                            child: Text(
                                              group,
                                              style: TextStyle(
                                                fontSize: 8,
                                                color: group == 'A'
                                                    ? Colors.indigo
                                                    : Colors.orange,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  _miniStatusToggle(
                                    name,
                                    isP,
                                    mainColor,
                                    isTMode,
                                  ),
                                ],
                              ),
                              if (!isP) ...[
                                const SizedBox(height: 6),
                                if (isTMode)
                                  _buildCustomReasonField(name)
                                else ...[
                                  _buildReasonDropdown(name, data),
                                  if (data['reason'] == '기타') ...[
                                    const SizedBox(height: 6),
                                    _buildCustomReasonField(name),
                                  ],
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
    );
  }

  Widget _buildCustomReasonField(String name) {
    return SizedBox(
      height: 32,
      child: TextField(
        controller: _customReasonControllers[name],
        decoration: InputDecoration(
          hintText: "결석 사유 직접 입력",
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          filled: true,
          fillColor: Colors.white,
        ),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildActionButtons(Color mainColor, bool isTMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isTMode)
                OutlinedButton.icon(
                  onPressed: _addNewStudent,
                  icon: const Icon(Icons.person_add, size: 14),
                  label: const Text(
                    "새친구 등록",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: mainColor,
                    side: BorderSide(color: mainColor),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              if (!isTMode) const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveAttendance,
                icon: const Icon(Icons.save, size: 14),
                label: const Text(
                  "출석 정보 저장",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "명단의 마지막입니다.",
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _miniStatusToggle(
    String name,
    bool isP,
    Color mainColor,
    bool isTMode,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _miniButton(name, '출석', isP, mainColor, isTMode),
        const SizedBox(width: 3),
        _miniButton(name, '결석', !isP, Colors.red.shade400, isTMode),
      ],
    );
  }

  Widget _miniButton(
    String name,
    String label,
    bool isSelected,
    Color color,
    bool isTMode,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _attendanceData[name]!['status'] = label;
          if (label == '출석') {
            _attendanceData[name]!['reason'] = '연락x';
            _customReasonControllers[name]?.clear();
          } else {
            if (isTMode) {
              _attendanceData[name]!['reason'] = '기타';
            }
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade500,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildTopSelector(Color mainColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _selectDate(context),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 12, color: mainColor),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('yyyy. MM. dd').format(_targetDate),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, size: 18, color: mainColor),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            height: 28,
            decoration: BoxDecoration(
              color: mainColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _currentCell,
                iconSize: 16,
                items: [
                  const DropdownMenuItem(
                    value: 'teachers',
                    child: Text(
                      '교사전체',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...List.generate(10, (i) => '${i + 1}')
                      .map(
                        (val) => DropdownMenuItem(
                          value: val,
                          child: Text(
                            '${val.padLeft(2, '0')}셀',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryArea(Color mainColor) {
    int pC = _attendanceData.values.where((e) => e['status'] == '출석').length;
    int aC = _attendanceData.values.where((e) => e['status'] != '출석').length;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      color: Colors.grey.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _sumItem('전체', _memberNames.length, Colors.blueGrey),
          _sumItem('출석', pC, mainColor),
          _sumItem('결석', aC, Colors.red.shade400),
        ],
      ),
    );
  }

  Widget _sumItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 9, color: color)),
        Text(
          '$count명',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildReasonDropdown(String name, Map<String, dynamic> data) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _absenceReasons.contains(data['reason'])
              ? data['reason']
              : '기타',
          items: _absenceReasons
              .map(
                (r) => DropdownMenuItem(
                  value: r,
                  child: Text(r, style: const TextStyle(fontSize: 12)),
                ),
              )
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
