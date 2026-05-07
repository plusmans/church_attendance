import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MigrationService {
  static const String appId = 'church-attendance-cdb07';

  /// ✅ 전체 데이터를 표준 경로(departments 또는 artifacts)로 이동시키는 함수
  static Future<void> migrateDataToDepartment(BuildContext context) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    
    // 마이그레이션 대상 부서 아이디 (appId와 동일하게 설정)
    const String targetDepartment = '중등부';
    
    // 기존 데이터가 저장되어 있던 공통 경로
    final prayerDataRef = firestore
        .collection('artifacts')
        .doc(appId)
        .collection('public')
        .doc('data');

    try {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🚀 데이터 마이그레이션을 시작합니다...')),
        );
      }

      // 1. 기존 학생 데이터 복합 복사
      final studentsSnap = await firestore.collection('students').get();
      for (var doc in studentsSnap.docs) {
        final newRef = firestore.collection('departments').doc(targetDepartment).collection('students').doc(doc.id);
        batch.set(newRef, doc.data());
      }

      // 2. 기존 교사 데이터 복사
      final teachersSnap = await firestore.collection('teachers').get();
      for (var doc in teachersSnap.docs) {
        final newRef = firestore.collection('departments').doc(targetDepartment).collection('teachers').doc(doc.id);
        batch.set(newRef, doc.data());
      }

      // 3. 기존 출석 데이터 복사
      final attendanceSnap = await firestore.collection('attendance').get();
      for (var doc in attendanceSnap.docs) {
        final newRef = firestore.collection('departments').doc(targetDepartment).collection('attendance').doc(doc.id);
        batch.set(newRef, doc.data());
      }

      // 4. 기존 개인 기도제목 복사
      final prayerSnap = await prayerDataRef.collection('prayer_requests').get();
      for (var doc in prayerSnap.docs) {
        final newRef = firestore.collection('departments').doc(targetDepartment).collection('prayer_requests').doc(doc.id);
        batch.set(newRef, doc.data());
      }

      // 5. 기존 공동 기도제목 복사
      final commonPrayerSnap = await prayerDataRef.collection('common_prayers').get();
      for (var doc in commonPrayerSnap.docs) {
        final newRef = firestore.collection('departments').doc(targetDepartment).collection('common_prayers').doc(doc.id);
        batch.set(newRef, doc.data());
      }

      // 6. 기존 긴급 기도제목 복사
      final urgentPrayerSnap = await prayerDataRef.collection('urgent_prayers').get();
      for (var doc in urgentPrayerSnap.docs) {
        final newRef = firestore.collection('departments').doc(targetDepartment).collection('urgent_prayers').doc(doc.id);
        batch.set(newRef, doc.data());
      }

      // 일괄 저장 실행
      await batch.commit();

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('마이그레이션 완료'),
            content: Text('모든 데이터가 "$targetDepartment" 부서 경로로 안전하게 이동되었습니다.'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인'))],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류 발생: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}