import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ 입력 제한 기능을 위해 추가
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
  State<StudentRegistrationDialog> createState() =>
      _StudentRegistrationDialogState();
}

class _StudentRegistrationDialogState extends State<StudentRegistrationDialog> {
  final _nameC = TextEditingController();
  final _phoneC = TextEditingController();
  final _birthC = TextEditingController();
  final _schoolC = TextEditingController();
  final _addressC = TextEditingController(text: '미입력');
  final _firstVisitC = TextEditingController();
  final _evangelistC = TextEditingController();
  final _churchNameC = TextEditingController(text: '성문교회');
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
  
  // ✅ 이름 에러 메시지 상태 추가
  String? _nameErrorText;

  final Map<String, List<String>> gradeCellMap = {
    '1학년담당': ['1', '2'],
    '2학년담당': ['3', '4', '5', '6'],
    '3학년담당': ['7', '8', '9', '10'],
    '1': ['1', '2'],
    '2': ['3', '4', '5', '6'],
    '3': ['7', '8', '9', '10'],
  };

  bool get _isFullAccess => 
      ['admin', '강도사', '부장', '개발자'].contains(widget.teacherRole.trim());
  bool get _isGradeAdmin => 
      widget.teacherRole.trim().contains('학년담당');

  @override
  void initState() {
    super.initState();
    final String role = widget.teacherRole.trim();
    
    if (_isFullAccess) {
      _grade = (widget.teacherGrade == '공통' || widget.teacherGrade.isEmpty)
          ? '1학년'
          : widget.teacherGrade;
    } else if (role == '1학년담당') {
      _grade = '1학년';
    } else if (role == '2학년담당') {
      _grade = '2학년';
    } else if (role == '3학년담당') {
      _grade = '3학년';
    } else {
      _grade = widget.teacherGrade;
    }

    final List<String> cellOptions = List.generate(10, (i) => (i + 1).toString());

    if (_isFullAccess) {
      _cell = (widget.initialCell == 'teachers' || widget.initialCell == '전체')
          ? '1'
          : widget.initialCell;
    } else if (_isGradeAdmin) {
      List<String> allowed = gradeCellMap[role] ?? [];
      if (allowed.contains(widget.initialCell)) {
        _cell = widget.initialCell;
      } else {
        _cell = allowed.isNotEmpty ? allowed.first : '1';
      }
    } else {
      _cell = widget.initialCell == 'teachers' ? '1' : widget.initialCell;
    }

    if (!cellOptions.contains(_cell)) {
      _cell = '1';
    }

    _firstVisitC.text = _getThisSunday();
  }

  String _getThisSunday() {
    DateTime now = DateTime.now();
    int diff = now.weekday % 7;
    return DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: diff)));
  }

  @override
  Widget build(BuildContext context) {
    List<String> allowedCellNumbers = [];
    if (_isFullAccess) {
      allowedCellNumbers = List.generate(10, (i) => (i + 1).toString());
    } else if (_isGradeAdmin) {
      allowedCellNumbers = gradeCellMap[widget.teacherRole.trim()] ?? [];
    } else {
      allowedCellNumbers = [_cell];
    }

    if (!allowedCellNumbers.contains(_cell)) {
      _cell = allowedCellNumbers.isNotEmpty ? allowedCellNumbers.first : '1';
    }

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      contentPadding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.person_add_rounded, color: Colors.indigo, size: 28),
          const SizedBox(width: 10),
          const Text(
            "새친구 등록",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: Colors.indigo,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSection("💎 기본 정보", Colors.indigo),
              // ✅ 이름 필드에 에러 텍스트 연결
              _buildTextField(
                "학생 이름 (필수)", 
                _nameC, 
                errorText: _nameErrorText,
                onChanged: (val) {
                  if (val.isNotEmpty && _nameErrorText != null) {
                    setState(() => _nameErrorText = null);
                  }
                }
              ),
              _buildTextField(
                "본인 연락처", 
                _phoneC, 
                isPhone: true,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9-]'))],
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown("성별", _gender, [
                      '남자',
                      '여자',
                    ], (v) => setState(() => _gender = v!)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDropdown(
                      "학년",
                      _grade,
                      ['1학년', '2학년', '3학년'],
                      _isFullAccess
                          ? (v) => setState(() => _grade = v!)
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildDropdown(
                "배정 셀",
                _cell,
                allowedCellNumbers,
                (_isFullAccess || _isGradeAdmin)
                    ? (v) => setState(() => _cell = v!)
                    : null,
              ),

              _buildSection("👣 신앙 및 전도", Colors.teal),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      "첫 방문일", 
                      _firstVisitC,
                      keyboardType: TextInputType.datetime,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.-]'))],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField("인도자", _evangelistC)),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown("신앙경험", _churchExp, [
                      '유',
                      '무',
                    ], (v) => setState(() => _churchExp = v!)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDropdown("세례상태", _baptism, [
                      '모름',
                      '학습',
                      '세례',
                      '입교',
                      '해당없음',
                    ], (v) => setState(() => _baptism = v!)),
                  ),
                ],
              ),

              _buildSection("📍 생활 및 가족", Colors.orange),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      "생년월일", 
                      _birthC, 
                      hint: "2011-05-04",
                      keyboardType: TextInputType.datetime,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.-]'))],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField("소속 학교", _schoolC)),
                ],
              ),
              _buildTextField("거주 주소", _addressC),
              Row(
                children: [
                  Expanded(child: _buildTextField("보호자 성함", _parentNameC)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTextField(
                      "보호자 연락처",
                      _parentPhoneC,
                      isPhone: true,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9-]'))],
                    ),
                  ),
                ],
              ),
              _buildTextField("부모님 출석교회", _churchNameC),
              Row(
                children: [
                  Expanded(child: _buildTextField("MBTI", _mbtiC)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField("형제관계", _siblingsC)),
                ],
              ),
              _buildTextField("교내 친구", _friendsC),
              _buildTextField("특이사항/메모", _notesC, maxLines: 2),

              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "취소",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "등록하기",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    // ✅ 이름 미입력 시 인라인 에러와 명확한 알림창 표시
    if (_nameC.text.trim().isEmpty) {
      setState(() => _nameErrorText = "학생 이름을 입력해주세요.");
      
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("입력 오류", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
          content: const Text("학생 이름이 등록되지 않았습니다.", style: TextStyle(fontSize: 16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("확인", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      );
      return;
    }

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
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: color.withValues(alpha: 0.2), thickness: 1.5)),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isPhone = false,
    int maxLines = 1,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? errorText, // ✅ 에러 텍스트 파라미터 추가
    ValueChanged<String>? onChanged, // ✅ 값 변경 콜백 추가
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: errorText, // ✅ 에러 메시지 표시
          errorStyle: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
          labelStyle: const TextStyle(fontSize: 14),
          hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.redAccent, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?>? onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        style: const TextStyle(fontSize: 15, color: Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          filled: true,
          fillColor: onChanged == null ? Colors.grey.shade100 : Colors.white,
        ),
        items: items
            .map(
              (e) => DropdownMenuItem(
                value: e,
                child: Text(e, style: const TextStyle(fontSize: 15)),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}