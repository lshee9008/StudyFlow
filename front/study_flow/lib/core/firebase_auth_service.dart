import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class FirebaseAuthService {
  static final _auth = FirebaseAuth.instance;
  static final _googleSignIn = GoogleSignIn();

  // ── 이메일 로그인 ──────────────────────────────
  static Future<UserCredential> signInWithEmail(
    String email,
    String password,
  ) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // ── 이메일 회원가입 ────────────────────────────
  static Future<UserCredential> signUpWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await cred.user?.updateDisplayName(displayName);
    return cred;
  }

  // ── 구글 로그인 ────────────────────────────────
  static Future<UserCredential?> signInWithGoogle() async {
    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile');

    if (kIsWeb) {
      // 웹: 팝업을 우선 사용해 Safari/Vercel redirect 세션 유실을 줄이고,
      // 팝업이 막힌 경우에만 redirect로 fallback합니다.
      try {
        return await _auth.signInWithPopup(provider);
      } on FirebaseAuthException catch (e) {
        if (e.code != 'popup-blocked' &&
            e.code != 'operation-not-supported-in-this-environment') {
          rethrow;
        }
        await _auth.signInWithRedirect(provider);
        return null; // 리디렉션 후 getGoogleRedirectResult()로 처리
      }
    } else {
      // 네이티브: GoogleSignIn 패키지
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    }
  }

  // ── 구글 리디렉션 결과 (웹 전용) ──────────────
  static Future<UserCredential?> getGoogleRedirectResult() async {
    if (!kIsWeb) return null;
    try {
      final result = await _auth.getRedirectResult();
      if (result.user != null) return result;
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── 로그아웃 ──────────────────────────────────
  static Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb) await _googleSignIn.signOut();
  }

  // ── Firebase 에러 메시지 한국어 변환 ──────────
  static String friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return '등록되지 않은 이메일입니다.';
      case 'wrong-password':
        return '비밀번호가 올바르지 않습니다.';
      case 'invalid-email':
        return '이메일 형식이 올바르지 않습니다.';
      case 'email-already-in-use':
        return '이미 사용 중인 이메일입니다.';
      case 'weak-password':
        return '비밀번호는 6자 이상이어야 합니다.';
      case 'too-many-requests':
        return '잠시 후 다시 시도해 주세요.';
      case 'account-exists-with-different-credential':
        return '다른 방법으로 이미 가입된 이메일입니다.';
      case 'popup-closed-by-user':
        return '로그인 창이 닫혔습니다.';
      default:
        return '로그인에 실패했습니다. (${e.code})';
    }
  }
}
