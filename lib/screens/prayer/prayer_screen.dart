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
    _isAdmin = widget.role == '강도사' || widget.role == '부장';
    
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
    await Future.wait([
      _loadMyPrayer(),
      _loadCommonPrayer(),
    ]);
  }

  Future<void> _loadMyPrayer() async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('artifacts')
          .doc(appId)
          .collection('public')
          .doc('data')
          .collection('prayer_requests')
          .doc('${_currentMonth}_${widget.teacherName}')
          .get();

      if (mounted) {
        if (doc.exists) {
          List<dynamic> contentList = doc.data()?['content'] ?? [];
          setState(() {
            _controllers = contentList.isNotEmpty
                ? contentList.map((text) => TextEditingController(text: text.toString())).toList()
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
      var doc = await FirebaseFirestore.instance
          .collection('artifacts')
          .doc(appId)
          .collection('public')
          .doc('data')
          .collection('common_prayers')
          .doc(_currentMonth)
          .get();

      if (mounted) {
        if (doc.exists) {
          List<dynamic> topics = doc.data()?['topics'] ?? [];
          setState(() {
            _commonControllers = topics.isNotEmpty
                ? topics.map((text) => TextEditingController(text: text.toString())).toList()
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

  void _addCommonField() => setState(() => _commonControllers.add(TextEditingController()));
  void _removeCommonField(int index) {
    if (_commonControllers.length > 1) {
      setState(() {
        _commonControllers[index].dispose();
        _commonControllers.removeAt(index);
      });
    }
  }

  Future<void> _savePrayer() async {
    List<String> prayerList = _controllers.map((c) => _cleanText(c.text.trim())).where((text) => text.isNotEmpty).toList();
    if (prayerList.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('artifacts').doc(appId).collection('public').doc('data').collection('prayer_requests').doc('${_currentMonth}_${widget.teacherName}').set({
        'teacherName': _cleanName(widget.teacherName), 
        'cell': widget.role, 
        'month': _currentMonth,
        'content': prayerList, 
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🙏 기도제목이 저장되었습니다.')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveCommonPrayer() async {
    List<String> topicList = _commonControllers.map((c) => _cleanText(c.text.trim())).where((text) => text.isNotEmpty).toList();
    setState(() => _isCommonSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('artifacts')
          .doc(appId)
          .collection('public')
          .doc('data')
          .collection('common_prayers')
          .doc(_currentMonth)
          .set({'month': _currentMonth, 'topics': topicList, 'updatedBy': widget.teacherName, 'updatedAt': FieldValue.serverTimestamp()});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📢 공동 기도제목 업데이트 완료.')));
    } finally {
      if (mounted) setState(() => _isCommonSaving = false);
    }
  }

  Future<void> _saveUrgentPrayer() async {
    final text = _urgentController.text.trim();
    if (text.isEmpty) return;

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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🚨 긴급 기도 요청이 공유되었습니다.')));
    } finally {
      if (mounted) setState(() => _isUrgentSaving = false);
    }
  }

  // 💡 [추가] 긴급 기도 요청 삭제 기능
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🗑️ 삭제되었습니다.')));
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
        .where((doc) => (doc.data() as Map<String, dynamic>)['month'] == _currentMonth)
        .toList();
    
    final urgentRequests = urgentSnapshot.docs
        .where((doc) => (doc.data() as Map<String, dynamic>)['month'] == _currentMonth)
        .toList();
    
    allRequests.sort((a, b) {
      var aData = a.data() as Map<String, dynamic>;
      var bData = b.data() as Map<String, dynamic>;
      return (bData['updatedAt'] ?? Timestamp.now()).compareTo(aData['updatedAt'] ?? Timestamp.now());
    });

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(35),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text('$_currentMonth 성문교회 중등부 기도제목', 
                  style: pw.TextStyle(font: fontBold, fontSize: 22, color: PdfColors.teal)),
            ),
            pw.SizedBox(height: 15),
            pw.Text('[ 공동 기도제목 ]', style: pw.TextStyle(font: fontBold, fontSize: 14)),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(color: PdfColors.teal50, borderRadius: pw.BorderRadius.circular(5)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: _commonControllers.map((c) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text('- ${c.text}', style: pw.TextStyle(font: font, fontSize: 11))
                )).toList(),
              ),
            ),
            if (urgentRequests.isNotEmpty) ...[
              pw.SizedBox(height: 25),
              pw.Text('[ 🚨 긴급 기도 요청 ]', style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.red)),
              pw.Divider(color: PdfColors.red100),
              ...urgentRequests.map((u) {
                final d = u.data() as Map<String, dynamic>;
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Text('• ${d['content']} (${d['authorName']} ${d['authorRole']})', 
                      style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.red900)),
                );
              }).toList(),
            ],
            pw.SizedBox(height: 25),
            pw.Text('[ 선생님별 기도제목 ]', style: pw.TextStyle(font: fontBold, fontSize: 14)),
            pw.Divider(thickness: 0.5),
            ...allRequests.asMap().entries.map((entry) {
              final data = entry.value.data() as Map<String, dynamic>;
              final idx = entry.key + 1;
              final name = _cleanName(data['teacherName'] ?? '교사');
              final roleInfo = data['cell'] ?? '-';
              final contents = data['content'] as List<dynamic>;

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('$idx. $name ($roleInfo)', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                    ...contents.asMap().entries.map((cEntry) => pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 12, top: 2),
                      child: pw.Text('- ${cEntry.key + 1}. ${_cleanText(cEntry.value.toString())}', 
                          style: pw.TextStyle(font: font, fontSize: 10, lineSpacing: 1.2)),
                    )).toList(),
                  ],
                ),
              );
            }).toList(),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: '성문중등부_기도제목_$_currentMonth.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMonthSelector(),
                      IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent), tooltip: 'PDF로 내보내기', onPressed: _generateAndPrintPdf),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildCommonArea(),
                  const SizedBox(height: 24),
                  _buildUrgentInputArea(),
                  const SizedBox(height: 24),
                  _buildInputTitle(),
                  ..._buildInputFields(),
                  const SizedBox(height: 12),
                  _buildSaveButton(),
                  const SizedBox(height: 30),
                  const Divider(thickness: 8, color: Color(0xFFF5F5F5)),
                  const SizedBox(height: 20),
                  Text('✨ $_currentMonth 선생님들의 기도 제목', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notification_important, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Text('🚨 긴급 기도 요청 (누구나 작성 가능)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900)),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _urgentController,
            maxLines: null,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: '환우 소식 등 긴급히 함께 기도할 제목을 입력하세요',
              hintStyle: TextStyle(color: Colors.red.shade200),
              isDense: true,
              border: InputBorder.none,
            ),
          ),
          const Divider(color: Colors.redAccent, thickness: 0.5),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isUrgentSaving ? null : _saveUrgentPrayer,
              child: _isUrgentSaving 
                ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                : const Text('공유하기', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildUrgentStreamArea() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('artifacts').doc(appId).collection('public').doc('data').collection('urgent_prayers').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
        
        var docs = snapshot.data!.docs.where((doc) => (doc.data() as Map<String, dynamic>)['month'] == _currentMonth).toList();
        if (docs.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

        return SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.shade100.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🚩 최근 긴급 요청', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 8),
                ...docs.map((d) {
                  var data = d.data() as Map<String, dynamic>;
                  // 💡 본인이 작성했거나 관리자인 경우 삭제 버튼 노출
                  bool canDelete = _isAdmin || data['authorName'] == widget.teacherName;
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text('• ${data['content']} (${data['authorName']} ${data['authorRole']})', 
                              style: const TextStyle(fontSize: 12, color: Colors.black87)),
                        ),
                        if (canDelete)
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.redAccent, size: 14),
                            onPressed: () => _deleteUrgentPrayer(d.id),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          )
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMonthSelector() {
    return Row(
      children: [
        const Icon(Icons.calendar_month, color: Colors.teal, size: 20),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.teal.shade100)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _currentMonth,
              items: _monthOptions.map((month) => DropdownMenuItem(value: month, child: Text(DateFormat('yyyy년 MM월').format(DateTime.parse('$month-01')), style: const TextStyle(fontSize: 14)))).toList(),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.teal.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [Icon(Icons.auto_awesome, color: Colors.teal.shade700, size: 20), const SizedBox(width: 8), Text('$_currentMonth 공동 기도제목', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900))]),
              if (_isAdmin) IconButton(icon: const Icon(Icons.add_circle, color: Colors.teal, size: 20), onPressed: _addCommonField, constraints: const BoxConstraints(), padding: EdgeInsets.zero),
            ],
          ),
          const SizedBox(height: 12),
          if (_isAdmin)
            ..._commonControllers.asMap().entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(children: [
                Expanded(child: TextField(controller: entry.value, style: const TextStyle(fontSize: 13), maxLines: null, keyboardType: TextInputType.multiline, decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8), prefixText: '${entry.key + 1}. ', hintText: '공동 기도제목 입력'))),
                IconButton(icon: const Icon(Icons.remove_circle, color: Colors.redAccent, size: 18), onPressed: () => _removeCommonField(entry.key)),
              ]),
            )).toList()
          else
            ..._commonControllers.asMap().entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${entry.key + 1}. ${_cleanText(entry.value.text)}', style: TextStyle(fontSize: 13, color: Colors.teal.shade800)),
            )),
          if (_isAdmin) ...[
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _isCommonSaving ? null : _saveCommonPrayer, style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white, visualDensity: VisualDensity.compact), child: _isCommonSaving ? const SizedBox(height: 15, width: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('공동 기도제목 업데이트', style: TextStyle(fontSize: 12)))),
          ]
        ],
      ),
    );
  }

  Widget _buildInputTitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('📝 나의 기도제목', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        TextButton.icon(onPressed: _addField, icon: const Icon(Icons.add_circle_outline, size: 20), label: const Text('항목 추가')),
      ],
    );
  }

  List<Widget> _buildInputFields() {
    return _controllers.asMap().entries.map((entry) {
      int idx = entry.key;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 12), child: CircleAvatar(radius: 12, backgroundColor: Colors.teal.shade100, child: Text('${idx + 1}', style: const TextStyle(fontSize: 12, color: Colors.teal)))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: entry.value, maxLines: null, keyboardType: TextInputType.multiline, decoration: const InputDecoration(hintText: '내용을 입력하세요', border: UnderlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 10)))),
            if (_controllers.length > 1) IconButton(padding: const EdgeInsets.only(top: 10), icon: const Icon(Icons.remove_circle_outline, color: Colors.grey, size: 20), onPressed: () => _removeField(idx)),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildSaveButton() {
    return SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _isSaving ? null : _savePrayer, style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: _isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('저장 및 공유하기', style: TextStyle(fontWeight: FontWeight.bold))));
  }

  Widget _buildTotalStreamList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('artifacts').doc(appId).collection('public').doc('data').collection('prayer_requests').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SliverFillRemaining(child: Center(child: Text("데이터 로드 중 오류가 발생했습니다.")));
        if (!snapshot.hasData) return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
        var docs = snapshot.data!.docs.where((doc) => (doc.data() as Map<String, dynamic>)['month'] == _currentMonth).toList();
        docs.sort((a, b) { var aData = a.data() as Map<String, dynamic>; var bData = b.data() as Map<String, dynamic>; return (bData['updatedAt'] ?? Timestamp.now()).compareTo(aData['updatedAt'] ?? Timestamp.now()); });
        if (docs.isEmpty) return const SliverFillRemaining(child: Padding(padding: EdgeInsets.all(32.0), child: Center(child: Text("등록된 기도제목이 없습니다.", textAlign: TextAlign.center))));
        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            List<dynamic> contents = data['content'] ?? [];
            return Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))], border: Border.all(color: Colors.grey.shade100)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Text('${index + 1}. ${_cleanName(data['teacherName'] ?? '교사')}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(width: 8), Text(data['cell'] ?? '-', style: TextStyle(color: Colors.teal.shade600, fontSize: 12, fontWeight: FontWeight.w600))]),
                const SizedBox(height: 10),
                ...contents.asMap().entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('${e.key + 1}. ${_cleanText(e.value.toString())}', style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4)))),
              ]),
            );
          }, childCount: docs.length),
        );
      },
    );
  }

  @override
  void dispose() {
    _urgentController.dispose();
    for (var c in _controllers) { c.dispose(); }
    for (var c in _commonControllers) { c.dispose(); }
    super.dispose();
  }
}