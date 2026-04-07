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
  int _studentTotal = 0;
  int _teacherPresent = 0;
  int _teacherTotal = 0;

  Map<String, Map<String, dynamic>> _cellStats = {};
  List<Map<String, dynamic>> _summaryList = [];

  Map<String, double> _cellAverages = {};
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

        for (var doc in studentSnap.docs) {
          String cell = doc['cell'] ?? '기타';
          String cleanCell = (int.tryParse(cell) ?? 0).toString();
          String name = _normalizeName(doc['name']);
          String group = doc['group'] ?? (doc['isRegular'] == true ? 'A' : 'B');

          if (!baseStats.containsKey(cleanCell)) {
            baseStats[cleanCell] = {
              'id': cleanCell,
              'total': 0,
              'present': 0,
              'records': <String, dynamic>{},
            };
          }
          if (group == 'A') {
            baseStats[cleanCell]!['total'] =
                (baseStats[cleanCell]!['total'] as int) + 1;
          }
          baseStats[cleanCell]!['records'][name] = {
            'status': '결석',
            'group': group,
          };
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

  void _processWeeklyData(
    QuerySnapshot snapshot,
    Map<String, Map<String, dynamic>> baseStats,
  ) {
    int sP = 0;
    int sT = 0;
    int tP = 0;
    int tT = 0;
    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      String docId = doc.id;
      Map<String, dynamic> attRecords = Map<String, dynamic>.from(
        data['records'] ?? {},
      );

      if (docId.startsWith('teachers')) {
        int present = 0;
        attRecords.forEach((rawName, info) {
          String name = _normalizeName(rawName);
          String status = info is Map ? info['status'] : '결석';
          if (status == '출석') present++;
          if (baseStats['교사']!['records'].containsKey(name)) {
            baseStats['교사']!['records'][name]['status'] = status;
          }
        });
        baseStats['교사']!['present'] = present;
      } else {
        String cleanId = (int.tryParse(docId.split('셀')[0]) ?? 0).toString();
        if (baseStats.containsKey(cleanId)) {
          attRecords.forEach((rawName, info) {
            String name = _normalizeName(rawName);
            String status = info is Map ? info['status'] : '결석';
            if (baseStats[cleanId]!['records'].containsKey(name)) {
              baseStats[cleanId]!['records'][name]['status'] = status;
            }
          });
          int present = 0;
          baseStats[cleanId]!['records'].forEach((name, info) {
            if (info['status'] == '출석') present++;
          });
          baseStats[cleanId]!['present'] = present;
        }
      }
    }
    Map<String, Map<String, dynamic>> individualWeekly = {};
    baseStats.forEach((cellKey, stat) {
      stat['records'].forEach((name, info) {
        individualWeekly[name] = {
          'name': name,
          'cell': cellKey == '교사' ? '교사' : cellKey,
          'status': info['status'],
          'p': info['status'] == '출석' ? 1 : 0,
          't': 1,
          'role': cellKey == '교사' ? '교사' : '학생',
          'group': info['group'] ?? 'A',
        };
      });
      if (cellKey == '교사') {
        tP += stat['present'] as int;
        tT += stat['total'] as int;
      } else {
        sP += stat['present'] as int;
        sT += stat['total'] as int;
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
    Map<String, Map<String, dynamic>> indv = {};

    int latestStudentTotal = sSnap.docs.where((d) {
      var data = d.data() as Map<String, dynamic>;
      return (data['group'] ?? (data['isRegular'] == true ? 'A' : 'B')) == 'A';
    }).length;
    int latestTeacherTotal = tSnap.docs.length;

    for (var doc in tSnap.docs) {
      String name = _normalizeName(doc['name']);
      indv[name] = {
        'name': name,
        'cell': '교사',
        'p': 0,
        't': 0,
        'role': '교사',
        'group': 'T',
      };
      if (!cellHistory.containsKey('교사')) cellHistory['교사'] = [];
    }
    for (var doc in sSnap.docs) {
      String name = _normalizeName(doc['name']);
      String cellId = (doc['cell'] ?? '0').toString();
      var data = doc.data() as Map<String, dynamic>;
      String group = data['group'] ?? (data['isRegular'] == true ? 'A' : 'B');
      String dbRole = data['role'] ?? '학생';
      String promotedAt = data['promotedAt'] ?? '';

      indv[name] = {
        'name': name,
        'cell': cellId,
        'p': 0,
        't': 0,
        'role': '학생',
        'group': group,
        'dbRole': dbRole,
        'promotedAt': promotedAt,
      };
      if (!cellHistory.containsKey(cellId)) cellHistory[cellId] = [];
    }

    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      String dateStr = data['date'];
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
        }
        if (isPresent) present++;
        if (group == 'A') groupATotal++;
      });
      if (!dateSummary.containsKey(dateStr)) {
        dateSummary[dateStr] = {'sP': 0, 'sT': 0, 'tP': 0, 'tT': 0};
      }
      if (docId.startsWith('teachers')) {
        dateSummary[dateStr]!['tP'] =
            (dateSummary[dateStr]!['tP'] ?? 0) + present;
        dateSummary[dateStr]!['tT'] =
            (dateSummary[dateStr]!['tT'] ?? 0) + records.length;
        cellHistory['교사']!.add(records.isEmpty ? 0 : present / records.length);
      } else {
        dateSummary[dateStr]!['sP'] =
            (dateSummary[dateStr]!['sP'] ?? 0) + present;
        dateSummary[dateStr]!['sT'] =
            (dateSummary[dateStr]!['sT'] ?? 0) + groupATotal;
        String cellId = docId.split('셀')[0];
        double rate = groupATotal > 0
            ? present / groupATotal
            : (present > 0 ? 1.0 : 0.0);
        if (cellHistory.containsKey(cellId)) cellHistory[cellId]!.add(rate);
      }
    }
    _summaryList =
        dateSummary.entries
            .map(
              (e) => {
                'date': e.key,
                'sP': e.value['sP'],
                'sT': e.value['sT'],
                'tP': e.value['tP'],
                'tT': e.value['tT'],
              },
            )
            .toList()
          ..sort(
            (a, b) => (b['date'] as String).compareTo(a['date'] as String),
          );

    Map<String, double> cellAverages = {};
    cellHistory.forEach(
      (cell, rates) => cellAverages[cell] = rates.isEmpty
          ? 0.0
          : rates.reduce((a, b) => a + b) / rates.length,
    );

    if (_summaryList.isNotEmpty) {
      _studentPresent =
          (_summaryList.map((e) => e['sP'] as int).reduce((a, b) => a + b) /
                  _summaryList.length)
              .round();
      _teacherPresent =
          (_summaryList.map((e) => e['tP'] as int).reduce((a, b) => a + b) /
                  _summaryList.length)
              .round();
      _studentTotal = latestStudentTotal;
      _teacherTotal = latestTeacherTotal;
    } else {
      _studentPresent = 0;
      _studentTotal = latestStudentTotal;
      _teacherPresent = 0;
      _teacherTotal = latestTeacherTotal;
    }
    if (mounted)
      setState(() {
        _cellAverages = cellAverages;
        _individualStats = indv;
      });
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
                            : _buildDashboard())),
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
        : "${_selectedDate.year}년 연간 누적";
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
                "학생 (재적)",
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
            const SizedBox(height: 2),
            Text(
              "${r.toStringAsFixed(1)}%",
              style: TextStyle(
                color: c,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
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
            InkWell(
              onTap: () => setState(
                () => _individualSortMode = _individualSortMode == '셀순'
                    ? '랭킹순'
                    : '셀순',
              ),
              child: Row(
                children: [
                  Text(
                    _individualSortMode,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Icon(Icons.sort, size: 14),
                ],
              ),
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

  Widget _buildDashboard() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_viewType == '월별') _buildMonthlyInsights(),
        _buildTrendChart(),
        const SizedBox(height: 24),
        _buildRankingArea('반별 평균 출석률 🏆', Colors.orange),
        const SizedBox(height: 24),
        _buildPastoralSections(),
      ],
    );
  }

  Widget _buildPastoralSections() {
    var perfectList = _individualStats.values
        .where((m) => m['role'] == '학생' && m['p'] == m['t'] && m['t'] > 0)
        .toList();

    var absentList = _individualStats.values
        .where((m) => m['role'] == '학생' && m['p'] == 0 && m['t'] > 0)
        .toList();

    var newMemberList = _individualStats.values
        .where((m) => m['role'] == '학생' && m['dbRole'] == "새친구" && m['t'] > 0)
        .toList();

    String currentMonthStr = DateFormat('yyyy-MM').format(_selectedDate);
    var promotedList = _individualStats.values
        .where(
          (m) =>
              m['role'] == '학생' &&
              m['promotedAt'] != null &&
              m['promotedAt'].toString().startsWith(currentMonthStr),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildNameListSection("🏆 이달의 개근자 명단", perfectList, Colors.teal),
        const SizedBox(height: 24),
        _buildNameListSection("📞 심방 권면 대상 (올결석)", absentList, Colors.red),
        const SizedBox(height: 24),
        if (promotedList.isNotEmpty) ...[
          _buildNameListSection("🎉 이달의 등반 소식", promotedList, Colors.indigo),
          const SizedBox(height: 24),
        ],
        _buildNewMemberStatusSection(newMemberList),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildNameListSection(
    String title,
    List<Map<String, dynamic>> list,
    Color themeColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: themeColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: themeColor.withOpacity(0.1)),
          ),
          child: list.isEmpty
              ? const Text(
                  "해당하는 학생이 없습니다.",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: list
                      .map(
                        (m) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: themeColor.withOpacity(0.2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            "${m['name']} (${m['cell']}셀)",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: themeColor.withOpacity(0.8),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildNewMemberStatusSection(List<Map<String, dynamic>> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            "🌱 새친구 정착 현황",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.withOpacity(0.1)),
          ),
          child: list.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "현재 등록된 새친구가 없습니다.",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                )
              : Column(
                  children: list.map((m) {
                    double progress = m['p'] / m['t'];
                    return ListTile(
                      dense: true,
                      title: Text(
                        "${m['name']} (${m['cell']}셀)",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.orange.withOpacity(0.1),
                            color: Colors.orange,
                            minHeight: 6,
                          ),
                        ),
                      ),
                      trailing: Text(
                        // ✅ '회' 단위를 '주' 단위로 변경
                        "${m['p']} / ${m['t']}주",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildMonthlyInsights() {
    int perfectAttendanceCount = _individualStats.values
        .where((m) => m['role'] == '학생' && m['p'] == m['t'] && m['t'] > 0)
        .length;
    var bestWeek = _summaryList.isEmpty
        ? null
        : _summaryList.reduce((a, b) {
            double rateA = a['sT'] > 0 ? a['sP'] / a['sT'] : 0;
            double rateB = b['sT'] > 0 ? b['sP'] / b['sT'] : 0;
            return rateA > rateB ? a : b;
          });

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "이번 달 하이라이트 ✨",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _insightCard(
                "🏆 이달의 개근상",
                "$perfectAttendanceCount명",
                Colors.teal,
              ),
              const SizedBox(width: 10),
              _insightCard(
                "🔥 베스트 주차",
                bestWeek != null
                    ? DateFormat(
                        'MM/dd',
                      ).format(DateTime.parse(bestWeek['date']))
                    : "-",
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _insightCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChart() {
    var sorted = List.from(_summaryList).reversed.toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '출석률 추이',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: sorted.map((item) {
                double rate = (item['sT'] ?? 0) > 0
                    ? (item['sP'] / item['sT'])
                    : 0;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${(rate * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 20,
                      height: (rate * 80) + 5,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['date'].substring(5),
                      style: const TextStyle(fontSize: 8, color: Colors.grey),
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

  Widget _buildRankingArea(String title, Color mainColor) {
    var sortedCells = _cellAverages.entries.where((e) => e.key != '교사').toList()
      ..sort((a, b) => b.value.compareTo(a.value));
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
          ...sortedCells.asMap().entries.map((entry) {
            int rank = entry.key + 1;
            var e = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: rank == 1
                        ? Colors.amber
                        : Colors.grey.shade200,
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 10,
                        color: rank == 1 ? Colors.white : Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${e.key}셀',
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
                    width: 60,
                    child: LinearProgressIndicator(
                      value: e.value,
                      color: mainColor,
                      backgroundColor: mainColor.withOpacity(0.1),
                      minHeight: 4,
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

  Widget _buildIndividualList() {
    var students = _individualStats.values
        .where((m) => m['role'] == '학생')
        .toList();
    if (_individualSortMode == '랭킹순') {
      students.sort(
        (a, b) => (b['p'] / (b['t'] > 0 ? b['t'] : 1)).compareTo(
          a['p'] / (a['t'] > 0 ? a['t'] : 1),
        ),
      );
    } else {
      students.sort(
        (a, b) => (int.tryParse(a['cell'] ?? '99') ?? 99).compareTo(
          int.tryParse(b['cell'] ?? '99') ?? 99,
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: students.length,
      itemBuilder: (context, idx) {
        var m = students[idx];
        double rate = (m['t'] ?? 0) > 0 ? (m['p'] / m['t']) : 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(child: Text(m['name'][0])),
            title: Text(
              m['name'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text("${m['cell']}셀 | ${m['group']}그룹"),
            trailing: Text(
              "${(rate * 100).toInt()}% (${m['p']}/${m['t']}회)",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: rate >= 0.8 ? Colors.teal : Colors.orange,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWeeklyDetailList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDashboardArea(),
        ..._cellStats.entries.map((e) {
          bool isT = e.key == '교사';
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ExpansionTile(
              initiallyExpanded: true,
              title: Text(
                isT ? '👨‍🏫 교사 전체' : '${e.key}셀',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              trailing: Text(
                '${e.value['present']} / ${isT ? '' : '재적 '}${e.value['total']}명',
                style: TextStyle(
                  color: isT ? Colors.orange : Colors.teal,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: _buildMemberGrid(
                    Map<String, dynamic>.from(e.value['records']),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildDashboardArea() {
    var sorted = _cellStats.entries.where((e) => e.key != '교사').toList()
      ..sort(
        (a, b) =>
            (b.value['present'] / (b.value['total'] > 0 ? b.value['total'] : 1))
                .compareTo(
                  a.value['present'] /
                      (a.value['total'] > 0 ? a.value['total'] : 1),
                ),
      );
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: sorted.map((e) {
          double rate = e.value['total'] > 0
              ? e.value['present'] / e.value['total']
              : 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    '${e.key}셀',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: LinearProgressIndicator(
                    value: rate,
                    color: Colors.teal,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(rate * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMemberGrid(Map<String, dynamic> records) {
    var sorted = records.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: sorted.map((e) {
        bool isP = e.value['status'] == '출석';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: isP ? Colors.teal.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            e.key,
            style: TextStyle(
              fontSize: 13,
              color: isP ? Colors.teal.shade800 : Colors.grey.shade400,
              fontWeight: isP ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _selectDate() async {
    if (_viewType == '월별') {
      int tempYear = _selectedDate.year;
      int tempMonth = _selectedDate.month;
      final pickedDate = await showDialog<DateTime>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            '조회 월 선택',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<int>(
                  value: tempYear,
                  isExpanded: true,
                  items: List.generate(5, (i) => 2024 + i)
                      .map(
                        (y) => DropdownMenuItem(value: y, child: Text('$y년')),
                      )
                      .toList(),
                  onChanged: (y) => tempYear = y!,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(12, (i) => i + 1).map((m) {
                    bool isCurrent = tempMonth == m;
                    return InkWell(
                      onTap: () =>
                          Navigator.pop(context, DateTime(tempYear, m, 1)),
                      child: Container(
                        width: 50,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isCurrent ? Colors.teal : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$m월',
                          style: TextStyle(
                            color: isCurrent ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
          ],
        ),
      );
      if (pickedDate != null) {
        setState(() {
          _selectedDate = pickedDate;
          _fetchStats();
        });
      }
    } else {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2024, 1, 1),
        lastDate: DateTime.now(),
        locale: const Locale('ko', 'KR'),
        selectableDayPredicate: (d) => d.weekday == DateTime.sunday,
      );
      if (picked != null) {
        setState(() {
          _selectedDate = picked;
          _fetchStats();
        });
      }
    }
  }
}
