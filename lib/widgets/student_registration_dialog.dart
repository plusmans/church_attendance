import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/student_service.dart';

class StudentRegistrationDialog extends StatefulWidget {
  final String initialCell;
  final String teacherRole;
  final String teacherGrade;
  final Function(String docId, String name) onRegistered;

  const StudentRegistrationDialog({
    super.key,
    required this.initialCell,
    required this.teacherRole,
    required this.teacherGrade,
    required this.onRegistered,
  });

  @override
  State<StudentRegistrationDialog> createState() => _StudentRegistrationDialogState();
}

class _StudentRegistrationDialogState extends State<StudentRegistrationDialog> {
  final _nameC = TextEditingController();
  final _phoneC = TextEditingController();
  final _birthC = TextEditingController();
  final _schoolC = TextEditingController();
  final _addressC = TextEditingController(text: '미입력');
  final _firstVisitC = TextEditingController();
  final _evangelistC = TextEditingController();
  final _churchNameC = TextEditingController(text: '성문교회'); // '부모님 출석교회'로 사용됨
  final _parentNameC = TextEditingController();
  final _parentPhoneC = TextEditingController(text: '미입력');
  final _mbtiC = TextEditingController(text: '미입력');
  final _siblingsC = TextEditingController(text: '미입력');
  final _friendsC = TextEditingController(text: '미입력');
  final _notesC = TextEditingController();

  String _gender = '남자';
  late String _grade;
  late String _cell;
  String _churchExp = '유';
  String _baptism = '해당없음';
  bool _isSaving = false;

  // 전역 관리자 권한 확인
  bool get _isGlobalAdmin => ['강도사', '부장', 'admin', '개발자'].contains(widget.teacherRole);
  
  // 학년 담당자 권한 확인
  bool get _isGradeAdmin => ['1학년담당', '2학년담당', '3학년담당'].contains(widget.teacherRole);

  @override
  void initState() {
    super.initState();
    
    // 학년 초기값 설정 로직
    if (_isGlobalAdmin) {
      _grade = (widget.teacherGrade == '공통' || widget.teacherGrade.isEmpty) ? '1학년' : widget.teacherGrade;
    } else if (widget.teacherRole == '1학년담당') {
      _grade = '1학년';
    } else if (widget.teacherRole == '2학년담당') {
      _grade = '2학년';
    } else if (widget.teacherRole == '3학년담당') {
      _grade = '3학년';
    } else {
      _grade = widget.teacherGrade;
    }

    // 셀 초기값 설정
    _cell = (widget.initialCell == 'teachers' || widget.initialCell == '전체') ? '1' : widget.initialCell;
    
    _firstVisitC.text = _getThisSunday();
  }

  String _getThisSunday() {
    DateTime now = DateTime.now();
    int diff = now.weekday % 7;
    return DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: diff)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("🎉 새친구 신규 등록", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSection("💎 기본 정보 (필수)", Colors.indigo),
              _buildTextField("학생 이름 (필수)", _nameC),
              _buildTextField("본인 전화", _phoneC, isPhone: true),
              Row(children: [
                Expanded(child: _buildDropdown("성별", _gender, ['남자', '여자'], (v) => setState(() => _gender = v!))),
                const SizedBox(width: 8),
                Expanded(child: _buildDropdown("학년", _grade, ['1학년', '2학년', '3학년'], _isGlobalAdmin ? (v) => setState(() => _grade = v!) : null)),
              ]),
              const SizedBox(height: 12),
              _buildDropdown("배정 셀", _cell, List.generate(10, (i) => (i + 1).toString()), (_isGlobalAdmin || _isGradeAdmin) ? (v) => setState(() => _cell = v!) : null),
              
              _buildSection("👣 신앙 정보", Colors.teal),
              _buildTextField("첫 방문일", _firstVisitC),
              _buildTextField("인도자", _evangelistC),
              Row(children: [
                Expanded(child: _buildDropdown("신앙경험", _churchExp, ['유', '무'], (v) => setState(() => _churchExp = v!))),
                const SizedBox(width: 8),
                Expanded(child: _buildDropdown("세례상태", _baptism, ['모름', '학습', '세례', '입교', '해당없음'], (v) => setState(() => _baptism = v!))),
              ]),

              _buildSection("📍 생활 및 가족", Colors.orange),
              _buildTextField("생년월일 (2011-05-04)", _birthC),
              _buildTextField("소속 학교", _schoolC),
              _buildTextField("거주 주소", _addressC),
              _buildTextField("보호자 성함", _parentNameC),
              _buildTextField("보호자 연락처", _parentPhoneC, isPhone: true),
              // ✅ 위치 이동 및 문구 변경: 보호자 연락처 다음으로 이동
              _buildTextField("부모님 출석교회", _churchNameC), 
              _buildTextField("MBTI", _mbtiC),
              _buildTextField("형제관계", _siblingsC),
              _buildTextField("교내 친구", _friendsC),
              _buildTextField("특이사항", _notesC, maxLines: 3),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isSaving ? null : () => Navigator.pop(context), child: const Text("취소")),
        ElevatedButton(
          onPressed: _isSaving ? null : _handleSave,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
          child: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("등록하기"),
        ),
      ],
    );
  }

  Future<void> _handleSave() async {
    if (_nameC.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final result = await StudentService.registerStudent(
        name: _nameC.text.trim(),
        cell: _cell,
        grade: _grade,
        gender: _gender,
        phone: _phoneC.text.trim(),
        birthDate: _birthC.text.trim(),
        school: _schoolC.text.trim(),
        address: _addressC.text.trim(),
        parentName: _parentNameC.text.trim(),
        parentPhone: _parentPhoneC.text.trim(),
        notes: _notesC.text.trim(),
        evangelist: _evangelistC.text.trim(),
        firstVisitDate: _firstVisitC.text.trim(),
        baptismStatus: _baptism,
        churchExperience: _churchExp,
        churchName: _churchNameC.text.trim(),
        mbti: _mbtiC.text.trim(),
        siblings: _siblingsC.text.trim(),
        churchFriends: _friendsC.text.trim(),
        isNewFriend: true,
      );
      widget.onRegistered(result['docId']!, result['finalName']!);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("등록 에러: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildSection(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(children: [
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        const Expanded(child: Divider(indent: 10)),
      ]),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isPhone = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
        decoration: InputDecoration(
          labelText: label, 
          border: const OutlineInputBorder(), 
          isDense: true, 
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?>? onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        filled: onChanged == null, 
        fillColor: onChanged == null ? Colors.grey.shade100 : null,
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
      onChanged: onChanged,
    );
  }
}