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

  // ✅ 셀 번호를 항상 두 자리(01, 02...)로 만들어주는 안전한 함수
  String _formatCell(String cell) {
    if (cell == '담당' || cell == 'teachers') return cell;
    int? cellNum = int.tryParse(cell);
    if (cellNum != null) {
      return cellNum.toString().padLeft(2, '0');
    }
    return cell;
  }

  // ✅ PDF 총괄 명단 기반 전체 학생 데이터 업데이트
  Future<void> _initializeStudentsFromPdf() async {
    setState(() => _isProcessing = true);
    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // 📝 PDF 1~6페이지의 모든 학생 데이터를 구조화한 리스트
      final List<Map<String, dynamic>> pdfStudentList = [
        // --- 1학년 (13년생) : 1~2셀 ---
        {
          'cell': '1',
          'name': '김지후',
          'grade': '1학년',
          'phone': '01058221215',
          'birthDate': '2013.12.11',
          'baptismStatus': '유아',
        },
        {
          'cell': '1',
          'name': '김예준',
          'grade': '1학년',
          'phone': '01049057675',
          'birthDate': '2013.07.22',
          'baptismStatus': '유아',
          'parentName': '방이숙',
          'address': '부천시 장말로 102 1828-201',
          'siblings': '김라엘',
        },
        {
          'cell': '1',
          'name': '유예준',
          'grade': '1학년',
          'phone': '01049987253',
          'birthDate': '2013.08.12',
          'baptismStatus': '유아',
          'parentName': '이소영',
          'address': '부천중동 그린타운삼성 1303동 1601호',
          'siblings': '유예훈',
          'mbti': 'INTP',
        },
        {
          'cell': '1',
          'name': '신요환',
          'grade': '1학년',
          'phone': '01052361728',
          'birthDate': '2013.12.09',
          'baptismStatus': '유아',
          'address': '상동 행복한마을 금호 2405동 2103호',
          'mbti': 'ENFP',
        },
        {
          'cell': '1',
          'name': '김이현',
          'grade': '1학년',
          'phone': '01066868549',
          'birthDate': '2013.08.28',
          'baptismStatus': 'X',
          'parentName': '용영은',
          'mbti': 'INFJ',
        },
        {
          'cell': '1',
          'name': '오은율',
          'grade': '1학년',
          'phone': '01079122256',
          'birthDate': '2013.07.05',
          'baptismStatus': '유아',
        },
        {
          'cell': '1',
          'name': '박다연',
          'grade': '1학년',
          'phone': '01031772093',
          'birthDate': '2013.02.22',
          'baptismStatus': '모름',
          'parentName': '조미영',
          'mbti': 'Intp',
        },
        {
          'cell': '1',
          'name': '김라현',
          'grade': '1학년',
          'phone': '01039151050',
          'birthDate': '2013.07.12',
          'baptismStatus': 'X',
          'parentName': '박은선',
          'mbti': 'Infp',
        },
        {
          'cell': '1',
          'name': '원지연',
          'grade': '1학년',
          'phone': '01043162053',
          'birthDate': '2013.05.30',
          'school': '성동중',
          'parentName': '곽면선',
        },
        {
          'cell': '1',
          'name': '정나경',
          'grade': '1학년',
          'group': 'B',
          'phone': '',
          'birthDate': '',
          'remarks': '부모님 반대',
        },
        {
          'cell': '1',
          'name': '이소율',
          'grade': '1학년',
          'group': 'B',
          'phone': '01093181767',
          'birthDate': '2013.01.10',
        },
        {
          'cell': '1',
          'name': '이윤서',
          'grade': '1학년',
          'group': 'B',
          'phone': '01082115910',
          'birthDate': '2013.02.25',
        },
        {
          'cell': '1',
          'name': '김민준',
          'grade': '1학년',
          'group': 'B',
          'phone': '01067582211',
          'birthDate': '2013.01.29',
          'school': '상도중',
        },

        {
          'cell': '2',
          'name': '조하율',
          'grade': '1학년',
          'phone': '01076569744',
          'birthDate': '2013.06.26',
          'school': '상동중',
          'baptismStatus': '유아',
          'parentName': '구선영',
          'mbti': 'estp',
        },
        {
          'cell': '2',
          'name': '홍주원',
          'grade': '1학년',
          'phone': '01027932038',
          'birthDate': '2013.01.04',
          'school': '부원중',
          'baptismStatus': '유아',
          'mbti': 'entj',
        },
        {
          'cell': '2',
          'name': '정하율',
          'grade': '1학년',
          'phone': '01097075879',
          'birthDate': '2013.01.07',
          'baptismStatus': '유아',
          'parentName': '김은실',
          'mbti': 'ENFP',
        },
        {
          'cell': '2',
          'name': '김본',
          'grade': '1학년',
          'phone': '01026417745',
          'birthDate': '2013.12.09',
          'school': '석천중',
          'baptismStatus': '유아',
          'parentName': '김서이',
          'mbti': 'ENFP',
        },
        {
          'cell': '2',
          'name': '박성윤',
          'grade': '1학년',
          'phone': '01098191302',
          'birthDate': '2013.08.27',
          'school': '서창중',
          'baptismStatus': '유아',
          'parentName': '김용선',
          'mbti': 'infp',
        },
        {
          'cell': '2',
          'name': '이하준',
          'grade': '1학년',
          'phone': '',
          'birthDate': '2013.11.21',
          'baptismStatus': '유아',
        },
        {
          'cell': '2',
          'name': '이시호',
          'grade': '1학년',
          'phone': '01074806380',
          'birthDate': '2013.04.02',
          'school': '상일중',
          'parentName': '박사미',
        },
        {
          'cell': '2',
          'name': '박하람',
          'grade': '1학년',
          'phone': '01047844429',
          'birthDate': '2013.07.22',
          'school': '석천중',
          'parentName': '김선미',
        },
        {
          'cell': '2',
          'name': '오수현',
          'grade': '1학년',
          'phone': '01087211717',
          'birthDate': '2013.11.13',
          'school': '상일중',
          'parentName': '박지연',
          'mbti': 'ESFP',
        },
        {
          'cell': '2',
          'name': '조수이',
          'grade': '1학년',
          'phone': '',
          'birthDate': '',
          'remarks': '부모님 성함 010-8956-3534',
        },
        {
          'cell': '2',
          'name': '이지훈',
          'grade': '1학년',
          'group': 'B',
          'phone': '',
          'birthDate': '',
        },
        {
          'cell': '2',
          'name': '임현후',
          'grade': '1학년',
          'group': 'B',
          'phone': '01087941153',
          'birthDate': '2013.12.22',
        },
        {
          'cell': '2',
          'name': '오건',
          'grade': '1학년',
          'group': 'B',
          'phone': '01035593099',
          'birthDate': '2013.09.12',
        },
        {
          'cell': '2',
          'name': '신연호',
          'grade': '1학년',
          'group': 'B',
          'phone': '01075898041',
          'birthDate': '2013.11.25',
        },

        // --- 2학년 (12년생) : 3~6셀 ---
        {
          'cell': '3',
          'name': '강규린',
          'grade': '2학년',
          'phone': '01034202563',
          'birthDate': '2012.07.10',
          'school': '상일중',
          'baptismStatus': '유아',
          'parentName': '김남희',
          'mbti': 'ENFP',
        },
        {
          'cell': '3',
          'name': '이서현',
          'grade': '2학년',
          'phone': '01034541925',
          'birthDate': '2012.08.25',
          'school': '상일중',
          'baptismStatus': '유아',
          'parentName': '소지혜',
          'mbti': 'ESFP',
        },
        {
          'cell': '3',
          'name': '이채안',
          'grade': '2학년',
          'phone': '01089135139',
          'birthDate': '2012.01.28',
          'school': '은행중',
          'baptismStatus': '입교',
          'parentName': '이은희',
          'mbti': 'INT',
        },
        {
          'cell': '3',
          'name': '황지영',
          'grade': '2학년',
          'phone': '01056626053',
          'birthDate': '2012.02.13',
          'school': '상일중',
          'parentName': '박정현',
        },
        {
          'cell': '3',
          'name': '김윤재',
          'grade': '2학년',
          'phone': '01082504248',
          'birthDate': '2012.09.14',
          'school': '수명중',
          'baptismStatus': 'X',
          'parentName': '유영화',
          'mbti': 'infp',
        },
        {
          'cell': '3',
          'name': '이라혜',
          'grade': '2학년',
          'phone': '01089093326',
          'birthDate': '2012.10.02',
          'school': '은행중',
          'baptismStatus': '유아',
          'parentName': '김은정',
          'mbti': 'ENFP',
        },
        {
          'cell': '3',
          'name': '이정림',
          'grade': '2학년',
          'phone': '01047952271',
          'birthDate': '2012.08.14',
          'school': '강신중',
          'baptismStatus': '유아',
          'parentName': '박정영',
          'mbti': 'ISTJ',
        },
        {
          'cell': '3',
          'name': '김은채',
          'grade': '2학년',
          'phone': '01089464324',
          'birthDate': '2012.07.29',
          'school': '상일중',
          'parentName': '이경숙',
        },
        {
          'cell': '3',
          'name': '장채린',
          'grade': '2학년',
          'phone': '01073177490',
          'birthDate': '2012.01.03',
          'school': '상일중',
          'parentName': '장광진',
        },
        {
          'cell': '3',
          'name': '김하엘',
          'grade': '2학년',
          'phone': '01051558311',
          'birthDate': '2012.01.07',
          'school': '상동중',
          'parentName': '이정희',
          'mbti': 'ISTP',
        },
        {
          'cell': '3',
          'name': '김주하',
          'grade': '2학년',
          'phone': '01076744375',
          'birthDate': '2012.01.05',
          'school': '상동중',
          'parentName': '이혜영',
        },
        {
          'cell': '3',
          'name': '박하진',
          'grade': '2학년',
          'phone': '01050676920',
          'birthDate': '',
        },

        {
          'cell': '4',
          'name': '음하경',
          'grade': '2학년',
          'phone': '01024230387',
          'birthDate': '2012.11.17',
          'school': '부인중',
          'parentName': '강지연',
          'mbti': 'ENFP',
        },
        {
          'cell': '4',
          'name': '김유나',
          'grade': '2학년',
          'phone': '01098672030',
          'birthDate': '2012.08.10',
          'school': '진산중',
          'parentName': '이지아',
          'mbti': 'ESFP',
        },
        {
          'cell': '4',
          'name': '김아현',
          'grade': '2학년',
          'phone': '01099012336',
          'birthDate': '2012.03.12',
          'school': '석천중',
          'baptismStatus': '유아',
          'parentName': '나애숙',
          'mbti': 'ISFP',
        },
        {
          'cell': '4',
          'name': '장유은',
          'grade': '2학년',
          'phone': '01055917025',
          'birthDate': '2012.07.25',
        },
        {
          'cell': '4',
          'name': '김수아',
          'grade': '2학년',
          'phone': '01037358421',
          'birthDate': '2012.10.11',
          'school': '불로중',
          'parentName': '채선주',
        },
        {
          'cell': '4',
          'name': '주재이',
          'grade': '2학년',
          'phone': '01053903577',
          'birthDate': '2012.02.12',
          'baptismStatus': '모름',
          'mbti': 'INEJ',
        },
        {
          'cell': '4',
          'name': '김아율',
          'grade': '2학년',
          'phone': '01026555362',
          'birthDate': '2012.12.21',
          'school': '부천여중',
        },
        {
          'cell': '4',
          'name': '박지영',
          'grade': '2학년',
          'phone': '01028797619',
          'birthDate': '2012.01.18',
          'school': '상일중',
          'parentName': '안연희',
          'mbti': 'ISFP',
        },
        {
          'cell': '4',
          'name': '최가온',
          'grade': '2학년',
          'group': 'B',
          'phone': '',
          'birthDate': '',
        },

        {
          'cell': '5',
          'name': '신하율',
          'grade': '2학년',
          'phone': '01094050627',
          'birthDate': '2012.06.27',
          'school': '성주중',
          'baptismStatus': '유아',
          'parentName': '한주연',
          'mbti': 'ENFP',
        },
        {
          'cell': '5',
          'name': '최인우',
          'grade': '2학년',
          'phone': '01097376147',
          'birthDate': '2012.08.16',
          'school': '부천중',
          'baptismStatus': '유아',
          'parentName': '김한나',
          'mbti': 'ENFP',
        },
        {
          'cell': '5',
          'name': '유준서',
          'grade': '2학년',
          'phone': '01063167664',
          'birthDate': '2012.05.10',
          'school': '상일중',
          'baptismStatus': '모름',
          'parentName': '이서아',
          'mbti': 'ENTJ',
        },
        {
          'cell': '5',
          'name': '유지훈',
          'grade': '2학년',
          'phone': '01058518289',
          'birthDate': '',
        },
        {
          'cell': '5',
          'name': '유준',
          'grade': '2학년',
          'phone': '',
          'birthDate': '',
          'school': '상업중',
          'parentName': '사모님',
        },
        {
          'cell': '5',
          'name': '장한솔',
          'grade': '2학년',
          'phone': '01055093863',
          'birthDate': '',
        },
        {
          'cell': '5',
          'name': '허민재',
          'grade': '2학년',
          'phone': '01095783592',
          'birthDate': '2012.09.28',
          'school': '상일중',
          'baptismStatus': '모름',
          'parentName': '박세정',
          'mbti': 'ESFJ',
        },
        {
          'cell': '5',
          'name': '송한준',
          'grade': '2학년',
          'phone': '01045646647',
          'birthDate': '2012.04.25',
          'school': '상일중',
          'baptismStatus': '모름',
          'parentName': '한율희',
          'mbti': 'ENFP',
        },
        {
          'cell': '5',
          'name': '김정한',
          'grade': '2학년',
          'phone': '01037568293',
          'birthDate': '2012.03.08',
          'school': '상일중',
          'baptismStatus': '모름',
          'parentName': '유은정',
          'mbti': 'ESTJ',
        },
        {
          'cell': '5',
          'name': '임동윤',
          'grade': '2학년',
          'phone': '01020670377',
          'birthDate': '2012.11.05',
          'school': '상일중',
          'mbti': 'ENFJ',
        },
        {
          'cell': '5',
          'name': '유승현',
          'grade': '2학년',
          'phone': '01050693736',
          'birthDate': '2012.07.16',
          'school': '상일중',
          'baptismStatus': '모름',
          'parentName': '정경희',
          'mbti': 'INFP',
        },
        {
          'cell': '5',
          'name': '정서준',
          'grade': '2학년',
          'phone': '01073727128',
          'birthDate': '2012.01.28',
          'school': '상일중',
          'baptismStatus': '유아',
          'parentName': '유혜진',
          'mbti': 'INFP',
        },

        {
          'cell': '6',
          'name': '장성민',
          'grade': '2학년',
          'phone': '01084817076',
          'birthDate': '2012.01.03',
          'school': '상일중',
          'baptismStatus': '입교',
          'parentName': '이미혜',
          'mbti': 'ENTP',
        },
        {
          'cell': '6',
          'name': '전수혁',
          'grade': '2학년',
          'phone': '01063153261',
          'birthDate': '2012.02.27',
          'school': '상일중',
          'parentName': '박채원',
          'mbti': 'ENFJ',
        },
        {
          'cell': '6',
          'name': '정지훈',
          'grade': '2학년',
          'phone': '01084812180',
          'birthDate': '2012.01.11',
          'school': '상일중',
          'baptismStatus': '모름',
          'parentName': '김수진',
        },
        {
          'cell': '6',
          'name': '정하윤',
          'grade': '2학년',
          'phone': '01057687801',
          'birthDate': '2012.07.12',
          'school': '상동중',
          'baptismStatus': '모름',
          'parentName': '김지현',
          'mbti': 'ISFP',
        },
        {
          'cell': '6',
          'name': '강한결',
          'grade': '2학년',
          'phone': '01091821050',
          'birthDate': '2012.07.26',
          'school': '상동중',
          'baptismStatus': '모름',
          'parentName': '김희은',
          'mbti': 'ISTJ',
        },
        {
          'cell': '6',
          'name': '조하영',
          'grade': '2학년',
          'phone': '01075859744',
          'birthDate': '2012.04.16',
          'school': '상동중',
          'baptismStatus': '유아',
          'parentName': '구선영',
        },
        {
          'cell': '6',
          'name': '임영웅',
          'grade': '2학년',
          'phone': '01054472488',
          'birthDate': '2012.11.16',
          'school': '상동중',
          'baptismStatus': 'X',
        },
        {
          'cell': '6',
          'name': '김범준',
          'grade': '2학년',
          'phone': '01052257228',
          'birthDate': '2012.09.27',
          'school': '상동중',
          'parentName': '김은경',
          'mbti': 'ENFP',
        },
        {
          'cell': '6',
          'name': '이태준',
          'grade': '2학년',
          'phone': '',
          'birthDate': '',
          'school': '상동중',
          'parentName': '박재현',
        },
        {
          'cell': '6',
          'name': '박서준',
          'grade': '2학년',
          'phone': '01026803822',
          'birthDate': '',
          'school': '상일중',
        },
        {
          'cell': '6',
          'name': '김유담',
          'grade': '2학년',
          'phone': '01091222938',
          'birthDate': '2012.04.18',
          'school': '상일중',
        },

        // --- 3학년 (11년생) : 7~10셀 ---
        {
          'cell': '7',
          'name': '김지원',
          'grade': '3학년',
          'phone': '01022781031',
          'birthDate': '2011.11.27',
          'school': '인천여중',
          'baptismStatus': '입교',
          'parentName': '이안진',
          'mbti': 'INFJ',
        },
        {
          'cell': '7',
          'name': '권세윤',
          'grade': '3학년',
          'phone': '01099347379',
          'birthDate': '2011.07.04',
          'school': '부평서여중',
          'baptismStatus': '입교',
          'parentName': '김성미',
          'mbti': 'ISFJ',
        },
        {
          'cell': '7',
          'name': '나윤서',
          'grade': '3학년',
          'phone': '01021299274',
          'birthDate': '2011.05.26',
          'school': '부천여중',
          'baptismStatus': '입교',
          'parentName': '최은미',
          'mbti': 'ESFP',
        },
        {
          'cell': '7',
          'name': '오승현',
          'grade': '3학년',
          'phone': '01024487598',
          'birthDate': '2011.07.18',
          'school': '상일중',
          'parentName': '박지연',
          'mbti': 'INFJ',
        },
        {
          'cell': '7',
          'name': '김지윤',
          'grade': '3학년',
          'phone': '01055684096',
          'birthDate': '2011.09.09',
          'school': '상일중',
          'parentName': '최명진',
          'mbti': 'ISTP',
        },

        {
          'cell': '8',
          'name': '전하율',
          'grade': '3학년',
          'phone': '01099795730',
          'birthDate': '2011.10.06',
          'school': '부인중',
          'baptismStatus': '입교',
          'parentName': '이은영',
          'mbti': 'ESTP',
        },
        {
          'cell': '8',
          'name': '김나희',
          'grade': '3학년',
          'phone': '01084802710',
          'birthDate': '2011.05.16',
          'school': '상일중',
          'baptismStatus': '학습',
          'parentName': '문혜경',
          'mbti': 'INFP',
        },
        {
          'cell': '8',
          'name': '김지현',
          'grade': '3학년',
          'phone': '01036209634',
          'birthDate': '2011.08.13',
          'school': '부천여중',
          'baptismStatus': '학습',
          'parentName': '윤혜연',
          'mbti': 'ESTP',
        },
        {
          'cell': '8',
          'name': '이서윤',
          'grade': '3학년',
          'group': 'B',
          'phone': '01036734060',
          'birthDate': '2011.04.06',
          'school': '삼산중',
          'parentName': '이지연',
          'mbti': 'ISTJ',
        },
        {
          'cell': '8',
          'name': '이혜율',
          'grade': '3학년',
          'phone': '01041893752',
          'birthDate': '2011.05.04',
          'school': '부인중',
          'mbti': 'INFP',
        },
        {
          'cell': '8',
          'name': '김나현',
          'grade': '3학년',
          'group': 'B',
          'phone': '01074555619',
          'birthDate': '2011.09.26',
        },

        {
          'cell': '9',
          'name': '김현성',
          'grade': '3학년',
          'phone': '01056987831',
          'birthDate': '2011.07.01',
          'school': '중원중',
          'baptismStatus': '입교',
          'parentName': '김영진',
          'mbti': 'ESTP',
        },
        {
          'cell': '9',
          'name': '강현호',
          'grade': '3학년',
          'phone': '01076580639',
          'birthDate': '2011.05.12',
          'school': '계남중',
          'baptismStatus': '입교',
          'parentName': '김해숙',
          'mbti': 'ENTP',
        },
        {
          'cell': '9',
          'name': '최은율',
          'grade': '3학년',
          'phone': '01037302437',
          'birthDate': '2011.09.19',
          'school': '중원중',
          'baptismStatus': '입교',
          'parentName': '김지희',
          'mbti': 'ESTP',
        },
        {
          'cell': '9',
          'name': '최다니엘',
          'grade': '3학년',
          'phone': '01052331487',
          'birthDate': '2011.03.11',
          'school': '부일중',
          'baptismStatus': '입교',
          'parentName': '강지연',
          'mbti': 'ENFP',
        },
        {
          'cell': '9',
          'name': '강지인',
          'grade': '3학년',
          'phone': '01050337050',
          'birthDate': '2011.11.08',
          'school': '상일중',
          'parentName': '정은진',
          'mbti': 'INTP',
        },
        {
          'cell': '9',
          'name': '이은호',
          'grade': '3학년',
          'phone': '01073806380',
          'birthDate': '2011.11.09',
          'school': '상일중',
          'baptismStatus': '학습',
          'parentName': '박사미',
        },
        {
          'cell': '9',
          'name': '김동휘',
          'grade': '3학년',
          'phone': '01091299530',
          'birthDate': '2011.09.08',
          'school': '상일중',
          'baptismStatus': '학습',
          'parentName': '이은영',
          'mbti': 'ENFP',
        },

        {
          'cell': '10',
          'name': '배은찬',
          'grade': '3학년',
          'phone': '01084649126',
          'birthDate': '2011.04.27',
          'school': '부명중',
          'baptismStatus': '세례',
          'parentName': '김수정',
          'mbti': 'ENTP',
        },
        {
          'cell': '10',
          'name': '김승범',
          'grade': '3학년',
          'phone': '01021346260',
          'birthDate': '2011.07.05',
          'school': '상일중',
          'baptismStatus': '입고',
          'parentName': '박월수',
          'mbti': 'ISFP',
        },
        {
          'cell': '10',
          'name': '이다윗',
          'grade': '3학년',
          'phone': '01033297158',
          'birthDate': '2011.11.21',
          'school': '부인중',
          'baptismStatus': '학습',
          'parentName': '유에스터',
          'mbti': 'ESFJ',
        },
        {
          'cell': '10',
          'name': '황준서',
          'grade': '3학년',
          'phone': '01033620340',
          'birthDate': '2011.11.28',
          'school': '상일중',
          'baptismStatus': '입교',
          'parentName': '김영미',
          'mbti': 'ISTP',
        },
        {
          'cell': '10',
          'name': '위영진',
          'grade': '3학년',
          'phone': '01079125499',
          'birthDate': '2011.12.03',
          'school': '도담중',
          'baptismStatus': '입교',
          'parentName': '김은진',
          'mbti': 'ESTP',
        },
        {
          'cell': '10',
          'name': '박주원',
          'grade': '3학년',
          'phone': '01035141553',
          'birthDate': '2011.10.04',
          'school': '상일중',
          'baptismStatus': 'X',
          'mbti': 'ENTP',
        },
        {
          'cell': '10',
          'name': '이효진',
          'grade': '3학년',
          'phone': '01076139420',
          'birthDate': '',
          'school': '상도중',
          'parentName': '김은주',
        },
      ];

      for (var s in pdfStudentList) {
        String name = s['name'];
        String rawCell = s['cell'];
        String grade = s['grade'] ?? '1학년';
        String formattedCell = _formatCell(rawCell);

        // 문서 ID 규칙: "01셀_1학년_김지후"
        String docId = '${formattedCell}셀_${grade}_$name';
        DocumentReference ref = FirebaseFirestore.instance
            .collection('students')
            .doc(docId);

        Map<String, dynamic> dataToSet = {
          'name': name,
          'cell': rawCell,
          'grade': grade,
          'phone': (s['phone'] ?? '').toString().replaceAll('-', ''),
          'birthDate': s['birthDate'] ?? '',
          'group': s['group'] ?? 'A',
          'isRegular': s['group'] != 'B',
          'address': s['address'] ?? '',
          'parentName': s['parentName'] ?? '',
          'parentPhone': (s['parentPhone'] ?? '').toString().replaceAll(
            '-',
            '',
          ),
          'school': s['school'] ?? '',
          'baptismStatus': s['baptismStatus'] ?? '',
          'mbti': s['mbti'] ?? '',
          'siblings': s['siblings'] ?? '',
          'churchFriends': s['churchFriends'] ?? '',
          'remarks': s['remarks'] ?? '',
          'role': '학생',
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // merge: true 옵션으로 기존 필드(출석 횟수 등) 보존
        batch.set(ref, dataToSet, SetOptions(merge: true));
      }

      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("👶 총 ${pdfStudentList.length}명의 학생 정보가 업데이트되었습니다."),
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ 업데이트 오류: $e")));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // 교사 담당 정보 업데이트
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
        '김진우': '교사',
        '장흥재': '교사',
        '고은아': '교사',
        '윤필규': '교사',
        '최혜정': '교사',
        '최봉균': '섬김',
        '이해영': '교사',
        '이정민': '교사',
        '최진수': '교사',
        '김정천': '교사',
        '장태윤': '교사',
        '박수빈': '교사',
        '양영환': '교사',
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

  // 교사 연락처 정보 업데이트
  Future<void> _updateTeacherContactInfo() async {
    setState(() => _isProcessing = true);
    try {
      final Map<String, Map<String, String>> pdfTeacherData = {
        '이성은': {'phone': '01041536820', 'birth': '2026년 09월 27일'},
        '김영욱': {'phone': '01045839493', 'birth': '2026년 03월 16일'},
        '이창희': {'phone': '01062800157', 'birth': '2026년 12월 19일'},
        '윤혜진': {'phone': '01027808027', 'birth': '2026년 06월 12일'},
        '김진욱': {'phone': '01034848103', 'birth': '2026년 02월 16일'},
        '김강지': {'phone': '01067049083', 'birth': '2026년 06월 07일'},
        '김시은': {'phone': '01099216332', 'birth': '2026년 01월 24일'},
        '차소정': {'phone': '01023406843', 'birth': '2026년 02월 26일'},
        '김예진': {'phone': '01039451581', 'birth': '2026년 07월 04일'},
        '강현아': {'phone': '01046587702', 'birth': '2026년 03월 25일'},
        '김진우': {'phone': '01024107831', 'birth': '2026년 01월 11일'},
        '장흥재': {'phone': '01054745723', 'birth': '2026년 02월 09일'},
        '고은아': {'phone': '01041003160', 'birth': '2026년 03월 13일'},
        '윤필규': {'phone': '01041523810', 'birth': '2026년 07월 28일'},
        '최혜정': {'phone': '01092883810', 'birth': '2026년 02월 05일'},
        '최봉균': {'phone': '01066574427', 'birth': '2026년 05월 11일'},
        '이해영': {'phone': '01076167620', 'birth': '2026년 11월 30일(음)'},
        '이정민': {'phone': '01094650691', 'birth': '2026년 04월 25일'},
        '최진수': {'phone': '01057171820', 'birth': '2026년 12월 19일'},
        '김정천': {'phone': '01057015239', 'birth': '2026년 09월 07일'},
        '장태윤': {'phone': '01095893160', 'birth': '2026년 07월 29일'},
        '박수빈': {'phone': '01033472725', 'birth': '2026년 09월 06일'},
        '양영환': {'phone': '01028039642', 'birth': '2026년 04월 14일'},
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
              Icons.verified_user_rounded,
              size: 60,
              color: Colors.blueGrey,
            ),
            const SizedBox(height: 10),
            const Text("데이터 안전 병합 모드 (PDF 전체 학생 반영)"),
            const SizedBox(height: 30),

            _buildActionCard(
              title: "전체 학생 상세 정보 업데이트",
              description: "PDF 총괄 명단의 모든 학생(약 80명) 데이터를 DB에 병합합니다.",
              icon: Icons.groups_rounded,
              color: Colors.teal,
              buttonText: "전체 학생 데이터 업데이트 실행",
              onPressed: _initializeStudentsFromPdf,
            ),

            const SizedBox(height: 20),

            _buildActionCard(
              title: "교사 '담당' 필드 추가",
              description: "찬양팀, 기획팀 등 담당 부서 정보를 추가합니다.",
              icon: Icons.assignment_turned_in_rounded,
              color: Colors.blueAccent,
              buttonText: "담당 정보 업데이트 실행",
              onPressed: _updateTeacherAssignmentInfo,
            ),

            const SizedBox(height: 20),

            _buildActionCard(
              title: "교사 연락처 정보 업데이트",
              description: "교사 명단 기준으로 연락처와 생일 정보를 최신화합니다.",
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
