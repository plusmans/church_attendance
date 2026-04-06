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
  String _groupingMode = '셀별';
  String _individualSortMode = '셀순';
  bool _isLoading = false;

  int _studentPresent = 0;
  int _studentTotal = 0; // ✅ 이제 이 변수는 철저하게 'A그룹(재적)' 총합을 의미합니다.
  int _teacherPresent = 0;
  int _teacherTotal = 0;

  Map<String, Map<String, dynamic>> _cellStats = {};
  List<Map<String, dynamic>> _summaryList = [];

  Map<String, double> _cellAverages = {};
  Map<int, double> _monthlyAverages = {};
  Map<String, Map<String, dynamic>> _individualStats = {};

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

  String _getWeekOfMonth(DateTime date) {
    int weekNum = ((date.day - 1) / 7).floor() + 1;
    return '${date.month}월 ${weekNum}주차';
  }

  String _normalizeName(dynamic rawName) {
    if (rawName == null) return '이름없음';
    return rawName.toString().replaceAll(' ', '');
  }

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
        endDate = DateTime(_selectedDate.year, 12, 31);
      } else {
        startDate = _selectedDate;
        endDate = _selectedDate;
      }

      String startStr = DateFormat('yyyy-MM-dd').format(startDate);
      String endStr = DateFormat('yyyy-MM-dd').format(endDate);

      var teacherSnap = await FirebaseFirestore.instance
          .collection('teachers')
          .get();
      var studentSnap = await FirebaseFirestore.instance
          .collection('students')
          .get();

      var snapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('date', isGreaterThanOrEqualTo: startStr)
          .where('date', isLessThanOrEqualTo: endStr)
          .get();

      if (_viewType == '주별') {
        Map<String, Map<String, dynamic>> baseStats = {};

        // 1. 교사 초기 명단 세팅
        Map<String, dynamic> teacherRecords = {};
        for (var doc in teacherSnap.docs) {
          String name = _normalizeName(doc['name']);
          teacherRecords[name] = {'status': '결석', 'group': 'T'};
        }
        baseStats['교사'] = {
          'id': 'teachers',
          'total': teacherSnap.docs.length,
          'present': 0,
          'records': teacherRecords,
        };

        // 2. 학생 초기 명단 세팅
        for (var doc in studentSnap.docs) {
          String cell = doc['cell'] ?? '기타';
          String cleanCell = (int.tryParse(cell) ?? 0).toString();
          String name = _normalizeName(doc['name']);
          String group = doc['group'] ?? (doc['isRegular'] == true ? 'A' : 'B');

          if (!baseStats.containsKey(cleanCell)) {
            baseStats[cleanCell] = {
              'id': cleanCell,
              'total': 0, // 여기서 total은 A그룹(재적) 인원수
              'present': 0,
              'records': <String, dynamic>{},
            };
          }
          if (group == 'A') {
            baseStats[cleanCell]!['total'] = (baseStats[cleanCell]!['total'] as int) + 1;
          }
          baseStats[cleanCell]!['records'][name] = {'status': '결석', 'group': group};
        }

        _processWeeklyData(snapshot, baseStats);
      } else {
        _processGroupedData(snapshot, teacherSnap, studentSnap);
      }
    } catch (e) {
      debugPrint("❌ 데이터 로드 에러: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCellTap(String actualId) async {
    if (widget.onCellTap != null) {
      widget.onCellTap!(actualId);
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceInputScreen(
          teacherCell: actualId,
          selectedDate: _selectedDate,
        ),
      ),
    );
    if (result == true) {
      if (!mounted) return;
      _fetchStats();
    }
  }

  void _processWeeklyData(
    QuerySnapshot snapshot,
    Map<String, Map<String, dynamic>> baseStats,
  ) {
    int sP = 0; int sT = 0; int tP = 0; int tT = 0;

    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      String docId = doc.id;
      Map<String, dynamic> attRecords = Map<String, dynamic>.from(data['records'] ?? {});

      if (docId.startsWith('teachers')) {
        int present = 0;
        attRecords.forEach((rawName, info) {
          String name = _normalizeName(rawName);
          String status = info is Map ? info['status'] : '결석';
          if (status == '출석') present++;
          
          if (baseStats['교사']!['records'].containsKey(name)) {
            baseStats['교사']!['records'][name]['status'] = status;
          } else {
            baseStats['교사']!['records'][name] = {'status': status, 'group': 'T'};
          }
        });
        baseStats['교사']!['present'] = present;
        baseStats['교사']!['total'] = baseStats['교사']!['records'].length;
      } else {
        String cleanId = (int.tryParse(docId.split('셀')[0]) ?? 0).toString();
        
        if (baseStats.containsKey(cleanId)) {
          attRecords.forEach((rawName, info) {
            String name = _normalizeName(rawName);
            String status = info is Map ? info['status'] : '결석';
            if (baseStats[cleanId]!['records'].containsKey(name)) {
              baseStats[cleanId]!['records'][name]['status'] = status;
            } else {
              baseStats[cleanId]!['records'][name] = {
                'status': status, 
                'group': info is Map ? (info['group'] ?? 'A') : 'A'
              };
            }
          });
          
          int present = 0;
          int groupATotal = 0;
          baseStats[cleanId]!['records'].forEach((name, info) {
            if (info['status'] == '출석') present++;
            if (info['group'] == 'A') groupATotal++;
          });
          baseStats[cleanId]!['present'] = present;
          baseStats[cleanId]!['total'] = groupATotal; // ✅ 재적 기준 업데이트
        } else {
          int present = 0;
          int groupATotal = 0;
          Map<String, dynamic> mergedRecords = {};
          attRecords.forEach((rawName, info) {
            String name = _normalizeName(rawName);
            String status = info is Map ? info['status'] : '결석';
            String group = info is Map ? (info['group'] ?? 'A') : 'A';
            if (status == '출석') present++;
            if (group == 'A') groupATotal++;
            mergedRecords[name] = {
              'status': status,
              'group': group
            };
          });
          baseStats[cleanId] = {
            'id': cleanId, 
            'total': groupATotal, // ✅ 재적 기준 업데이트
            'present': present, 
            'records': mergedRecords
          };
        }
      }
    }

    Map<String, Map<String, dynamic>> individualWeekly = {};
    baseStats.forEach((cellKey, stat) {
      Map<String, dynamic> records = stat['records'];
      records.forEach((name, info) {
        individualWeekly[name] = {
          'name': name,
          'cell': cellKey == '교사' ? '교사' : cellKey,
          'status': info['status'],
          'p': info['status'] == '출석' ? 1 : 0,
          't': 1,
          'role': cellKey == '교사' ? '교사' : '학생',
          'group': info['group'] ?? 'A' 
        };
      });

      if (cellKey == '교사') {
        tP += stat['present'] as int;
        tT += stat['total'] as int;
      } else {
        sP += stat['present'] as int;
        sT += stat['total'] as int; // ✅ 셀별 재적 총합
      }
    });

    if (mounted) {
      setState(() {
        _cellStats = Map.fromEntries(
          baseStats.entries.toList()..sort((a, b) {
            if (a.key == '교사') return 1;
            if (b.key == '교사') return -1;
            return (int.tryParse(a.key) ?? 99).compareTo(
              int.tryParse(b.key) ?? 99,
            );
          }),
        );
        _individualStats = individualWeekly;
        _studentPresent = sP;
        _studentTotal = sT; 
        _teacherPresent = tP;
        _teacherTotal = tT;
      });
    }
  }

  void _processGroupedData(
    QuerySnapshot snapshot,
    QuerySnapshot tSnap,
    QuerySnapshot sSnap,
  ) {
    Map<String, Map<String, int>> dateSummary = {};
    Map<String, List<double>> cellHistory = {};
    Map<int, List<double>> monthHistory = {};
    Map<String, Map<String, dynamic>> indv = {};

    for (var doc in tSnap.docs) {
      String name = _normalizeName(doc['name']);
      indv[name] = {'name': name, 'cell': '교사', 'p': 0, 't': 0, 'role': '교사', 'group': 'T'};
      if (!cellHistory.containsKey('교사')) cellHistory['교사'] = [];
    }
    for (var doc in sSnap.docs) {
      String name = _normalizeName(doc['name']);
      String cellId = (doc['cell'] ?? '0').toString();
      String group = doc['group'] ?? (doc['isRegular'] == true ? 'A' : 'B');
      indv[name] = {'name': name, 'cell': cellId, 'p': 0, 't': 0, 'role': '학생', 'group': group};
      if (!cellHistory.containsKey(cellId)) cellHistory[cellId] = [];
    }

    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      String dateStr = data['date'];
      DateTime dt = DateTime.parse(dateStr);
      String docId = doc.id;
      Map<String, dynamic> records = Map<String, dynamic>.from(
        data['records'] ?? {},
      );

      int present = 0;
      int groupATotal = 0;

      records.forEach((rawName, info) {
        String name = _normalizeName(rawName);
        bool isPresent = info is Map && info['status'] == '출석';
        String group = 'A';

        if (indv.containsKey(name)) {
          group = indv[name]!['group'] ?? 'A';
          indv[name]!['p'] += isPresent ? 1 : 0;
          indv[name]!['t'] += 1;
        } else if (info is Map && info.containsKey('group')) {
          group = info['group'];
        }

        if (isPresent) present++;
        if (group == 'A') groupATotal++;
      });

      if (!dateSummary.containsKey(dateStr)) {
        dateSummary[dateStr] = {'sP': 0, 'sT': 0, 'tP': 0, 'tT': 0};
      }
      
      if (docId.startsWith('teachers')) {
        dateSummary[dateStr]!['tP'] = (dateSummary[dateStr]!['tP'] ?? 0) + present;
        dateSummary[dateStr]!['tT'] = (dateSummary[dateStr]!['tT'] ?? 0) + records.length;
        cellHistory['교사']!.add(records.isEmpty ? 0 : present / records.length);
      } else {
        dateSummary[dateStr]!['sP'] = (dateSummary[dateStr]!['sP'] ?? 0) + present;
        dateSummary[dateStr]!['sT'] = (dateSummary[dateStr]!['sT'] ?? 0) + groupATotal; // ✅ 학생 총계는 무조건 A그룹(재적) 합산
        
        String cellId = docId.split('셀')[0];
        // 0으로 나누기 방지 및 B그룹만 출석한 경우 100% 반영 처리
        double rate = groupATotal > 0 ? present / groupATotal : (present > 0 ? 1.0 : 0.0);
        if (cellHistory.containsKey(cellId)) cellHistory[cellId]!.add(rate);
        
        if (_viewType == '누적') {
          int m = dt.month;
          if (!monthHistory.containsKey(m)) monthHistory[m] = [];
          monthHistory[m]!.add(rate);
        }
      }
    }

    _summaryList = dateSummary.entries.map((e) => {
      'date': e.key,
      'sP': e.value['sP'],
      'sT': e.value['sT'],
      'tP': e.value['tP'],
      'tT': e.value['tT'],
    }).toList()..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

    Map<String, double> cellAverages = {};
    cellHistory.forEach(
      (cell, rates) => cellAverages[cell] = rates.isEmpty ? 0.0 : rates.reduce((a, b) => a + b) / rates.length,
    );

    Map<int, double> monthlyAverages = {};
    monthHistory.forEach(
      (month, rates) => monthlyAverages[month] = rates.isEmpty ? 0.0 : rates.reduce((a, b) => a + b) / rates.length,
    );

    if (_summaryList.isNotEmpty) {
      _studentPresent = (_summaryList.map((e) => e['sP'] as int).reduce((a, b) => a + b) / _summaryList.length).round();
      _studentTotal = (_summaryList.map((e) => e['sT'] as int).reduce((a, b) => a + b) / _summaryList.length).round();
      _teacherPresent = (_summaryList.map((e) => e['tP'] as int).reduce((a, b) => a + b) / _summaryList.length).round();
      _teacherTotal = (_summaryList.map((e) => e['tT'] as int).reduce((a, b) => a + b) / _summaryList.length).round();
    } else {
      _studentPresent = 0;
      _studentTotal = sSnap.docs.where((d) => (d['group'] ?? (d['isRegular'] == true ? 'A' : 'B')) == 'A').length; // 초기화면 A그룹 총원 카운트
      _teacherPresent = 0;
      _teacherTotal = tSnap.docs.length;
    }

    if (mounted) {
      setState(() {
        _cellAverages = cellAverages;
        _monthlyAverages = monthlyAverages;
        _individualStats = indv;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildSummaryHeader(),
          _buildViewToggle(),
          _buildGroupingToggle(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_groupingMode == '개인별'
                      ? _buildIndividualList()
                      : (_viewType == '주별'
                            ? _buildWeeklyDetailList()
                            : _viewType == '월별'
                            ? _buildMonthlyDashboard()
                            : _buildCumulativeDashboard())),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader() {
    double sRate = _studentTotal > 0
        ? (_studentPresent / _studentTotal) * 100
        : (_studentPresent > 0 ? 100 : 0);
    double tRate = _teacherTotal > 0
        ? (_teacherPresent / _teacherTotal) * 100
        : (_teacherPresent > 0 ? 100 : 0);
    String titleText = _viewType == '주별'
        ? DateFormat('yyyy년 MM월 dd일').format(_selectedDate)
        : _viewType == '월별'
        ? DateFormat('yyyy년 MM월').format(_selectedDate)
        : "${_selectedDate.year}년 연간 누적 통계";
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "$p / $t",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                // ✅ 재적 표기 추가
                if (title == "학생")
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      "(재적)",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
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

  Widget _buildGroupingToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _toggleButton(
                '셀별',
                _groupingMode == '셀별',
                () => setState(() => _groupingMode = '셀별'),
              ),
              const SizedBox(width: 8),
              _toggleButton(
                '개인별',
                _groupingMode == '개인별',
                () => setState(() => _groupingMode = '개인별'),
              ),
            ],
          ),
          if (_groupingMode == '개인별')
            Row(
              children: [
                const Text(
                  '정렬: ',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _sortButton(
                  '셀순',
                  _individualSortMode == '셀순',
                  () => setState(() => _individualSortMode = '셀순'),
                ),
                const SizedBox(width: 4),
                _sortButton(
                  '랭킹순',
                  _individualSortMode == '랭킹순',
                  () => setState(() => _individualSortMode = '랭킹순'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueGrey : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.blueGrey : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _sortButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.teal.shade700 : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }

  Widget _buildIndividualList() {
    var allMembers = _individualStats.values.toList();
    var teachers = allMembers.where((m) => m['role'] == '교사').toList();
    var students = allMembers.where((m) => m['role'] == '학생').toList();

    if (_individualSortMode == '랭킹순') {
      teachers.sort((a, b) {
        double rateA = a['t'] > 0 ? a['p'] / a['t'] : 0;
        double rateB = b['t'] > 0 ? b['p'] / b['t'] : 0;
        if (rateB != rateA) return rateB.compareTo(rateA);
        return (a['name'] as String).compareTo(b['name'] as String);
      });
      students.sort((a, b) {
        double rateA = a['t'] > 0 ? a['p'] / a['t'] : 0;
        double rateB = b['t'] > 0 ? b['p'] / b['t'] : 0;
        if (rateB != rateA) return rateB.compareTo(rateA);
        return (a['name'] as String).compareTo(b['name'] as String);
      });
    } else {
      teachers.sort(
        (a, b) => (a['name'] as String).compareTo(b['name'] as String),
      );
      students.sort((a, b) {
        int cellA = int.tryParse(a['cell'] ?? '99') ?? 99;
        int cellB = int.tryParse(b['cell'] ?? '99') ?? 99;
        if (cellA != cellB) return cellA.compareTo(cellB);
        return (a['name'] as String).compareTo(b['name'] as String);
      });
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader("👶 학생 명단", Colors.blue),
        ...students.map((m) => _buildIndividualCard(m)),
        const SizedBox(height: 24),
        _buildSectionHeader("👨‍🏫 교사 명단", Colors.orange),
        ...teachers.map((m) => _buildIndividualCard(m)),
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndividualCard(Map<String, dynamic> item) {
    bool isTeacher = item['role'] == '교사';
    String group = item['group'] ?? 'A'; 
    
    Widget trailing;
    if (_viewType == '주별') {
      bool isP = item['status'] == '출석';
      trailing = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isP ? Colors.teal : Colors.red.shade400,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          item['status'] ?? '결석',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else {
      double rate = (item['t'] ?? 0) > 0 ? (item['p'] / item['t']) : 0;
      trailing = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${(rate * 100).toInt()}%',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: rate >= 0.8 ? Colors.teal : Colors.orange,
              fontSize: 14,
            ),
          ),
          Text(
            '${item['p']}/${item['t']}회',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      );
    }

    String subtitleText = isTeacher
        ? '중등부 교사'
        : '${item['cell'].toString().padLeft(2, '0')}셀 학생${group == 'B' ? ' (B그룹)' : ' (A그룹)'}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isTeacher
              ? Colors.orange.shade50
              : (group == 'B' ? Colors.orange.shade50 : Colors.blue.shade50),
          child: Text(
            item['name']?[0] ?? '?',
            style: TextStyle(
              color: isTeacher ? Colors.orange : (group == 'B' ? Colors.orange : Colors.blue),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        title: Text(
          item['name'] ?? '이름없음',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          subtitleText,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        trailing: trailing,
      ),
    );
  }

  Widget _buildWeeklyDetailList() {
    if (_cellStats.isEmpty) {
      return const Center(
        child: Text("표시할 명단이 없습니다.", style: TextStyle(color: Colors.grey)),
      );
    }
    List<Widget> listItems = [_buildDashboardArea()];
    _cellStats.forEach((displayKey, stat) {
      String actualId = stat['id'];
      bool isT = displayKey == '교사';
      listItems.add(
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isT ? Colors.orange.shade200 : Colors.grey.shade200,
            ),
          ),
          child: ExpansionTile(
            initiallyExpanded: true,
            title: InkWell(
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
            // ✅ 셀의 트레일링 텍스트에 "재적" 표기 명확히
            trailing: Text(
              isT ? '${stat['present']} / ${stat['total']} 명' : '${stat['present']} / 재적 ${stat['total']} 명',
              style: TextStyle(
                color: isT ? Colors.orange : Colors.teal,
                fontWeight: FontWeight.bold,
              ),
            ),
            children: [
              _buildMemberGrid(Map<String, dynamic>.from(stat['records']), isTeacher: isT),
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: TextButton.icon(
                  onPressed: () => _handleCellTap(actualId),
                  icon: Icon(
                    Icons.edit,
                    size: 16,
                    color: isT ? Colors.orange : Colors.teal,
                  ),
                  label: Text(
                    isT ? "교사 출석 입력하기" : "학생 출석 입력하기",
                    style: TextStyle(color: isT ? Colors.orange : Colors.teal),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
    return ListView(padding: const EdgeInsets.all(16), children: listItems);
  }

  Widget _buildMemberGrid(Map<String, dynamic> records, {bool isTeacher = false}) {
    if (isTeacher) {
      var sortedEntries = records.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
      return Padding(
        padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
        child: _buildChipWrap(sortedEntries)
      );
    }

    var groupA = records.entries.where((e) => e.value['group'] == 'A').toList()..sort((a, b) => a.key.compareTo(b.key));
    var groupB = records.entries.where((e) => e.value['group'] == 'B').toList()..sort((a, b) => a.key.compareTo(b.key));

    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (groupA.isNotEmpty) ...[
            const Text('A그룹', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 6),
            _buildChipWrap(groupA),
          ],
          if (groupA.isNotEmpty && groupB.isNotEmpty) const SizedBox(height: 12),
          if (groupB.isNotEmpty) ...[
            const Text('B그룹', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
            const SizedBox(height: 6),
            _buildChipWrap(groupB),
          ]
        ]
      )
    );
  }

  Widget _buildChipWrap(List<MapEntry<String, dynamic>> entries) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: entries.map((e) {
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
    );
  }

  Widget _buildMonthlyDashboard() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMonthlyTrendChart(),
        const SizedBox(height: 24),
        _buildRankingArea('반별 월간 평균 랭킹 🏆', Colors.orange),
        const SizedBox(height: 24),
        Row(
          children: [
            Container(width: 4, height: 16, color: Colors.teal),
            const SizedBox(width: 8),
            const Text(
              '주차별 상세 통계',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_summaryList.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                "해당 월에 등록된 출석 데이터가 없습니다.",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ..._summaryList.map((item) => _buildModernDateCard(item)).toList(),
      ],
    );
  }

  Widget _buildCumulativeDashboard() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildAnnualTrendChart(),
        const SizedBox(height: 24),
        _buildRankingArea('올해의 성실 반(셀) TOP 🏆', Colors.teal),
        const SizedBox(height: 24),
        _buildAnnualSummaryCards(),
        const SizedBox(height: 24),
        Row(
          children: [
            Container(width: 4, height: 16, color: Colors.blueGrey),
            const SizedBox(width: 8),
            const Text(
              '전체 출석 기록 (최근순)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_summaryList.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                "올해 등록된 출석 데이터가 없습니다.",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ..._summaryList.map((item) => _buildModernDateCard(item)).toList(),
      ],
    );
  }

  Widget _buildRankingArea(String title, Color mainColor) {
    var sortedCells = _cellAverages.entries.toList()
      ..sort((a, b) {
        if (a.key == '교사') return 1;
        if (b.key == '교사') return -1;
        int rateCompare = b.value.compareTo(a.value);
        if (rateCompare != 0) return rateCompare;
        return (int.tryParse(a.key) ?? 99).compareTo(int.tryParse(b.key) ?? 99);
      });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mainColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: mainColor,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          if (sortedCells.isEmpty)
            const Text(
              "표시할 셀 정보가 없습니다.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ...sortedCells.map((e) {
            int rank = sortedCells.indexOf(e) + 1;
            bool isTeacher = e.key == '교사';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: rank == 1 && !isTeacher
                        ? Colors.orange
                        : Colors.grey.shade100,
                    child: Text(
                      isTeacher ? '-' : '$rank',
                      style: TextStyle(
                        fontSize: 12,
                        color: rank == 1 && !isTeacher
                            ? Colors.white
                            : Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isTeacher ? '👨‍🏫 교사전체' : '${e.key}셀',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '${(e.value * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: mainColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 80,
                    child: LinearProgressIndicator(
                      value: e.value,
                      color: mainColor,
                      backgroundColor: mainColor.withOpacity(0.1),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildMonthlyTrendChart() {
    var sortedSummary = List.from(_summaryList).reversed.toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [
          BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '주차별 출석률 추이',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: sortedSummary.isEmpty
                  ? [
                      const Center(
                        child: Text("데이터 없음", style: TextStyle(fontSize: 12)),
                      ),
                    ]
                  : sortedSummary.map((item) {
                      DateTime dt = DateTime.parse(item['date']);
                      double rate = (item['sT'] ?? 0) > 0
                          ? (item['sP'] / item['sT'])
                          : (item['sP'] > 0 ? 1.0 : 0.0);
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${(rate * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 32,
                            height: (rate > 1.0 ? 1.0 : rate) * 80 + 5,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.blue.shade400,
                                  Colors.blue.shade200,
                                ],
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getWeekOfMonth(dt),
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnualTrendChart() {
    var months = _monthlyAverages.keys.toList()..sort();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigo.shade100),
        boxShadow: [
          BoxShadow(color: Colors.indigo.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '연간 월별 출석 추이',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: months.isEmpty
                  ? [
                      const Center(
                        child: Text("데이터 없음", style: TextStyle(fontSize: 12)),
                      ),
                    ]
                  : months.map((m) {
                      double rate = _monthlyAverages[m] ?? 0;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${(rate * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 20,
                            height: (rate > 1.0 ? 1.0 : rate) * 90 + 5,
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade400,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$m월',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnualSummaryCards() {
    int bestMonth = 1;
    double maxRate = 0;
    _monthlyAverages.forEach((m, r) {
      if (r > maxRate) {
        maxRate = r;
        bestMonth = m;
      }
    });
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.star, color: Colors.orange, size: 20),
                const SizedBox(height: 8),
                const Text(
                  'Best 출석 달',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$bestMonth월 (${(maxRate * 100).toInt()}%)',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.calendar_month, color: Colors.blue, size: 20),
                const SizedBox(height: 8),
                const Text(
                  '총 주일 수',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_summaryList.length}주',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernDateCard(Map<String, dynamic> item) {
    DateTime dt = DateTime.parse(item['date']);
    double sRate = (item['sT'] ?? 0) > 0 ? (item['sP'] / item['sT']) : (item['sP'] > 0 ? 1.0 : 0.0);
    double tRate = (item['tT'] ?? 0) > 0 ? (item['tP'] / item['tT']) : (item['tP'] > 0 ? 1.0 : 0.0);
    String grade = sRate >= 0.9
        ? '최상'
        : sRate >= 0.7
        ? '양호'
        : '관리';
    Color gradeColor = sRate >= 0.9
        ? Colors.green
        : sRate >= 0.7
        ? Colors.teal
        : Colors.orange;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedDate = dt;
          _viewType = '주별';
          _fetchStats();
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getWeekOfMonth(dt),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      DateFormat('MM월 dd일 주일 현황').format(dt),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: gradeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    grade,
                    style: TextStyle(
                      color: gradeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.people_outline,
                            size: 14,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '학생',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const Spacer(),
                          // ✅ 여기서도 재적임을 명시
                          Text(
                            '${item['sP']} / 재적 ${item['sT']}명',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: sRate > 1.0 ? 1.0 : sRate,
                        minHeight: 4,
                        color: Colors.blue,
                        backgroundColor: Colors.blue.withOpacity(0.1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.school_outlined,
                            size: 14,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '교사',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${item['tP']} / ${item['tT']}명',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: tRate > 1.0 ? 1.0 : tRate,
                        minHeight: 4,
                        color: Colors.orange,
                        backgroundColor: Colors.orange.withOpacity(0.1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardArea() {
    var studentCells = _cellStats.entries.where((e) => e.key != '교사').toList()
      ..sort((a, b) {
        double rateA = a.value['total'] > 0
            ? (a.value['present'] / a.value['total'])
            : (a.value['present'] > 0 ? 1.0 : 0.0);
        double rateB = b.value['total'] > 0
            ? (b.value['present'] / b.value['total'])
            : (b.value['present'] > 0 ? 1.0 : 0.0);
        return rateB.compareTo(rateA);
      });
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.leaderboard, color: Colors.teal, size: 22),
              const SizedBox(width: 8),
              const Text(
                '반별 출석률 현황',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...studentCells.map((e) {
            double rate = e.value['total'] > 0
                ? e.value['present'] / e.value['total']
                : (e.value['present'] > 0 ? 1.0 : 0.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 45,
                    child: Text(
                      '${e.key}셀',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(
                          value: rate > 1.0 ? 1.0 : rate,
                          color: rate >= 0.8 ? Colors.teal : Colors.orange,
                          backgroundColor: Colors.grey.shade100,
                          minHeight: 12,
                        ),
                        const SizedBox(height: 4),
                        // ✅ 분모가 재적임을 확실하게 설명
                        Text(
                          '출석 ${e.value['present']}명 / 재적 ${e.value['total']}명',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${(rate * 100).toInt()}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Future<void> _showMonthPicker() async {
    int selectedYear = _selectedDate.year;
    int selectedMonth = _selectedDate.month;
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('조회 월 선택'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<int>(
                value: selectedYear,
                isExpanded: true,
                items: List.generate(5, (index) => 2024 + index)
                    .map((y) => DropdownMenuItem(value: y, child: Text('$y년')))
                    .toList(),
                onChanged: (val) => setStateDialog(() => selectedYear = val!),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(12, (index) => index + 1)
                    .map(
                      (m) => ChoiceChip(
                        label: Text('$m월'),
                        selected: selectedMonth == m,
                        onSelected: (s) =>
                            setStateDialog(() => selectedMonth = m),
                        selectedColor: Colors.teal,
                        labelStyle: TextStyle(
                          color: selectedMonth == m
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, DateTime(selectedYear, selectedMonth)),
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _fetchStats();
      });
    }
  }

  Future<void> _selectDate() async {
    if (_viewType == '월별') {
      await _showMonthPicker();
      return;
    }
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
      locale: const Locale('ko', 'KR'),
      selectableDayPredicate: (DateTime day) => day.weekday == DateTime.sunday,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _fetchStats();
      });
    }
  }
}