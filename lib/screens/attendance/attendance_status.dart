import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AttendanceStatusScreen extends StatefulWidget {
  final Function(String)? onCellTap;
  const AttendanceStatusScreen({super.key, this.onCellTap});

  @override
  State<AttendanceStatusScreen> createState() => _AttendanceStatusScreenState();
}

class _AttendanceStatusScreenState extends State<AttendanceStatusScreen> {
  DateTime _selectedDate = _getRecentSunday();
  String _viewType = '주별'; // '주별', '월별', '누적'
  bool _isLoading = false;

  int _totalPresent = 0;
  int _totalStudents = 0;

  Map<String, Map<String, dynamic>> _cellStats = {}; // 주별 상세 (명단 포함)
  List<Map<String, dynamic>> _summaryList = []; // 월별/누적용 리스트

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
    _fetchStats();
  }

  // 📡 데이터 가져오기 통합 함수
  Future<void> _fetchStats() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // 1. 재적 학생 수 파악
      var studentSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .get();
      _totalStudents = studentSnapshot.docs.length;
      Map<String, int> studentCountByCell = {};
      for (var doc in studentSnapshot.docs) {
        String cell = doc.data()['cell']?.toString() ?? '미지정';
        studentCountByCell[cell] = (studentCountByCell[cell] ?? 0) + 1;
      }

      // 2. 날짜 범위 설정
      DateTime startDate;
      DateTime endDate = DateTime.now();

      if (_viewType == '월별') {
        startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
        endDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
      } else if (_viewType == '누적') {
        startDate = DateTime(_selectedDate.year, 1, 1); // 올해 1월 1일부터
      } else {
        startDate = _selectedDate;
        endDate = _selectedDate;
      }

      // 3. 파이어베이스 쿼리
      var snapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where(
            'date',
            isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(startDate),
          )
          .where(
            'date',
            isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(endDate),
          )
          .get();

      if (_viewType == '주별') {
        _processWeeklyData(snapshot, studentCountByCell);
      } else {
        _processGroupedData(snapshot);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching stats: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 💡 [주별] 데이터 처리 (타입 에러 해결 버전)
  void _processWeeklyData(
    QuerySnapshot snapshot,
    Map<String, int> studentCountByCell,
  ) {
    Map<String, Map<String, dynamic>> tempStats = {};
    int tempPresentTotal = 0;

    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      String cell = data['cell']?.toString() ?? '0';

      // ✅ LinkedMap 에러 방지를 위해 .from() 사용
      Map<String, dynamic> records = data['records'] != null
          ? Map<String, dynamic>.from(data['records'])
          : {};

      int present = 0;
      records.forEach((name, info) {
        if (info is Map) {
          var infoMap = Map<String, dynamic>.from(info);
          if (infoMap['status']?.toString() == '출석') present++;
        }
      });

      tempPresentTotal += present;
      tempStats[cell] = {
        'total': studentCountByCell[cell] ?? 0,
        'present': present,
        'records': records,
      };
    }

    // 데이터가 없는 셀도 표시
    studentCountByCell.forEach((cell, count) {
      if (!tempStats.containsKey(cell)) {
        tempStats[cell] = {'total': count, 'present': 0, 'records': {}};
      }
    });

    _cellStats = Map.fromEntries(
      tempStats.entries.toList()..sort(
        (a, b) =>
            (int.tryParse(a.key) ?? 99).compareTo(int.tryParse(b.key) ?? 99),
      ),
    );
    _totalPresent = tempPresentTotal;
  }

  // 💡 [월별/누적] 데이터 처리 (타입 에러 해결 버전)
  void _processGroupedData(QuerySnapshot snapshot) {
    Map<String, int> dateSummary = {};
    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      String date = data['date'];

      Map<String, dynamic> records = data['records'] != null
          ? Map<String, dynamic>.from(data['records'])
          : {};

      int present = 0;
      records.forEach((name, info) {
        if (info is Map) {
          var infoMap = Map<String, dynamic>.from(info);
          if (infoMap['status']?.toString() == '출석') present++;
        }
      });
      dateSummary[date] = (dateSummary[date] ?? 0) + present;
    }

    _summaryList = dateSummary.entries
        .map(
          (e) => {'date': e.key, 'present': e.value, 'total': _totalStudents},
        )
        .toList();
    _summaryList.sort((a, b) => b['date'].compareTo(a['date']));

    if (dateSummary.isNotEmpty) {
      _totalPresent =
          (dateSummary.values.reduce((a, b) => a + b) / dateSummary.length)
              .round();
    } else {
      _totalPresent = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    double rate = _totalStudents > 0
        ? (_totalPresent / _totalStudents) * 100
        : 0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildSummaryHeader(rate),
          _buildViewToggle(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_viewType == '주별'
                      ? _buildWeeklyDetailList()
                      : _buildGroupedList()),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(double rate) {
    String titleText = "";
    if (_viewType == '주별')
      titleText = DateFormat('yyyy년 MM월 dd일').format(_selectedDate);
    else if (_viewType == '월별')
      titleText = DateFormat('yyyy년 MM월').format(_selectedDate);
    else
      titleText = "2026년 누적 현황";

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        children: [
          InkWell(
            onTap: _viewType == '누적' ? null : _selectDate,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  titleText,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                if (_viewType != '누적')
                  const Icon(Icons.arrow_drop_down, color: Colors.teal),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.05),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem(
                  _viewType == '주별' ? "출석 인원" : "평균 출석",
                  "$_totalPresent명",
                  Colors.teal,
                ),
                _statItem("총 재적", "$_totalStudents명", Colors.black87),
                _statItem("출석률", "${rate.toStringAsFixed(1)}%", Colors.orange),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Row(
        children: ['주별', '월별', '누적']
            .map(
              (type) => Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _viewType = type;
                      _fetchStats();
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _viewType == type
                          ? Colors.teal
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      type,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _viewType == type ? Colors.white : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildWeeklyDetailList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _cellStats.length,
      itemBuilder: (context, index) {
        String cell = _cellStats.keys.elementAt(index);
        var stat = _cellStats[cell]!;
        Map<String, dynamic> records = Map<String, dynamic>.from(
          stat['records'],
        );

        List<String> presentNames = [];
        records.forEach((name, info) {
          if (info is Map && info['status'] == '출석') presentNames.add(name);
        });

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ExpansionTile(
            shape: const Border(),
            title: Text(
              '$cell셀',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            trailing: Text(
              '${stat['present']} / ${stat['total']} 명',
              style: const TextStyle(
                color: Colors.teal,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            subtitle: Text(
              presentNames.isEmpty ? "출석 인원 없음" : presentNames.join(', '),
              style: const TextStyle(fontSize: 13, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: records.entries.map((e) {
                    bool isPresent = e.value['status'] == '출석';
                    return Chip(
                      label: Text(
                        e.key,
                        style: TextStyle(
                          color: isPresent
                              ? Colors.white
                              : Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: isPresent
                          ? Colors.teal
                          : Colors.grey.shade100,
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ),
              TextButton(
                onPressed: () => widget.onCellTap?.call(cell),
                child: const Text("이 셀 출석 수정하기"),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupedList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _summaryList.length,
      itemBuilder: (context, index) {
        var item = _summaryList[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const Icon(Icons.event_note, color: Colors.teal),
            title: Text(
              '${item['date']} 주일',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('출석: ${item['present']}명 / 재적: ${item['total']}명'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              setState(() {
                _selectedDate = DateTime.parse(item['date']);
                _viewType = '주별';
                _fetchStats();
              });
            },
          ),
        );
      },
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      locale: const Locale('ko', 'KR'),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _fetchStats();
      });
    }
  }
}
