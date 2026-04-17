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
  final ScrollController _scrollController = ScrollController();
  final ScrollController _trendScrollController = ScrollController();
  
  DateTime _selectedDate = _getRecentSunday();
  String _viewType = '주별';
  String _groupingMode = '셀별';
  String _individualSortMode = '셀순';
  bool _isLoading = false;

  int _studentPresent = 0;   
  int _studentTotal = 0;     
  int _studentGrandTotal = 0; 
  int _teacherPresent = 0;
  int _teacherTotal = 0;

  Map<String, Map<String, dynamic>> _cellStats = {};
  List<Map<String, dynamic>> _summaryList = [];

  final Map<String, double> _cellAverages = {}; 
  Map<String, Map<String, dynamic>> _individualStats = {};

  Map<String, Map<String, int>> _gradeStats = {};
  Map<String, Map<String, int>> _genderStats = {};
  Map<String, int> _absenceReasonCounts = {};

  static DateTime _getRecentSunday() {
    final DateTime now = DateTime.now();
    final int diff = now.weekday % 7;
    return DateTime(now.year, now.month, now.day).subtract(Duration(days: diff));
  }

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _trendScrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _scrollToLatestTrend() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_trendScrollController.hasClients) {
        _trendScrollController.jumpTo(_trendScrollController.position.maxScrollExtent);
      }
    });
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

      final String startStr = DateFormat('yyyy-MM-dd').format(startDate);
      final String endStr = DateFormat('yyyy-MM-dd').format(endDate);

      final snapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('date', isGreaterThanOrEqualTo: startStr)
          .where('date', isLessThanOrEqualTo: endStr)
          .get();

      final studentSnap = await FirebaseFirestore.instance.collection('students').get();
      final teacherSnap = await FirebaseFirestore.instance.collection('teachers').get();
      
      final Map<String, Map<String, dynamic>> studentMaster = {};
      for (var d in studentSnap.docs) {
        studentMaster[_normalizeName(d.data()['name'])] = d.data();
      }

      final Set<String> teacherNames = {};
      for (var d in teacherSnap.docs) {
        teacherNames.add(_normalizeName(d.data()['name']));
      }

      _initStatsMaps();

      if (_viewType == '주별') {
        _processWeeklyData(snapshot, studentMaster, teacherNames, teacherSnap.docs.length);
      } else {
        _processGroupedData(snapshot, studentMaster, teacherNames, teacherSnap.docs.length);
      }
    } catch (e) {
      debugPrint("❌ 통계 처리 에러: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isFutureStudent(String? firstVisitDate, String targetDate) {
    if (firstVisitDate == null || firstVisitDate.isEmpty || firstVisitDate == '미입력') return false;
    try {
      return firstVisitDate.compareTo(targetDate) > 0;
    } catch (e) {
      return false;
    }
  }

  void _processWeeklyData(QuerySnapshot snapshot, Map<String, Map<String, dynamic>> master, Set<String> teacherNames, int teacherCount) {
    final Map<String, Map<String, dynamic>> baseStats = {};
    int sP = 0; 
    int sT = 0; 
    int sGT = 0; 
    int tP = 0;
    final Map<String, Map<String, dynamic>> indv = {};
    final String selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    master.forEach((name, data) {
      if (teacherNames.contains(name)) return;
      if (_isFutureStudent(data['firstVisitDate'], selectedDateStr)) return;
      final String cell = (data['cell'] ?? '0').toString();
      final String group = (data['group'] ?? 'B').toString().trim().toUpperCase();
      final String role = (data['role'] ?? '학생').toString(); 

      if (!baseStats.containsKey(cell)) {
        baseStats[cell] = {'id': cell, 'total': 0, 'present': 0, 'records': <String, dynamic>{}};
      }
      baseStats[cell]!['records'][name] = {'status': '결석', 'group': group, 'grade': data['grade'], 'gender': data['gender'], 'role': role};
      
      sGT++; 
      if (group == 'A') {
        sT++;
        baseStats[cell]!['total'] = (baseStats[cell]!['total'] as int) + 1;
      }
    });

    if (!baseStats.containsKey('교사')) {
      baseStats['교사'] = {'id': '교사', 'total': teacherCount, 'present': 0, 'records': <String, dynamic>{}};
    }
    for (var tName in teacherNames) {
      baseStats['교사']!['records'][tName] = {'status': '결석', 'role': '교사', 'cell': '교사'};
    }

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final Map<String, dynamic> records = Map<String, dynamic>.from(data['records'] ?? {});
      bool isTeacherDoc = doc.id.startsWith('teachers');

      records.forEach((rawName, info) {
        final String n = _normalizeName(rawName);
        final infoMap = Map<String, dynamic>.from(info);
        
        bool isActuallyTeacher = teacherNames.contains(n) || isTeacherDoc;
        String currentRole = isActuallyTeacher ? '교사' : (infoMap['role'] ?? master[n]?['role'] ?? '학생');
        String currentCell = isActuallyTeacher ? '교사' : (infoMap['cell']?.toString() ?? master[n]?['cell']?.toString() ?? '0');

        if (!isActuallyTeacher && _isFutureStudent(master[n]?['firstVisitDate'], selectedDateStr)) return;

        if (isActuallyTeacher) {
          baseStats['교사']!['records'][n] = {...infoMap, 'role': '교사', 'cell': '교사'};
          if (infoMap['status'] == '출석' || infoMap['status'] == '인정') tP++;
        } else {
          final String cellId = doc.id.split('셀')[0];
          if (!baseStats.containsKey(cellId)) baseStats[cellId] = {'id': cellId, 'total': 0, 'present': 0, 'records': <String, dynamic>{}};

          if (!baseStats[cellId]!['records'].containsKey(n)) {
            baseStats[cellId]!['records'][n] = {...infoMap, 'role': currentRole, 'cell': currentCell};
            sGT++; 
            if ((infoMap['group'] ?? 'B').toString().trim().toUpperCase() == 'A') {
              sT++;
              baseStats[cellId]!['total'] = (baseStats[cellId]!['total'] as int) + 1;
            }
          } else {
            final existing = Map<String, dynamic>.from(baseStats[cellId]!['records'][n]);
            baseStats[cellId]!['records'][n] = <String, dynamic>{...existing, ...infoMap, 'role': currentRole, 'cell': currentCell};
          }
        }
      });
    }

    _cellAverages.clear();
    baseStats.forEach((cId, stat) {
      final Map<String, dynamic> records = Map<String, dynamic>.from(stat['records'] ?? {});
      int presentInCell = 0;
      records.forEach((name, info) {
        final infoMap = Map<String, dynamic>.from(info);
        final String n = _normalizeName(name);
        bool isTeacher = teacherNames.contains(n) || infoMap['role'] == '교사' || cId == '교사';
        final String role = isTeacher ? '교사' : (infoMap['role'] ?? '학생');
        final String group = (infoMap['group'] ?? 'B').toString().trim().toUpperCase();
        final String displayCell = isTeacher ? '교사' : cId;
        
        indv[n] = {...infoMap, 'name': name, 'cell': displayCell, 'role': role};

        if (infoMap['status'] == '출석' || infoMap['status'] == '인정') {
          presentInCell++;
          if (role != '교사') {
            sP++;
            final String g = (infoMap['grade'] ?? '1학년').toString();
            final String sex = (infoMap['gender'] ?? '남자').toString();
            if (_gradeStats.containsKey(g)) _gradeStats[g]!['p'] = (_gradeStats[g]!['p'] ?? 0) + 1;
            if (_genderStats.containsKey(sex)) _genderStats[sex]!['p'] = (_genderStats[sex]!['p'] ?? 0) + 1;
          }
        }

        if (role != '교사' && group == 'A') {
          final String g = (infoMap['grade'] ?? '1학년').toString();
          final String sex = (infoMap['gender'] ?? '남자').toString();
          if (_gradeStats.containsKey(g)) _gradeStats[g]!['t'] = (_gradeStats[g]!['t'] ?? 0) + 1;
          if (_genderStats.containsKey(sex)) _genderStats[sex]!['t'] = (_genderStats[sex]!['t'] ?? 0) + 1;
        }

        if (infoMap['status'] != '출석' && infoMap['status'] != '인정' && group == 'A' && role != '교사') {
          _absenceReasonCounts[infoMap['reason'] ?? '연락x'] = (_absenceReasonCounts[infoMap['reason'] ?? '연락x'] ?? 0) + 1;
        }
      });
      stat['present'] = presentInCell;
      _cellAverages[cId] = stat['total'] > 0 ? stat['present'] / stat['total'] : 0.0;
    });

    setState(() {
      _cellStats = Map.fromEntries(baseStats.entries.toList()..sort((a, b) {
        if (a.key == '교사') return 1;
        if (b.key == '교사') return -1;
        return (int.tryParse(a.key) ?? 99).compareTo(int.tryParse(b.key) ?? 99);
      }));
      _studentPresent = sP;
      _studentTotal = sT;
      _studentGrandTotal = sGT;
      _teacherPresent = tP;
      _teacherTotal = teacherCount;
      _individualStats = indv;
    });
  }

  void _processGroupedData(QuerySnapshot snapshot, Map<String, Map<String, dynamic>> master, Set<String> teacherNames, int teacherCount) {
    final Map<String, Map<String, int>> dateSummary = {};
    final Map<String, Map<String, dynamic>> indv = {};
    final Map<String, Map<String, int>> cellGroupStats = {};

    final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    int currentTotalA = 0;
    int currentGrandTotal = 0;

    master.forEach((name, data) {
      if (teacherNames.contains(name)) return;
      if (_isFutureStudent(data['firstVisitDate'], todayStr)) return;
      currentGrandTotal++;
      String group = (data['group'] ?? 'B').toString().trim().toUpperCase();
      if (group == 'A') {
        currentTotalA++;
      }
    });

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final String date = data['date'] ?? '';
      final Map<String, dynamic> records = Map<String, dynamic>.from(data['records'] ?? {});
      if (!dateSummary.containsKey(date)) {
        dateSummary[date] = {'sP': 0, 'sT': 0};
      }

      records.forEach((name, info) {
        final String n = _normalizeName(name);
        final infoMap = Map<String, dynamic>.from(info);
        final bool isP = infoMap['status'] == '출석' || infoMap['status'] == '인정';
        
        bool isActuallyTeacher = teacherNames.contains(n) || doc.id.startsWith('teachers');
        final String role = isActuallyTeacher ? '교사' : (infoMap['role'] ?? master[n]?['role'] ?? '학생');
        final String cell = isActuallyTeacher ? '교사' : (infoMap['cell']?.toString() ?? master[n]?['cell']?.toString() ?? '0');

        if (!isActuallyTeacher && _isFutureStudent(master[n]?['firstVisitDate'], date)) return;

        if (!isActuallyTeacher) {
          final String g = (infoMap['grade'] ?? (master[n]?['grade'] ?? '1학년')).toString();
          final String sex = (infoMap['gender'] ?? (master[n]?['gender'] ?? '남자')).toString();
          final String group = (infoMap['group'] ?? 'B').toString().trim().toUpperCase();

          if (!cellGroupStats.containsKey(cell)) cellGroupStats[cell] = {'p': 0, 't': 0};

          if (isP) {
            dateSummary[date]!['sP'] = (dateSummary[date]!['sP'] ?? 0) + 1;
            cellGroupStats[cell]!['p'] = cellGroupStats[cell]!['p']! + 1;
            if (_gradeStats.containsKey(g)) _gradeStats[g]!['p'] = (_gradeStats[g]!['p'] ?? 0) + 1;
            if (_genderStats.containsKey(sex)) _genderStats[sex]!['p'] = (_genderStats[sex]!['p'] ?? 0) + 1;
          } else if (group == 'A') {
             _absenceReasonCounts[infoMap['reason'] ?? '연락x'] = (_absenceReasonCounts[infoMap['reason'] ?? '연락x'] ?? 0) + 1;
          }
          
          if (group == 'A') {
            dateSummary[date]!['sT'] = (dateSummary[date]!['sT'] ?? 0) + 1;
            cellGroupStats[cell]!['t'] = cellGroupStats[cell]!['t']! + 1;
            if (_gradeStats.containsKey(g)) _gradeStats[g]!['t'] = (_gradeStats[g]!['t'] ?? 0) + 1;
            if (_genderStats.containsKey(sex)) _genderStats[sex]!['t'] = (_genderStats[sex]!['t'] ?? 0) + 1;
          }
        } else if (isP) {
          dateSummary[date]!['tP'] = (dateSummary[date]!['tP'] ?? 0) + 1;
        }

        if (!indv.containsKey(n)) {
          indv[n] = {'name': name, 'p': 0, 't': 0, 'role': role, 'cell': cell, ...infoMap};
        }
        indv[n]!['p'] = (indv[n]!['p'] ?? 0) + (isP ? 1 : 0);
        indv[n]!['t'] = (indv[n]!['t'] ?? 0) + 1;
        indv[n]!['role'] = role;
        indv[n]!['cell'] = cell;
        
        if (infoMap.containsKey('firstVisitDate')) indv[n]!['firstVisitDate'] = infoMap['firstVisitDate'];
        if (infoMap.containsKey('promotedAt')) indv[n]!['promotedAt'] = infoMap['promotedAt'];
        if (infoMap.containsKey('evangelist')) indv[n]!['evangelist'] = infoMap['evangelist']; 
      });
    }

    _summaryList = dateSummary.entries.map((e) => {'date': e.key, ...e.value}).toList()
      ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

    _cellAverages.clear();
    cellGroupStats.forEach((cId, stat) {
      if (stat['t']! > 0) {
        _cellAverages[cId] = stat['p']! / stat['t']!;
      } else {
        _cellAverages[cId] = 0.0;
      }
    });

    final double dayCount = _summaryList.length.toDouble();
    if (dayCount > 0) {
      _gradeStats.forEach((k, v) { 
        v['p'] = (v['p']! / dayCount).round(); 
        v['t'] = (v['t']! / dayCount).round(); 
      });
      _genderStats.forEach((k, v) { 
        v['p'] = (v['p']! / dayCount).round(); 
        v['t'] = (v['t']! / dayCount).round(); 
      });
    }

    setState(() {
      _individualStats = indv;
      _studentTotal = currentTotalA;
      _studentGrandTotal = currentGrandTotal;
      _studentPresent = _summaryList.isEmpty ? 0 : (_summaryList.map((e) => e['sP'] as int).reduce((a, b) => a + b) / _summaryList.length).round();
      _teacherTotal = teacherCount;
      _teacherPresent = _summaryList.isEmpty ? 0 : (_summaryList.map((e) => e['tP'] as int).reduce((a, b) => a + b) / _summaryList.length).round();
    });

    _scrollToLatestTrend();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : ListView(
              controller: _scrollController,
              padding: EdgeInsets.zero,
              children: [
                _buildSummaryHeader(),
                _buildViewToggle(),
                _buildGroupingToggle(),
                if (_groupingMode == '개인별') 
                  _buildIndividualList()
                else if (_viewType == '주별') 
                  _buildWeeklyDetailList() 
                else 
                  _buildDashboard(),
                
                _buildScrollToTopButton(),
                const SizedBox(height: 40), 
              ],
            ),
    );
  }

  Widget _buildScrollToTopButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Center(
        child: TextButton.icon(
          onPressed: _scrollToTop,
          icon: const Icon(Icons.arrow_upward_rounded, size: 20, color: Colors.teal),
          label: const Text(
            "맨 위로 이동",
            style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            backgroundColor: Colors.teal.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    final double sRate = _studentTotal > 0 ? (_studentPresent / _studentTotal) * 100 : 0;
    final double tRate = _teacherTotal > 0 ? (_teacherPresent / _teacherTotal) * 100 : 0;
    final String titleText = _viewType == '주별' ? DateFormat('yyyy. MM. dd').format(_selectedDate) : _viewType == '월별' ? DateFormat('yyyy년 MM월').format(_selectedDate) : "${_selectedDate.year}년 연간 누적";
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), 
      child: Column(
        children: [
          InkWell(
            onTap: _viewType == '누적' ? null : _selectDate, 
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center, 
              children: [
                Text(titleText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)), 
                if (_viewType != '누적') const Icon(Icons.arrow_drop_down, color: Colors.teal, size: 24)
              ]
            )
          ), 
          const SizedBox(height: 12), 
          Row(
            children: [
              _buildSummaryCard("학생 (재적/총원)", _studentPresent, _studentTotal, sRate, Colors.blue, grandTot: _studentGrandTotal), 
              const SizedBox(width: 8), 
              _buildSummaryCard("교사", _teacherPresent, _teacherTotal, tRate, Colors.orange)
            ]
          )
        ]
      )
    );
  }

  Widget _buildSummaryCard(String t, int p, int tot, double r, Color c, {int? grandTot}) { 
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12), 
        decoration: BoxDecoration(color: c.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withValues(alpha: 0.1))), 
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, 
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Text(t, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 11)), 
                Text(grandTot != null ? "$p / $tot ($grandTot명)" : "$p / $tot명", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))
              ]
            ), 
            Text("${r.toInt()}%", style: TextStyle(color: c, fontSize: 15, fontWeight: FontWeight.bold))
          ]
        )
      )
    ); 
  }

  Widget _buildViewToggle() { 
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), 
      child: Container(
        height: 40, 
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)), 
        child: Row(
          children: ['주별', '월별', '누적'].map((type) { 
            bool isS = _viewType == type; 
            return Expanded(
              child: GestureDetector(
                onTap: () { 
                  setState(() { 
                    _viewType = type; 
                    if (type == '주별') {
                      _selectedDate = _getRecentSunday();
                    }
                    _fetchStats(); 
                  }); 
                }, 
                child: Container(
                  alignment: Alignment.center, 
                  decoration: BoxDecoration(color: isS ? Colors.teal : Colors.transparent, borderRadius: BorderRadius.circular(10)), 
                  child: Text(type, style: TextStyle(color: isS ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 14))
                )
              )
            ); 
          }).toList()
        )
      )
    ); 
  }

  Widget _buildGroupingToggle() { 
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6), 
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, 
        children: [
          Row(
            children: [
              _toggleButton('셀별', _groupingMode == '셀별', () => setState(() => _groupingMode = '셀별')), 
              const SizedBox(width: 8), 
              _toggleButton('개인별', _groupingMode == '개인별', () => setState(() => _groupingMode = '개인별'))
            ]
          ), 
          if (_groupingMode == '개인별') InkWell(
            onTap: () => setState(() => _individualSortMode = _individualSortMode == '셀순' ? '랭킹순' : '셀순'), 
            child: Row(
              children: [
                Text(_individualSortMode, style: const TextStyle(fontSize: 13, color: Colors.blueGrey, fontWeight: FontWeight.bold)), 
                const Icon(Icons.sort, size: 16)
              ]
            )
          )
        ]
      )
    ); 
  }

  Widget _toggleButton(String l, bool s, VoidCallback t) { 
    return GestureDetector(
      onTap: t, 
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7), 
        decoration: BoxDecoration(color: s ? Colors.blueGrey : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: s ? Colors.blueGrey : Colors.grey.shade300)), 
        child: Text(l, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: s ? Colors.white : Colors.grey.shade600))
      )
    ); 
  }

  Widget _buildDashboard() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              if (_viewType == '월별' || _viewType == '누적') _buildMonthlyInsights(),
              _buildDemographicStats(), const SizedBox(height: 20),
              _buildAbsenceReasonRanking(), const SizedBox(height: 20),
              _buildTrendChart(), const SizedBox(height: 20),
              _buildRankingArea(_viewType == '누적' ? '연간 출석률 순위 🏆' : '반별 출석률 🏆', Colors.orange),
              const SizedBox(height: 20),
              _buildPastoralSections(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDemographicStats() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.only(left: 4, bottom: 10), child: Text("학년 및 성별 출석 현황 📊", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
      Row(children: [_buildDemographicCard("학년별", _gradeStats, Colors.blue), const SizedBox(width: 10), _buildDemographicCard("성별", _genderStats, Colors.pink)]),
    ]);
  }

  Widget _buildDemographicCard(String title, Map<String, Map<String, int>> stats, Color color) {
    return Expanded(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.1))),
      child: Column(children: stats.entries.map((e) {
        final double r = e.value['t']! > 0 ? e.value['p']! / e.value['t']! : 0;
        return Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), Text("${(r * 100).toInt()}% (${e.value['p']}/${e.value['t']})", style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 4), ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: r.clamp(0.0, 1.0), backgroundColor: color.withValues(alpha: 0.1), color: color.withValues(alpha: 0.4), minHeight: 4)),
        ]));
      }).toList()),
    ));
  }

  Widget _buildAbsenceReasonRanking() {
    final sortedReasons = _absenceReasonCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sortedReasons.take(5).toList();
    final int tot = _absenceReasonCounts.values.fold(0, (s, c) => s + c);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.only(left: 4, bottom: 10), child: Text("결석 사유 분석 Top 5 🔍", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.02), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withValues(alpha: 0.05))),
        child: tot == 0 ? const Center(child: Text("데이터 없음", style: TextStyle(fontSize: 13, color: Colors.grey))) : Column(children: top5.asMap().entries.map((e) {
          final double p = e.value.value / tot;
          return Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
            SizedBox(width: 20, child: Text("${e.key + 1}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.redAccent))),
            Expanded(child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(e.value.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)), Text("${e.value.value}명", style: const TextStyle(fontSize: 12, color: Colors.blueGrey))]),
              const SizedBox(height: 3), ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: p.clamp(0.0, 1.0), color: Colors.redAccent.withValues(alpha: 0.4), backgroundColor: Colors.redAccent.withValues(alpha: 0.05), minHeight: 4)),
            ])),
          ]));
        }).toList()),
      ),
    ]);
  }

  Widget _buildTrendChart() {
    final sortedTrend = List.from(_summaryList).reversed.toList();
    return Container(
      padding: const EdgeInsets.all(14), 
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withValues(alpha: 0.05))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('출석률 추이', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blue)),
        const SizedBox(height: 16),
        SingleChildScrollView(
          controller: _trendScrollController,
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start, 
            crossAxisAlignment: CrossAxisAlignment.end, 
            children: sortedTrend.map((i) {
              final double r = (i['sP'] ?? 0) > 0 ? (i['sP'] / (i['sT'] ?? 1)) : 0;
              return Container(
                width: 50, 
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end, 
                  children: [
                    Text('${(r * 100).toInt()}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                    const SizedBox(height: 4),
                    Container(
                      width: 18, 
                      height: (r.clamp(0.0, 1.2) * 60) + 4, 
                      decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4))
                    ),
                    const SizedBox(height: 6),
                    Text((i['date'] as String).substring(5).replaceAll('-', '/'), style: const TextStyle(fontSize: 9, color: Colors.grey)),
                  ]
                ),
              );
            }).toList()
          ),
        ),
      ]),
    );
  }

  Widget _buildRankingArea(String title, Color mainColor) {
    final sortedCells = _cellAverages.entries.where((e) => e.key != '교사').toList()..sort((a, b) => b.value.compareTo(a.value));
    return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: mainColor.withValues(alpha: 0.1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: mainColor, fontSize: 17)),
        const SizedBox(height: 12),
        ...sortedCells.asMap().entries.map((entry) {
          final int rnk = entry.key + 1;
          final v = entry.value;
          return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
            CircleAvatar(radius: 11, backgroundColor: rnk == 1 ? Colors.amber : Colors.grey.shade100, child: Text('$rnk', style: TextStyle(fontSize: 11, color: rnk == 1 ? Colors.white : Colors.grey))),
            const SizedBox(width: 10), Text('${v.key}셀', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(), Text('${(v.value * 100).toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, color: mainColor, fontSize: 14)),
            const SizedBox(width: 10), SizedBox(width: 60, child: LinearProgressIndicator(value: v.value.clamp(0.0, 1.0), color: mainColor.withValues(alpha: 0.6), backgroundColor: mainColor.withValues(alpha: 0.05), minHeight: 4)),
          ]));
        }),
      ]),
    );
  }

  Widget _buildIndividualList() {
    final studentList = _individualStats.values.where((m) => m['role'] != '교사').toList();
    if (_individualSortMode == '랭킹순') {
      studentList.sort((a, b) => (((b['p'] ?? 0) as num) / ((b['t'] ?? 1) as num)).compareTo(((a['p'] ?? 0) as num) / ((a['t'] ?? 1) as num)));
    } else {
      studentList.sort((a, b) => (int.tryParse(a['cell'] ?? '99') ?? 99).compareTo(int.tryParse(b['cell'] ?? '99') ?? 99));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(10), 
      itemCount: studentList.length, 
      shrinkWrap: true, 
      physics: const NeverScrollableScrollPhysics(), 
      itemBuilder: (c, i) {
        final m = studentList[i];
        final double r = (m['t'] ?? 0) > 0 ? (m['p'] / m['t']) : 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 6), 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), 
          child: ListTile(
            dense: true, 
            visualDensity: const VisualDensity(horizontal: 0, vertical: 0), 
            leading: Row(
              mainAxisSize: MainAxisSize.min, 
              children: [
                SizedBox(width: 30, child: Text('${i + 1}', style: TextStyle(fontSize: 12, color: Colors.grey.shade400))), 
                CircleAvatar(radius: 16, child: Text(m['name'][0], style: const TextStyle(fontSize: 12)))
              ]
            ), 
            title: Text(m['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), 
            subtitle: Text("${m['cell']}셀 | ${m['group']}그룹", style: const TextStyle(fontSize: 13)), 
            trailing: Text("${(r * 100).toInt()}% (${m['p']}/${m['t']}회)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: r >= 0.8 ? Colors.teal : Colors.orange))
          )
        );
      }
    );
  }

  Widget _buildWeeklyDetailList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _buildDemographicStats(), const SizedBox(height: 16),
              _buildAbsenceReasonRanking(), const SizedBox(height: 16),
              _buildDashboardArea(),
            ],
          ),
        ),
        ..._cellStats.entries.map((e) {
          final bool isT = e.key == '교사';
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ExpansionTile(
              dense: true, 
              initiallyExpanded: true, 
              shape: const RoundedRectangleBorder(side: BorderSide.none),
              title: Text(isT ? '👨‍🏫 교사 전체' : '${e.key}셀', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)), 
              trailing: Text('${e.value['present']} / ${e.value['total']}명', style: TextStyle(color: isT ? Colors.orange : Colors.teal, fontWeight: FontWeight.bold, fontSize: 14)), 
              children: [Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: _buildMemberGrid(Map<String, dynamic>.from(e.value['records']), isT))]
            ),
          );
        }),
      ],
    );
  }

  // ✅ [수정] '출석'과 '인정' 상태에 따른 색상 구분 처리
  // Error 해결: themeColor를 MaterialColor로 변경
  Widget _buildMemberGrid(Map<String, dynamic> r, bool isT) {
    final entries = r.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    
    Widget buildChip(String name, String status, MaterialColor themeColor) {
      Color bgColor;
      Color textColor;
      if (status == '출석') {
        bgColor = themeColor.withValues(alpha: 0.05);
        textColor = themeColor.shade800; // ✅ 이제 에러가 발생하지 않습니다.
      } else if (status == '인정') {
        // ✅ 인정 상태는 무조건 파란색(Blue)으로 표시
        bgColor = Colors.blue.withValues(alpha: 0.05);
        textColor = Colors.blue.shade800;
      } else {
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade400;
      }
      
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
        child: Text(
          name, 
          style: TextStyle(
            fontSize: 16, 
            color: textColor, 
            fontWeight: (status == '출석' || status == '인정') ? FontWeight.bold : FontWeight.normal
          )
        ),
      );
    }

    if (isT) {
      return Wrap(
        spacing: 8, runSpacing: 8, 
        children: entries.map((i) => buildChip(i.key, i.value['status'] ?? '결석', Colors.orange)).toList(),
      );
    }
    
    final gA = entries.where((i) => (i.value['group'] ?? 'A') == 'A').toList();
    final gB = entries.where((i) => (i.value['group'] ?? 'A') == 'B').toList();
    
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (gA.isNotEmpty) Wrap(
        spacing: 8, runSpacing: 8, 
        children: gA.map((i) => buildChip(i.key, i.value['status'] ?? '결석', Colors.teal)).toList(),
      ),
      if (gB.isNotEmpty) ...[
        const SizedBox(height: 16), 
        const Text("특별 관리(B)", style: TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.bold)), 
        const SizedBox(height: 8), 
        Wrap(
          spacing: 8, runSpacing: 8, 
          children: gB.map((i) => buildChip(i.key, i.value['status'] ?? '결석', Colors.orange)).toList(),
        )
      ],
    ]);
  }

  Widget _buildPastoralSections() {
    final String dateFilter = _viewType == '누적' ? DateFormat('yyyy').format(_selectedDate) : DateFormat('yyyy-MM').format(_selectedDate);
    
    final perfectStudents = _individualStats.values.where((m) => m['role'] != '교사' && m['p'] == m['t'] && m['t'] > 0).toList();
    perfectStudents.sort((a, b) {
      int cellA = int.tryParse(a['cell']?.toString() ?? '99') ?? 99;
      int cellB = int.tryParse(b['cell']?.toString() ?? '99') ?? 99;
      return cellA.compareTo(cellB);
    });

    final perfectTeachers = _individualStats.values.where((m) => m['role'] == '교사' && m['p'] == m['t'] && m['t'] > 0).toList();
    perfectTeachers.sort((a, b) => (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? ''));
    
    final first = _individualStats.values.where((m) => m['role'] != '교사' && (m['firstVisitDate']?.toString().startsWith(dateFilter) ?? false)).toList();
    final promoted = _individualStats.values.where((m) => m['role'] != '교사' && (m['promotedAt']?.toString().startsWith(dateFilter) ?? false)).toList();
    final absent = _individualStats.values.where((m) => m['role'] != '교사' && (m['p'] ?? 0) == 0 && (m['t'] ?? 0) > 0).toList();

    final evangelismRecords = _individualStats.values.where((m) => 
      m['role'] != '교사' && 
      (m['firstVisitDate']?.toString().startsWith(dateFilter) ?? false) && 
      (m['evangelist']?.toString().isNotEmpty ?? false)
    ).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, 
      children: [
        _buildPerfectAttendanceGroup(perfectStudents, perfectTeachers), 
        const SizedBox(height: 20), 
        _buildNameListSection("새친구 방문 🎁", first, Colors.orange), 
        const SizedBox(height: 20), 
        _buildEvangelismSection(evangelismRecords), 
        const SizedBox(height: 20), 
        _buildNameListSection("등반 소식 🎉", promoted, Colors.indigo), 
        const SizedBox(height: 20), 
        _buildNameListSection("심방 권면 대상 📞", absent, Colors.red)
      ]
    );
  }

  Widget _buildEvangelismSection(List<Map<String, dynamic>> l) {
    const Color c = Colors.deepPurple;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.only(left: 4, bottom: 8), child: Text("전도 소식 📢", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))), 
      Container(
        width: double.infinity, 
        padding: const EdgeInsets.all(12), 
        decoration: BoxDecoration(color: c.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withValues(alpha: 0.08))), 
        child: l.isEmpty ? const Text("대상자 없음", style: TextStyle(color: Colors.grey, fontSize: 13)) : Wrap(
          spacing: 8, runSpacing: 8, 
          children: l.map((m) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), 
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: c.withValues(alpha: 0.1))), 
            child: Text("${m['evangelist']} : ${m['name']} (새친구)", style: const TextStyle(fontSize: 13, color: c, fontWeight: FontWeight.bold))
          )).toList()
        )
      )
    ]);
  }

  Widget _buildPerfectAttendanceGroup(List<Map<String, dynamic>> students, List<Map<String, dynamic>> teachers) {
    const Color c = Colors.teal;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.only(left: 4, bottom: 8), child: Text("개근자 🏆", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))), 
      Container(
        width: double.infinity, 
        padding: const EdgeInsets.all(12), 
        decoration: BoxDecoration(color: c.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withValues(alpha: 0.08))), 
        child: (students.isEmpty && teachers.isEmpty) 
          ? const Text("대상자 없음", style: TextStyle(color: Colors.grey, fontSize: 13)) 
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (students.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: students.map((m) => _buildNameChip(m, c)).toList()),
                if (students.isNotEmpty && teachers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(child: Divider(color: c.withValues(alpha: 0.2), thickness: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(Icons.star_rounded, color: c.withValues(alpha: 0.3), size: 14),
                        ),
                        Expanded(child: Divider(color: c.withValues(alpha: 0.2), thickness: 1)),
                      ],
                    ),
                  ),
                if (teachers.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: teachers.map((m) => _buildNameChip(m, c)).toList()),
              ],
            ),
      )
    ]);
  }

  Widget _buildNameChip(Map<String, dynamic> m, Color c) {
    bool isTeacher = m['role'] == '교사';
    String cellValue = (m['cell'] ?? '0').toString();
    String info = isTeacher ? '교사' : (cellValue == 'null' ? '0셀' : '$cellValue셀');
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), 
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: c.withValues(alpha: 0.1))), 
      child: Text("${m['name']} ($info)", style: TextStyle(fontSize: 13, color: c.withValues(alpha: 0.8), fontWeight: FontWeight.bold))
    );
  }

  Widget _buildNameListSection(String t, List<Map<String, dynamic>> l, Color c) { 
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))), 
      Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withValues(alpha: 0.08))), child: l.isEmpty ? const Text("대상자 없음", style: TextStyle(color: Colors.grey, fontSize: 13)) : Wrap(spacing: 8, runSpacing: 8, children: l.map((m) => _buildNameChip(m, c)).toList()))
    ]); 
  }

  Widget _buildDashboardArea() {
    final sortedDashboard = _cellStats.entries.where((e) => e.key != '교사').toList()..sort((a, b) => (b.value['present'] / (b.value['total'] > 0 ? b.value['total'] : 1)).compareTo(a.value['present'] / (a.value['total'] > 0 ? a.value['total'] : 1)));
    return Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.only(bottom: 10), child: Row(children: [Icon(Icons.auto_graph, size: 16, color: Colors.teal), SizedBox(width: 8), Text("📊 셀별 출석 현황 (랭킹순)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal))])),
        ...sortedDashboard.map((e) {
          final double rate = e.value['total'] > 0 ? e.value['present'] / e.value['total'] : 0;
          return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
            SizedBox(width: 45, child: Text('${e.key}셀', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: rate.clamp(0.0, 1.0), color: Colors.teal.withValues(alpha: 0.6), backgroundColor: Colors.white, minHeight: 7))),
            const SizedBox(width: 10), Text('${(rate * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
          ]));
        }),
      ]),
    );
  }

  Widget _buildMonthlyInsights() {
    final int studentPerfectCount = _individualStats.values.where((m) => m['role'] != '교사' && m['p'] == m['t'] && m['t'] > 0).length;
    final int teacherPerfectCount = _individualStats.values.where((m) => m['role'] == '교사' && m['p'] == m['t'] && m['t'] > 0).length;
    
    final String period = _viewType == '누적' ? DateFormat('yyyy').format(_selectedDate) : DateFormat('yyyy-MM').format(_selectedDate);
    final int newFriendsCount = _individualStats.values.where((m) => 
      m['role'] != '교사' && (m['firstVisitDate']?.toString().startsWith(period) ?? false)
    ).length;

    String bestCell = "없음";
    double maxR = -1.0;
    _cellAverages.forEach((c, r) {
      if (c != '교사' && r > maxR) {
        maxR = r;
        bestCell = "$c셀";
      }
    });

    return Padding(
      padding: const EdgeInsets.only(bottom: 16), 
      child: Column(
        children: [
          Row(children: [
            Expanded(child: _insightCard("학생 개근", "$studentPerfectCount명", Colors.blue)), 
            const SizedBox(width: 10), 
            Expanded(child: _insightCard("교사 개근", "$teacherPerfectCount명", Colors.orange)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _insightCard("새친구 방문", "$newFriendsCount명", Colors.deepPurple)),
            const SizedBox(width: 10),
            Expanded(
              child: _viewType == '누적'
                ? Builder(builder: (context) {
                    final String year = DateFormat('yyyy').format(_selectedDate);
                    final int totalNew = _individualStats.values.where((m) => m['role'] != '교사' && (m['firstVisitDate']?.toString().startsWith(year) ?? false)).length;
                    final int promoted = _individualStats.values.where((m) => m['role'] != '교사' && (m['promotedAt']?.toString().startsWith(year) ?? false)).length;
                    final double rate = totalNew > 0 ? (promoted / totalNew) * 100 : 0;
                    return _insightCard("연간 정착률", "${rate.toStringAsFixed(1)}%", Colors.indigo);
                  })
                : _insightCard("최고 출석 셀", bestCell, Colors.teal),
            ),
          ]),
        ],
      )
    );
  }

  Widget _insightCard(String l, String v, Color c) { 
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14), 
      decoration: BoxDecoration(color: c.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withValues(alpha: 0.2))), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Text(l, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c)), 
          const SizedBox(height: 4),
          Text(v, style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: c))
        ]
      )
    ); 
  }

  Future<void> _selectDate() async {
    if (_viewType == '월별') {
      int ty = _selectedDate.year;
      int tm = _selectedDate.month;
      final pd = await showDialog<DateTime>(context: context, builder: (c) => AlertDialog(title: const Text('조회 월 선택', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), content: SizedBox(width: double.maxFinite, child: Column(mainAxisSize: MainAxisSize.min, children: [DropdownButton<int>(value: ty, isExpanded: true, items: List.generate(5, (i) => 2024 + i).map((y) => DropdownMenuItem(value: y, child: Text('$y년'))).toList(), onChanged: (y) => ty = y!), const SizedBox(height: 12), Wrap(spacing: 10, runSpacing: 10, children: List.generate(12, (i) => i + 1).map((m) { bool isCurrent = tm == m; return InkWell(onTap: () => Navigator.pop(context, DateTime(ty, m, 1)), child: Container(width: 50, height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: isCurrent ? Colors.teal : Colors.grey.shade100, borderRadius: BorderRadius.circular(8)), child: Text('$m월', style: TextStyle(color: isCurrent ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)))); }).toList())])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))]));
      if (pd != null) { setState(() { _selectedDate = pd; _fetchStats(); }); }
    } else {
      final DateTime? pd = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2024, 1, 1), lastDate: DateTime.now(), locale: const Locale('ko', 'KR'), selectableDayPredicate: (d) => d.weekday == DateTime.sunday);
      if (pd != null) { setState(() { _selectedDate = pd; _fetchStats(); }); }
    }
  }
}