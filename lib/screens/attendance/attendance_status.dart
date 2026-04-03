import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'attendance_input.dart';

class AttendanceStatusScreen extends StatefulWidget {
  final Function(String)? onCellTap;
  const AttendanceStatusScreen({super.key, this.onCellTap});

  @override
  State<AttendanceStatusScreen> createState() => _AttendanceStatusScreenState();
}

class _AttendanceStatusScreenState extends State<AttendanceStatusScreen> {
  DateTime _selectedDate = _getRecentSunday();
  String _viewType = '주별';
  bool _isLoading = false;

  int _studentPresent = 0;
  int _studentTotal = 0;
  int _teacherPresent = 0;
  int _teacherTotal = 0;

  Map<String, Map<String, dynamic>> _cellStats = {};
  List<Map<String, dynamic>> _summaryList = [];

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

  // ✅ 데이터를 불러오는 핵심 함수
  Future<void> _fetchStats() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      DateTime startDate;
      DateTime endDate = DateTime.now();

      if (_viewType == '월별') {
        startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
        endDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
      } else if (_viewType == '누적') {
        startDate = DateTime(_selectedDate.year, 1, 1);
      } else {
        startDate = _selectedDate;
        endDate = _selectedDate;
      }

      String startStr = DateFormat('yyyy-MM-dd').format(startDate);
      String endStr = DateFormat('yyyy-MM-dd').format(endDate);

      var snapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('date', isGreaterThanOrEqualTo: startStr)
          .where('date', isLessThanOrEqualTo: endStr)
          .get(const GetOptions(source: Source.serverAndCache)); // 서버 데이터를 우선시

      if (snapshot.docs.isEmpty) {
        setState(() {
          _cellStats = {};
          _studentPresent = 0;
          _studentTotal = 0;
          _teacherPresent = 0;
          _teacherTotal = 0;
          _isLoading = false;
        });
        return;
      }

      if (_viewType == '주별') {
        _processWeeklyData(snapshot);
      } else {
        _processGroupedData(snapshot);
      }
    } catch (e) {
      debugPrint("❌ 데이터 로드 에러: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

 // ✅ [수정] 메뉴바 유지를 위한 내비게이션 로직
  Future<void> _handleCellTap(String actualId) async {
    debugPrint("🚀 [수정 시작] 선택된 셀 ID: $actualId");

    // 상황 1: 만약 부모(HomeNavigation)에서 넘겨준 탭 전환 함수가 있다면 그것을 사용 (가장 확실함)
    if (widget.onCellTap != null) {
      widget.onCellTap!(actualId);
      return; 
    }

    // 상황 2: 일반적인 Push 이동 (메뉴바 유지를 위해 context를 명확히 사용)
    final result = await Navigator.push(
      context, // Navigator.of(context) 대신 context를 직접 전달
      MaterialPageRoute(
        builder: (context) => AttendanceInputScreen(
          teacherCell: actualId,
          selectedDate: _selectedDate,
        ),
      ),
    );

    debugPrint("🚩 [복귀 완료] 결과값: $result");

    if (result == true || _cellStats.isEmpty) {
      if (!mounted) return;
      _fetchStats();
    }
  }
  void _processWeeklyData(QuerySnapshot snapshot) {
    Map<String, Map<String, dynamic>> tempStats = {};
    int sP = 0;
    int sT = 0;
    int tP = 0;
    int tT = 0;

    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      String docId = doc.id;
      Map<String, dynamic> records = Map<String, dynamic>.from(
        data['records'] ?? {},
      );

      int present = 0;
      records.forEach((name, info) {
        if (info is Map && info['status'] == '출석') present++;
      });

      if (docId.startsWith('teachers')) {
        tP += present;
        tT += records.length;
        tempStats['교사'] = {
          'id': 'teachers',
          'total': records.length,
          'present': present,
          'records': records,
        };
      } else {
        String rawId = docId.split('셀')[0];
        String cleanId = (int.tryParse(rawId) ?? 0).toString();

        sP += present;
        sT += records.length;
        tempStats[cleanId] = {
          'id': cleanId,
          'total': records.length,
          'present': present,
          'records': records,
        };
      }
    }

    if (mounted) {
      setState(() {
        _cellStats = Map.fromEntries(
          tempStats.entries.toList()..sort((a, b) {
            if (a.key == '교사') return -1;
            if (b.key == '교사') return 1;
            return (int.tryParse(a.key) ?? 99).compareTo(
              int.tryParse(b.key) ?? 99,
            );
          }),
        );
        _studentPresent = sP;
        _studentTotal = sT;
        _teacherPresent = tP;
        _teacherTotal = tT;
      });
    }
  }

  void _processGroupedData(QuerySnapshot snapshot) {
    Map<String, Map<String, int>> dateSummary = {};
    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      String date = data['date'];
      String docId = doc.id;
      Map<String, dynamic> records = Map<String, dynamic>.from(
        data['records'] ?? {},
      );
      int present = 0;
      records.forEach((name, info) {
        if (info is Map && info['status'] == '출석') present++;
      });
      if (!dateSummary.containsKey(date)) {
        dateSummary[date] = {'sP': 0, 'sT': 0, 'tP': 0, 'tT': 0};
      }
      if (docId.startsWith('teachers')) {
        dateSummary[date]!['tP'] = (dateSummary[date]!['tP'] ?? 0) + present;
        dateSummary[date]!['tT'] =
            (dateSummary[date]!['tT'] ?? 0) + records.length;
      } else {
        dateSummary[date]!['sP'] = (dateSummary[date]!['sP'] ?? 0) + present;
        dateSummary[date]!['sT'] =
            (dateSummary[date]!['sT'] ?? 0) + records.length;
      }
    }
    _summaryList = dateSummary.entries
        .map(
          (e) => {
            'date': e.key,
            'sP': e.value['sP'],
            'sT': e.value['sT'],
            'tP': e.value['tP'],
            'tT': e.value['tT'],
          },
        )
        .toList();
    _summaryList.sort((a, b) => b['date'].compareTo(a['date']));
    if (_summaryList.isNotEmpty) {
      _studentPresent =
          (_summaryList.map((e) => e['sP'] as int).reduce((a, b) => a + b) /
                  _summaryList.length)
              .round();
      _studentTotal =
          (_summaryList.map((e) => e['sT'] as int).reduce((a, b) => a + b) /
                  _summaryList.length)
              .round();
      _teacherPresent =
          (_summaryList.map((e) => e['tP'] as int).reduce((a, b) => a + b) /
                  _summaryList.length)
              .round();
      _teacherTotal =
          (_summaryList.map((e) => e['tT'] as int).reduce((a, b) => a + b) /
                  _summaryList.length)
              .round();
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("🎨 [빌드] 통계 리스트 개수: ${_cellStats.length}");

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildSummaryHeader(),
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

  Widget _buildSummaryHeader() {
    double sRate = _studentTotal > 0
        ? (_studentPresent / _studentTotal) * 100
        : 0;
    double tRate = _teacherTotal > 0
        ? (_teacherPresent / _teacherTotal) * 100
        : 0;
    String titleText = _viewType == '주별'
        ? DateFormat('yyyy년 MM월 dd일').format(_selectedDate)
        : _viewType == '월별'
        ? DateFormat('yyyy년 MM월').format(_selectedDate)
        : "${_selectedDate.year}년 누적 현황";
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
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
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                if (_viewType != '누적')
                  const Icon(Icons.arrow_drop_down, color: Colors.teal),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              _buildSummaryCard(
                "학생",
                _studentPresent,
                _studentTotal,
                sRate,
                Colors.blue,
              ),
              const SizedBox(width: 10),
              _buildSummaryCard(
                "교사",
                _teacherPresent,
                _teacherTotal,
                tRate,
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, int p, int t, double r, Color c) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: c.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                color: c,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "$p / $t",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              "${r.toStringAsFixed(1)}%",
              style: TextStyle(color: c, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Row(
        children: ['주별', '월별', '누적'].map((type) {
          return Expanded(
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
                  color: _viewType == type ? Colors.teal : Colors.grey.shade100,
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
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWeeklyDetailList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _cellStats.length,
      itemBuilder: (context, index) {
        String displayKey = _cellStats.keys.elementAt(index);
        var stat = _cellStats[displayKey]!;
        String actualId = stat['id'];
        bool isT = displayKey == '교사';

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isT ? Colors.orange.shade200 : Colors.grey.shade200,
            ),
          ),
          child: ExpansionTile(
            title: InkWell(
              // ✅ [수정] 텍스트 클릭 시 핸들러 호출
              onTap: () => _handleCellTap(actualId),
              child: Text(
                isT ? '👨‍🏫 교사 전체' : '$displayKey셀',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isT ? Colors.orange.shade900 : Colors.black87,
                  decoration: TextDecoration.underline,
                  decorationColor: isT
                      ? Colors.orange.withOpacity(0.3)
                      : Colors.grey.shade400,
                ),
              ),
            ),
            trailing: Text(
              '${stat['present']} / ${stat['total']} 명',
              style: TextStyle(
                color: isT ? Colors.orange : Colors.teal,
                fontWeight: FontWeight.bold,
              ),
            ),
            children: [
              _buildMemberGrid(Map<String, dynamic>.from(stat['records'])),
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: TextButton.icon(
                  // ✅ [수정] 버튼 클릭 시 핸들러 호출
                  onPressed: () => _handleCellTap(actualId),
                  icon: Icon(
                    Icons.edit,
                    size: 16,
                    color: isT ? Colors.orange : Colors.teal,
                  ),
                  label: Text(
                    isT ? "교사 출석 수정" : "학생 출석 수정",
                    style: TextStyle(color: isT ? Colors.orange : Colors.teal),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupedList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _summaryList.length,
      itemBuilder: (context, index) {
        var item = _summaryList[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const Icon(Icons.calendar_today, color: Colors.teal),
            title: Text(
              '${item['date']} 주일',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '학생: ${item['sP']}/${item['sT']}  |  교사: ${item['tP']}/${item['tT']}',
            ),
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

  Widget _buildMemberGrid(Map<String, dynamic> records) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: records.entries.map((e) {
          bool isP = e.value['status'] == '출석';
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isP ? Colors.teal.withOpacity(0.1) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              e.key,
              style: TextStyle(
                fontSize: 11,
                color: isP ? Colors.teal.shade700 : Colors.grey.shade500,
                fontWeight: isP ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2026, 1, 1),
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
