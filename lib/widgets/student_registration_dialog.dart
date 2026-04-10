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

  // 학년별 셀 매핑 데이터
  final Map<String, List<String>> gradeCellMap = {
    '1학년담당': ['1', '2'],
    '2학년담당': ['3', '4', '5', '6'],
    '3학년담당': ['7', '8', '9', '10'],
    '1': ['1', '2'],
    '2': ['3', '4', '5', '6'],
    '3': ['7', '8', '9', '10'],
  };

  // 권한 판별 Getters
  bool get _isAdmin => widget.teacherRole.trim() == 'admin';
  bool get _isFullAccess => 
      ['admin', '강도사', '부장', '개발자'].contains(widget.teacherRole.trim());
  bool get _isGradeAdmin => 
      widget.teacherRole.trim().contains('학년담당');

  @override
  void initState() {
    super.initState();
    final String role = widget.teacherRole.trim();
    
    // 1. 학년 초기 설정
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

    // 2. 셀 초기 설정 및 유효성 검사
    final List<String> cellOptions = List.generate(10, (i) => (i + 1).toString());

    if (_isFullAccess) {
      // admin, 강도사, 부장님은 현재 선택되어 있던 셀을 기본으로 하되, 
      // '교사', '전체' 등 숫자가 아닌 경우 '1'셀로 시작
      _cell = (widget.initialCell == 'teachers' || widget.initialCell == '전체')
          ? '1'
          : widget.initialCell;
    } else if (_isGradeAdmin) {
      // 학년담당은 자신의 학년 범위 내의 셀인지 확인 후 초기값 설정
      List<String> allowed = gradeCellMap[role] ?? [];
      if (allowed.contains(widget.initialCell)) {
        _cell = widget.initialCell;
      } else {
        _cell = allowed.isNotEmpty ? allowed.first : '1';
      }
    } else {
      // 일반 교사는 본인의 셀로 고정 (학생 등록이므로 teachers는 제외)
      _cell = widget.initialCell == 'teachers' ? '1' : widget.initialCell;
    }

    // 💡 [추가] 최종 안전장치: 결정된 _cell 값이 전체 드롭다운 항목(1~10)에 없는 경우 '1'로 고정
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
    // 현재 로그인한 교사가 선택 가능한 셀 목록 구성
    List<String> allowedCellNumbers = [];
    if (_isFullAccess) {
      allowedCellNumbers = List.generate(10, (i) => (i + 1).toString());
    } else if (_isGradeAdmin) {
      allowedCellNumbers = gradeCellMap[widget.teacherRole.trim()] ?? [];
    } else {
      allowedCellNumbers = [_cell];
    }

    // 💡 빌드 시점 안전장치: _cell이 현재 권한에서 허용된 목록에 없으면 첫 번째 항목 선택
    if (!allowedCellNumbers.contains(_cell)) {
      _cell = allowedCellNumbers.isNotEmpty ? allowedCellNumbers.first : '1';
    }

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
      contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Row(
        children: [
          const Icon(Icons.person_add_rounded, color: Colors.indigo, size: 22),
          const SizedBox(width: 8),
          const Text(
            "새친구 등록",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
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
              _buildTextField("학생 이름 (필수)", _nameC),
              _buildTextField("본인 연락처", _phoneC, isPhone: true),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown("성별", _gender, [
                      '남자',
                      '여자',
                    ], (v) => setState(() => _gender = v!)),
                  ),
                  const SizedBox(width: 8),
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
              const SizedBox(height: 8),
              // ✅ 배정 셀 드롭다운: 보정된 _cell과 allowedCellNumbers 사용
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
                  Expanded(child: _buildTextField("첫 방문일", _firstVisitC)),
                  const SizedBox(width: 8),
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
                  const SizedBox(width: 8),
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
                    child: _buildTextField("생년월일", _birthC, hint: "2011-05-04"),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTextField("소속 학교", _schoolC)),
                ],
              ),
              _buildTextField("거주 주소", _addressC),
              Row(
                children: [
                  Expanded(child: _buildTextField("보호자 성함", _parentNameC)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTextField(
                      "보호자 연락처",
                      _parentPhoneC,
                      isPhone: true,
                    ),
                  ),
                ],
              ),
              _buildTextField("부모님 출석교회", _churchNameC),
              Row(
                children: [
                  Expanded(child: _buildTextField("MBTI", _mbtiC)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTextField("형제관계", _siblingsC)),
                ],
              ),
              _buildTextField("교내 친구", _friendsC),
              _buildTextField("특이사항/메모", _notesC, maxLines: 2),

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "취소",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "등록하기",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (_nameC.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("학생 이름을 입력해주세요!")));
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
      padding: const EdgeInsets.only(top: 15, bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: color.withOpacity(0.2), thickness: 1)),
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: isPhone
            ? TextInputType.phone
            : (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(fontSize: 12),
          hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
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
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<String>(
        value: value,
        style: const TextStyle(fontSize: 13, color: Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          filled: true,
          fillColor: onChanged == null ? Colors.grey.shade100 : Colors.white,
        ),
        items: items
            .map(
              (e) => DropdownMenuItem(
                value: e,
                child: Text(e, style: const TextStyle(fontSize: 13)),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}