import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../providers/user_provider.dart';
import '../home/home_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  late AnimationController _bgCtrl;
  late Animation<double> _bgAnim;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);
    _bgAnim = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_idCtrl.text.isEmpty || _pwCtrl.text.isEmpty) {
      setState(() => _error = '아이디와 비밀번호를 입력해주세요.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final err = await ref
        .read(userProvider.notifier)
        .loginUser(_idCtrl.text.trim(), _pwCtrl.text);

    if (!mounted) return;
    if (err == null) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } else {
      setState(() {
        _loading = false;
        _error = '아이디 또는 비밀번호가 올바르지 않습니다.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      body: Stack(
        children: [
          // 배경
          AnimatedBuilder(
            animation: _bgAnim,
            builder: (_, __) => CustomPaint(
              painter: _LoginBgPainter(_bgAnim.value),
              size: MediaQuery.of(context).size,
            ),
          ),

          // 뒤로가기
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _BackBtn(onTap: () => Navigator.pop(context)),
              ),
            ),
          ),

          // 콘텐츠
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SFLogo(size: 28),
                    const SizedBox(height: 44),

                    _GlassFormCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.bgTertiary,
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(color: AppTheme.borderSubtle),
                                ),
                                child: const Icon(
                                  Icons.login_rounded,
                                  size: 15,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '다시 오셨군요',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  Text(
                                    '계정에 로그인하세요.',
                                    style: AppTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          SFTextField(
                            label: '아이디',
                            hint: '아이디를 입력하세요',
                            controller: _idCtrl,
                            prefixIcon: Icons.person_outline_rounded,
                            onSubmitted: (_) => _login(),
                          ),
                          const SizedBox(height: 14),
                          SFTextField(
                            label: '비밀번호',
                            hint: '비밀번호를 입력하세요',
                            controller: _pwCtrl,
                            obscure: true,
                            prefixIcon: Icons.lock_outline_rounded,
                            onSubmitted: (_) => _login(),
                          ),

                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            _ErrorBox(message: _error!),
                          ],

                          const SizedBox(height: 24),
                          _LoginSubmitBtn(
                            isLoading: _loading,
                            onPressed: _login,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 글라스 폼 카드 ───────────────────────────────────────
class _GlassFormCard extends StatelessWidget {
  final Widget child;
  const _GlassFormCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.borderDefault.withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: AppTheme.blue.withValues(alpha: 0.03),
            blurRadius: 60,
            spreadRadius: 10,
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── 에러 박스 ────────────────────────────────────────────
class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: AppTheme.red.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppTheme.red.withValues(alpha: 0.25)),
    ),
    child: Row(
      children: [
        Icon(Icons.error_outline_rounded, size: 15, color: AppTheme.red),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            message,
            style: GoogleFonts.inter(color: AppTheme.red, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

// ─── 로그인 제출 버튼 ─────────────────────────────────────
class _LoginSubmitBtn extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  const _LoginSubmitBtn({required this.isLoading, required this.onPressed});
  @override
  State<_LoginSubmitBtn> createState() => _LoginSubmitBtnState();
}

class _LoginSubmitBtnState extends State<_LoginSubmitBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: GestureDetector(
      onTap: widget.isLoading ? null : widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: widget.isLoading
              ? null
              : LinearGradient(
                  colors: _hover
                      ? [const Color(0xFFDDFF88), AppTheme.accent]
                      : [AppTheme.accent, AppTheme.accentMuted],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: widget.isLoading ? AppTheme.bgTertiary : null,
          borderRadius: BorderRadius.circular(10),
          boxShadow: !widget.isLoading
              ? [
                  BoxShadow(
                    color: AppTheme.accent.withValues(
                      alpha: _hover ? 0.28 : 0.14,
                    ),
                    blurRadius: _hover ? 20 : 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: widget.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: AppTheme.textSecondary,
                    strokeWidth: 1.5,
                  ),
                )
              : Text(
                  '로그인',
                  style: GoogleFonts.inter(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
        ),
      ),
    ),
  );
}

// ─── 뒤로가기 버튼 ────────────────────────────────────────
class _BackBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _BackBtn({required this.onTap});
  @override
  State<_BackBtn> createState() => _BackBtnState();
}

class _BackBtnState extends State<_BackBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _hover
              ? AppTheme.bgSecondary.withValues(alpha: 0.8)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: _hover
              ? Border.all(color: AppTheme.borderSubtle)
              : null,
        ),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 15,
          color: _hover ? AppTheme.textPrimary : AppTheme.textSecondary,
        ),
      ),
    ),
  );
}

// ─── 배경 페인터 ──────────────────────────────────────────
class _LoginBgPainter extends CustomPainter {
  final double t;
  const _LoginBgPainter(this.t);

  @override
  void paint(Canvas c, Size s) {
    void blob(double cx, double cy, double r, Color col, double a) {
      c.drawCircle(
        Offset(cx * s.width, cy * s.height),
        r,
        Paint()
          ..color = col.withValues(alpha: a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 140),
      );
    }

    blob(0.08 + t * 0.06, 0.18, 260, AppTheme.blue, 0.07);
    blob(0.9, 0.8 + t * 0.04, 220, AppTheme.purple, 0.05);
    blob(0.5, 1.0, 280, AppTheme.accent, 0.04);
  }

  @override
  bool shouldRepaint(_LoginBgPainter o) => (o.t - t).abs() > 0.004;
}
