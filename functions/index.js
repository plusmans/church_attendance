const {setGlobalOptions} = require("firebase-functions");
const {onRequest} = require("firebase-functions/https");
const logger = require("firebase-functions/logger");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

// ✅ Firebase Admin 초기화 (Firestore 읽기 및 FCM 알림 전송 권한 획득)
admin.initializeApp();

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started


// ✅ 공통: 중등부 교사들에게 푸시 알림을 발송하는 헬퍼 함수
async function notifyAllTeachers(title, content) {
  try {
    const teachersSnapshot = await admin.firestore()
      .collection('departments')
      .doc('중등부')
      .collection('teachers')
      .get();

    const tokens = [];
    teachersSnapshot.forEach(doc => {
      const token = doc.data().fcmToken;
      if (token) {
        tokens.push(token);
      }
    });

    if (tokens.length === 0) {
      logger.log("❌ 알림을 수신할 교사 토큰이 없습니다.");
      return;
    }

    logger.log(`🚀 발송 준비 완료! 총 ${tokens.length}개의 기기로 전송을 시도합니다.`);

    const message = {
      notification: { title: title, body: content.length > 40 ? content.substring(0, 40) + '...' : content },
      data: { screen: 'prayer_screen' }, // 알림 탭 시 기도 화면으로 이동시키는 핵심 데이터!
      tokens: tokens, // 최대 500개까지 한 번에 전송 가능
    };

    const response = await admin.messaging().sendEachForMulticast(message);
    logger.log(`알림 발송 완료 - 성공: ${response.successCount}, 실패: ${response.failureCount}`);
  } catch (error) {
    logger.error("알림 발송 중 에러 발생:", error);
  }
}

// ✅ 1. 일반 중보기도 등록 시 알림 (prayer_requests 컬렉션 감지)
// 한글 경로 오류를 피하기 위해 {departmentId} 와일드카드 사용
exports.sendPrayerNotification = onDocumentCreated("departments/{departmentId}/prayer_requests/{prayerId}", async (event) => {
  logger.log("🔥 [일반 기도 감지됨!] 문서 ID:", event.params.prayerId);

  const snapshot = event.data;
  if (!snapshot) return;

  const prayerData = snapshot.data();
  const author = prayerData.teacherName || '교사';
  
  // ✅ 본문 내용을 고정 문구로 단순화
  const content = '새로운 기도제목이 등록되었습니다.'; 

  const title = `🙏 새로운 중보기도 (${author})`;

  await notifyAllTeachers(title, content);
});

// ✅ 2. 긴급기도 등록 시 알림 (urgent_prayers 컬렉션 감지)
// 한글 경로 오류를 피하기 위해 {departmentId} 와일드카드 사용
exports.sendUrgentPrayerNotification = onDocumentCreated("departments/{departmentId}/urgent_prayers/{prayerId}", async (event) => {
  logger.log("🔥 [긴급 기도 감지됨!] 문서 ID:", event.params.prayerId);
 
  const snapshot = event.data;
  if (!snapshot) return;

  const prayerData = snapshot.data();
  const author = prayerData.authorName || '교사';
  
  // ✅ 본문 내용을 고정 문구로 단순화
  const content = '새로운 긴급 기도제목이 등록되었습니다.'; 

  const title = `🚨 긴급 기도요청 (${author})`;

  await notifyAllTeachers(title, content);
});
