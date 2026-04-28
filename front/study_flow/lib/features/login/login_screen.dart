import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/firebase_auth_service.dart';
import '../../core/theme.dart';
import '../../core/ui/app_components.dart';
import '../../providers/user_provider.dart';
import '../home/home_screen.dart';
import 'auth_shared.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy        = false;
  bool _googleBusy  = false;
  String? _message;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── 이메일 로그인 ──────────────────────────────
  Future<void> _login() async {
    final email    = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _message = '이메일과 비밀번호를 입력해 주세요.');
      return;
    }

    setState(() { _busy = true; _message = null; });

    try {
      final cred = await FirebaseAuthService.signInWithEmail(email, password);
      if (!mounted) return;
      final error = await ref
          .read(userProvider.notifier)
          .loginWithFirebase(cred.user!);
      if (!mounted) return;
      if (error == null) { _goHome(); return; }
      setState(() { _busy = false; _message = error; });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() { _busy = false; _message = FirebaseAuthService.friendlyError(e); });
    } catch (_) {
      if (!mounted) return;
      setState(() { _busy = false; _message = '로그인에 실패했습니다.'; });
    }
  }

  // ── Google 로그인 ──────────────────────────────
  Future<void> _loginGoogle() async {
    setState(() { _googleBusy = true; _message = null; });

    try {
      final cred = await FirebaseAuthService.signInWithGoogle();
      if (cred == null) { setState(() => _googleBusy = false); return; }
      if (!mounted) return;
      final error = await ref
          .read(userProvider.notifier)
          .loginWithFirebase(cred.user!);
      if (!mounted) return;
      if (error == null) { _goHome(); return; }
      setState(() { _googleBusy = false; _message = error; });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() { _googleBusy = false; _message = FirebaseAuthService.friendlyError(e); });
    } catch (_) {
      if (!mounted) return;
      setState(() { _googleBusy = false; _message = 'Google 로그인에 실패했습니다.'; });
    }
  }

  void _goHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      child: AuthSplitLayout(
        left: const AuthHero(
          eyebrow: '로그인',
          title: '바로 이어서\n작업합니다.',
          body: '이전 학습 흐름과 최근 노트를 빠르게 다시 불러옵니다.',
          items: [
            (LucideIcons.folderOpen, '최근 프로젝트 이어가기'),
            (LucideIcons.sparkles,   '요약과 그래프 이어보기'),
            (LucideIcons.search,     '문맥 검색 유지'),
          ],
        ),
        right: AuthPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AuthHeader(title: '로그인', subtitle: '계정을 선택하거나 이메일로 입력하세요.'),
              const SizedBox(height: 24),

              // ── Google 버튼 ──────────────────────
              _GoogleSignInButton(
                busy: _googleBusy,
                onPressed: _loginGoogle,
              ),
              const SizedBox(height: 20),

              // ── 구분선 ───────────────────────────
              _OrDivider(),
              const SizedBox(height: 20),

              // ── 이메일 / 비밀번호 ─────────────────
              AppInput(
                controller: _emailController,
                hintText: 'name@example.com',
                label: '이메일',
                icon: LucideIcons.mail,
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: AppSpace.md),
              AppInput(
                controller: _passwordController,
                hintText: '비밀번호',
                label: '비밀번호',
                icon: LucideIcons.lock,
                obscureText: true,
                onSubmitted: (_) => _login(),
              ),

              if (_message != null) ...[
                const SizedBox(height: AppSpace.md),
                AppInlineMessage(message: _message!),
              ],

              const SizedBox(height: AppSpace.lg),
              AppButton(
                label: '로그인',
                onPressed: _busy ? null : _login,
                busy: _busy,
                width: double.infinity,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Google 로그인 버튼 ───────────────────────────────────────

class _GoogleSignInButton extends StatefulWidget {
  final bool busy;
  final VoidCallback onPressed;
  const _GoogleSignInButton({required this.busy, required this.onPressed});

  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.busy ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 48,
          decoration: BoxDecoration(
            color: _hovered
                ? (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8F8F8))
                : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered
                  ? colors.accent.withValues(alpha: 0.4)
                  : colors.border,
              width: 1.5,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: widget.busy
              ? Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.accent,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _GoogleLogo(size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Google로 계속하기',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1F1F1F),
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── Google "G" 로고 (CustomPainter) ─────────────────────────

class _GoogleLogo extends StatelessWidget {
  final double size;
  const _GoogleLogo({this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final r  = w / 2;

    // 원형 클립
    canvas.clipRRect(RRect.fromRectAndRadius(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      Radius.circular(r),
    ));

    // 배경 흰색
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()..color = Colors.white);

    // 4색 호 (빨/노/초/파)
    const colors = [
      Color(0xFFEA4335), // 빨간
      Color(0xFFFBBC05), // 노란
      Color(0xFF34A853), // 초록
      Color(0xFF4285F4), // 파란
    ];
    const sweeps = [
      90.0, 90.0, 90.0, 90.0,
    ];
    const starts = [
      -180.0, -90.0, 0.0, 90.0,
    ];

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.28;

    final arcR = r * 0.72;
    final arcRect = Rect.fromCircle(
      center: Offset(cx, cy),
      radius: arcR,
    );

    for (int i = 0; i < 4; i++) {
      arcPaint.color = colors[i];
      canvas.drawArc(
        arcRect,
        starts[i] * (3.14159265 / 180),
        sweeps[i] * (3.14159265 / 180),
        false,
        arcPaint,
      );
    }

    // 중앙 흰 원 (도넛 효과)
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.44,
      Paint()..color = Colors.white,
    );

    // 파란 직사각형 (오른쪽 연장선)
    final rectPaint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - w * 0.14, r * 1.0, w * 0.28),
      rectPaint,
    );

    // 흰 원 다시 덮기
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.44,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─── "또는" 구분선 ────────────────────────────────────────────

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Row(
      children: [
        Expanded(child: Divider(color: colors.border, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '또는 이메일로',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary.withValues(alpha: 0.6),
            ),
          ),
        ),
        Expanded(child: Divider(color: colors.border, height: 1)),
      ],
    );
  }
}
