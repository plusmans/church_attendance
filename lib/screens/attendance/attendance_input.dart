import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AttendanceInputScreen extends StatefulWidget {
  final String teacherCell;

  const AttendanceInputScreen({super.key, required this.teacherCell});

  @override
  State<AttendanceInputScreen> createState() => _AttendanceInputScreenState();
}

class _AttendanceInputScreenState extends State<AttendanceInputScreen> {
  late String _selectedCell;
  late DateTime _selectedDate;

  List<Map<String, dynamic>> _studentsList = [];
  Map<String, Map<String, dynamic>> _attendanceData = {};
  bool _isLoading = false;

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

  DateTime _getRecentSunday() {
    DateTime now = DateTime.now();
    int daysToSubtract = now.weekday % 7;
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: daysToSubtract));
  }

  @override
  void initState() {
    super.initState();
    _selectedCell = widget.teacherCell == '담당' ? '1' : widget.teacherCell;
    _selectedDate = _getRecentSunday();
    _fetchStudentsAndAttendance();
  }

  // 📅 날짜 선택 (한국어 설정 & 미래 날짜 차단 적용)
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(DateTime.now())
          ? DateTime.now()
          : _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
      locale: const Locale('ko', 'KR'),
      selectableDayPredicate: (DateTime date) {
        return date.weekday == DateTime.sunday;
      },
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.teal,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchStudentsAndAttendance();
    }
  }

  Future<void> _fetchStudentsAndAttendance() async {
    setState(() {
      _isLoading = true;
    });

    try {
      var studentSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('cell', isEqualTo: _selectedCell)
          .get();

      List<Map<String, dynamic>> loadedStudents = [];

      for (var doc in studentSnapshot.docs) {
        var data = doc.data();
        bool isBeforeRegistration = false;

        if (data.containsKey('registeredAt') && data['registeredAt'] != null) {
          DateTime regDate = (data['registeredAt'] as Timestamp).toDate();
          DateTime pureRegDate = DateTime(
            regDate.year,
            regDate.month,
            regDate.day,
          );
          DateTime pureSelectedDate = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
          );

          if (pureRegDate.isAfter(pureSelectedDate)) {
            isBeforeRegistration = true;
          }
        }

        data['isBeforeRegistration'] = isBeforeRegistration;
        loadedStudents.add(data);
      }

      loadedStudents.sort(
        (a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''),
      );

      String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      String paddedCell = '${_selectedCell.padLeft(2, '0')}셀';
      String docId = '${paddedCell}_$formattedDate';

      var attendanceDoc = await FirebaseFirestore.instance
          .collection('attendance')
          .doc(docId)
          .get();
      Map<String, Map<String, dynamic>> loadedData = {};

      if (attendanceDoc.exists &&
          attendanceDoc.data()!.containsKey('records')) {
        Map<String, dynamic> existingRecords = attendanceDoc.data()!['records'];
        for (var student in loadedStudents) {
          String name = student['name'];
          if (existingRecords.containsKey(name)) {
            loadedData[name] = Map<String, dynamic>.from(existingRecords[name]);
          } else {
            loadedData[name] = {
              'status': '출석',
              'reason': '연락x',
              'customReason': '',
            };
          }
        }
      } else {
        for (var student in loadedStudents) {
          loadedData[student['name']] = {
            'status': '출석',
            'reason': '연락x',
            'customReason': '',
          };
        }
      }

      setState(() {
        _studentsList = loadedStudents;
        _attendanceData = loadedData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showAddStudentDialog() {
    TextEditingController nameController = TextEditingController();
    TextEditingController birthController = TextEditingController();
    TextEditingController phoneController = TextEditingController();
    TextEditingController schoolController = TextEditingController();
    TextEditingController addressController = TextEditingController();
    TextEditingController memoController = TextEditingController();
    TextEditingController parentNameController = TextEditingController();
    TextEditingController parentRoleController = TextEditingController();
    TextEditingController parentPhoneController = TextEditingController();

    String gender = '남자';
    String grade = '중1';
    String parentChurchAttendance = '출석(본교회)';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text(
                '🎉 새친구 상세 등록',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '[$_selectedCell셀]에 새로운 친구의 상세 정보를 입력합니다.',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: '이름 (필수)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: '성별',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              value: gender,
                              items: ['남자', '여자']
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) =>
                                  setStateDialog(() => gender = val!),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: '학년',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              value: grade,
                              items: ['중1', '중2', '중3']
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) =>
                                  setStateDialog(() => grade = val!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: birthController,
                              decoration: const InputDecoration(
                                labelText: '생일 (선택)',
                                hintText: '예: 0514',
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
                                labelText: '연락처 (선택)',
                                hintText: '010-...',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: schoolController,
                        decoration: const InputDecoration(
                          labelText: '학교 (선택)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: addressController,
                        decoration: const InputDecoration(
                          labelText: '주소 (선택)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: memoController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: '인도자 및 비고 (선택)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          border: Border.all(color: Colors.blueGrey.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.family_restroom,
                                  size: 18,
                                  color: Colors.blueGrey,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  '부모님 정보',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueGrey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
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
                                  child: DropdownButtonFormField<String>(
                                    decoration: const InputDecoration(
                                      labelText: '교회 출석',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    value: parentChurchAttendance,
                                    items: ['출석(본교회)', '출석(타교회)', '미출석', '모름']
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(
                                              e,
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (val) => setStateDialog(
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    String newName = nameController.text.trim();
                    if (newName.isEmpty) return;
                    Navigator.pop(context);
                    setState(() {
                      _isLoading = true;
                    });
                    try {
                      await FirebaseFirestore.instance
                          .collection('students')
                          .add({
                            'name': newName,
                            'gender': gender,
                            'grade': grade,
                            'birth': birthController.text.trim(),
                            'phone': phoneController.text.trim(),
                            'school': schoolController.text.trim(),
                            'address': addressController.text.trim(),
                            'memo': memoController.text.trim(),
                            'parentName': parentNameController.text.trim(),
                            'parentChurchAttendance': parentChurchAttendance,
                            'parentRole': parentRoleController.text.trim(),
                            'parentPhone': parentPhoneController.text.trim(),
                            'cell': _selectedCell,
                            'role': '새친구',
                            'registeredAt': FieldValue.serverTimestamp(),
                          });
                      _fetchStudentsAndAttendance();
                    } catch (e) {
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  },
                  child: const Text('저장하기'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _onSaveButtonPressed() async {
    String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    String paddedCell = '${_selectedCell.padLeft(2, '0')}셀';
    String docId = '${paddedCell}_$formattedDate';

    Map<String, Map<String, dynamic>> finalDataToSave = {};
    for (var student in _studentsList) {
      if (student['isBeforeRegistration'] == true) continue;
      finalDataToSave[student['name']] = _attendanceData[student['name']]!;
    }

    try {
      await FirebaseFirestore.instance.collection('attendance').doc(docId).set({
        'cell': _selectedCell,
        'date': formattedDate,
        'records': finalDataToSave,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('🎉 출석 저장 완료!')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: const BoxDecoration(color: Colors.white),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '📅 출석 기준일:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _selectDate(context),
                      icon: const Icon(
                        Icons.calendar_month,
                        color: Colors.teal,
                      ),
                      label: Text(
                        DateFormat('yyyy. MM. dd').format(_selectedDate),
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
                      '✅ 출석 체크 반:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _showAddStudentDialog,
                          icon: const Icon(
                            Icons.person_add,
                            color: Colors.orange,
                          ),
                        ),
                        DropdownButton<String>(
                          value: _selectedCell,
                          items: List.generate(10, (i) => '${i + 1}')
                              .map(
                                (val) => DropdownMenuItem(
                                  value: val,
                                  child: Text('${val.padLeft(2, '0')}셀'),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null)
                              setState(() {
                                _selectedCell = val;
                                _fetchStudentsAndAttendance();
                              });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.teal),
                  )
                : ListView.builder(
                    itemCount: _studentsList.length,
                    itemBuilder: (context, index) {
                      var student = _studentsList[index];
                      String name = student['name'];
                      bool isDisabled = student['isBeforeRegistration'] == true;
                      var data = _attendanceData[name]!;

                      return Opacity(
                        opacity: isDisabled ? 0.4 : 1.0,
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    // ✅ [수정 완료] 이름 앞에 순번(index + 1) 추가
                                    Text(
                                      '${index + 1}. $name',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (isDisabled)
                                      const Text(
                                        '🚫 등록 전 날짜',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                                if (!isDisabled) ...[
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                data['status'] == '출석'
                                                ? Colors.teal
                                                : Colors.grey.shade200,
                                          ),
                                          onPressed: () => setState(
                                            () =>
                                                _attendanceData[name]!['status'] =
                                                    '출석',
                                          ),
                                          child: const Text('출석'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                data['status'] == '결석'
                                                ? Colors.red.shade400
                                                : Colors.grey.shade200,
                                          ),
                                          onPressed: () => setState(
                                            () =>
                                                _attendanceData[name]!['status'] =
                                                    '결석',
                                          ),
                                          child: const Text('결석'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (data['status'] == '결석')
                                    DropdownButton<String>(
                                      isExpanded: true,
                                      value: data['reason'],
                                      items: _absenceReasons
                                          .map(
                                            (r) => DropdownMenuItem(
                                              value: r,
                                              child: Text(r),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (val) => setState(
                                        () => _attendanceData[name]!['reason'] =
                                            val!,
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onSaveButtonPressed,
        backgroundColor: Colors.teal,
        label: const Text('출석 저장하기', style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.save, color: Colors.white),
      ),
    );
  }
}
