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

  // 학년별/성별 통계 변수
  Map<String, Map<String, int>> _gradeStats = {};
  Map<String, Map<String, int>> _genderStats = {};
  Map<String, Map<String, Map<String, int>>> _gradeGenderStats = {};

  // 결석 사유 통계 변수
  Map<String, int> _absenceReasonCounts = {};

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

  void _initStatsMaps() {
    _gradeStats = {
      '1학년': {'p': 0, 't': 0},
      '2학년': {'p': 0, 't': 0},
      '3학년': {'p': 0, 't': 0},
    };
    _genderStats = {
      '남자': {'p': 0, 't': 0},
      '여자': {'p': 0, 't': 0},
    };
    _gradeGenderStats = {
      '1학년': {
        '남자': {'p': 0, 't': 0},
        '여자': {'p': 0, 't': 0},
      },
      '2학년': {
        '남자': {'p': 0, 't': 0},
        '여자': {'p': 0, 't': 0},
      },
      '3학년': {
        '남자': {'p': 0, 't': 0},
        '여자': {'p': 0, 't': 0},
      },
    };
    _absenceReasonCounts = {};
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

      _initStatsMaps();

      // ✅ [중요] 재적 인원 계산 로직 통일 (항상 현재 DB 기준으로 고정)
      int currentStudentTotal = studentSnap.docs.where((d) {
        var data = d.data();
        return (data['group'] ?? (data['isRegular'] == true ? 'A' : 'B')) ==
            'A';
      }).length;
      int currentTeacherTotal = teacherSnap.docs.length;

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
          String grade = doc['grade'] ?? '1학년';
          String gender = doc['gender'] ?? '남자';

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
            if (_gradeStats.containsKey(grade))
              _gradeStats[grade]!['t'] = _gradeStats[grade]!['t']! + 1;
            if (_genderStats.containsKey(gender))
              _genderStats[gender]!['t'] = _genderStats[gender]!['t']! + 1;
            if (_gradeGenderStats.containsKey(grade) &&
                _gradeGenderStats[grade]!.containsKey(gender)) {
              _gradeGenderStats[grade]![gender]!['t'] =
                  _gradeGenderStats[grade]![gender]!['t']! + 1;
            }
          }
          baseStats[cleanCell]!['records'][name] = {
            'status': '결석',
            'group': group,
            'grade': grade,
            'gender': gender,
            'dbRole': doc['role'] ?? '학생',
            'promotedAt': doc['promotedAt'] ?? '',
            'firstVisitDate': doc['firstVisitDate'] ?? '',
            'evangelist': doc['evangelist'] ?? '',
          };
        }
        _processWeeklyData(
          snapshot,
          baseStats,
          currentStudentTotal,
          currentTeacherTotal,
        );
      } else {
        _processGroupedData(
          snapshot,
          teacherSnap,
          studentSnap,
          currentStudentTotal,
          currentTeacherTotal,
        );
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
    int sT,
    int tT,
  ) {
    int sP = 0;
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
          if (baseStats['교사']!['records'].containsKey(name))
            baseStats['교사']!['records'][name]['status'] = status;
        });
        baseStats['교사']!['present'] = present;
      } else {
        String cleanId = (int.tryParse(docId.split('셀')[0]) ?? 0).toString();
        if (baseStats.containsKey(cleanId)) {
          attRecords.forEach((rawName, info) {
            String name = _normalizeName(rawName);
            String status = info is Map ? info['status'] : '결석';
            if (status != '출석') {
              String reason = (info is Map ? info['reason'] : null) ?? '연락x';
              _absenceReasonCounts[reason] =
                  (_absenceReasonCounts[reason] ?? 0) + 1;
            }
            if (baseStats[cleanId]!['records'].containsKey(name)) {
              var memberInfo = baseStats[cleanId]!['records'][name];
              memberInfo['status'] = status;
              if (status == '출석' && memberInfo['group'] == 'A') {
                String grade = memberInfo['grade'] ?? '1학년';
                String gender = memberInfo['gender'] ?? '남자';
                if (_gradeStats.containsKey(grade))
                  _gradeStats[grade]!['p'] = _gradeStats[grade]!['p']! + 1;
                if (_genderStats.containsKey(gender))
                  _genderStats[gender]!['p'] = _genderStats[gender]!['p']! + 1;
                if (_gradeGenderStats.containsKey(grade) &&
                    _gradeGenderStats[grade]!.containsKey(gender)) {
                  _gradeGenderStats[grade]![gender]!['p'] =
                      _gradeGenderStats[grade]![gender]!['p']! + 1;
                }
              }
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
          'dbRole': info['dbRole'],
          'promotedAt': info['promotedAt'],
          'firstVisitDate': info['firstVisitDate'],
          'evangelist': info['evangelist'],
        };
      });
      if (cellKey != '교사') sP += stat['present'] as int;
    });

    if (mounted)
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
        _studentTotal = sT; // ✅ 통일된 재적수 적용
        _teacherPresent = baseStats['교사']!['present'];
        _teacherTotal = tT; // ✅ 통일된 재적수 적용
      });
  }

  void _processGroupedData(
    QuerySnapshot snapshot,
    QuerySnapshot tSnap,
    QuerySnapshot sSnap,
    int sT,
    int tT,
  ) {
    Map<String, Map<String, int>> dateSummary = {};
    Map<String, List<double>> cellHistory = {};
    Map<String, Map<String, dynamic>> indv = {};

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
      String grade = data['grade'] ?? '1학년';
      String gender = data['gender'] ?? '남자';
      indv[name] = {
        'name': name,
        'cell': cellId,
        'p': 0,
        't': 0,
        'role': '학생',
        'group': group,
        'dbRole': data['role'] ?? '학생',
        'promotedAt': data['promotedAt'] ?? '',
        'firstVisitDate': data['firstVisitDate'] ?? '',
        'evangelist': data['evangelist'] ?? '',
        'grade': grade,
        'gender': gender,
      };
      if (!cellHistory.containsKey(cellId)) cellHistory[cellId] = [];
      if (group == 'A') {
        if (_gradeStats.containsKey(grade))
          _gradeStats[grade]!['t'] = _gradeStats[grade]!['t']! + 1;
        if (_genderStats.containsKey(gender))
          _genderStats[gender]!['t'] = _genderStats[gender]!['t']! + 1;
        if (_gradeGenderStats.containsKey(grade) &&
            _gradeGenderStats[grade]!.containsKey(gender))
          _gradeGenderStats[grade]![gender]!['t'] =
              _gradeGenderStats[grade]![gender]!['t']! + 1;
      }
    }
    Map<String, Map<String, Map<String, int>>> dailyGradeGender = {};
    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      String dateStr = data['date'];
      String docId = doc.id;
      Map<String, dynamic> records = Map<String, dynamic>.from(
        data['records'] ?? {},
      );
      if (!dailyGradeGender.containsKey(dateStr))
        dailyGradeGender[dateStr] = {};
      int present = 0;
      int groupATotal = 0;
      records.forEach((rawName, info) {
        String name = _normalizeName(rawName);
        bool isPresent = info is Map && info['status'] == '출석';
        if (!isPresent && !docId.startsWith('teachers')) {
          String reason = (info is Map ? info['reason'] : null) ?? '연락x';
          _absenceReasonCounts[reason] =
              (_absenceReasonCounts[reason] ?? 0) + 1;
        }
        if (indv.containsKey(name)) {
          var member = indv[name]!;
          String group = member['group'] ?? 'A';
          member['p'] += isPresent ? 1 : 0;
          member['t'] += 1;
          if (group == 'A' && isPresent) {
            String grade = member['grade'] ?? '1학년';
            String gender = member['gender'] ?? '남자';
            if (!dailyGradeGender[dateStr]!.containsKey(grade))
              dailyGradeGender[dateStr]![grade] = {};
            dailyGradeGender[dateStr]![grade]![gender] =
                (dailyGradeGender[dateStr]![grade]![gender] ?? 0) + 1;
          }
          if (isPresent) present++;
          if (group == 'A') groupATotal++;
        }
      });
      if (!dateSummary.containsKey(dateStr))
        dateSummary[dateStr] = {'sP': 0, 'sT': 0, 'tP': 0, 'tT': 0};
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
    if (dailyGradeGender.isNotEmpty) {
      double dayCount = dailyGradeGender.length.toDouble();
      _gradeGenderStats.forEach((grade, genders) {
        int gP = 0;
        genders.forEach((gender, stats) {
          int totalP = 0;
          dailyGradeGender.values.forEach((day) {
            if (day.containsKey(grade) && day[grade]!.containsKey(gender))
              totalP += day[grade]![gender]!;
          });
          stats['p'] = (totalP / dayCount).round();
          gP += stats['p']!;
          _genderStats[gender]!['p'] =
              _genderStats[gender]!['p']! + stats['p']!;
        });
        _gradeStats[grade]!['p'] = gP;
      });
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
    }

    if (mounted)
      setState(() {
        _studentTotal = sT; // ✅ 통일된 재적수 적용
        _teacherTotal = tT; // ✅ 통일된 재적수 적용
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
        ? DateFormat('yyyy. MM. dd').format(_selectedDate)
        : _viewType == '월별'
        ? DateFormat('yyyy년 MM월').format(_selectedDate)
        : "${_selectedDate.year}년 연간 누적";
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                if (_viewType != '누적')
                  const Icon(
                    Icons.arrow_drop_down,
                    color: Colors.teal,
                    size: 20,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildSummaryCard(
                "학생 (재적)",
                _studentPresent,
                _studentTotal,
                sRate,
                Colors.blue,
              ),
              const SizedBox(width: 8),
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
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: c.withOpacity(0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: c,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
                Text(
                  "$p / $t명",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Text(
              "${r.toStringAsFixed(1)}%",
              style: TextStyle(
                color: c,
                fontSize: 13,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: ['주별', '월별', '누적'].map((type) {
            bool isS = _viewType == type;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _viewType = type;
                    _fetchStats();
                  });
                },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isS ? Colors.teal : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                      color: isS ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildGroupingToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
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
              const SizedBox(width: 6),
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
                      fontSize: 11,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueGrey : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? Colors.blueGrey : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_viewType == '월별' || _viewType == '누적') _buildMonthlyInsights(),
        _buildDemographicStats(),
        const SizedBox(height: 16),
        _buildAbsenceReasonRanking(),
        const SizedBox(height: 16),
        _buildTrendChart(),
        const SizedBox(height: 16),
        _buildRankingArea(
          _viewType == '누적' ? '연간 출석률 순위 🏆' : '반별 출석률 🏆',
          Colors.orange,
        ),
        const SizedBox(height: 16),
        _buildPastoralSections(),
      ],
    );
  }

  Widget _buildDemographicStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            "학년 및 성별 출석 현황 📊",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        Row(
          children: [
            _buildDemographicCard("학년별", _gradeStats, Colors.blue),
            const SizedBox(width: 8),
            _buildDemographicCard("성별", _genderStats, Colors.pink),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _gradeGenderStats.entries.map((e) {
              return Expanded(
                child: Column(
                  children: [
                    Text(
                      e.key,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...e.value.entries.map((ge) {
                      double rate = ge.value['t']! > 0
                          ? ge.value['p']! / ge.value['t']!
                          : 0;
                      Color c = ge.key == '남자' ? Colors.blue : Colors.pink;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 2,
                          horizontal: 4,
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  ge.key,
                                  style: const TextStyle(fontSize: 9),
                                ),
                                Text(
                                  "${ge.value['p']}/${ge.value['t']}명",
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: rate,
                                backgroundColor: c.withOpacity(0.05),
                                color: c.withOpacity(0.5),
                                minHeight: 2,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAbsenceReasonRanking() {
    var sorted = _absenceReasonCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    var top5 = sorted.take(5).toList();
    int total = _absenceReasonCounts.values.fold(0, (s, c) => s + c);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            "결석 사유 분석 Top 5 🔍",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withOpacity(0.05)),
          ),
          child: total == 0
              ? const Center(
                  child: Text(
                    "데이터 없음",
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                )
              : Column(
                  children: top5.asMap().entries.map((entry) {
                    double portion = entry.value.value / total;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 15,
                            child: Text(
                              "${entry.key + 1}",
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      entry.value.key,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      "${entry.value.value}명",
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: portion,
                                    color: Colors.redAccent.withOpacity(0.4),
                                    backgroundColor: Colors.redAccent
                                        .withOpacity(0.05),
                                    minHeight: 3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildDemographicCard(
    String title,
    Map<String, Map<String, int>> stats,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          children: stats.entries.map((e) {
            double rate = e.value['t']! > 0 ? e.value['p']! / e.value['t']! : 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        e.key,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "${(rate * 100).toInt()}% (${e.value['p']}/${e.value['t']})",
                        style: TextStyle(
                          fontSize: 9,
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: rate,
                      backgroundColor: color.withOpacity(0.1),
                      color: color.withOpacity(0.4),
                      minHeight: 3,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTrendChart() {
    var sorted = List.from(_summaryList).reversed.toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade50),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '출석률 추이',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
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
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: 16,
                      height: (rate * 50) + 2,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade200,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item['date'].substring(5),
                      style: const TextStyle(fontSize: 7, color: Colors.grey),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: mainColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: mainColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          ...sortedCells.asMap().entries.map((entry) {
            int rank = entry.key + 1;
            var e = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 9,
                    backgroundColor: rank == 1
                        ? Colors.amber
                        : Colors.grey.shade100,
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 9,
                        color: rank == 1 ? Colors.white : Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${e.key}셀',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(e.value * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: mainColor,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 50,
                    child: LinearProgressIndicator(
                      value: e.value,
                      color: mainColor.withOpacity(0.6),
                      backgroundColor: mainColor.withOpacity(0.05),
                      minHeight: 3,
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
      padding: const EdgeInsets.all(8),
      itemCount: students.length,
      itemBuilder: (context, idx) {
        var m = students[idx];
        double rate = (m['t'] ?? 0) > 0 ? (m['p'] / m['t']) : 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ListTile(
            dense: true,
            visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 0,
            ),
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${idx + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                CircleAvatar(
                  radius: 14,
                  child: Text(
                    m['name'][0],
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            title: Text(
              m['name'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Text(
              "${m['cell']}셀 | ${m['group']}그룹",
              style: const TextStyle(fontSize: 11),
            ),
            trailing: Text(
              "${(rate * 100).toInt()}% (${m['p']}/${m['t']}회)",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
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
      padding: const EdgeInsets.all(12),
      children: [
        _buildDemographicStats(),
        const SizedBox(height: 12),
        _buildAbsenceReasonRanking(),
        const SizedBox(height: 12),
        _buildDashboardArea(),
        ..._cellStats.entries.map((e) {
          bool isT = e.key == '교사';
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: ExpansionTile(
              dense: true,
              initiallyExpanded: true,
              title: Text(
                isT ? '👨‍🏫 교사 전체' : '${e.key}셀',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              trailing: Text(
                '${e.value['present']} / ${e.value['total']}명',
                style: TextStyle(
                  color: isT ? Colors.orange : Colors.teal,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: _buildMemberGrid(
                    Map<String, dynamic>.from(e.value['records']),
                    isT,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        const SizedBox(height: 40),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.auto_graph, size: 14, color: Colors.teal),
                SizedBox(width: 6),
                Text(
                  "📊 셀별 출석 현황 (랭킹순)",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
          ),
          ...sorted.map((e) {
            double rate = e.value['total'] > 0
                ? e.value['present'] / e.value['total']
                : 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 35,
                    child: Text(
                      '${e.key}셀',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: rate,
                        color: Colors.teal.withOpacity(0.6),
                        backgroundColor: Colors.white,
                        minHeight: 5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(rate * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
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

  Widget _buildMemberGrid(Map<String, dynamic> records, bool isTeacher) {
    if (isTeacher)
      return _buildNameWrap(
        records.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      );
    var groupA = records.entries.where((e) => e.value['group'] == 'A').toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    var groupB = records.entries.where((e) => e.value['group'] == 'B').toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (groupA.isNotEmpty) ...[_buildNameWrap(groupA)],
        if (groupA.isNotEmpty && groupB.isNotEmpty) const Divider(height: 16),
        if (groupB.isNotEmpty) ...[
          const Text(
            "특별 관리(B)",
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 4),
          _buildNameWrap(groupB),
        ],
      ],
    );
  }

  Widget _buildNameWrap(List<MapEntry<String, dynamic>> entries) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: entries.map((e) {
        bool isP = e.value['status'] == '출석';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isP ? Colors.teal.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            e.key,
            style: TextStyle(
              fontSize: 12,
              color: isP ? Colors.teal.shade800 : Colors.grey.shade400,
              fontWeight: isP ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPastoralSections() {
    String filterLabelPrefix = _viewType == '누적' ? '연간' : '이달의';
    String yearStr = DateFormat('yyyy').format(_selectedDate);
    String monthStr = DateFormat('yyyy-MM').format(_selectedDate);
    String dateFilter = _viewType == '누적' ? yearStr : monthStr;

    var perfectList = _individualStats.values
        .where((m) => m['role'] == '학생' && m['p'] == m['t'] && m['t'] > 0)
        .toList();
    var promotedList = _individualStats.values
        .where(
          (m) =>
              m['role'] == '학생' &&
              (m['promotedAt']?.toString().startsWith(dateFilter) ?? false),
        )
        .toList();
    var firstVisitList = _individualStats.values
        .where(
          (m) =>
              m['role'] == '학생' &&
              (m['firstVisitDate']?.toString().startsWith(dateFilter) ?? false),
        )
        .toList();
    var absentList = _individualStats.values
        .where((m) => m['role'] == '학생' && m['p'] == 0 && m['t'] > 0)
        .toList();
    var freshNewFriends = _individualStats.values
        .where((m) => m['role'] == '학생' && m['dbRole'] == "새친구" && m['t'] > 0)
        .toList();
    var otherBGroup = _individualStats.values
        .where(
          (m) =>
              m['role'] == '학생' &&
              m['group'] == "B" &&
              m['dbRole'] != "새친구" &&
              m['t'] > 0,
        )
        .toList();

    Map<String, List<String>> evangelistMap = {};
    for (var m in firstVisitList) {
      String evName = m['evangelist']?.toString().trim() ?? '';
      if (evName.isNotEmpty && evName != "자진") {
        if (!evangelistMap.containsKey(evName)) evangelistMap[evName] = [];
        evangelistMap[evName]!.add(m['name']);
      }
    }
    var evangelistList = evangelistMap.entries
        .map(
          (e) => {'evangelist': e.key, 'invitedStudents': e.value.join(', ')},
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildNameListSection(
          "$filterLabelPrefix 개근자 🏆",
          perfectList,
          Colors.teal,
        ),
        const SizedBox(height: 16),
        _buildEvangelistSection(
          "📢 $filterLabelPrefix 전도자",
          evangelistList,
          Colors.purple,
        ),
        const SizedBox(height: 16),
        if (firstVisitList.isNotEmpty) ...[
          _buildNameListSection(
            "🎁 $filterLabelPrefix 새친구 방문",
            firstVisitList,
            Colors.orange,
          ),
          const SizedBox(height: 16),
        ],
        if (promotedList.isNotEmpty) ...[
          _buildNameListSection(
            "🎉 $filterLabelPrefix 등반 소식",
            promotedList,
            Colors.indigo,
          ),
          const SizedBox(height: 16),
        ],
        _buildNameListSection("📞 심방 권면 대상", absentList, Colors.red),
        const SizedBox(height: 16),
        _buildSplitNewMemberStatusSection(
          "🌱 새친구 정착 현황",
          freshNewFriends,
          otherBGroup,
        ),
        const SizedBox(height: 40),
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
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: themeColor.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: themeColor.withOpacity(0.08)),
          ),
          child: list.isEmpty
              ? const Text(
                  "대상자 없음",
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                )
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: list
                      .map(
                        (m) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: themeColor.withOpacity(0.1),
                            ),
                          ),
                          child: Text(
                            "${m['name']} (${m['cell']}셀)",
                            style: TextStyle(
                              fontSize: 11,
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

  Widget _buildEvangelistSection(
    String title,
    List<Map<String, dynamic>> list,
    Color themeColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: themeColor.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: themeColor.withOpacity(0.08)),
          ),
          child: list.isEmpty
              ? const Text(
                  "데이터 없음",
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                )
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: list
                      .map(
                        (m) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: themeColor.withOpacity(0.1),
                            ),
                          ),
                          child: Text(
                            "${m['evangelist']} (${m['invitedStudents']})",
                            style: TextStyle(
                              fontSize: 11,
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

  Widget _buildSplitNewMemberStatusSection(
    String title,
    List<Map<String, dynamic>> freshList,
    List<Map<String, dynamic>> otherList,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (freshList.isEmpty && otherList.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    "관리 대상 없음",
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ),
              if (freshList.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.egg_alt_rounded,
                        size: 14,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        "금년 신규 등록 새친구",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "${freshList.length}명",
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ...freshList.map((m) => _buildStatusTile(m)),
              ],
              if (freshList.isNotEmpty && otherList.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Divider(height: 16, thickness: 0.5),
                ),
              if (otherList.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.manage_search_rounded,
                        size: 14,
                        color: Colors.blueGrey,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        "정착 관리 B그룹 (기존 인원)",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "${otherList.length}명",
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.blueGrey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ...otherList.map((m) => _buildStatusTile(m)),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusTile(Map<String, dynamic> m) {
    double progress = (m['t'] ?? 1) > 0 ? m['p'] / m['t'] : 0;
    bool isNew = m['dbRole'] == "새친구";
    Color mainColor = isNew ? Colors.orange : Colors.blueGrey;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      title: Text(
        "${m['name']} (${m['cell']}셀)",
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: mainColor.withOpacity(0.05),
            color: mainColor.withOpacity(0.6),
            minHeight: 4,
          ),
        ),
      ),
      trailing: Text(
        "${m['p']}/${m['t']}주",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: mainColor,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildMonthlyInsights() {
    int perfectAttendanceCount = _individualStats.values
        .where((m) => m['role'] == '학생' && m['p'] == m['t'] && m['t'] > 0)
        .length;
    if (_viewType == '누적') {
      String currentYear = DateFormat('yyyy').format(_selectedDate);
      int totalNew = _individualStats.values
          .where(
            (m) =>
                m['role'] == '학생' &&
                (m['firstVisitDate']?.toString().startsWith(currentYear) ??
                    false),
          )
          .length;
      int promoted = _individualStats.values
          .where(
            (m) =>
                m['role'] == '학생' &&
                (m['promotedAt']?.toString().startsWith(currentYear) ?? false),
          )
          .length;
      double settlementRate = totalNew > 0 ? (promoted / totalNew) * 100 : 0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            _insightCard("개근자", "$perfectAttendanceCount명", Colors.teal),
            const SizedBox(width: 8),
            _insightCard(
              "정착률",
              "${settlementRate.toStringAsFixed(1)}%",
              Colors.indigo,
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          _insightCard("이달의 개근", "$perfectAttendanceCount명", Colors.teal),
          const SizedBox(width: 8),
          _insightCard("최고 출석 셀", "1셀", Colors.orange),
        ],
      ),
    );
  }

  Widget _insightCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
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
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(12, (i) => i + 1).map((m) {
                    bool isCurrent = tempMonth == m;
                    return InkWell(
                      onTap: () =>
                          Navigator.pop(context, DateTime(tempYear, m, 1)),
                      child: Container(
                        width: 45,
                        height: 35,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isCurrent ? Colors.teal : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$m월',
                          style: TextStyle(
                            color: isCurrent ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
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
