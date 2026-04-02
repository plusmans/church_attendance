import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    return now.subtract(Duration(days: daysToSubtract));
  }

  @override
  void initState() {
    super.initState();
    _selectedCell = widget.teacherCell == '담당' ? '1' : widget.teacherCell;
    _selectedDate = _getRecentSunday();
    _fetchStudentsAndAttendance();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
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

      String formattedDate = _selectedDate.toString().substring(0, 10);
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('데이터 로드 실패: $e')));
      }
    }
  }

  // 📝 [생일 및 부모님 정보 그룹화 추가!]
  void _showAddStudentDialog() {
    TextEditingController nameController = TextEditingController();
    TextEditingController birthController =
        TextEditingController(); // 💡 생일 컨트롤러
    TextEditingController phoneController = TextEditingController();
    TextEditingController schoolController = TextEditingController();
    TextEditingController addressController = TextEditingController();
    TextEditingController memoController = TextEditingController();

    // 💡 부모님 정보 컨트롤러
    TextEditingController parentNameController = TextEditingController();
    TextEditingController parentRoleController = TextEditingController();
    TextEditingController parentPhoneController = TextEditingController();

    String gender = '남자';
    String grade = '중1';
    String parentChurchAttendance = '출석(본교회)'; // 💡 부모님 출석 기본값

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

                      // 1. 이름 (필수)
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: '이름 (필수)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 2. 성별과 학년
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

                      // 3. 생일과 연락처
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

                      // 4. 학교 / 주소 / 비고
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
                          hintText: '동/호수까지 상세히',
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
                          hintText: '예: 홍길동 인도, 알러지 있음 등',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 👨‍👩‍👧 5. 부모님 정보 박스 (별도로 예쁘게 묶어줍니다!)
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
                                      hintText: '예: 집사',
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
                                hintText: '010-0000-0000',
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
                  child: const Text('취소', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    String newName = nameController.text.trim();
                    if (newName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('이름을 입력해주세요!')),
                      );
                      return;
                    }

                    Navigator.pop(context);
                    setState(() {
                      _isLoading = true;
                    });

                    try {
                      // 💡 생일과 부모님 정보까지 통째로 저장됩니다!
                      await FirebaseFirestore.instance
                          .collection('students')
                          .add({
                            'name': newName,
                            'gender': gender,
                            'grade': grade,
                            'birth': birthController.text.trim(), // 생일
                            'phone': phoneController.text.trim(),
                            'school': schoolController.text.trim(),
                            'address': addressController.text.trim(),
                            'memo': memoController.text.trim(),
                            // 부모님 데이터 모음
                            'parentName': parentNameController.text.trim(),
                            'parentChurchAttendance': parentChurchAttendance,
                            'parentRole': parentRoleController.text.trim(),
                            'parentPhone': parentPhoneController.text.trim(),
                            // 기본 시스템 데이터
                            'cell': _selectedCell,
                            'role': '새친구',
                            'registeredAt': FieldValue.serverTimestamp(),
                          });

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('새친구 상세 정보가 저장되었습니다! 🥳'),
                          ),
                        );
                      }

                      _fetchStudentsAndAttendance();
                    } catch (e) {
                      setState(() {
                        _isLoading = false;
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('등록 실패: $e')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  child: const Text(
                    '저장하기',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _onSaveButtonPressed() {
    if (_selectedCell != widget.teacherCell) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('대타 출석 체크 확인'),
            ],
          ),
          content: Text(
            '선생님의 담당 반(${widget.teacherCell}셀)이 아닙니다.\n\n현재 화면의 [$_selectedCell셀] 출석을\n대신 저장하시겠습니까?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _executeSave();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text(
                '네, 대신 저장합니다',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    } else {
      _executeSave();
    }
  }

  Future<void> _executeSave() async {
    String formattedDate = _selectedDate.toString().substring(0, 10);
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

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('🎉 출석이 성공적으로 저장되었습니다!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      }
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
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
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
                        color: Colors.black87,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _selectDate(context),
                      icon: const Icon(
                        Icons.calendar_month,
                        color: Colors.teal,
                      ),
                      label: Text(
                        _selectedDate.toString().substring(0, 10),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        backgroundColor: Colors.teal.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '✅ 출석 체크 반:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _showAddStudentDialog,
                          icon: const Icon(
                            Icons.person_add_alt_1,
                            color: Colors.deepOrange,
                          ),
                          tooltip: '새친구 등록',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.orange.shade50,
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _selectedCell,
                          underline: Container(height: 2, color: Colors.teal),
                          items: List.generate(10, (index) {
                            String cellNum = '${index + 1}';
                            String displayCell = '${cellNum.padLeft(2, '0')}셀';
                            return DropdownMenuItem(
                              value: cellNum,
                              child: Text(
                                displayCell,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedCell = newValue;
                              });
                              _fetchStudentsAndAttendance();
                            }
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
                : _studentsList.isEmpty
                ? const Center(child: Text('해당 반에 학생이 없습니다.'))
                : ListView.builder(
                    itemCount: _studentsList.length,
                    itemBuilder: (context, index) {
                      var student = _studentsList[index];
                      String name = student['name'];
                      String role = student['role'];
                      bool isDisabled = student['isBeforeRegistration'] == true;

                      var studentData = _attendanceData[name]!;
                      String status = studentData['status'];
                      String reason = studentData['reason'];

                      return Opacity(
                        opacity: isDisabled ? 0.4 : 1.0,
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          elevation: isDisabled ? 0 : 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        decoration: isDisabled
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (role == '새친구')
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade100,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Text(
                                          '새친구',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.deepOrange,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    const Spacer(),
                                    Text(
                                      student['school'] ?? '',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                if (isDisabled)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      '🚫 이 날짜 이후에 등록된 학생입니다.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                else ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: status == '출석'
                                                ? Colors.teal
                                                : Colors.grey.shade200,
                                            foregroundColor: status == '출석'
                                                ? Colors.white
                                                : Colors.black87,
                                            elevation: status == '출석' ? 2 : 0,
                                          ),
                                          onPressed: () => setState(
                                            () =>
                                                _attendanceData[name]!['status'] =
                                                    '출석',
                                          ),
                                          child: const Text(
                                            '🟢 출석',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: status == '결석'
                                                ? Colors.red.shade400
                                                : Colors.grey.shade200,
                                            foregroundColor: status == '결석'
                                                ? Colors.white
                                                : Colors.black87,
                                            elevation: status == '결석' ? 2 : 0,
                                          ),
                                          onPressed: () => setState(
                                            () =>
                                                _attendanceData[name]!['status'] =
                                                    '결석',
                                          ),
                                          child: const Text(
                                            '🔴 결석',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  if (status == '결석') ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              const Text(
                                                '결석 사유: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.red,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: DropdownButton<String>(
                                                  isExpanded: true,
                                                  value: reason,
                                                  items: _absenceReasons.map((
                                                    String val,
                                                  ) {
                                                    return DropdownMenuItem(
                                                      value: val,
                                                      child: Text(val),
                                                    );
                                                  }).toList(),
                                                  onChanged: (String? newVal) {
                                                    if (newVal != null) {
                                                      setState(
                                                        () =>
                                                            _attendanceData[name]!['reason'] =
                                                                newVal,
                                                      );
                                                    }
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (reason == '기타') ...[
                                            const SizedBox(height: 8),
                                            TextFormField(
                                              initialValue:
                                                  studentData['customReason'],
                                              decoration: const InputDecoration(
                                                hintText: '결석 사유를 직접 입력해주세요',
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                                fillColor: Colors.white,
                                                filled: true,
                                              ),
                                              onChanged: (val) {
                                                _attendanceData[name]!['customReason'] =
                                                    val;
                                              },
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
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
        icon: const Icon(Icons.save, color: Colors.white),
        label: const Text(
          '출석 저장하기',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}
