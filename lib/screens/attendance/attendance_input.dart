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
  final Map<String, String> _initialStatusMap = {};
  List<String> _memberNames = [];
  final Map<String, TextEditingController> _customReasonControllers = {};

  final Map<String, List<String>> gradeCellMap = {
    '1': ['1', '2'], '2': ['3', '4', '5', '6'], '3': ['7', '8', '9', '10'],
    '1학년': ['1', '2'], '2학년': ['3', '4', '5', '6'], '3학년': ['7', '8', '9', '10'],
    '1학년담당': ['1', '2'], '2학년담당': ['3', '4', '5', '6'], '3학년담당': ['7', '8', '9', '10'],
  };

  final List<String> _absenceReasons = ['연락x', '장기결석', '늦잠', '질병', '여행', '친척방문', '타교회', '본당예배', '학원', '기타'];

  @override
  void initState() {
    super.initState();
    _targetDate = widget.selectedDate ?? _getRecentSunday();
    final String role = widget.teacherRole.trim();
    final bool isAdmin = role == 'admin';
    final bool isFullAccess = isAdmin || role == '강도사' || role == '부장';
    final bool isGradeManager = role.contains('학년담당');
    
    if (isFullAccess) {
      _currentCell = (isAdmin && widget.teacherCell != '담당') ? widget.teacherCell : 'teachers';
    } else if (isGradeManager) {
      List<String> allowed = gradeCellMap[role] ?? gradeCellMap[widget.teacherGrade.trim()] ?? [];
      _currentCell = allowed.contains(widget.teacherCell) ? widget.teacherCell : (allowed.isNotEmpty ? allowed.first : '1');
    } else {
      _currentCell = widget.teacherCell == '담당' ? 'teachers' : widget.teacherCell;
    }

    SchedulerBinding.instance.addPostFrameCallback((_) { 
      if (mounted) {
        _loadData(); 
      }
    });
  }

  DateTime _getRecentSunday() {
    DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday % 7));
  }

  String _extractGroup(Map<String, dynamic> data) {
    if (data.containsKey('group') && data['group'] != null && data['group'].toString().isNotEmpty) {
      return data['group'].toString().toUpperCase();
    }
    return (data['isRegular'] == true) ? 'A' : 'B';
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      String dateStr = DateFormat('yyyy-MM-dd').format(_targetDate);
      String cleanCellNum = _currentCell == 'teachers' ? 'teachers' : (int.tryParse(_currentCell) ?? _currentCell).toString();
      String docId = _currentCell == 'teachers' ? "teachers_$dateStr" : "$cleanCellNum셀_$dateStr";

      var attendanceDoc = await FirebaseFirestore.instance.collection('attendance').doc(docId).get();
      if (!mounted) return; // ✅ 비동기 작업 후 체크

      QuerySnapshot masterSnap;
      if (_currentCell == 'teachers') {
        masterSnap = await FirebaseFirestore.instance.collection('teachers').get();
      } else {
        masterSnap = await FirebaseFirestore.instance.collection('students').where('cell', isEqualTo: cleanCellNum).get();
      }
      if (!mounted) return; // ✅ 비동기 작업 후 체크

      Map<String, Map<String, dynamic>> masterInfoMap = {};
      for (var mDoc in masterSnap.docs) {
        var mData = mDoc.data() as Map<String, dynamic>;
        String name = (mData['name'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          masterInfoMap[name] = {...mData, 'docId': mDoc.id};
        }
      }

      for (var controller in _customReasonControllers.values) {
        controller.dispose();
      }
      _customReasonControllers.clear();
      _initialStatusMap.clear();

      Map<String, Map<String, dynamic>> finalData = {};
      Set<String> allMemberNames = {};

      if (attendanceDoc.exists) {
        Map<String, dynamic> records = Map<String, dynamic>.from(attendanceDoc.data()?['records'] ?? {});
        allMemberNames = {...records.keys, ...masterInfoMap.keys};

        for (var name in allMemberNames) {
          if (records.containsKey(name)) {
            var rec = Map<String, dynamic>.from(records[name]);
            finalData[name] = rec;
            _initialStatusMap[name] = rec['status'] ?? '결석';
          } else {
            var mData = masterInfoMap[name]!;
            finalData[name] = {
              'status': '결석', 'reason': '연락x', 'customReason': '',
              'grade': mData['grade'] ?? '', 'role': mData['role'] ?? '',
              'cell': mData['cell'] ?? cleanCellNum,
              'group': _extractGroup(mData), 'docId': mData['docId'],
              'gender': mData['gender'] ?? '남자',
              'firstVisitDate': mData['firstVisitDate'] ?? '',
              'evangelist': mData['evangelist'] ?? '',
              'promotedAt': mData['promotedAt'] ?? '',
              'school': mData['school'] ?? '',
            };
            _initialStatusMap[name] = '결석';
          }
          _customReasonControllers[name] = TextEditingController(text: finalData[name]!['customReason'] ?? '');
        }
      } else {
        String defStatus = _currentCell == 'teachers' ? '출석' : '결석';
        masterInfoMap.forEach((name, mData) {
          allMemberNames.add(name);
          _initialStatusMap[name] = defStatus;
          _customReasonControllers[name] = TextEditingController();
          finalData[name] = {
            'status': defStatus, 'reason': '연락x', 'customReason': '',
            'grade': mData['grade'] ?? '', 'role': mData['role'] ?? '',
            'cell': mData['cell'] ?? (_currentCell == 'teachers' ? '교사' : _currentCell),
            'group': _extractGroup(mData), 'docId': mData['docId'],
            'gender': mData['gender'] ?? '남자',
            'firstVisitDate': mData['firstVisitDate'] ?? '',
            'evangelist': mData['evangelist'] ?? '',
            'promotedAt': mData['promotedAt'] ?? '',
            'school': mData['school'] ?? '',
          };
        });
      }

      List<String> sortedNames = allMemberNames.toList();
      sortedNames.sort((a, b) {
        String gA = (finalData[a]?['group'] ?? 'B').toString().toUpperCase();
        String gB = (finalData[b]?['group'] ?? 'B').toString().toUpperCase();
        if (gA != gB) return gA.compareTo(gB);
        return a.compareTo(b);
      });

      if (mounted) { // ✅ 최종 결과 반영 전 체크
        setState(() {
          _memberNames = sortedNames;
          _attendanceData = finalData;
        });
      }
    } catch (e) { 
      debugPrint("❌ 로드 에러: $e"); 
    } finally { 
      if (mounted) setState(() => _isLoading = false); 
    }
  }

  Future<void> _saveAttendance() async {
    if (_memberNames.isEmpty || !mounted) return;
    setState(() => _isLoading = true);
    
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    
    try {
      String dateStr = DateFormat('yyyy-MM-dd').format(_targetDate);
      String cleanCellNum = _currentCell == 'teachers' ? 'teachers' : _currentCell;
      String docId = _currentCell == 'teachers' ? "teachers_$dateStr" : "$cleanCellNum셀_$dateStr";

      WriteBatch batch = FirebaseFirestore.instance.batch();
      Map<String, Map<String, dynamic>> recordsToSave = {};

      for (var name in _memberNames) {
        if (_attendanceData.containsKey(name)) {
          var currentData = _attendanceData[name]!;
          recordsToSave[name] = {
            'status': currentData['status'] ?? '결석',
            'reason': currentData['reason'] ?? '연락x',
            'customReason': _customReasonControllers[name]?.text ?? '',
            'grade': currentData['grade'] ?? '',
            'group': currentData['group'] ?? 'A',
            'role': currentData['role'] ?? '학생',
            'cell': currentData['cell'] ?? cleanCellNum,
            'gender': currentData['gender'] ?? '남자',
            'firstVisitDate': currentData['firstVisitDate'] ?? '',
            'evangelist': currentData['evangelist'] ?? '',
            'promotedAt': currentData['promotedAt'] ?? '',
            'school': currentData['school'] ?? '',
          };

          if (_currentCell != 'teachers') {
            String oldS = _initialStatusMap[name] ?? '결석';
            String newS = currentData['status'] ?? '결석';
            String? masterId = currentData['docId'];
            if (masterId != null && masterId.isNotEmpty) {
              DocumentReference mRef = FirebaseFirestore.instance.collection('students').doc(masterId);
              if (oldS != '출석' && newS == '출석') {
                batch.update(mRef, {'attendanceCount': FieldValue.increment(1)});
              } else if (oldS == '출석' && newS != '출석') {
                batch.update(mRef, {'attendanceCount': FieldValue.increment(-1)});
              }
            }
          }
        }
      }

      batch.set(FirebaseFirestore.instance.collection('attendance').doc(docId), {
        'cell': cleanCellNum, 'date': dateStr, 'records': recordsToSave, 'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();
      if (!mounted) return; // ✅ 저장 완료 후 체크
      
      messenger.showSnackBar(const SnackBar(content: Text("💾 저장되었습니다."))); 
      if (navigator.canPop()) {
        navigator.pop(true); 
      }
    } catch (e) { 
      debugPrint("❌ 저장 에러: $e"); 
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text("❌ 저장 실패")));
      }
    } finally { 
      if (mounted) setState(() => _isLoading = false); 
    }
  }

  void _addNewStudent() {
    showDialog(context: context, barrierDismissible: false, builder: (context) => StudentRegistrationDialog(
      initialCell: _currentCell, teacherRole: widget.teacherRole, teacherGrade: widget.teacherGrade,
      onRegistered: (docId, finalName) {
        if (!mounted) return;
        setState(() {
          _memberNames.add(finalName);
          _attendanceData[finalName] = { 
            'status': '출석', 'reason': '연락x', 'customReason': '', 'docId': docId, 'group': 'B', 'role': '새친구', 
            'grade': widget.teacherGrade, 'cell': _currentCell, 'gender': '남자', 'firstVisitDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
            'evangelist': '', 'promotedAt': '', 'school': '',
          };
          _initialStatusMap[finalName] = '결석'; 
          _customReasonControllers[finalName] = TextEditingController();
          
          _memberNames.sort((a, b) {
            String gA = (_attendanceData[a]?['group'] ?? 'B').toString().toUpperCase();
            String gB = (_attendanceData[b]?['group'] ?? 'B').toString().toUpperCase();
            if (gA != gB) return gA.compareTo(gB);
            return a.compareTo(b);
          });
        });
      },
    ));
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
                if (index == _memberNames.length) {
                  return _buildActionButtons(mainColor, isTMode);
                }
                String name = _memberNames[index]; 
                var data = _attendanceData[name]!; 
                bool isP = data['status'] == '출석';
                String group = (data['group'] ?? 'B').toString();

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isP ? Colors.white : Colors.red.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(12), 
                    border: Border.all(color: isP ? Colors.grey.shade100 : Colors.red.shade50),
                  ),
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Column(children: [
                    Row(children: [
                      SizedBox(width: 24, child: Text('${index + 1}', style: TextStyle(fontSize: 12, color: Colors.grey.shade400))), 
                      Expanded(
                        child: Row(
                          children: [
                            Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            if (!isTMode) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: group == 'A' ? Colors.blue.shade50 : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  group,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: group == 'A' ? Colors.blue.shade700 : Colors.orange.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ), 
                      _miniStatusToggle(name, isP, mainColor)
                    ]),
                    if (!isP) ...[
                      const SizedBox(height: 10), 
                      isTMode ? _buildCustomReasonField(name) : _buildReasonDropdown(name, data)
                    ],
                  ])),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSelector(Color mainColor) {
    final String role = widget.teacherRole.trim();
    final bool isFull = ['admin', '강도사', '부장'].contains(role);
    final bool isGrade = role.contains('학년담당');
    List<String> allowed = isFull ? List.generate(10, (i) => '${i + 1}') : (isGrade ? (gradeCellMap[role] ?? gradeCellMap[widget.teacherGrade.trim()] ?? []) : [_currentCell]);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1.5))),
      child: Row(children: [
        Expanded(
          child: InkWell(
            onTap: () => _selectDate(), 
            child: Row(children: [
              Icon(Icons.calendar_today, size: 16, color: mainColor), 
              const SizedBox(width: 8), 
              Text(DateFormat('yyyy. MM. dd').format(_targetDate), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)), 
              Icon(Icons.arrow_drop_down, size: 24, color: mainColor)
            ])
          )
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12), 
          height: 38, 
          decoration: BoxDecoration(color: mainColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: mainColor.withValues(alpha: 0.2))),
          child: DropdownButtonHideUnderline(
            child: (isFull || isGrade) ? DropdownButton<String>(
              value: _currentCell, 
              iconSize: 22, 
              items: [
                if (isFull) const DropdownMenuItem(value: 'teachers', child: Text('교사전체', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))), 
                ...allowed.map((val) => DropdownMenuItem(value: val, child: Text('${val.padLeft(2, '0')}셀', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))))
              ], 
              onChanged: (val) { if (val != null) setState(() { _currentCell = val; _loadData(); }); }
            ) : Padding(
                padding: const EdgeInsets.symmetric(vertical: 6), 
                child: Text(_currentCell == 'teachers' ? '교사전체' : '${_currentCell.padLeft(2, '0')}셀', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))
            )
          )
        ),
      ]),
    );
  }

  Widget _buildSummaryArea(Color mC) { 
    int pC = _attendanceData.values.where((e) => e['status'] == '출석').length; 
    int aC = _attendanceData.values.where((e) => e['status'] != '출석').length; 
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10), 
      color: Colors.grey.shade50, 
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly, 
        children: [
          _sumItem('전체', _memberNames.length, Colors.blueGrey), 
          _sumItem('출석', pC, mC), 
          _sumItem('결석', aC, Colors.red.shade400)
        ]
      )
    ); 
  }

  Widget _sumItem(String l, int c, Color clr) { 
    return Column(children: [
      Text(l, style: TextStyle(fontSize: 11, color: clr, fontWeight: FontWeight.w500)), 
      Text('$c명', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: clr))
    ]); 
  }

  Widget _buildReasonDropdown(String n, Map<String, dynamic> d) { 
    return Container(
      height: 42, 
      padding: const EdgeInsets.symmetric(horizontal: 10), 
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100, width: 1.2)), 
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true, 
          value: _absenceReasons.contains(d['reason']) ? d['reason'] : '기타', 
          items: _absenceReasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 15)))).toList(), 
          onChanged: (v) { 
            if (v != null) {
              if (mounted) setState(() => _attendanceData[n]!['reason'] = v);
            }
          }
        )
      )
    ); 
  }

  Widget _buildCustomReasonField(String n) { 
    return SizedBox(
      height: 42, 
      child: TextField(
        controller: _customReasonControllers[n], 
        decoration: InputDecoration(
          hintText: "결석 사유 직접 입력", 
          isDense: true, 
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), 
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), 
          filled: true, 
          fillColor: Colors.white
        ), 
        style: const TextStyle(fontSize: 14)
      )
    ); 
  }

  Widget _buildActionButtons(Color mC, bool isT) { 
    return Padding(padding: const EdgeInsets.symmetric(vertical: 30), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (!isT) OutlinedButton.icon(onPressed: _addNewStudent, icon: const Icon(Icons.person_add, size: 16), label: const Text("새친구 등록", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), style: OutlinedButton.styleFrom(foregroundColor: mC, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), side: BorderSide(color: mC, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))), 
      if (!isT) const SizedBox(width: 12), 
      ElevatedButton.icon(onPressed: _isLoading ? null : _saveAttendance, icon: const Icon(Icons.save, size: 16), label: const Text("출석 저장", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), style: ElevatedButton.styleFrom(backgroundColor: mC, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))
    ])); 
  }

  Widget _miniStatusToggle(String n, bool isP, Color mC) { return Row(mainAxisSize: MainAxisSize.min, children: [_miniButton(n, '출석', isP, mC), const SizedBox(width: 6), _miniButton(n, '결석', !isP, Colors.red.shade400)]); }

  Widget _miniButton(String n, String l, bool s, Color c) { 
    return GestureDetector(
      onTap: () { 
        if (mounted) {
          setState(() => _attendanceData[n]!['status'] = l);
        }
      }, 
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), 
        decoration: BoxDecoration(color: s ? c : Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: s ? c : Colors.grey.shade200)), 
        child: Text(l, style: TextStyle(color: s ? Colors.white : Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 13))
      )
    ); 
  }

  Future<void> _selectDate() async { 
    final DateTime? picked = await showDatePicker(context: context, initialDate: _targetDate, firstDate: DateTime(2025, 1, 1), lastDate: DateTime.now(), locale: const Locale('ko', 'KR'), selectableDayPredicate: (day) => day.weekday == DateTime.sunday); 
    if (picked != null && mounted) { 
      setState(() { _targetDate = picked; _loadData(); }); 
    } 
  }

  @override 
  void dispose() { 
    for (var controller in _customReasonControllers.values) {
      controller.dispose();
    }
    super.dispose(); 
  }
}