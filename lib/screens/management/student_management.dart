import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'setup_initial_data.dart'; 

class StudentManagementScreen extends StatefulWidget {
  // ✅ 부모 위젯(home_navigation.dart)에서 const로 호출할 수 있도록 명시
  const StudentManagementScreen({super.key});

  @override
  State<StudentManagementScreen> createState() => _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  bool _isLoading = true;
  String _selectedFilter = '전체'; 
  String _individualSortMode = '셀순';

  List<Map<String, dynamic>> _students = [];

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  // ✅ Timestamp 타입 에러를 방지하기 위한 안전한 문자열 변환 함수
  String _formatValue(dynamic value) {
    if (value == null) return "-";
    if (value is String) return value.isEmpty ? "-" : value;
    if (value is Timestamp) {
      return DateFormat('yyyy-MM-dd').format(value.toDate());
    }
    return value.toString();
  }

  Future<void> _loadStudentData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      var snapshot = await FirebaseFirestore.instance.collection('students').get();
      List<Map<String, dynamic>> temp = [];
      for (var doc in snapshot.docs) {
        var data = doc.data();
        data['docId'] = doc.id; 
        temp.add(data);
      }
      setState(() {
        _students = temp;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ 데이터 로드 중 오류: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 필터링 로직: group 필드 기반 (A: 정규, B: 새친구)
    List<Map<String, dynamic>> filteredList = _students.where((s) {
      String group = s['group'] ?? (s['isRegular'] == true ? 'A' : 'B');
      if (_selectedFilter == '새친구') return group == 'B';
      if (_selectedFilter == '정규학생') return group == 'A';
      return true;
    }).toList();

    // 정렬 로직
    if (_individualSortMode == '랭킹순') {
      filteredList.sort((a, b) {
        int countA = a['attendanceCount'] ?? 0;
        int countB = b['attendanceCount'] ?? 0;
        if (countB != countA) return countB.compareTo(countA);
        return (a['name'] ?? '').compareTo(b['name'] ?? '');
      });
    } else {
      filteredList.sort((a, b) {
        int cellA = int.tryParse(a['cell'] ?? '99') ?? 99;
        int cellB = int.tryParse(b['cell'] ?? '99') ?? 99;
        if (cellA != cellB) return cellA.compareTo(cellB);
        return (a['name'] ?? '').compareTo(b['name'] ?? '');
      });
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredList.isEmpty
                    ? const Center(child: Text("표시할 학생이 없습니다."))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) => _buildStudentCard(filteredList[index]),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // ✅ 별도의 초기 데이터 설정 페이지로 이동
          final result = await Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => const SetupInitialDataScreen())
          );
          if (result == true) _loadStudentData(); 
        },
        backgroundColor: Colors.redAccent,
        tooltip: "초기 데이터 설정",
        child: const Icon(Icons.settings_suggest, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: ['전체', '새친구', '정규학생'].map((filter) {
              bool isSelected = _selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(filter, style: const TextStyle(fontSize: 12)),
                  selected: isSelected,
                  onSelected: (val) { if (val) setState(() => _selectedFilter = filter); },
                  selectedColor: Colors.indigo,
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                ),
              );
            }).toList(),
          ),
          DropdownButton<String>(
            value: _individualSortMode,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            underline: const SizedBox(),
            items: ['셀순', '랭킹순'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) { if (v != null) setState(() => _individualSortMode = v); },
          )
        ],
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    // group 필드가 없으면 기존 isRegular 필드로 추론하여 표시
    String group = student['group'] ?? (student['isRegular'] == true ? 'A' : 'B');
    bool isRegular = group == 'A';
    int attendanceCount = student['attendanceCount'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade200)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isRegular ? Colors.indigo.shade50 : Colors.orange.shade50,
          child: Text(group, style: TextStyle(color: isRegular ? Colors.indigo : Colors.orange, fontWeight: FontWeight.bold)),
        ),
        title: Row(
          children: [
            Text(student['name'] ?? '이름 없음', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
              child: Text('${student['cell']}셀', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
            ),
          ],
        ),
        subtitle: isRegular
            ? const Text('A그룹 (정규학생)', style: TextStyle(fontSize: 12, color: Colors.indigo))
            : Text('B그룹 (새친구 - $attendanceCount/4회)', style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _infoRow(Icons.calendar_today, "첫 출석일", _formatValue(student['firstVisitDate'])),
                _infoRow(Icons.auto_awesome, "등반일", _formatValue(student['promotedAt'])),
                _infoRow(Icons.person_outline, "전도자", (student['evangelist'] != null && student['evangelist'] != "") ? student['evangelist'] : "없음"),
                _infoRow(Icons.history_edu, "교회 경험", _formatValue(student['churchExperience'])),
                _infoRow(Icons.phone, "연락처", _formatValue(student['phone'])),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!isRegular)
                      ElevatedButton.icon(
                        onPressed: () => _promoteToGroupA(student),
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: const Text("A그룹으로 등반"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: () => _demoteToGroupB(student),
                        icon: const Icon(Icons.person_add_alt_1, size: 16),
                        label: const Text("B그룹(새친구) 전환"),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.orange, side: const BorderSide(color: Colors.orange)),
                      ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () { /* 정보 수정 상세 페이지 */ },
                      child: const Text("정보 수정"),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ✅ B그룹(새친구) 수동 전환
  Future<void> _demoteToGroupB(Map<String, dynamic> student) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("그룹 전환"),
        content: Text("${student['name']} 학생을 B그룹(새친구) 상태로 변경하시겠습니까?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("취소")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("전환")),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('students').doc(student['docId']).update({
        'group': 'B',
        'isRegular': false,
        'attendanceCount': 0,
        'promotedAt': "-", 
      });
      _loadStudentData();
    }
  }

  // ✅ A그룹(정규학생) 등반 처리
  Future<void> _promoteToGroupA(Map<String, dynamic> student) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("등반 확정"),
        content: Text("${student['name']} 학생을 A그룹(정규학생)으로 전환하시겠습니까?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("취소")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("확정")),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('students').doc(student['docId']).update({
        'group': 'A',
        'isRegular': true,
        'attendanceCount': 99, 
        'promotedAt': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      });
      _loadStudentData();
    }
  }
}