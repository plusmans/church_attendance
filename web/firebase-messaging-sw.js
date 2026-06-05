importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js");

// ✅ lib/firebase_options.dart 파일에 있는 web 설정을 참고하여 채워주세요!
firebase.initializeApp({
  apiKey: "AIzaSyDmhLun8MrOZJANF8kEFVLEsevbtWe0x4I", 
  authDomain: "church-attendance-cdb07.firebaseapp.com",
  projectId: "church-attendance-cdb07",
  storageBucket: "church-attendance-cdb07.firebasestorage.app",
  messagingSenderId: "64193540272",
  appId: "1:64193540272:web:ee797e9af7bc35a371cb75"
});

const messaging = firebase.messaging();

// ✅ 백그라운드 알림 수신 시 알림창을 강제로 화면에 띄우는 로직 (복구됨)
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] 백그라운드 알림 수신: ', payload);
  
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: 'icons/Icon-192.png', // ✅ 경로 에러 방지를 위해 슬래시 제거
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// ✅ 사용자가 스마트폰 상단에 뜬 푸시 알림을 탭(클릭)했을 때 앱 화면을 열어주는 로직
self.addEventListener('notificationclick', function(event) {
  event.notification.close(); // 클릭 시 알림창 닫기
  
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(windowClients) {
      if (windowClients.length > 0) {
        // 이미 앱이 백그라운드에 열려있다면 그 화면을 앞으로 가져옴
        return windowClients[0].focus();
      } else {
        // 앱이 완전히 닫혀있다면 새로 실행
        return clients.openWindow('/');
      }
    })
  );
});