import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherManagementScreen extends StatefulWidget {
  const TeacherManagementScreen({super.key});

  @override
  State<TeacherManagementScreen> createState() =>
      _TeacherManagementScreenState();
}

class _TeacherManagementScreenState extends State<TeacherManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // 더 밝고 깨끗한 배경색
      appBar: AppBar(
        title: const Text(
          '교사 계정 관리',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('teachers').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                '등록된 교사가 없습니다.',
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
            );
          }

          final teachers = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: teachers.length,
            itemBuilder: (context, index) {
              var teacher = teachers[index];
              var data = teacher.data() as Map<String, dynamic>;
              bool isFirstLogin = data['isFirstLogin'] ?? false;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      // ✅ withOpacity -> withValues(alpha: 0.03)로 수정
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // 1. 순번 표시 영역
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          // ✅ withOpacity -> withValues(alpha: 0.1)로 수정
                          color: Colors.teal.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.teal,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // 2. 정보 표시 영역
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  data['name'] ?? '이름 없음',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${data['cell']}셀',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              data['phone'] ?? '번호 없음',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // 상태 배지
                            _buildStatusBadge(isFirstLogin),
                          ],
                        ),
                      ),

                      // 3. 버튼 영역
                      ElevatedButton(
                        onPressed: () =>
                            _showResetDialog(context, teacher.id, data['name']),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFirstLogin
                              ? const Color(0xFFE2E8F0)
                              : const Color(0xFFFFF1F2),
                          foregroundColor: isFirstLogin
                              ? const Color(0xFF64748B)
                              : const Color(0xFFE11D48),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          isFirstLogin ? '대기중' : '비번 초기화',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // 상태 배지 빌더
  Widget _buildStatusBadge(bool isFirstLogin) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isFirstLogin
            ? const Color(0xFFFEF3C7) // Amber light
            : const Color(0xFFDCFCE7), // Green light
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFirstLogin ? Icons.access_time_filled : Icons.check_circle,
            size: 12,
            color: isFirstLogin
                ? const Color(0xFFD97706)
                : const Color(0xFF16A34A),
          ),
          const SizedBox(width: 4),
          Text(
            isFirstLogin ? '비밀번호 변경 대기' : '정상 사용 중',
            style: TextStyle(
              color: isFirstLogin
                  ? const Color(0xFFD97706)
                  : const Color(0xFF16A34A),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // 초기화 확인 팝업 (모바일 최적화)
  void _showResetDialog(BuildContext context, String docId, String? name) {
    // ✅ 비동기 작업 전에 ScaffoldMessenger와 Navigator 상태를 미리 확보하여 async gap 이슈 해결
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '${name ?? '교사'} 계정 초기화',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '해당 교사가 다음 로그인 시 비밀번호를 다시 설정하도록 플래그를 변경합니다.\n\n'
          '⚠️ 관리자 페이지(Firebase)에서 비밀번호를 임시 비번으로 수동 변경하신 후 실행해주세요.',
          style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF475569)),
        ),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('teachers')
                    .doc(docId)
                    .update({'isFirstLogin': true});
                
                // ✅ 비동기 작업(await) 직후에 mounted 상태를 확인하여 context 안전성 확보
                if (!mounted) return;
                
                // 미리 참조해둔 navigator와 messenger를 사용하여 경고 해결
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: const Text('초기화 상태로 변경되었습니다.'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text('오류 발생: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('실행하기'),
          ),
        ],
      ),
    );
  }
}