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

  // 1. 모든 학생을 A그룹 및 기본값으로 일괄 초기화
  Future<void> _runInitialSetup() async {
    setState(() => _isProcessing = true);
    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      var snapshot = await FirebaseFirestore.instance
          .collection('students')
          .get();

      if (snapshot.docs.isEmpty) throw "등록된 학생 데이터가 없습니다.";

      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'group': 'A',
          'isRegular': true,
          'attendanceCount': 0,
          'firstVisitDate': '2025-01-01',
          'promotedAt': '2025-01-01',
          'evangelist': '',
          'churchExperience': '유',
        });
      }

      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🎉 학생 정보 기본값 초기화가 완료되었습니다.")),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ 오류 발생: $e")));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ✅ 2. 실제 출석부 기록을 바탕으로 학생별 누적 카운트 재계산 (컴파일 에러 해결 및 규칙 준수 버전)
  Future<void> _recalculateAttendanceCounts() async {
    setState(() => _isProcessing = true);
    try {
      String currentYear = "2026"; // 대상 연도

      // 💡 [컴파일 에러 해결] 쿼리를 단순화하여 전체를 가져온 후 메모리에서 필터링합니다 (Rule 2 준수)
      var attendanceSnapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .get();

      // 학생별(셀_이름 키 조합) 출석 횟수 집계
      Map<String, int> attendanceMap = {};

      for (var doc in attendanceSnapshot.docs) {
        var data = doc.data();
        String? date = data['date'];

        // 해당 연도 데이터만 필터링
        if (date == null || !date.startsWith(currentYear)) continue;

        String? cell = data['cell'];
        if (cell == null || cell == 'teachers') continue;

        Map<String, dynamic> records = Map<String, dynamic>.from(
          data['records'] ?? {},
        );
        records.forEach((rawName, info) {
          String name = rawName.toString().replaceAll(' ', '');
          String status = info is Map ? (info['status'] ?? '결석') : '결석';

          if (status == '출석') {
            String key = '${cell}_$name';
            attendanceMap[key] = (attendanceMap[key] ?? 0) + 1;
          }
        });
      }

      // 학생 마스터 DB 업데이트
      var studentsSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .get();
      WriteBatch batch = FirebaseFirestore.instance.batch();
      int updateCount = 0;

      for (var doc in studentsSnapshot.docs) {
        var data = doc.data();
        String studentName = (data['name'] ?? '').toString().replaceAll(
          ' ',
          '',
        );
        String studentCell = (data['cell'] ?? '').toString();

        String key = '${studentCell}_$studentName';
        int actualCount = attendanceMap[key] ?? 0;

        batch.update(doc.reference, {'attendanceCount': actualCount});
        updateCount++;
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "✅ $updateCount명의 학생 출석 카운트가 $currentYear년 기록으로 업데이트되었습니다.",
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ 재계산 오류: $e");
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ 재계산 중 오류 발생: $e")));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // 3. 잘못된 이름 수정 함수 (기존 유지)
  Future<void> _fixWrongName() async {
    setState(() => _isProcessing = true);
    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      String oldDocId = '01셀_1학년_김범준';
      String newDocId = '01셀_1학년_김민준';
      String oldName = '김범준';
      String newName = '김민준';

      DocumentReference oldRef = FirebaseFirestore.instance
          .collection('students')
          .doc(oldDocId);
      DocumentSnapshot snap = await oldRef.get();
      if (snap.exists) {
        Map<String, dynamic> data = snap.data() as Map<String, dynamic>;
        data['name'] = newName;
        batch.set(
          FirebaseFirestore.instance.collection('students').doc(newDocId),
          data,
        );
        batch.delete(oldRef);
      }

      var attSnap = await FirebaseFirestore.instance
          .collection('attendance')
          .get();
      for (var doc in attSnap.docs) {
        Map<String, dynamic> data = doc.data();
        if (data['records'] != null && data['records'][oldName] != null) {
          batch.update(doc.reference, {
            'records.$newName': data['records'][oldName],
            'records.$oldName': FieldValue.delete(),
          });
        }
      }
      await batch.commit();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("✅ 이름 수정 동기화 완료!")));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ 수정 오류: $e")));
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
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.analytics_rounded, size: 80, color: Colors.indigo),
            const SizedBox(height: 20),
            const Text(
              "데이터 재계산 및 초기화",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            _buildActionCard(
              title: "실제 출석 횟수 동기화",
              description:
                  "2026년 출석부 기록을 모두 전수 조사하여 학생들의 누적 출석 횟수(attendanceCount)를 실제 값으로 고칩니다.",
              icon: Icons.sync,
              color: Colors.indigo,
              buttonText: "출석 카운트 재계산 실행",
              onPressed: _recalculateAttendanceCounts,
            ),

            const SizedBox(height: 20),

            _buildActionCard(
              title: "학생 정보 일괄 초기화",
              description: "모든 학생을 A그룹(정규)으로 변경하고 기타 정보를 기본값으로 맞춥니다.",
              icon: Icons.restart_alt,
              color: Colors.redAccent,
              buttonText: "일괄 초기화 실행",
              onPressed: _runInitialSetup,
            ),

            const SizedBox(height: 20),

            _buildActionCard(
              title: "이름 오타 수정",
              description: "김범준 → 김민준 학생의 오타를 수정하고 과거 출석부 기록의 이름까지 동기화합니다.",
              icon: Icons.person_search,
              color: Colors.teal,
              buttonText: "이름 수정 실행",
              onPressed: _fixWrongName,
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
