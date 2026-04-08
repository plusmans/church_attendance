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

  // ✅ [최종 완성본] 1~10셀 모든 학생 포함 및 '미입력' 자동 보정 업데이트
  Future<void> _updateStudentDetailedInfo() async {
    setState(() => _isProcessing = true);
    try {
      // 📝 [전체 명단 데이터] 엑셀 및 PDF 원본 기반 (누락 학생 전원 포함)
      final Map<String, Map<String, String>> excelDetailedData = {
        // --- 1셀 ---
        '김지후': {
          'parentPhone': '010-2084-1211',
          'churchName': '성문교회',
          'siblings': 'X',
          'churchFriends': '',
          'address': '인천 연수구 원인재로56 현대아파트',
          'mbti': 'ISTP',
        },
        '김예준': {
          'parentPhone': '010-4428-7675',
          'churchName': '성문교회',
          'siblings': '김라엘 (상동초)',
          'churchFriends': '',
          'address': '부천시 장말로 102 1828-201',
          'mbti': '모름',
        },
        '유예준': {
          'parentPhone': '010-8798-7253',
          'churchName': '성문교회',
          'siblings': '유예훈(청년지구)',
          'churchFriends': '',
          'address': '부천중동 그린타운삼성 1303동 1601호',
          'mbti': 'INTP',
        },
        '신요환': {
          'parentPhone': '010-3435-1728',
          'churchName': '성문교회',
          'siblings': '',
          'churchFriends': '',
          'address': '상동 행복한마을 금호 2405동 2103호',
          'mbti': 'ENFP',
        },
        '김이현': {
          'parentPhone': '010-5324-8549',
          'churchName': '성문교회',
          'siblings': '김선우 (인천중산고)',
          'churchFriends': '',
          'address': '인천 중구 두미포로 112 102동 1002호',
          'mbti': 'INFJ',
        },
        '오은율': {
          'parentPhone': '010-2556-4863',
          'churchName': '성문교회',
          'siblings': '',
          'churchFriends': '박다연',
          'address': '원미구 상동 587-1번지',
          'mbti': '모름',
        },
        '박다연': {
          'parentPhone': '010-5092-2093',
          'churchName': '성문교회',
          'siblings': '박재현(대학생)',
          'churchFriends': '오은율',
          'address': '상이로 69 벚꽃마을 202호',
          'mbti': 'Intp',
        },
        '김라현': {
          'parentPhone': '010-2709-1050',
          'churchName': '부개제일교회',
          'siblings': '김라민(상미초등)',
          'churchFriends': '박다연',
          'address': '부개동',
          'mbti': 'Infp',
        },
        '원지연': {
          'parentPhone': '010-5603-0681',
          'churchName': '성문교회',
          'siblings': '',
          'churchFriends': '',
          'address': '성동',
          'mbti': '',
        },

        // --- 2셀 ---
        '조하율': {
          'parentPhone': '010-2782-9744',
          'churchName': '성문교회',
          'siblings': '조하영(상동중)',
          'churchFriends': '',
          'address': '부천 상미로 9번길 26-3',
          'mbti': 'estp',
        },
        '홍주원': {
          'parentPhone': '010-9129-2567',
          'churchName': '지구촌교회',
          'siblings': '홍지온(상미초)',
          'churchFriends': '조하율',
          'address': '부천시 원미구 신상로91',
          'mbti': 'enti',
        },
        '정하율': {
          'parentPhone': '010-2659-8579',
          'churchName': '성문교회',
          'siblings': '정하랑, 정하엘',
          'churchFriends': '홍주원',
          'address': '인천부평 영성중로16 삼산미래타운 509-804',
          'mbti': 'ENFP',
        },
        '김본': {
          'parentPhone': '010-6528-7745',
          'churchName': '성문교회',
          'siblings': '김담(상인초등학교)',
          'churchFriends': '박성윤',
          'address': '상동로186 다정한마을 2127동 904호',
          'mbti': 'ENFP',
        },
        '박성윤': {
          'parentPhone': '010-4763-1019',
          'churchName': '성문교회',
          'siblings': '박성준, 박성현',
          'churchFriends': '김본',
          'address': '인천남동 장아산로158',
          'mbti': 'infp',
        },
        '이하준': {
          'parentPhone': '010-4340-7035',
          'churchName': '성문교회',
          'siblings': '',
          'churchFriends': '이시호',
          'address': '부천시 원미구 조마루로 104',
          'mbti': '',
        },
        '이시호': {
          'parentPhone': '010-3616-8289',
          'churchName': '성문교회',
          'siblings': '이은호(상일중)',
          'churchFriends': '이하준',
          'address': '부천 상동',
          'mbti': '',
        },
        '박하람': {
          'parentPhone': '010-7654-4429',
          'churchName': '성문교회',
          'siblings': '',
          'churchFriends': '',
          'address': '석천중',
          'mbti': '',
        },
        '오수현': {
          'parentPhone': '010-8721-1717',
          'churchName': '성문교회',
          'siblings': '오승현(상일중)',
          'churchFriends': '조수아',
          'address': '상일중',
          'mbti': 'ESFP',
        },
        '조수아': {
          'parentPhone': '010-8956-3534',
          'churchName': '성문교회',
          'siblings': '',
          'churchFriends': '오수현',
          'address': '',
          'mbti': '',
        },

        // --- 3셀 ---
        '강규린': {
          'parentPhone': '010-6328-2563',
          'churchName': '성문교회',
          'siblings': '강규리, 강규빈',
          'churchFriends': '이채안, 이서현',
          'address': '부천시 조마루로 85번길 24-1',
          'mbti': 'ENFP',
        },
        '이서현': {
          'parentPhone': '010-7208-1925',
          'churchName': '성문교회',
          'siblings': '이예찬(상동고)',
          'churchFriends': '전체 친함',
          'address': '부천 상동 555-13',
          'mbti': 'ESFP',
        },
        '이채안': {
          'parentPhone': '010-8979-5139',
          'churchName': '성문교회',
          'siblings': '이재하',
          'churchFriends': '강규린',
          'address': '시흥 은계남로12',
          'mbti': 'INT',
        },
        '황지영': {
          'parentPhone': '010-7233-0766',
          'churchName': '교회X',
          'siblings': '',
          'churchFriends': '',
          'address': '상동',
          'mbti': '',
        },
        '김윤재': {
          'parentPhone': '010-3292-8788',
          'churchName': '교회X',
          'siblings': '없음',
          'churchFriends': '',
          'address': '서울강서 마곡수명산파크',
          'mbti': 'infp',
        },
        '이라혜': {
          'parentPhone': '010-2485-3316',
          'churchName': '사랑스러운교회',
          'siblings': '이주혜',
          'churchFriends': '이청림',
          'address': '시흥시 은계남로12',
          'mbti': 'ENFP',
        },
        '이정림': {
          'parentPhone': '010-3732-2271',
          'churchName': '성문교회',
          'siblings': '이청운',
          'churchFriends': '이라혜, 강규린',
          'address': '신월동 남부순환로',
          'mbti': 'ISTJ',
        },
        '김은채': {
          'parentPhone': '010-8964-4324',
          'churchName': '교회X',
          'siblings': '',
          'churchFriends': '',
          'address': '행복한마을 금호A',
          'mbti': '',
        },
        '장채린': {
          'parentPhone': '010-5511-9775',
          'churchName': '성문교회',
          'siblings': '',
          'churchFriends': '',
          'address': '상일중',
          'mbti': '',
        },
        '김하엘': {
          'parentPhone': '010-7576-6669',
          'churchName': '타교회',
          'siblings': '김하준',
          'churchFriends': '강규린, 이채안',
          'address': '상동 금호어울림',
          'mbti': 'ISTP',
        },
        '김주하': {
          'parentPhone': '010-8648-0919',
          'churchName': '성문교회',
          'siblings': '',
          'churchFriends': '',
          'address': '상동중',
          'mbti': '',
        },
        '박하진': {
          'parentPhone': '미입력',
          'churchName': '미입력',
          'siblings': '',
          'churchFriends': '',
          'address': '',
          'mbti': '',
        },

        // --- 4셀 ---
        '음하경': {
          'parentPhone': '010-4129-0387',
          'churchName': '성문교회',
          'siblings': '음하연',
          'churchFriends': '박지영',
          'address': '부천시 조마루로 105번길 18',
          'mbti': 'ENFP',
        },
        '김유나': {
          'parentPhone': '010-9592-2030',
          'churchName': '성문교회',
          'siblings': '수현, 세현, 우현',
          'churchFriends': '',
          'address': '인천부평 굴포로105',
          'mbti': 'ESFP',
        },
        '김아현': {
          'parentPhone': '010-9782-1108',
          'churchName': '성문교회',
          'siblings': '',
          'churchFriends': '주재이',
          'address': '부천 도약로81',
          'mbti': 'ISFP',
        },
        '장유은': {
          'parentPhone': '미입력',
          'churchName': '미입력',
          'siblings': '',
          'churchFriends': '',
          'address': '',
          'mbti': '',
        },
        '김수아': {
          'parentPhone': '010-6398-9163',
          'churchName': '성문교회',
          'siblings': '',
          'churchFriends': '김아현',
          'address': '인천 고산후로',
          'mbti': '',
        },
        '주재이': {
          'parentPhone': '010-6398-9163',
          'churchName': '성문교회',
          'siblings': '주은선, 주아현',
          'churchFriends': '김아현',
          'address': '인천 고산후로249',
          'mbti': 'INEJ',
        },
        '김아율': {
          'parentPhone': '010-8844-5362',
          'churchName': '성문교회',
          'siblings': '',
          'churchFriends': '',
          'address': '중동',
          'mbti': '',
        },
        '박지영': {
          'parentPhone': '010-4244-5515',
          'churchName': '교회X',
          'siblings': '박주영',
          'churchFriends': '음하경',
          'address': '부천시 원미구 조마루로',
          'mbti': 'ISFP',
        },
        '최가온': {
          'parentPhone': '미입력',
          'churchName': '미입력',
          'siblings': '',
          'churchFriends': '',
          'address': '새친구',
          'mbti': '',
        },

        // --- 5셀 ---
        '신하율': {
          'parentPhone': '010-3846-4288',
          'churchName': '성문교회',
          'siblings': 'X',
          'churchFriends': '준서, 영진',
          'address': '부천 경인로26번길 자이',
          'mbti': 'ENFP',
        },
        '최인우': {
          'parentPhone': '010-8537-6147',
          'churchName': '성문교회',
          'siblings': '죄인아',
          'churchFriends': '신하율',
          'address': '부천 창말로176번길 39-12',
          'mbti': 'ENFP',
        },
        '유준서': {
          'parentPhone': '010-3266-7664',
          'churchName': '교회X',
          'siblings': 'X',
          'churchFriends': '김정한, 송한준',
          'address': '부천 부흥로49 백송마을',
          'mbti': 'ENTJ',
        },
        '유지훈': {
          'parentPhone': '미입력',
          'churchName': '미입력',
          'siblings': '',
          'churchFriends': '',
          'address': '',
          'mbti': '',
        },
        '유준': {
          'parentPhone': '010-5337-2075',
          'churchName': '성문교회',
          'siblings': '',
          'churchFriends': '',
          'address': '상업중 인근',
          'mbti': '',
        },
        '장한솔': {
          'parentPhone': '010-5337-2075',
          'churchName': '성문교회',
          'siblings': '',
          'churchFriends': '',
          'address': '',
          'mbti': '',
        },
        '허민재': {
          'parentPhone': '010-9128-3592',
          'churchName': '교회X',
          'siblings': '허민성',
          'churchFriends': '김정한',
          'address': '상동 한양아파트',
          'mbti': 'ESFJ',
        },
        '송한준': {
          'parentPhone': '010-4238-6647',
          'churchName': '교회',
          'siblings': 'X',
          'churchFriends': '정한, 성민',
          'address': '상동 백송마을자이',
          'mbti': 'ENFP',
        },
        '김정한': {
          'parentPhone': '010-6267-5138',
          'churchName': '교회X',
          'siblings': '',
          'churchFriends': '송한준',
          'address': '상동 행복한마을 2403동',
          'mbti': 'ESTJ',
        },
        '임동윤': {
          'parentPhone': '010-2812-4085',
          'churchName': '교회X',
          'siblings': '',
          'churchFriends': '김정한',
          'address': '상일중 인근',
          'mbti': 'ENFJ',
        },
        '유승현': {
          'parentPhone': '010-5091-3174',
          'churchName': '교회X',
          'siblings': '유승주',
          'churchFriends': '김정한',
          'address': '상일중 인근',
          'mbti': 'INFP',
        },
        '정서준': {
          'parentPhone': '010-8653-5892',
          'churchName': '성문교회',
          'siblings': '정민지',
          'churchFriends': '전수혁',
          'address': '상동 백송자이',
          'mbti': 'INFP',
        },

        // --- 6셀 ---
        '장성민': {
          'parentPhone': '010-9910-0067',
          'churchName': '성문교회',
          'siblings': '장동욱',
          'churchFriends': '정하윤',
          'address': '상동 하얀마을 2601-201',
          'mbti': 'ENTP',
        },
        '전수혁': {
          'parentPhone': '010-9507-9350',
          'churchName': '타교회',
          'siblings': '전수아',
          'churchFriends': '장성민',
          'address': '상동 조마루로48',
          'mbti': 'ENFJ',
        },
        '정지훈': {
          'parentPhone': '010-7303-2180',
          'churchName': '타교회',
          'siblings': '',
          'churchFriends': '전수혁',
          'address': '상일중 인근',
          'mbti': '',
        },
        '정하윤': {
          'parentPhone': '010-8495-7801',
          'churchName': '타교회',
          'siblings': '정시훈',
          'churchFriends': '박서준',
          'address': '부천원미 상이로51번길',
          'mbti': 'ISFP',
        },
        '강한결': {
          'parentPhone': '010-8628-1050',
          'churchName': '성문교회',
          'siblings': '',
          'churchFriends': '',
          'address': '상동중',
          'mbti': 'ISTJ',
        },
        '조하영': {
          'parentPhone': '010-2782-9744',
          'churchName': '성문교회',
          'siblings': '조하율',
          'churchFriends': '신하율',
          'address': '부천원미 상이로9번딜',
          'mbti': '',
        },
        '임영웅': {
          'parentPhone': '미입력',
          'churchName': '교회X',
          'siblings': '임예린, 임예빈',
          'churchFriends': '조하영',
          'address': '상이로 81',
          'mbti': '',
        },
        '김범준': {
          'parentPhone': '010-9008-2291',
          'churchName': '성문교회',
          'siblings': 'X',
          'churchFriends': '장성민',
          'address': '상동중',
          'mbti': 'ENFP',
        },
        '이태준': {
          'parentPhone': '010-7420-0806',
          'churchName': '교회X',
          'siblings': '',
          'churchFriends': '',
          'address': '태산아파트',
          'mbti': '',
        },
        '박서준': {
          'parentPhone': '미입력',
          'churchName': '성문교회',
          'siblings': '',
          'churchFriends': '장성민',
          'address': '상일중 인근',
          'mbti': '',
        },
        '김유담': {
          'parentPhone': '010-9122-2938',
          'churchName': '미입력',
          'siblings': '',
          'churchFriends': '',
          'address': '상일중',
          'mbti': '',
        },

        // --- 7셀 ---
        '김지원': {
          'parentPhone': '010-4197-8033',
          'churchName': '성문교회',
          'siblings': '김민수, 김민재',
          'churchFriends': '나윤서, 전하율',
          'address': '인천 동춘동 원인재로56',
          'mbti': 'INFJ',
        },
        '권세윤': {
          'parentPhone': '010-5040-7379',
          'churchName': '타교회',
          'siblings': '권세은, 권세희',
          'churchFriends': '전하율',
          'address': '인천 산곡3동 현대a',
          'mbti': 'ISFJ',
        },
        '나윤서': {
          'parentPhone': '010-4991-9274',
          'churchName': '성문교회',
          'siblings': '나수연, 나가연',
          'churchFriends': '김지원',
          'address': '부천역 푸르지오A',
          'mbti': 'ESFP',
        },
        '오승현': {
          'parentPhone': '010-8721-1717',
          'churchName': '성문교회',
          'siblings': '오수현',
          'churchFriends': '김지윤',
          'address': '서해그랑블 2406-102',
          'mbti': 'INFJ',
        },
        '김지윤': {
          'parentPhone': '010-5496-5037',
          'churchName': '성문교회',
          'siblings': '김건우',
          'churchFriends': '오승현',
          'address': '상동로 25',
          'mbti': 'ISTP',
        },

        // --- 8셀 ---
        '전하율': {
          'parentPhone': '010-9797-7908',
          'churchName': '타교회',
          'siblings': '전하리',
          'churchFriends': '권세윤',
          'address': '상일로 71',
          'mbti': 'ESTP',
        },
        '김나희': {
          'parentPhone': '010-9451-2710',
          'churchName': '성문교회',
          'siblings': '태현, 태희',
          'churchFriends': '나윤서',
          'address': '하얀마을 2613',
          'mbti': 'INFP',
        },
        '김지현': {
          'parentPhone': '010-9310-9634',
          'churchName': '교화X',
          'siblings': '수현',
          'churchFriends': '',
          'address': '경인로29번길',
          'mbti': 'ESTP',
        },
        '이서윤': {
          'parentPhone': '010-5261-7191',
          'churchName': '교회X',
          'siblings': '이지훈',
          'churchFriends': '미입력',
          'address': '후정도로 12',
          'mbti': 'ISTJ',
        },
        '이혜율': {
          'parentPhone': '010-9190-3752',
          'churchName': '성문교회',
          'siblings': '이온을',
          'churchFriends': '',
          'address': '상동 삼익아파트',
          'mbti': 'INFP',
        },
        '김나현': {
          'parentPhone': '010-7455-5619',
          'churchName': '미입력',
          'siblings': '',
          'churchFriends': '',
          'address': '',
          'mbti': '',
        },

        // --- 9셀 ---
        '김예나': {
          'parentPhone': '미입력',
          'churchName': '성문교회',
          'siblings': '',
          'churchFriends': '',
          'address': '',
          'mbti': '',
        },
        '김현성': {
          'parentPhone': '010-6822-4749',
          'churchName': '성문교회',
          'siblings': '김다현',
          'churchFriends': '강현호',
          'address': '한라마을3단지',
          'mbti': 'ESTP',
        },
        '강현호': {
          'parentPhone': '010-4470-7702',
          'churchName': '성문교회',
          'siblings': '현아, 현수',
          'churchFriends': '김현성',
          'address': '중동로 204',
          'mbti': 'ENTP',
        },
        '최은율': {
          'parentPhone': '010-8643-7437',
          'churchName': '성문교회',
          'siblings': '최은서',
          'churchFriends': '김승범',
          'address': '약대 아이파크',
          'mbti': 'ESTP',
        },
        '최다니엘': {
          'parentPhone': '010-9135-1487',
          'churchName': '성문교회',
          'siblings': '최온유',
          'churchFriends': '황준서',
          'address': '삼산주공미래타운',
          'mbti': 'ENFP',
        },
        '강지인': {
          'parentPhone': '010-4726-7050',
          'churchName': '성문교회',
          'siblings': '강지후',
          'churchFriends': 'X',
          'address': '신상로 91',
          'mbti': 'INTP',
        },
        '이은호': {
          'parentPhone': '010-3616-8289',
          'churchName': '성문교회',
          'siblings': '이시호',
          'churchFriends': '',
          'address': '상일중',
          'mbti': '미입력',
        },
        '김동휘': {
          'parentPhone': '010-6248-9530',
          'churchName': '성문교회',
          'siblings': '',
          'churchFriends': '배은찬',
          'address': '서해그랑블 2412',
          'mbti': 'ENFP',
        },

        // --- 10셀 ---
        '배은찬': {
          'parentPhone': '010-4608-7046',
          'churchName': '성문교회',
          'siblings': '배은서',
          'churchFriends': '위영진',
          'address': '중동 보람마을',
          'mbti': 'ENTP',
        },
        '김승범': {
          'parentPhone': '010-4092-6260',
          'churchName': '성문교회',
          'siblings': '김승준',
          'churchFriends': '현성',
          'address': '현대아이파크',
          'mbti': 'ISFP',
        },
        '이다윗': {
          'parentPhone': '010-7757-7158',
          'churchName': '은광교회',
          'siblings': '이요셉',
          'churchFriends': '황준서',
          'address': '상이로39번길',
          'mbti': 'ESFJ',
        },
        '황준서': {
          'parentPhone': '010-8972-5522',
          'churchName': '성문교회',
          'siblings': '황세나',
          'churchFriends': '김승범',
          'address': '상동 하얀마을 2605',
          'mbti': 'ISTP',
        },
        '위영진': {
          'parentPhone': '010-3160-5499',
          'churchName': '성문교회',
          'siblings': '위영호',
          'churchFriends': '이다윗',
          'address': '도당동 112',
          'mbti': 'ESTP',
        },
        '박주원': {
          'parentPhone': '010-3514-1553',
          'churchName': '성문교회',
          'siblings': '미입력',
          'churchFriends': '이다윗',
          'address': '부천 하얀마을',
          'mbti': 'ENTP',
        },
        '이효진': {
          'parentPhone': '010-2817-9420',
          'churchName': '성문교회',
          'siblings': '미입력',
          'churchFriends': '미입력',
          'address': '장말로 188번길',
          'mbti': '미입력',
        },
      };

      var snapshot = await FirebaseFirestore.instance
          .collection('students')
          .get();
      if (snapshot.docs.isEmpty) throw "DB에 등록된 학생이 없습니다.";

      WriteBatch batch = FirebaseFirestore.instance.batch();
      int updateCount = 0;

      for (var doc in snapshot.docs) {
        String dbName = (doc.data()['name'] ?? '').toString().trim();

        if (excelDetailedData.containsKey(dbName)) {
          var info = excelDetailedData[dbName]!;

          // ✅ 비어있거나 부정적인 의미의 단어는 모두 '미입력'으로 처리
          String safeUpdate(String key) {
            String val = (info[key] ?? '').trim();
            if (val.isEmpty ||
                val == 'X' ||
                val == '정보없음' ||
                val == '미등록' ||
                val == '없음') {
              return '미입력';
            }
            return val;
          }

          batch.update(doc.reference, {
            'parentPhone': safeUpdate('parentPhone'),
            'churchName': safeUpdate('churchName'),
            'siblings': safeUpdate('siblings'),
            'churchFriends': safeUpdate('churchFriends'),
            'address': safeUpdate('address'),
            'mbti': safeUpdate('mbti'),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          updateCount++;
        }
      }

      if (updateCount > 0) {
        await batch.commit();
        if (mounted)
          _showResultSnackBar(
            "📑 $updateCount명의 모든 학생 정보가 '미입력' 보정 포함 업데이트되었습니다.",
          );
      } else {
        if (mounted) _showResultSnackBar("⚠️ 일치하는 학생 이름을 찾지 못했습니다.");
      }
    } catch (e) {
      if (mounted) _showResultSnackBar("❌ 업데이트 오류: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showResultSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.indigo.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '전체 셀 데이터 최종 동기화',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(
              Icons.verified_user_rounded,
              size: 80,
              color: Colors.indigo,
            ),
            const SizedBox(height: 16),
            const Text(
              "1~10셀 누락 없는 데이터 주입",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "7~9셀을 포함하여 모든 셀의 누락된 학생 정보를 복구했습니다.\n비어있는 정보는 자동으로 '미입력' 처리됩니다.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),

            _buildActionCard(
              title: "최종 전수 동기화 실행",
              description: "부모님 번호, 주소, 형제, MBTI, 친구 정보를 실제 명단 기준으로 업데이트합니다.",
              icon: Icons.storage_rounded,
              color: Colors.orange.shade800,
              buttonText: "전체 데이터 업데이트 실행",
              onPressed: _updateStudentDetailedInfo,
            ),

            const SizedBox(height: 20),
            const Text(
              "⚠️ DB 명단과 이름이 일치하는 학생만 선별하여 업데이트합니다.",
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
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
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
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
