import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SetupInitialDataScreen extends StatefulWidget {
  const SetupInitialDataScreen({super.key});

  @override
  State<SetupInitialDataScreen> createState() => _SetupInitialDataScreenState();
}

class _SetupInitialDataScreenState extends State<SetupInitialDataScreen> {
  bool _isProcessing = false;

  // ✅ 오직 '성별' 필드만 규칙에 따라 업데이트하는 함수
  Future<void> _updateStudentGenderOnly() async {
    setState(() => _isProcessing = true);
    try {
      // 1. 현재 DB에 등록된 모든 학생 데이터를 가져옴
      var snapshot = await FirebaseFirestore.instance
          .collection('students')
          .get();

      if (snapshot.docs.isEmpty) throw "DB에 등록된 학생이 없습니다.";

      WriteBatch batch = FirebaseFirestore.instance.batch();
      int updateCount = 0;

      for (var doc in snapshot.docs) {
        var data = doc.data();
        String name = (data['name'] ?? '').toString().trim();
        String cell = (data['cell'] ?? '').toString().trim();
        String gender = '';

        // 🛠 성별 할당 규칙 적용

        // 3, 4, 7, 8셀 -> 여자
        if (['3', '03', '4', '04', '7', '07', '8', '08'].contains(cell)) {
          gender = '여자';
        }
        // 5, 6, 9, 10셀 -> 남자
        else if (['5', '05', '6', '06', '9', '09', '10'].contains(cell)) {
          gender = '남자';
        }
        // 1셀 상세 규칙
        else if (cell == '1' || cell == '01') {
          // 김지후, 김예준, 유예준, 신요환, 김민준, 정나겸 -> 남자 (정나경 제외됨)
          List<String> maleList1 = ['김지후', '김예준', '유예준', '신요환', '김민준', '정나겸'];
          gender = maleList1.contains(name) ? '남자' : '여자';
        }
        // 2셀 상세 규칙
        else if (cell == '2' || cell == '02') {
          // 조하율, 홍주원, 정하율, 김본, 박성윤, 이시호, 이하준, 이지훈, 임현후, 오건, 신연호 -> 남자
          List<String> maleList2 = [
            '조하율',
            '홍주원',
            '정하율',
            '김본',
            '박성윤',
            '이시호',
            '이하준',
            '이지훈',
            '임현후',
            '오건',
            '신연호',
          ];
          gender = maleList2.contains(name) ? '남자' : '여자';
        }

        if (gender.isNotEmpty) {
          // ✅ 다른 데이터는 절대 건드리지 않고 gender 필드만 업데이트
          batch.update(doc.reference, {'gender': gender});
          updateCount++;
        }
      }

      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("👫 $updateCount명의 학생 성별 정보만 선별 업데이트되었습니다.")),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ 성별 업데이트 오류: $e")));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // 교사 담당 정보 업데이트 (기존 유지)
  Future<void> _updateTeacherAssignmentInfo() async {
    setState(() => _isProcessing = true);
    try {
      final Map<String, String> pdfAssignmentData = {
        '이성은': '교역자',
        '김영욱': '부서담당',
        '이창희': '찬양팀',
        '윤혜진': '미디어팀',
        '김진욱': '기획팀',
        '김강지': '기획팀&회계',
        '김시은': '기획팀',
        '차소정': '섬김팀',
        '김예진': '섬김팀',
        '강현아': '찬양팀(반주)',
      };
      var snapshot = await FirebaseFirestore.instance
          .collection('teachers')
          .get();
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        String dbName = (doc.data()['name'] ?? '').toString().trim();
        if (pdfAssignmentData.containsKey(dbName)) {
          batch.update(doc.reference, {
            'assignment': pdfAssignmentData[dbName],
          });
        }
      }
      await batch.commit();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("📋 교사 담당 정보 업데이트 완료")));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // 교사 연락처 정보 업데이트 (기존 유지)
  Future<void> _updateTeacherContactInfo() async {
    setState(() => _isProcessing = true);
    try {
      final Map<String, Map<String, String>> pdfTeacherData = {
        '이성은': {'phone': '01041536820', 'birth': '2026년 09월 27일'},
        '김영욱': {'phone': '01045839493', 'birth': '2026년 03월 16일'},
      };
      var snapshot = await FirebaseFirestore.instance
          .collection('teachers')
          .get();
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        String dbName = (doc.data()['name'] ?? '').toString().trim();
        if (pdfTeacherData.containsKey(dbName)) {
          batch.update(doc.reference, {
            'phone': pdfTeacherData[dbName]!['phone']!.replaceAll('-', ''),
            'birthDate': pdfTeacherData[dbName]!['birth'],
          });
        }
      }
      await batch.commit();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("✅ 교사 정보 업데이트 완료")));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '초기 데이터 관리',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(
              Icons.person_pin_circle_rounded,
              size: 60,
              color: Colors.blueGrey,
            ),
            const SizedBox(height: 10),
            const Text("기존 데이터 보존 & 특정 필드 선별 업데이트"),
            const SizedBox(height: 30),

            _buildActionCard(
              title: "학생 성별 필드만 추가/업데이트",
              description:
                  "셀별/이름별 규칙에 따라 성별 필드만 생성합니다. 다른 데이터(출석횟수, 주소 등)는 전혀 건드리지 않습니다.",
              icon: Icons.wc_rounded,
              color: Colors.pinkAccent,
              buttonText: "성별 필드 선별 업데이트 실행",
              onPressed: _updateStudentGenderOnly,
            ),

            const SizedBox(height: 20),

            _buildActionCard(
              title: "교사 '담당' 필드 추가",
              description: "찬양팀, 기획팀 등 담당 부서 정보만 업데이트합니다.",
              icon: Icons.assignment_turned_in_rounded,
              color: Colors.blueAccent,
              buttonText: "담당 정보 업데이트 실행",
              onPressed: _updateTeacherAssignmentInfo,
            ),

            const SizedBox(height: 20),

            _buildActionCard(
              title: "교사 연락처 정보 업데이트",
              description: "교사 명단 기준으로 연락처와 생일 정보만 최신화합니다.",
              icon: Icons.phonelink_ring_rounded,
              color: Colors.green,
              buttonText: "연락처/생일 업데이트 실행",
              onPressed: _updateTeacherContactInfo,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      buttonText,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
