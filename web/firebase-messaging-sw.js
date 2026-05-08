// 1. 브라우저 백그라운드용 Firebase JS SDK 불러오기
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js");

// 2. 프로젝트의 Firebase 웹 설정값 등록 (firebase_options.dart 파일 내용과 동일)
const firebaseConfig = {
  apiKey: 'AIzaSyDmhLun8MrOZJANF8kEFVLEsevbtWe0x4I',
  appId: '1:64193540272:web:ee797e9af7bc35a371cb75',
  messagingSenderId: '64193540272',
  projectId: 'church-attendance-cdb07',
  authDomain: 'church-attendance-cdb07.firebaseapp.com',
  storageBucket: 'church-attendance-cdb07.firebasestorage.app',
  measurementId: 'G-ZZJDFCW88W'
};

// 3. 앱 초기화 및 백그라운드 메시징 객체 생성
firebase.initializeApp(firebaseConfig);
const messaging = firebase.messaging();