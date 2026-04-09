import 'package:cloud_firestore/cloud_firestore.dart';

/// 학생 및 새친구 등록을 담당하는 공통 서비스 클래스
class StudentService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// 새친구/학생 통합 등록 함수
  /// 
  /// [문서 ID 생성 규칙]: {셀}_${학년}_${이름} (예: 01셀_1학년_홍길동)
  /// [중복 처리]: 동일한 ID가 존재할 경우 이름 뒤에 A, B, C... 접미사를 붙여 고유성을 확보함
  static Future<Map<String, String>> registerStudent({
    required String name,
    required String cell,
    required String grade,
    required String gender,
    String? phone,
    String? birthDate,
    String? school,
    String? address,
    String? parentName,
    String? parentPhone,
    String? notes,
    String? evangelist,
    String? firstVisitDate,
    String? baptismStatus,
    String? churchExperience,
    String? churchName,
    String? mbti,
    String? siblings,
    String? churchFriends,
    bool isNewFriend = true,
  }) async {
    // 1. 셀 번호 패딩 처리 (예: '1' -> '01', '담당' -> '담당')
    String cleanCell = (int.tryParse(cell) ?? cell).toString().padLeft(2, '0');
    
    // 2. 중복을 확인하여 유일한 문서 ID와 최종 이름 결정
    final Map<String, String> uniqueInfo = await _generateUniqueIdAndName(cleanCell, grade, name);
    String finalDocId = uniqueInfo['docId']!;
    String finalName = uniqueInfo['name']!;

    // 3. 저장할 데이터 구조 정의 (필드명 통합)
    final Map<String, dynamic> studentData = {
      'name': finalName,
      'cell': cell, // 원본 셀 번호 문자열 저장
      'grade': grade,
      'gender': gender,
      'phone': phone ?? '',
      'birthDate': birthDate ?? '',
      'school': school ?? '',
      'address': address ?? '미입력',
      'parentName': parentName ?? '',
      'parentPhone': parentPhone ?? '미입력',
      'notes': notes ?? '', // 'memo' 필드 대신 'notes'로 통일
      'role': isNewFriend ? '새친구' : '학생',
      'group': 'B', // 신규 등록 시 무조건 B그룹(관리대상)으로 시작
      'isRegular': false,
      'attendanceCount': 0, // 기본 출석 횟수는 0회
      'firstVisitDate': firstVisitDate ?? '',
      'promotedAt': '',
      'remarks' : '',
      'evangelist': evangelist ?? '미입력',
      'baptismStatus': baptismStatus ?? '해당없음',
      'isBaptized': ['세례', '입교'].contains(baptismStatus),
      'churchExperience': churchExperience ?? '유',
      'churchName': churchName ?? '성문교회',
      'mbti': mbti ?? '미입력',
      'siblings': siblings ?? '미입력',
      'churchFriends': churchFriends ?? '미입력',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // 4. Firestore에 문서 생성 (ID 직접 지정)
    await _db.collection('students').doc(finalDocId).set(studentData);

    return {
      "docId": finalDocId,
      "finalName": finalName,
    };
  }

  /// Firestore를 조회하여 중복되지 않는 문서 ID와 이름을 생성하는 내부 함수
  static Future<Map<String, String>> _generateUniqueIdAndName(
    String cell, 
    String grade, 
    String name
  ) async {
    String baseId = "${cell}셀_${grade}_$name";
    
    // 첫 번째 시도: 기본 ID 확인
    var doc = await _db.collection('students').doc(baseId).get();
    if (!doc.exists) {
      return {"docId": baseId, "name": name};
    }

    // 중복 발생 시 접미사(A, B, C...) 순차적으로 확인
    List<String> suffixes = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J'];
    for (String suffix in suffixes) {
      String candidateName = "$name$suffix";
      String candidateId = "${cell}셀_${grade}_$candidateName";
      
      var checkDoc = await _db.collection('students').doc(candidateId).get();
      if (!checkDoc.exists) {
        return {"docId": candidateId, "name": candidateName};
      }
    }

    // 모든 접미사가 사용 중일 경우 최후의 수단으로 타임스탬프 사용
    String timestampName = "$name${DateTime.now().millisecondsSinceEpoch % 10000}";
    return {
      "docId": "${cell}셀_${grade}_$timestampName",
      "name": timestampName
    };
  }
}