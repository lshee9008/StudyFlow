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

class CreateMembershipScreen extends ConsumerStatefulWidget {
  const CreateMembershipScreen({super.key});

  @override
  ConsumerState<CreateMembershipScreen> createState() =>
      _CreateMembershipScreenState();
}

class _CreateMembershipScreenState
    extends ConsumerState<CreateMembershipScreen> {
  final _nameController     = TextEditingController();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();
  bool _busy        = false;
  bool _googleBusy  = false;
  String? _message;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ── 이메일 회원가입 ──────────────────────────────
  Future<void> _signup() async {
    final name     = _nameController.text.trim();
    final email    = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm  = _confirmController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _message = '모든 항목을 입력해 주세요.');
      return;
    }
    if (name.length < 2) {
      setState(() => _message = '이름은 2자 이상이어야 합니다.');
      return;
    }
    if (!email.contains('@')) {
      setState(() => _message = '올바른 이메일 주소를 입력해 주세요.');
      return;
    }
    if (password.length < 6) {
      setState(() => _message = '비밀번호는 6자 이상이어야 합니다.');
      return;
    }
    if (password != confirm) {
      setState(() => _message = '비밀번호가 일치하지 않습니다.');
      return;
    }

    setState(() { _busy = true; _message = null; });

    try {
      final cred = await FirebaseAuthService.signUpWithEmail(
        email,
        password,
        name,
      );
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
      setState(() { _busy = false; _message = '가입에 실패했습니다.'; });
    }
  }

  // ── Google 회원가입/로그인 ──────────────────────
  Future<void> _signupGoogle() async {
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
          eyebrow: '회원가입',
          title: '새 계정을 만들고\n바로 시작합니다.',
          body: '프로젝트와 노트를 저장하고, 요약·검색 기능을 모두 사용할 수 있습니다.',
          items: [
            (LucideIcons.folderKanban, '프로젝트와 노트 저장'),
            (LucideIcons.sparkles,     '요약과 복습 사용'),
            (LucideIcons.search,       '검색 흐름 유지'),
          ],
        ),
        right: AuthPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AuthHeader(title: '계정 만들기', subtitle: '계정을 선택하거나 이메일로 입력하세요.'),
              const SizedBox(height: 24),

              // ── Google 버튼 ──────────────────────
              _GoogleSignUpButton(
                busy: _googleBusy,
                onPressed: _signupGoogle,
              ),
              const SizedBox(height: 20),

              // ── 구분선 ───────────────────────────
              _OrDivider(),
              const SizedBox(height: 20),

              // ── 이름 ─────────────────────────────
              AppInput(
                controller: _nameController,
                hintText: '홍길동',
                label: '이름',
                icon: LucideIcons.user,
                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              ),
              const SizedBox(height: AppSpace.md),

              // ── 이메일 ───────────────────────────
              AppInput(
                controller: _emailController,
                hintText: 'name@example.com',
                label: '이메일',
                icon: LucideIcons.mail,
                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              ),
              const SizedBox(height: AppSpace.md),

              // ── 비밀번호 ─────────────────────────
              AppInput(
                controller: _passwordController,
                hintText: '6자 이상',
                label: '비밀번호',
                icon: LucideIcons.lock,
                obscureText: true,
                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              ),
              const SizedBox(height: AppSpace.md),

              // ── 비밀번호 확인 ────────────────────
              AppInput(
                controller: _confirmController,
                hintText: '비밀번호 확인',
                label: '비밀번호 확인',
                icon: LucideIcons.shieldCheck,
                obscureText: true,
                onSubmitted: (_) => _signup(),
              ),

              if (_message != null) ...[
                const SizedBox(height: AppSpace.md),
                AppInlineMessage(message: _message!),
              ],

              const SizedBox(height: AppSpace.lg),
              AppButton(
                label: '가입',
                onPressed: _busy ? null : _signup,
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

// ─── Google 가입 버튼 ──────────────────────────────────────────

class _GoogleSignUpButton extends StatefulWidget {
  final bool busy;
  final VoidCallback onPressed;
  const _GoogleSignUpButton({required this.busy, required this.onPressed});

  @override
  State<_GoogleSignUpButton> createState() => _GoogleSignUpButtonState();
}

class _GoogleSignUpButtonState extends State<_GoogleSignUpButton> {
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
    final w  = size.width;
    final h  = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final r  = w / 2;

    canvas.clipRRect(RRect.fromRectAndRadius(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      Radius.circular(r),
    ));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = Colors.white);

    const colors = [
      Color(0xFFEA4335),
      Color(0xFFFBBC05),
      Color(0xFF34A853),
      Color(0xFF4285F4),
    ];
    const sweeps = [90.0, 90.0, 90.0, 90.0];
    const starts = [-180.0, -90.0, 0.0, 90.0];

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.28;

    final arcR    = r * 0.72;
    final arcRect = Rect.fromCircle(center: Offset(cx, cy), radius: arcR);

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

    canvas.drawCircle(Offset(cx, cy), r * 0.44, Paint()..color = Colors.white);
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - w * 0.14, r * 1.0, w * 0.28),
      Paint()..color = const Color(0xFF4285F4),
    );
    canvas.drawCircle(Offset(cx, cy), r * 0.44, Paint()..color = Colors.white);
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
