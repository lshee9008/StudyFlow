// ════════════════════════════════════════════════════════════
// firebase_options.dart
// Firebase Console > 프로젝트 설정 > 웹 앱 > SDK 설정에서
// 아래 값들을 교체하세요.
// ════════════════════════════════════════════════════════════
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError('이 플랫폼은 지원되지 않습니다.');
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyB3qiyfvR8BRl0Fy_HEGHsEqSZNdROGmm0",
    authDomain: "studyflow-46be9.firebaseapp.com",
    projectId: "studyflow-46be9",
    storageBucket: "studyflow-46be9.firebasestorage.app",
    messagingSenderId: "295566493508",
    appId: "1:295566493508:web:6e629c3e79c116f0bbb911",
    measurementId: "G-F2YHNNJVKQ",
  );
}
