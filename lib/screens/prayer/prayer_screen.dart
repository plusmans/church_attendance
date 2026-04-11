import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PrayerScreen extends StatefulWidget {
  final String teacherName;
  final String cell;
  final String role;

  const PrayerScreen({
    super.key,
    required this.teacherName,
    required this.cell,
    required this.role,
  });

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
  List<TextEditingController> _controllers = [TextEditingController()];
  List<TextEditingController> _commonControllers = [];
  final TextEditingController _urgentController = TextEditingController();

  late String _currentMonth;
  bool _isSaving = false;
  bool _isCommonSaving = false;
  bool _isUrgentSaving = false;
  bool _isAdmin = false;

  final String appId = 'church-attendance-cdb07';
  late List<String> _monthOptions;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateFormat('yyyy-MM').format(DateTime.now());

    _isAdmin =
        widget.role == '강도사' ||
        widget.role == '부장' ||
        widget.role == 'admin' ||
        widget.role == '개발자';

    _generateMonthOptions();
    _loadAllData();
  }

  void _generateMonthOptions() {
    _monthOptions = [];
    DateTime start = DateTime(2026, 1);
    DateTime end = DateTime(DateTime.now().year, 12);
    DateTime current = start;
    while (current.isBefore(end.add(const Duration(days: 1)))) {
      _monthOptions.add(DateFormat('yyyy-MM').format(current));
      current = DateTime(current.year, current.month + 1);
    }
    if (!_monthOptions.contains(_currentMonth)) {
      _monthOptions.add(_currentMonth);
      _monthOptions.sort();
    }
  }

  String _cleanText(String text) {
    return text.replaceFirst(RegExp(r'^(\d+[\.\)\s\-]+|[①-⑮]\s*)'), '').trim();
  }

  String _cleanName(String name) {
    return name.replaceAll(RegExp(r'\d+'), '').trim();
  }

  Future<void> _loadAllData() async {
    await Future.wait([_loadMyPrayer(), _loadCommonPrayer()]);
  }

  Future<void> _loadMyPrayer() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('artifacts')
          .doc(appId)
          .collection('public')
          .doc('data')
          .collection('prayer_requests')
          .doc('${_currentMonth}_${widget.teacherName}')
          .get();

      if (mounted) {
        if (doc.exists) {
          final List<dynamic> contentList = doc.get('content') ?? [];
          setState(() {
            _controllers = contentList.isNotEmpty
                ? contentList
                      .map(
                        (text) => TextEditingController(text: text.toString()),
                      )
                      .toList()
                : [TextEditingController()];
          });
        } else {
          setState(() => _controllers = [TextEditingController()]);
        }
      }
    } catch (e) {
      debugPrint("❌ 로드 에러: $e");
    }
  }

  Future<void> _loadCommonPrayer() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('artifacts')
          .doc(appId)
          .collection('public')
          .doc('data')
          .collection('common_prayers')
          .doc(_currentMonth)
          .get();

      if (mounted) {
        if (doc.exists) {
          final List<dynamic> topics = doc.get('topics') ?? [];
          setState(() {
            _commonControllers = topics.isNotEmpty
                ? topics
                      .map(
                        (text) => TextEditingController(text: text.toString()),
                      )
                      .toList()
                : [TextEditingController(text: '내용을 입력해주세요.')];
          });
        } else {
          setState(() {
            _commonControllers = [
              TextEditingController(text: '말씀으로 바로 서는 중등부'),
              TextEditingController(text: '풍성한 열매 맺는 선생님들'),
              TextEditingController(text: '말씀 중심의 아이들'),
            ];
          });
        }
      }
    } catch (e) {
      debugPrint("❌ 로드 에러: $e");
    }
  }

  void _addField() => setState(() => _controllers.add(TextEditingController()));
  void _removeField(int index) {
    if (_controllers.length > 1) {
      setState(() {
        _controllers[index].dispose();
        _controllers.removeAt(index);
      });
    }
  }

  void _addCommonField() =>
      setState(() => _commonControllers.add(TextEditingController()));
  void _removeCommonField(int index) {
    if (_commonControllers.length > 1) {
      setState(() {
        _commonControllers[index].dispose();
        _commonControllers.removeAt(index);
      });
    }
  }

  Future<void> _savePrayer() async {
    final List<String> prayerList = _controllers
        .map((c) => _cleanText(c.text.trim()))
        .where((text) => text.isNotEmpty)
        .toList();
    if (prayerList.isEmpty) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('artifacts')
          .doc(appId)
          .collection('public')
          .doc('data')
          .collection('prayer_requests')
          .doc('${_currentMonth}_${widget.teacherName}')
          .set({
            'teacherName': _cleanName(widget.teacherName),
            'cell': widget.role,
            'month': _currentMonth,
            'content': prayerList,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('🙏 기도제목이 저장되었습니다.')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveCommonPrayer() async {
    final List<String> topicList = _commonControllers
        .map((c) => _cleanText(c.text.trim()))
        .where((text) => text.isNotEmpty)
        .toList();
    setState(() => _isCommonSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('artifacts')
          .doc(appId)
          .collection('public')
          .doc('data')
          .collection('common_prayers')
          .doc(_currentMonth)
          .set({
            'month': _currentMonth,
            'topics': topicList,
            'updatedBy': widget.teacherName,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('📢 공동 기도제목 업데이트 완료.')));
      }
    } finally {
      if (mounted) {
        setState(() => _isCommonSaving = false);
      }
    }
  }

  Future<void> _saveUrgentPrayer() async {
    final text = _urgentController.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() => _isUrgentSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('artifacts')
          .doc(appId)
          .collection('public')
          .doc('data')
          .collection('urgent_prayers')
          .add({
            'month': _currentMonth,
            'content': text,
            'authorName': widget.teacherName,
            'authorRole': widget.role,
            'createdAt': FieldValue.serverTimestamp(),
          });

      _urgentController.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('🚨 긴급 기도 요청이 공유되었습니다.')));
      }
    } finally {
      if (mounted) {
        setState(() => _isUrgentSaving = false);
      }
    }
  }

  Future<void> _deleteUrgentPrayer(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('artifacts')
          .doc(appId)
          .collection('public')
          .doc('data')
          .collection('urgent_prayers')
          .doc(docId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('🗑️ 삭제되었습니다.')));
      }
    } catch (e) {
      debugPrint("❌ 삭제 에러: $e");
    }
  }

  Future<void> _generateAndPrintPdf() async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.notoSansKRRegular();
    final fontBold = await PdfGoogleFonts.notoSansKRBold();

    final prayerSnapshot = await FirebaseFirestore.instance
        .collection('artifacts')
        .doc(appId)
        .collection('public')
        .doc('data')
        .collection('prayer_requests')
        .get();

    final urgentSnapshot = await FirebaseFirestore.instance
        .collection('artifacts')
        .doc(appId)
        .collection('public')
        .doc('data')
        .collection('urgent_prayers')
        .get();

    final allRequests = prayerSnapshot.docs
        .where(
          (doc) => doc.get('month') == _currentMonth,
        )
        .toList();

    final urgentRequests = urgentSnapshot.docs
        .where(
          (doc) => doc.get('month') == _currentMonth,
        )
        .toList();

    allRequests.sort((a, b) {
      final Timestamp? aTime = a.get('updatedAt');
      final Timestamp? bTime = b.get('updatedAt');
      return (bTime ?? Timestamp.now()).compareTo(
        aTime ?? Timestamp.now(),
      );
    });

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(35),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                '$_currentMonth 성문교회 중등부 기도제목',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 22,
                  color: PdfColors.teal,
                ),
              ),
            ),
            pw.SizedBox(height: 15),
            pw.Text(
              '[ 공동 기도제목 ]',
              style: pw.TextStyle(font: fontBold, fontSize: 14),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.teal50,
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: _commonControllers
                    .map(
                      (c) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 4),
                        child: pw.Text(
                          '- ${c.text}',
                          style: pw.TextStyle(font: font, fontSize: 11),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            if (urgentRequests.isNotEmpty) ...[
              pw.SizedBox(height: 25),
              pw.Text(
                '[ 🚨 긴급 기도 요청 ]',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 14,
                  color: PdfColors.red,
                ),
              ),
              pw.Divider(color: PdfColors.red100),
              ...urgentRequests.map((u) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Text(
                    '• ${u.get('content')} (${u.get('authorName')} ${u.get('authorRole')})',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 10,
                      color: PdfColors.red900,
                    ),
                  ),
                );
              }),
            ],
            pw.SizedBox(height: 25),
            pw.Text(
              '[ 선생님별 기도제목 ]',
              style: pw.TextStyle(font: fontBold, fontSize: 14),
            ),
            pw.Divider(thickness: 0.5),
            ...allRequests.asMap().entries.map((entry) {
              final doc = entry.value;
              final idx = entry.key + 1;
              final name = _cleanName(doc.get('teacherName') ?? '교사');
              final roleInfo = doc.get('cell') ?? '-';
              final List<dynamic> contents = doc.get('content') ?? [];

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '$idx. $name ($roleInfo)',
                      style: pw.TextStyle(font: fontBold, fontSize: 12),
                    ),
                    ...contents
                        .asMap()
                        .entries
                        .map(
                          (cEntry) => pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 12, top: 2),
                            child: pw.Text(
                              '- ${cEntry.key + 1}. ${_cleanText(cEntry.value.toString())}',
                              style: pw.TextStyle(
                                font: font,
                                fontSize: 10,
                                lineSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              );
            }),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '성문중등부_기도제목_$_currentMonth.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // ✅ 월 선택 드롭다운 (상단 왼쪽)
                      _buildMonthSelector(),
                      // ✅ PDF 출력 버튼 (상단 오른쪽) 확대
                      TextButton.icon(
                        onPressed: _generateAndPrintPdf,
                        icon: const Icon(
                          Icons.picture_as_pdf,
                          color: Colors.redAccent,
                          size: 18, // ✅ 14 -> 18로 확대
                        ),
                        label: const Text(
                          'PDF 출력',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 14, // ✅ 11 -> 14로 확대
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12, // ✅ 8 -> 12로 확대
                            vertical: 8, // ✅ 4 -> 8로 확대
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: Colors.red.shade100,
                              width: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildCommonArea(),
                  const SizedBox(height: 12),
                  _buildUrgentInputArea(),
                  const SizedBox(height: 12),
                  _buildInputTitle(),
                  ..._buildInputFields(),
                  const SizedBox(height: 8),
                  _buildSaveButton(),
                  const SizedBox(height: 20),
                  const Divider(thickness: 4, color: Color(0xFFF5F5F5)),
                  const SizedBox(height: 12),
                  Text(
                    '✨ $_currentMonth 선생님들의 기도 제목',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildUrgentStreamArea(),
          _buildTotalStreamList(),
        ],
      ),
    );
  }

  Widget _buildUrgentInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notification_important,
                color: Colors.red,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                '🚨 긴급 기도 요청',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.red.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _urgentController,
            maxLines: null,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: '긴급히 함께 기도할 제목을 입력하세요',
              hintStyle: TextStyle(
                color: Colors.red.shade200,
                fontSize: 13,
              ),
              isDense: true,
              border: InputBorder.none,
            ),
          ),
          const Divider(color: Colors.redAccent, thickness: 0.5, height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isUrgentSaving ? null : _saveUrgentPrayer,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(50, 24),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: _isUrgentSaving
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.red,
                      ),
                    )
                  : const Text(
                      '공유하기',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgentStreamArea() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('artifacts')
          .doc(appId)
          .collection('public')
          .doc('data')
          .collection('urgent_prayers')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        final docs = snapshot.data!.docs
            .where(
              (doc) => doc.get('month') == _currentMonth,
            )
            .toList();
        if (docs.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade100.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🚩 최근 긴급 요청',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 6),
                ...docs.map((d) {
                  final bool canDelete =
                      _isAdmin || d.get('authorName') == widget.teacherName;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '• ${d.get('content')} (${d.get('authorName')})',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (canDelete)
                          GestureDetector(
                            onTap: () => _deleteUrgentPrayer(d.id),
                            child: const Icon(
                              Icons.close,
                              color: Colors.redAccent,
                              size: 14,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // ✅ 월 선택 드롭다운 UI 확대
  Widget _buildMonthSelector() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.calendar_month, color: Colors.teal, size: 18), // ✅ 16 -> 18로 확대
        const SizedBox(width: 6),
        Container(
          height: 38, // ✅ 28 -> 38로 대폭 확대
          padding: const EdgeInsets.symmetric(horizontal: 10), // ✅ 6 -> 10으로 확대
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.teal.shade200, width: 1.0), // ✅ 선 두께 및 색상 강조
            color: Colors.white,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _currentMonth,
              icon: const Icon(Icons.arrow_drop_down, size: 24, color: Colors.teal), // ✅ 18 -> 24로 확대
              style: const TextStyle(
                fontSize: 16, // ✅ 12 -> 16으로 대폭 확대
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
              items: _monthOptions
                  .map(
                    (month) => DropdownMenuItem(
                      value: month,
                      child: Text(
                        DateFormat(
                          'yyyy년 MM월',
                        ).format(DateTime.parse('$month-01')),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (String? newValue) {
                if (newValue != null && newValue != _currentMonth) {
                  setState(() => _currentMonth = newValue);
                  _loadAllData();
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommonArea() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: Colors.teal.shade700,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$_currentMonth 공동 기도제목',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade900,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              if (_isAdmin)
                IconButton(
                  icon: const Icon(
                    Icons.add_circle,
                    color: Colors.teal,
                    size: 18,
                  ),
                  onPressed: _addCommonField,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_isAdmin)
            ..._commonControllers.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: entry.value,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 4,
                              ),
                              prefixText: '${entry.key + 1}. ',
                              hintText: '공동 기도제목 입력',
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          onPressed: () => _removeCommonField(entry.key),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                )
          else
            ..._commonControllers.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${entry.key + 1}. ${_cleanText(entry.value.text)}',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.teal.shade800,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
          if (_isAdmin) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 34,
              child: ElevatedButton(
                onPressed: _isCommonSaving ? null : _saveCommonPrayer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: _isCommonSaving
                    ? const SizedBox(
                        height: 12,
                        width: 12,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        '공동 기도제목 업데이트',
                        style: TextStyle(fontSize: 13),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputTitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          '📝 나의 기도제목',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        TextButton.icon(
          onPressed: _addField,
          icon: const Icon(Icons.add_circle_outline, size: 16),
          label: const Text('항목 추가', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(60, 30),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildInputFields() {
    return _controllers.asMap().entries.map((entry) {
      final int idx = entry.key;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: CircleAvatar(
                radius: 10,
                backgroundColor: Colors.teal.shade100,
                child: Text(
                  '${idx + 1}',
                  style: const TextStyle(fontSize: 10, color: Colors.teal),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: entry.value,
                maxLines: null,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: '내용을 입력하세요',
                  border: UnderlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            if (_controllers.length > 1)
              IconButton(
                padding: const EdgeInsets.only(top: 6),
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.grey,
                  size: 18,
                ),
                onPressed: () => _removeField(idx),
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _savePrayer,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: _isSaving
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                '저장 및 공유하기',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
      ),
    );
  }

  Widget _buildTotalStreamList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('artifacts')
          .doc(appId)
          .collection('public')
          .doc('data')
          .collection('prayer_requests')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data!.docs
            .where(
              (doc) => doc.get('month') == _currentMonth,
            )
            .toList();

        docs.sort((a, b) {
          final Timestamp? aTime = a.get('updatedAt');
          final Timestamp? bTime = b.get('updatedAt');
          return (bTime ?? Timestamp.now()).compareTo(
            aTime ?? Timestamp.now(),
          );
        });

        if (docs.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(
                child: Text(
                  "등록된 기도제목이 없습니다.",
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final doc = docs[index];
            final List<dynamic> contents = doc.get('content') ?? [];
            return Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${index + 1}. ${_cleanName(doc.get('teacherName') ?? '교사')}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        (doc.get('cell') ?? '-').toString(),
                        style: TextStyle(
                          color: Colors.teal.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...contents.asMap().entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${e.key + 1}. ${_cleanText(e.value.toString())}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            );
          }, childCount: docs.length),
        );
      },
    );
  }

  @override
  void dispose() {
    _urgentController.dispose();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var c in _commonControllers) {
      c.dispose();
    }
    super.dispose();
  }
}