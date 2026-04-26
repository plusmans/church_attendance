import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StudentMigrationScreen extends StatefulWidget {
  const StudentMigrationScreen({super.key});

  @override
  State<StudentMigrationScreen> createState() => _StudentMigrationScreenState();
}

class _StudentMigrationScreenState extends State<StudentMigrationScreen> {
  final TextEditingController _oldIdController = TextEditingController(text: '07셀_3학년_권세윤');
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
    
    // 💡 에러 해결: 변수명을 명확하게 정의합니다.
    final String newCellForAtt = int.parse(newCellInput).toString(); // "8"
    final String newStudentCellId = '${newCellInput.padLeft(2, '0')}셀'; // "08셀"
    final String newId = '${newStudentCellId}_${parts[1]}_$studentName';

    setState(() => _isLoading = true);

    try {
      final db = FirebaseFirestore.instance;
      final studentRef = db.collection('students');
      final attendanceRef = db.collection('attendance');

      DocumentSnapshot studentDoc = await studentRef.doc(oldIdInput).get();
      if (!studentDoc.exists) {
        throw '학생 정보($oldIdInput)를 찾을 수 없습니다.';
      }

      final studentData = studentDoc.data() as Map<String, dynamic>;
      final batch = db.batch();

      studentData['cell'] = newCellForAtt;
      studentData['updatedAt'] = FieldValue.serverTimestamp();
      
      if (oldIdInput != newId) {
        batch.set(studentRef.doc(newId), studentData);
        batch.delete(studentRef.doc(oldIdInput));
      } else {
        batch.update(studentRef.doc(oldIdInput), {'cell': newCellForAtt});
      }

      final attendanceSnapshot = await attendanceRef.get();
      final String oldCellNum = oldIdInput.split('셀').first;
      final String oldCellForAtt = int.parse(oldCellNum).toString();
      
      // ✅ Lint 수정: 문자열 보간을 표준 방식으로 변경
      final oldCellDocs = attendanceSnapshot.docs.where((doc) => doc.id.startsWith('${oldCellForAtt}셀_')).toList();
      bool todayHandled = false;

      for (var attDoc in oldCellDocs) {
        final records = Map<String, dynamic>.from(attDoc.data()['records'] ?? {});
        if (records.containsKey(studentName)) {
          final datePart = attDoc.id.split('_').last;
          if (datePart == todayDate) {
            todayHandled = true;
          }

          Map<String, dynamic> record = Map<String, dynamic>.from(records[studentName]);
          record['cell'] = newCellForAtt;

          if (oldCellForAtt != newCellForAtt) {
            batch.update(attendanceRef.doc(attDoc.id), {'records.$studentName': FieldValue.delete()});
            // 💡 에러 해결: 정의된 newCellForAtt 변수 사용
            batch.set(attendanceRef.doc('${newCellForAtt}셀_$datePart'), {
              'cell': newCellForAtt,
              'date': datePart,
              'records': { studentName: record },
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } else {
            batch.update(attendanceRef.doc(attDoc.id), {'records.$studentName.cell': newCellForAtt});
          }
        }
      }

      if (!todayHandled) {
        // 💡 에러 해결: 정의된 newCellForAtt 변수 사용
        final todayDocId = '${newCellForAtt}셀_$todayDate';
        final todayDoc = await attendanceRef.doc(todayDocId).get();
        bool alreadyInToday = false;
        if (todayDoc.exists) {
          final records = Map<String, dynamic>.from(todayDoc.data()?['records'] ?? {});
          if (records.containsKey(studentName)) {
            alreadyInToday = true;
          }
        }

        if (!alreadyInToday) {
          final Map<String, dynamic> forceRecord = {
            'cell': newCellForAtt,
            'status': '출석',
            'grade': studentData['grade'] ?? parts[1],
            'group': studentData['group'] ?? 'A',
            'gender': studentData['gender'] ?? '',
            'role': '학생',
            'reason': '',
            'customReason': '',
          };
          batch.set(attendanceRef.doc(todayDocId), {
            'cell': newCellForAtt,
            'date': todayDate,
            'records': { studentName: forceRecord },
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      await batch.commit();

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('교정 및 이동 완료'),
            content: Text('권세윤 학생의 셀 정보를 "$newCellForAtt"로 통일했습니다.'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
              child: const Text('✨ 데이터를 "8"로 통일하여 교정합니다.', style: TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 32),
            TextField(controller: _oldIdController, decoration: const InputDecoration(labelText: '현재 학생 ID', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _newCellController, decoration: const InputDecoration(labelText: '대상 셀 번호', border: OutlineInputBorder()), keyboardType: TextInputType.number),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _migrateStudent,
                icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.build_circle),
                label: const Text('데이터 보정 실행'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}