import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'attendance_input.dart';

class AttendanceStatusScreen extends StatefulWidget {
  // 💡 1. 변수 선언
  final Function(String)? onCellTap;

  // 💡 2. 생성자 수정 (이 부분이 에러의 핵심 원인이었습니다!)
  const AttendanceStatusScreen({super.key, this.onCellTap});

  @override
  State<AttendanceStatusScreen> createState() => _AttendanceStatusScreenState();
}

class _AttendanceStatusScreenState extends State<AttendanceStatusScreen> {
  DateTime _selectedDate = _getRecentSunday();
  bool _isLoading = false;
  int _totalStudents = 0;
  int _totalPresent = 0;
  Map<String, Map<String, dynamic>> _cellStats = {};

  static DateTime _getRecentSunday() {
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
    _fetchAttendanceStats();
  }

  // 📡 데이터 로드 함수 (타입 에러 완벽 방어 버전)
  Future<void> _fetchAttendanceStats() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. 전체 학생 정보 로드
      var studentSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .get();
      Map<String, int> studentCountByCell = {};
      _totalStudents = studentSnapshot.docs.length;

      for (var doc in studentSnapshot.docs) {
        var data = doc.data();
        String cell = data['cell']?.toString() ?? '미지정';
        studentCountByCell[cell] = (studentCountByCell[cell] ?? 0) + 1;
      }

      // 2. 해당 날짜 출석 기록 로드
      String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      var attendanceSnapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('date', isEqualTo: formattedDate)
          .get();

      Map<String, Map<String, dynamic>> tempStats = {};
      int tempPresentTotal = 0;

      for (var doc in attendanceSnapshot.docs) {
        var data = doc.data();
        String cell = data['cell']?.toString() ?? '0';

        // 🔥 [핵심 수정] LinkedMap 에러를 방지하기 위해 Map.from을 사용합니다.
        Map<String, dynamic> records = {};
        if (data['records'] != null) {
          records = Map<String, dynamic>.from(data['records']);
        }

        int presentInCell = 0;
        records.forEach((name, info) {
          // info 역시 Map이므로 안전하게 타입을 변환합니다.
          final Map<String, dynamic> infoMap = Map<String, dynamic>.from(info);
          if (infoMap['status']?.toString() == '출석') {
            presentInCell++;
          }
        });

        tempPresentTotal += presentInCell;
        tempStats[cell] = {
          'total': studentCountByCell[cell] ?? 0,
          'present': presentInCell,
          'records': records,
        };
      }

      // 기록이 없는 셀도 기본값 채우기
      studentCountByCell.forEach((cell, count) {
        if (!tempStats.containsKey(cell)) {
          tempStats[cell] = {'total': count, 'present': 0, 'records': {}};
        }
      });

      if (mounted) {
        setState(() {
          // 셀 이름 순서대로 정렬 (숫자 정렬)
          _cellStats = Map.fromEntries(
            tempStats.entries.toList()..sort((a, b) {
              int aNum = int.tryParse(a.key) ?? 99;
              int bNum = int.tryParse(b.key) ?? 99;
              return aNum.compareTo(bNum);
            }),
          );
          _totalPresent = tempPresentTotal;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching attendance: $e"); // 터미널에 에러 출력
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    double attendanceRate = _totalStudents > 0
        ? (_totalPresent / _totalStudents) * 100
        : 0;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: RefreshIndicator(
        onRefresh: _fetchAttendanceStats,
        child: Column(
          children: [
            // 상단 날짜/통계 요약바
            Container(
              color: Colors.white,
              padding: const EdgeInsets.only(bottom: 15),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: InkWell(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.teal,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: Colors.white,
                              size: 18,
                            ),
                            Text(
                              DateFormat('yyyy. MM. dd').format(_selectedDate),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem(
                        "전체",
                        "$_totalStudents",
                        Colors.black87,
                      ),
                      _buildSummaryItem("출석", "$_totalPresent", Colors.teal),
                      _buildSummaryItem(
                        "출석률",
                        "${attendanceRate.toStringAsFixed(1)}%",
                        Colors.orange,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 셀별 리스트
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.teal),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 10, bottom: 20),
                      itemCount: _cellStats.length,
                      itemBuilder: (context, index) {
                        String cellName = _cellStats.keys.elementAt(index);
                        var stat = _cellStats[cellName]!;
                        return _buildCellCard(cellName, stat);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildCellCard(String cellName, Map<String, dynamic> stat) {
    // 💡 여기서도 타입을 안전하게 다시 변환합니다.
    Map<String, dynamic> records = Map<String, dynamic>.from(
      stat['records'] ?? {},
    );
    List<String> presents = [];
    List<String> absents = [];

    records.forEach((name, info) {
      final Map<String, dynamic> infoMap = Map<String, dynamic>.from(info);
      if (infoMap['status']?.toString() == '출석') {
        presents.add(name);
      } else {
        String reason = infoMap['reason']?.toString() ?? '사유없음';
        String customReason = infoMap['customReason']?.toString() ?? '';
        String fullReason = reason == '연락x'
            ? ''
            : '($reason${customReason != '' ? ':$customReason' : ''})';
        absents.add("$name$fullReason");
      }
    });

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        onTap: () async {
          // ✅ 새 창을 띄우지 않고, 부모(HomeNavigation)에게 "화면만 바꿔줘!"라고 신호만 보냅니다.
          if (widget.onCellTap != null) {
            widget.onCellTap!(cellName);
          }
        },
        borderRadius: BorderRadius.circular(15),
        child: Column(
          children: [
            ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 15,
                backgroundColor: Colors.teal.shade50,
                child: Text(
                  cellName,
                  style: const TextStyle(
                    color: Colors.teal,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                '$cellName셀 현황',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: Text(
                '${stat['present']}/${stat['total']} 명',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNameRow(
                    "🟢 출석",
                    presents.isEmpty ? "기록 없음" : presents.join(", "),
                    Colors.teal,
                  ),
                  const SizedBox(height: 8),
                  _buildNameRow(
                    "🔴 결석",
                    absents.isEmpty ? "없음" : absents.join(", "),
                    Colors.redAccent,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameRow(String label, String names, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 45,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        Expanded(
          child: Text(
            names,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade800,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
      locale: const Locale('ko', 'KR'),
      selectableDayPredicate: (date) => date.weekday == DateTime.sunday,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchAttendanceStats();
    }
  }
}
