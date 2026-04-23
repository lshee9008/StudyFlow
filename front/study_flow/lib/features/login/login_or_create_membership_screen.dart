import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import 'login_screen.dart';
import 'create_membership_screen.dart';
import 'registered_users_screen.dart';

class LoginOrCreateMembershipScreen extends StatefulWidget {
  const LoginOrCreateMembershipScreen({super.key});

  @override
  State<LoginOrCreateMembershipScreen> createState() =>
      _LoginOrCreateMembershipScreenState();
}

class _LoginOrCreateMembershipScreenState
    extends State<LoginOrCreateMembershipScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _bgCtrl;
  late Animation<double> _bgAnim;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat(reverse: true);
    _bgAnim = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      body: Stack(
        children: [
          // 애니메이션 배경
          AnimatedBuilder(
            animation: _bgAnim,
            builder: (_, __) => CustomPaint(
              painter: _AuthBgPainter(_bgAnim.value),
              size: MediaQuery.of(context).size,
            ),
          ),

          // 콘텐츠
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 32),
                    const SFLogo(size: 32),
                    const SizedBox(height: 48),

                    // 글라스 카드
                    _GlassCard(
                      child: Column(
                        children: [
                          // 아이콘
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.accentDim,
                                  AppTheme.bgTertiary,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.accent.withValues(alpha: 0.25),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.accent.withValues(alpha: 0.1),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.waving_hand_rounded,
                              color: AppTheme.accent,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '계정이 있으신가요?',
                            style: GoogleFonts.inter(
                              color: AppTheme.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '로그인하거나 새 계정을 만들어 시작하세요.',
                            style: AppTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),

                          // 로그인 버튼 (그라디언트)
                          _GradientLoginBtn(
                            onPressed: () => Navigator.push(
                              context,
                              _route(const LoginScreen()),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // 회원가입 버튼
                          SFButton(
                            label: '새 계정 만들기',
                            width: double.infinity,
                            outlined: true,
                            onPressed: () => Navigator.push(
                              context,
                              _route(const CreateMembershipScreen()),
                            ),
                          ),

                          const SizedBox(height: 28),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 1,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        AppTheme.borderSubtle,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Text('또는', style: AppTheme.bodySmall),
                              ),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppTheme.borderSubtle,
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // 기기 계정 버튼
                          _DeviceAccountBtn(
                            onTap: () => Navigator.push(
                              context,
                              _route(const RegisteredUsersScreen()),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),
                    Text(
                      '계정을 만들면 서비스 이용약관에 동의하는 것입니다.',
                      style: AppTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  PageRoute _route(Widget page) => PageRouteBuilder(
    pageBuilder: (_, a, __) => page,
    transitionsBuilder: (_, a, __, child) =>
        FadeTransition(opacity: a, child: child),
    transitionDuration: const Duration(milliseconds: 280),
  );
}

// ─── 글라스 카드 ──────────────────────────────────────────
class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.borderDefault.withValues(alpha: 0.8),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: AppTheme.accent.withValues(alpha: 0.03),
            blurRadius: 60,
            spreadRadius: 10,
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── 그라디언트 로그인 버튼 ───────────────────────────────
class _GradientLoginBtn extends StatefulWidget {
  final VoidCallback onPressed;
  const _GradientLoginBtn({required this.onPressed});
  @override
  State<_GradientLoginBtn> createState() => _GradientLoginBtnState();
}

class _GradientLoginBtnState extends State<_GradientLoginBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: GestureDetector(
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _hover
                ? [const Color(0xFFDDFF88), AppTheme.accent]
                : [AppTheme.accent, AppTheme.accentMuted],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: _hover ? 0.3 : 0.15),
              blurRadius: _hover ? 20 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          '로그인',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    ),
  );
}

// ─── 기기 계정 버튼 ───────────────────────────────────────
class _DeviceAccountBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _DeviceAccountBtn({required this.onTap});
  @override
  State<_DeviceAccountBtn> createState() => _DeviceAccountBtnState();
}

class _DeviceAccountBtnState extends State<_DeviceAccountBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _hover
              ? AppTheme.bgTertiary
              : AppTheme.bgPrimary.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _hover ? AppTheme.borderStrong : AppTheme.borderSubtle,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.phone_android_rounded,
              size: 15,
              color: _hover ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              '이 기기의 계정으로 계속하기',
              style: GoogleFonts.inter(
                color: _hover ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ─── 배경 페인터 ──────────────────────────────────────────
class _AuthBgPainter extends CustomPainter {
  final double t;
  const _AuthBgPainter(this.t);

  @override
  void paint(Canvas c, Size s) {
    void blob(double cx, double cy, double r, Color col, double a) {
      c.drawCircle(
        Offset(cx * s.width, cy * s.height),
        r,
        Paint()
          ..color = col.withValues(alpha: a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 160),
      );
    }

    blob(0.1 + t * 0.06, 0.2, 280, AppTheme.blue, 0.07);
    blob(0.92, 0.15 + t * 0.05, 240, AppTheme.accent, 0.05);
    blob(0.5 + math.sin(t * math.pi) * 0.06, 0.9, 300, AppTheme.purple, 0.06);
  }

  @override
  bool shouldRepaint(_AuthBgPainter o) => (o.t - t).abs() > 0.004;
}
