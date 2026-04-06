import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  State<StudentManagementScreen> createState() =>
      _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  bool _isLoading = true;
  String _selectedFilter = '전체'; // 전체, 새친구, 정규학생
  String _individualSortMode = '셀순'; // 셀순, 랭킹순

  List<Map<String, dynamic>> _students = [];

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  // Firestore 데이터의 날짜 형식을 안전하게 문자열로 변환하는 함수
  String _formatValue(dynamic value) {
    if (value == null) return "-";
    if (value is String) return value.isEmpty ? "-" : value;
    // 만약 데이터가 Firestore의 Timestamp 객체라면 String으로 변환
    if (value is Timestamp) {
      return DateFormat('yyyy-MM-dd').format(value.toDate());
    }
    return value.toString();
  }

  Future<void> _loadStudentData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('students')
          .get();
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
      debugPrint("❌ 학생 로드 에러: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _initializeAllToRegular() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "초기 데이터 일괄 설정",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "현재 등록된 모든 학생을 아래 값으로 초기화하시겠습니까?\n\n"
          "• 등반 상태: 정규 학생\n"
          "• 출석 횟수: 99회\n"
          "• 첫 출석/등반일: 2025-01-01\n"
          "• 교회 경험: 유 / 전도자: 없음\n\n"
          "※ 기존에 Timestamp로 저장된 데이터도 문자열로 교체됩니다.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("취소"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text("일괄 변경 실행"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        WriteBatch batch = FirebaseFirestore.instance.batch();
        var snapshot = await FirebaseFirestore.instance
            .collection('students')
            .get();

        for (var doc in snapshot.docs) {
          batch.update(doc.reference, {
            'isRegular': true,
            'attendanceCount': 99,
            'firstVisitDate': '2025-01-01',
            'promotedAt': '2025-01-01',
            'evangelist': '',
            'churchExperience': '유',
          });
        }

        await batch.commit();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ 모든 학생 정보가 정규 학생으로 초기화되었습니다.")),
          );
          _loadStudentData();
        }
      } catch (e) {
        debugPrint("❌ 초기화 실패: $e");
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filteredList = _students.where((s) {
      if (_selectedFilter == '새친구') return s['isRegular'] == false;
      if (_selectedFilter == '정규학생') return s['isRegular'] == true;
      return true;
    }).toList();

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
                    itemBuilder: (context, index) =>
                        _buildStudentCard(filteredList[index]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _initializeAllToRegular,
        backgroundColor: Colors.indigo,
        tooltip: "데이터 초기화",
        child: const Icon(Icons.settings_backup_restore, color: Colors.white),
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
                  onSelected: (val) {
                    if (val) setState(() => _selectedFilter = filter);
                  },
                  selectedColor: Colors.indigo,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
              );
            }).toList(),
          ),
          DropdownButton<String>(
            value: _individualSortMode,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            underline: const SizedBox(),
            items: [
              '셀순',
              '랭킹순',
            ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _individualSortMode = v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    bool isRegular = student['isRegular'] ?? false;
    int attendanceCount = student['attendanceCount'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isRegular
              ? Colors.indigo.shade50
              : Colors.orange.shade50,
          child: Text(
            student['name']?[0] ?? '?',
            style: TextStyle(
              color: isRegular ? Colors.indigo : Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              student['name'] ?? '이름 없음',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${student['cell']}셀',
                style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
              ),
            ),
          ],
        ),
        subtitle: isRegular
            ? const Text(
                '정규 학생 (등반 완료)',
                style: TextStyle(fontSize: 12, color: Colors.indigo),
              )
            : Text(
                '새친구 (누적 출석 $attendanceCount/4회)',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ✅ _formatValue를 적용하여 Timestamp 에러 방지
                _infoRow(
                  Icons.calendar_today,
                  "첫 출석일",
                  _formatValue(student['firstVisitDate']),
                ),
                _infoRow(
                  Icons.auto_awesome,
                  "등반일",
                  _formatValue(student['promotedAt']),
                ),
                _infoRow(
                  Icons.person_outline,
                  "전도자",
                  (student['evangelist'] != null && student['evangelist'] != "")
                      ? student['evangelist']
                      : "없음",
                ),
                _infoRow(
                  Icons.history_edu,
                  "교회 경험",
                  _formatValue(student['churchExperience']),
                ),
                _infoRow(Icons.phone, "연락처", _formatValue(student['phone'])),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!isRegular)
                      ElevatedButton.icon(
                        onPressed: () => _promoteStudent(student),
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: const Text("정식 등반 처리"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: () => _demoteToNewFriend(student),
                        icon: const Icon(Icons.person_add_alt_1, size: 16),
                        label: const Text("새친구로 표시"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                        ),
                      ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {
                        // TODO: 정보 수정 페이지 연결
                      },
                      child: const Text("정보 수정"),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Future<void> _demoteToNewFriend(Map<String, dynamic> student) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("새친구 전환"),
        content: Text(
          "${student['name']} 학생을 새친구 상태로 변경하시겠습니까?\n(누적 출석 횟수가 0으로 초기화됩니다)",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("취소"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text("전환"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('students')
          .doc(student['docId'])
          .update({
            'isRegular': false,
            'attendanceCount': 0,
            'promotedAt': "-",
          });
      _loadStudentData();
    }
  }

  Future<void> _promoteStudent(Map<String, dynamic> student) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("등반 확정"),
        content: Text("${student['name']} 학생을 정식 학생으로 전환하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("취소"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            child: const Text("확정"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('students')
          .doc(student['docId'])
          .update({
            'isRegular': true,
            'attendanceCount': 99,
            'promotedAt': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          });
      _loadStudentData();
    }
  }
}
