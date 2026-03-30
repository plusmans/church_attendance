import 'package:flutter/material.dart';

void main() {
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // 우측 상단 'DEBUG' 띠 제거
      title: '중등부 출석부',
      theme: ThemeData(
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[100], // 앱 배경을 살짝 회색으로
      ),
      home: const AttendanceScreen(),
    );
  }
}

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  // 1. 가상의 학생 명단 (나중에 Firebase DB에서 불러올 자리입니다)
  final List<String> students = ['김민수', '이지은', '박도윤', '최서연', '정하준'];
  
  // 2. 출석 상태를 저장하는 공간 (이름 : 출석여부)
  final Map<String, bool> attendanceStatus = {};

  @override
  void initState() {
    super.initState();
    // 처음 화면이 켜질 때 모든 학생을 '결석(false)' 상태로 세팅
    for (var student in students) {
      attendanceStatus[student] = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 실시간으로 출석(true) 체크된 학생 수 계산
    int presentCount = attendanceStatus.values.where((status) => status).length;

    return Scaffold(
      // [상단바 영역]
      appBar: AppBar(
        title: const Text('1학년 1반 출석부', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      
      // [중앙 메인 영역]
      body: Column(
        children: [
          // 날짜 및 통계 요약 박스
          Container(
            padding: const EdgeInsets.all(20.0),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('2026년 3월 29일 주일', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('오늘의 나눔: 히브리서 4장', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '출석 $presentCount / 총 ${students.length}명',
                    style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          
          // 학생 리스트 (스크롤 가능)
          Expanded(
            child: ListView.builder(
              itemCount: students.length,
              itemBuilder: (context, index) {
                String studentName = students[index];
                bool isPresent = attendanceStatus[studentName]!;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.grey.shade300, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    title: Text(
                      studentName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    // 출석/결석 토글 스위치
                    trailing: Switch(
                      value: isPresent,
                      activeColor: Colors.green,
                      onChanged: (value) {
                        setState(() {
                          attendanceStatus[studentName] = value; // 스위치를 누르면 상태 변경
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      
      // [하단 고정 영역]
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: () {
              // 나중에 이 버튼을 누르면 Firebase로 데이터가 쏘아집니다.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('출석 데이터가 임시 저장되었습니다!')),
              );
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '출석 저장하기',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}