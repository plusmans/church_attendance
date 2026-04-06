import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SetupInitialDataScreen extends StatefulWidget {
  const SetupInitialDataScreen({super.key});

  @override
  State<SetupInitialDataScreen> createState() => _SetupInitialDataScreenState();
}

class _SetupInitialDataScreenState extends State<SetupInitialDataScreen> {
  bool _isProcessing = false;

  // 기존: 모든 학생을 A그룹(정규) 및 기본값으로 일괄 초기화하는 함수
  Future<void> _runInitialSetup() async {
    setState(() => _isProcessing = true);
    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      var snapshot = await FirebaseFirestore.instance.collection('students').get();
      
      if (snapshot.docs.isEmpty) {
        throw "등록된 학생 데이터가 없습니다.";
      }

      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'group': 'A',              
          'isRegular': true,         
          'attendanceCount': 99,     
          'firstVisitDate': '2025-01-01',
          'promotedAt': '2025-01-01',
          'evangelist': '',          
          'churchExperience': '유',   
        });
      }
      
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🎉 초기 데이터(A그룹) 설정이 완료되었습니다!"))
        );
        Navigator.pop(context, true); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ 오류 발생: $e")));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ✅ 추가됨: 잘못된 학생 이름과 출석부 기록을 일괄 수정하는 임시 함수
  Future<void> _fixWrongName() async {
    setState(() => _isProcessing = true);
    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      
      String oldDocId = '01셀_1학년_김범준';
      String newDocId = '01셀_1학년_김민준';
      String oldName = '김범준';
      String newName = '김민준';

      // 1. 학생 문서 수정 (새 문서 복사 후 이전 문서 삭제)
      DocumentReference oldStudentRef = FirebaseFirestore.instance.collection('students').doc(oldDocId);
      DocumentSnapshot oldStudentSnap = await oldStudentRef.get();

      if (oldStudentSnap.exists) {
        Map<String, dynamic> data = oldStudentSnap.data() as Map<String, dynamic>;
        data['name'] = newName; // 이름 필드 값 변경
        
        DocumentReference newStudentRef = FirebaseFirestore.instance.collection('students').doc(newDocId);
        batch.set(newStudentRef, data);
        batch.delete(oldStudentRef);
      }

      // 2. 출석부(attendance) 컬렉션에서 과거 기록 수정
      var attendanceSnap = await FirebaseFirestore.instance.collection('attendance').get();
      for (var doc in attendanceSnap.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        // records 맵 안에 '김범준' 키가 존재하는지 확인
        if (data['records'] != null && data['records'][oldName] != null) {
          var recordData = data['records'][oldName]; // 기존 출석/결석 데이터 복사
          
          // 새 이름으로 데이터 추가하고, 옛날 이름 키는 삭제 처리
          batch.update(doc.reference, {
            'records.$newName': recordData,
            'records.$oldName': FieldValue.delete(),
          });
        }
      }

      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ 김범준 → 김민준 학생 정보 및 출석부 수정이 완료되었습니다!"))
        );
      }
    } catch (e) {
      debugPrint("❌ 수정 오류: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ 수정 오류: $e")));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('초기 데이터 등록', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.warning_amber_rounded, size: 80, color: Colors.redAccent),
            const SizedBox(height: 20),
            const Text(
              "데이터 일괄 초기화",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.redAccent),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: const Text(
                "이 작업은 현재 등록된 모든 학생의 정보를 아래와 같이 일괄 변경합니다.\n\n"
                "• 소속 그룹: A그룹 (정규학생)\n"
                "• 누적 출석: 99회\n"
                "• 첫 출석 및 등반일: 2025-01-01\n"
                "• 전도자: (없음) / 교회경험: 유",
                style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.6),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _runInitialSetup,
                icon: _isProcessing 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.bolt),
                label: Text(
                  _isProcessing ? "처리 중..." : "일괄 데이터 등록 실행", 
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Divider(),
            ),

            // ✅ 김범준 -> 김민준 일괄 수정 전용 버튼 영역
            const Text(
              "특정 학생 오류 수정",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
            const SizedBox(height: 12),
            const Text(
              "'01셀_1학년_김범준'을 '김민준'으로 변경하고, 과거 출석부의 이름도 함께 동기화합니다.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _isProcessing ? null : _fixWrongName,
                icon: const Icon(Icons.build_circle_outlined),
                label: const Text("김범준 → 김민준 일괄 수정하기"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.indigo,
                  side: const BorderSide(color: Colors.indigo),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}