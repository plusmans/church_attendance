import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StudentMigrationScreen extends StatefulWidget {
  const StudentMigrationScreen({super.key});

  @override
  State<StudentMigrationScreen> createState() => _StudentMigrationScreenState();
}

class _StudentMigrationScreenState extends State<StudentMigrationScreen> {
  // 💡 대상 학생 (이미 옮겨진 경우에도 이 ID를 입력하면 교정됩니다)
  final TextEditingController _oldIdController = TextEditingController(text: '08셀_3학년_권세윤');
  // 💡 목표 셀: 08 (내부 필드는 "8"로 저장됨)
  final TextEditingController _newCellController = TextEditingController(text: '08');
  
  bool _isLoading = false;

  Future<void> _migrateStudent() async {
    final oldIdInput = _oldIdController.text.trim();
    final newCellInput = _newCellController.text.trim();

    if (oldIdInput.isEmpty || newCellInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('정보를 모두 입력해주세요.')));
      return;
    }

    final parts = oldIdInput.split('_');
    if (parts.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID 형식이 올바르지 않습니다.')));
      return;
    }
    
    final String studentName = parts[2];
    final String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    // 💡 핵심: 출석부와 학생 필드 모두 "8" 형식을 사용하도록 통일 (캡처 화면 기준)
    final String newCellForField = int.parse(newCellInput).toString(); // "08" -> "8"
    final String newStudentCellId = '${newCellInput.padLeft(2, '0')}셀'; // "08셀"
    final String newId = '${newStudentCellId}_${parts[1]}_$studentName';

    setState(() => _isLoading = true);

    try {
      final db = FirebaseFirestore.instance;
      final studentRef = db.collection('students');
      final attendanceRef = db.collection('attendance');

      // [1] 학생 데이터 찾기
      DocumentSnapshot studentDoc = await studentRef.doc(oldIdInput).get();
      if (!studentDoc.exists) {
        throw '학생 정보($oldIdInput)를 찾을 수 없습니다.';
      }

      final studentData = studentDoc.data() as Map<String, dynamic>;
      final batch = db.batch();

      // [A] 학생 마스터 정보 업데이트 (cell 값을 "8"로 통일)
      studentData['cell'] = newCellForField; // 💡 "08"이 아닌 "8"로 저장
      studentData['updatedAt'] = FieldValue.serverTimestamp();
      
      // 만약 ID가 바뀌어야 하는 상황(07->08)이라면 새로 만들고 지움
      if (oldIdInput != newId) {
        batch.set(studentRef.doc(newId), studentData);
        batch.delete(studentRef.doc(oldIdInput));
      } else {
        // 이미 08셀 ID라면 필드만 업데이트
        batch.update(studentRef.doc(oldIdInput), {'cell': newCellForField});
      }

      // [B] 출석 데이터 처리
      final attendanceSnapshot = await attendanceRef.get();
      final String oldCellNum = oldIdInput.split('셀').first;
      final String oldCellForAtt = int.parse(oldCellNum).toString();
      
      final oldCellDocs = attendanceSnapshot.docs.where((doc) => doc.id.startsWith('${oldCellForAtt}셀_')).toList();
      bool todayHandled = false;

      for (var attDoc in oldCellDocs) {
        final records = Map<String, dynamic>.from(attDoc.data()['records'] ?? {});
        if (records.containsKey(studentName)) {
          final datePart = attDoc.id.split('_').last;
          if (datePart == todayDate) todayHandled = true;

          Map<String, dynamic> record = Map<String, dynamic>.from(records[studentName]);
          record['cell'] = newCellForField; // 💡 내부 cell 필드도 "8"로 교정

          // 셀 번호가 바뀌는 이동인 경우에만 문서간 이동 수행
          if (oldCellForAtt != newCellForField) {
            batch.update(attendanceRef.doc(attDoc.id), {'records.$studentName': FieldValue.delete()});
            batch.set(attendanceRef.doc('${newCellForField}셀_$datePart'), {
              'cell': newCellForField,
              'date': datePart,
              'records': { studentName: record },
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } else {
            // 셀 번호는 같은데 데이터만 교정하는 경우
            batch.update(attendanceRef.doc(attDoc.id), {'records.$studentName.cell': newCellForField});
          }
        }
      }

      // [C] 오늘 날짜 누락 보정 (8셀 오늘 기록에 권세윤이 없는 경우)
      final todayDocId = '${newCellForField}셀_$todayDate';
      final todayDoc = await attendanceRef.doc(todayDocId).get();
      bool alreadyInToday = false;
      if (todayDoc.exists) {
        final records = Map<String, dynamic>.from(todayDoc.data()?['records'] ?? {});
        if (records.containsKey(studentName)) alreadyInToday = true;
      }

      if (!alreadyInToday) {
        final Map<String, dynamic> forceRecord = {
          'cell': newCellForField,
          'status': '출석',
          'grade': studentData['grade'] ?? parts[1],
          'group': studentData['group'] ?? 'A',
          'gender': studentData['gender'] ?? '',
          'role': '학생',
          'reason': '',
          'customReason': '',
        };
        batch.set(attendanceRef.doc(todayDocId), {
          'cell': newCellForField,
          'date': todayDate,
          'records': { studentName: forceRecord },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('교정 및 이동 완료'),
            content: Text(
              '권세윤 학생의 셀 정보를 "${newCellForField}"(으)로 통일했습니다.\n\n'
              '이제 현황 페이지에서 별도의 "08셀" 섹션 없이\n'
              '기존 8셀 명단에 함께 나타납니다.'
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('학생 데이터 통합 교정'), backgroundColor: Colors.indigo, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade200)),
              child: const Text('✨ "08셀"이 따로 생기는 문제를 해결하기 위해 내부 데이터를 "8"로 통일하여 교정합니다.', style: TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 32),
            TextField(controller: _oldIdController, decoration: const InputDecoration(labelText: '현재 학생 ID', hintText: '이미 옮겼다면 08셀_3학년_권세윤 입력', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _newCellController, decoration: const InputDecoration(labelText: '대상 셀 번호 (08)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _migrateStudent,
                icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.build_circle),
                label: const Text('데이터 값 통일 및 보정 실행', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}