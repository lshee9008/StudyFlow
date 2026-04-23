import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../login/login_or_create_membership_screen.dart';
import '../../core/theme.dart';

class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});
  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen>
    with TickerProviderStateMixin {
  late AnimationController _ctrl;
  late AnimationController _bgCtrl;
  late AnimationController _shimCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _bgAnim;
  late Animation<double> _shimAnim;
  int _hoverFeature = -1;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);
    _shimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _bgAnim = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut);
    _shimAnim = CurvedAnimation(parent: _shimCtrl, curve: Curves.linear);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _bgCtrl.dispose();
    _shimCtrl.dispose();
    super.dispose();
  }

  void _goToAuth() => Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (_, a, __) => const LoginOrCreateMembershipScreen(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 380),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 700;

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      body: Stack(
        children: [
          // 그라디언트 메시 배경
          AnimatedBuilder(
            animation: _bgAnim,
            builder: (_, __) => CustomPaint(
              painter: _MeshBgPainter(_bgAnim.value),
              size: MediaQuery.of(context).size,
            ),
          ),

          // 그리드 패턴 (미묘한 dot grid)
          CustomPaint(
            painter: _GridPainter(),
            size: MediaQuery.of(context).size,
          ),

          // 메인 콘텐츠
          SafeArea(
            bottom: false,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: isMobile ? 24 : 80,
                    right: isMobile ? 24 : 80,
                    top: isMobile ? 0 : 28,
                    bottom: isMobile ? 0 : 28,
                  ),
                  child: isMobile
                      ? _MobileLayout(
                          onStart: _goToAuth,
                          hoverFeature: _hoverFeature,
                          onHoverFeature: (i) =>
                              setState(() => _hoverFeature = i),
                          shimAnim: _shimAnim,
                        )
                      : _DesktopLayout(
                          onStart: _goToAuth,
                          hoverFeature: _hoverFeature,
                          onHoverFeature: (i) =>
                              setState(() => _hoverFeature = i),
                          shimAnim: _shimAnim,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 배경 메시 페인터 ──────────────────────────────────────
class _MeshBgPainter extends CustomPainter {
  final double t;
  const _MeshBgPainter(this.t);

  @override
  void paint(Canvas c, Size s) {
    void blob(double cx, double cy, double r, Color col, double a) {
      c.drawCircle(
        Offset(cx * s.width, cy * s.height),
        r,
        Paint()
          ..color = col.withValues(alpha: a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 180),
      );
    }

    // 파란 블롭 (왼쪽 상단)
    blob(
      0.1 + t * 0.08,
      0.15 + math.sin(t * math.pi) * 0.08,
      380,
      AppTheme.blue,
      0.09,
    );
    // 라임 블롭 (오른쪽 상단)
    blob(
      0.88 - t * 0.05,
      0.08 + math.cos(t * math.pi) * 0.06,
      320,
      AppTheme.accent,
      0.06,
    );
    // 보라 블롭 (하단 중앙)
    blob(
      0.5 + math.sin(t * math.pi * 0.7) * 0.1,
      0.88,
      420,
      AppTheme.purple,
      0.07,
    );
    // 그린 블롭 (우측)
    blob(0.98, 0.5 + t * 0.1, 240, AppTheme.green, 0.04);
    // 추가 앰비언트
    blob(0.3, 0.7 + math.cos(t * math.pi) * 0.05, 300, AppTheme.blue, 0.03);
  }

  @override
  bool shouldRepaint(_MeshBgPainter o) => (o.t - t).abs() > 0.003;
}

// ─── dot grid 배경 ────────────────────────────────────────
class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas c, Size s) {
    final paint = Paint()
      ..color = AppTheme.borderSubtle.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    const spacing = 32.0;
    for (double x = 0; x < s.width; x += spacing) {
      for (double y = 0; y < s.height; y += spacing) {
        c.drawCircle(Offset(x, y), 0.8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter o) => false;
}

// ─── 데스크톱 레이아웃 ─────────────────────────────────────
class _DesktopLayout extends StatelessWidget {
  final VoidCallback onStart;
  final int hoverFeature;
  final void Function(int) onHoverFeature;
  final Animation<double> shimAnim;

  const _DesktopLayout({
    required this.onStart,
    required this.hoverFeature,
    required this.onHoverFeature,
    required this.shimAnim,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 상단 네비
        Row(
          children: [
            const SFLogo(size: 26),
            const Spacer(),
            _NavLink(label: '기능 소개'),
            const SizedBox(width: 24),
            _NavLink(label: '데모'),
            const SizedBox(width: 24),
            _GlowButton(label: '시작하기', onPressed: onStart),
          ],
        ),

        const Spacer(),

        // 배지
        _StatusBadge(),
        const SizedBox(height: 28),

        // 헤드라인 (그라디언트 텍스트)
        _GradientHeadline(
          text: '학습의 흐름을 끊지 않는\nAI 인지 보조 에이전트',
          shimAnim: shimAnim,
          fontSize: 58,
        ),
        const SizedBox(height: 24),

        // 서브텍스트
        Text(
          '강의를 들으며 동시에 요약하고, 이해하고, 기억하세요.\n실시간 AI가 여러분의 학습 흐름을 함께 만들어갑니다.',
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary,
            fontSize: 17,
            height: 1.7,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 48),

        // CTA 영역
        Row(
          children: [
            _PrimaryBtn(onPressed: onStart),
            const SizedBox(width: 20),
            _FeaturePill(),
          ],
        ),

        const Spacer(),

        // 기능 카드 (height 고정 필수 — Spacer 없는 Row이므로)
        SizedBox(
          height: 170,
          child: _FeatureCards(
            hoverFeature: hoverFeature,
            onHover: onHoverFeature,
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

// ─── 모바일 레이아웃 ──────────────────────────────────────
class _MobileLayout extends StatelessWidget {
  final VoidCallback onStart;
  final int hoverFeature;
  final void Function(int) onHoverFeature;
  final Animation<double> shimAnim;

  const _MobileLayout({
    required this.onStart,
    required this.hoverFeature,
    required this.onHoverFeature,
    required this.shimAnim,
  });

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final topPad = screenH > 750 ? 24.0 : 12.0;
    final heroSpacing = screenH > 750 ? 28.0 : 18.0;
    final ctaSpacing = screenH > 750 ? 32.0 : 20.0;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: topPad),
          const SFLogo(size: 24),
          SizedBox(height: heroSpacing),
          _StatusBadge(),
          const SizedBox(height: 20),
          _GradientHeadline(
            text: '학습의 흐름을\n끊지 않는\nAI 노트',
            shimAnim: shimAnim,
            fontSize: 42,
          ),
          const SizedBox(height: 16),
          Text(
            '강의를 들으며 동시에 요약하고,\n이해하고, 기억하세요.',
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              fontSize: 15,
              height: 1.65,
            ),
          ),
          SizedBox(height: ctaSpacing),
          _PrimaryBtn(onPressed: onStart, fullWidth: true),
          const SizedBox(height: 14),
          _FeaturePill(),
          const SizedBox(height: 32),
          _FeatureCards(
            hoverFeature: hoverFeature,
            onHover: onHoverFeature,
            compact: true,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── 그라디언트 헤드라인 (shimmer 효과) ─────────────────
class _GradientHeadline extends StatelessWidget {
  final String text;
  final Animation<double> shimAnim;
  final double fontSize;
  const _GradientHeadline({
    required this.text,
    required this.shimAnim,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimAnim,
      builder: (_, __) {
        final shimOffset = shimAnim.value * 2 - 0.5;
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1.5 + shimOffset * 3, 0),
            end: Alignment(1.5 + shimOffset * 3, 0),
            colors: const [
              AppTheme.textPrimary,
              Color(0xFFFFFFFF),
              AppTheme.textPrimary,
              Color(0xFFD4E8FF), // 파란빛 하이라이트
              AppTheme.textPrimary,
            ],
            stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
          ).createShader(bounds),
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: fontSize > 50 ? -2.5 : -2.0,
              height: 1.08,
            ),
          ),
        );
      },
    );
  }
}

// ─── 공통 위젯들 ───────────────────────────────────────────
class _NavLink extends StatefulWidget {
  final String label;
  const _NavLink({required this.label});
  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 150),
      style: GoogleFonts.inter(
        color: _hover ? AppTheme.textPrimary : AppTheme.textSecondary,
        fontSize: 14,
        fontWeight: _hover ? FontWeight.w500 : FontWeight.w400,
      ),
      child: Text(widget.label),
    ),
  );
}

class _GlowButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  const _GlowButton({required this.label, required this.onPressed});
  @override
  State<_GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<_GlowButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: GestureDetector(
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: _hover ? AppTheme.bgTertiary : AppTheme.bgSecondary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _hover ? AppTheme.borderStrong : AppTheme.borderDefault,
          ),
          boxShadow: _hover
              ? [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.08),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Text(
          widget.label,
          style: GoogleFonts.inter(
            color: _hover ? AppTheme.textPrimary : AppTheme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentDim,
            AppTheme.bgSecondary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withValues(alpha: 0.06),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 펄스 도트
          _PulseDot(),
          const SizedBox(width: 9),
          Text(
            '졸업작품 프로젝트 · 3조  ·  Open Beta',
            style: GoogleFonts.inter(
              color: AppTheme.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ac, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: AppTheme.accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: _pulse.value * 0.8),
              blurRadius: 8 * _pulse.value,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryBtn extends StatefulWidget {
  final VoidCallback onPressed;
  final bool fullWidth;
  const _PrimaryBtn({required this.onPressed, this.fullWidth = false});
  @override
  State<_PrimaryBtn> createState() => _PrimaryBtnState();
}

class _PrimaryBtnState extends State<_PrimaryBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final btn = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: widget.fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _hover
                  ? [const Color(0xFFDDFF88), AppTheme.accent]
                  : [AppTheme.accent, AppTheme.accentMuted],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: _hover ? 0.4 : 0.22),
                blurRadius: _hover ? 28 : 16,
                offset: const Offset(0, 6),
                spreadRadius: _hover ? 2 : 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '무료로 시작하기',
                style: GoogleFonts.inter(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                transform: _hover
                    ? (Matrix4.identity()..translate(4.0, 0.0))
                    : Matrix4.identity(),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.black,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return btn;
  }
}

class _FeaturePill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: AppTheme.green.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.green.withValues(alpha: 0.3)),
          ),
          child: Icon(Icons.check_rounded, size: 10, color: AppTheme.green),
        ),
        const SizedBox(width: 8),
        Text(
          '무료 · 가입 30초 · 로컬 저장',
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ─── 기능 카드 ────────────────────────────────────────────
class _FeatureCards extends StatelessWidget {
  final int hoverFeature;
  final void Function(int) onHover;
  final bool compact;

  const _FeatureCards({
    required this.hoverFeature,
    required this.onHover,
    this.compact = false,
  });

  static const _features = [
    (
      Icons.auto_awesome_rounded,
      '실시간 AI 요약',
      '타이핑하는 순간 AI가 구조화된\n학습 노트를 자동 생성합니다.',
      AppTheme.accent,
      AppTheme.accentDim,
    ),
    (
      Icons.hub_rounded,
      '지식 그래프',
      '개념 간 연결관계를 마인드맵으로\n시각적으로 파악합니다.',
      AppTheme.blue,
      AppTheme.blueDim,
    ),
    (
      Icons.quiz_rounded,
      'AI 퀴즈',
      '학습한 내용으로 즉시 복습 퀴즈를\n생성하고 이해도를 확인합니다.',
      AppTheme.purple,
      AppTheme.purpleDim,
    ),
    (
      Icons.manage_search_rounded,
      '의미 기반 검색',
      '키워드 없이 내용의 의미로\n노트를 찾아드립니다.',
      AppTheme.green,
      AppTheme.greenDim,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        children: _features.asMap().entries.map((e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _FeatureCard(
              index: e.key,
              feature: e.value,
              isHovered: hoverFeature == e.key,
              onHover: (v) => onHover(v ? e.key : -1),
              compact: true,
            ),
          );
        }).toList(),
      );
    }

    return Row(
      children: _features.asMap().entries.map((e) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: e.key < _features.length - 1 ? 12 : 0,
            ),
            child: _FeatureCard(
              index: e.key,
              feature: e.value,
              isHovered: hoverFeature == e.key,
              onHover: (v) => onHover(v ? e.key : -1),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final int index;
  final dynamic feature;
  final bool isHovered;
  final void Function(bool) onHover;
  final bool compact;

  const _FeatureCard({
    required this.index,
    required this.feature,
    required this.isHovered,
    required this.onHover,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final IconData icon = feature.$1;
    final String title = feature.$2;
    final String desc = feature.$3;
    final Color color = feature.$4;
    final Color bgColor = feature.$5;

    if (compact) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isHovered ? bgColor : AppTheme.bgSecondary.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isHovered
                ? color.withValues(alpha: 0.3)
                : AppTheme.borderSubtle,
            width: isHovered ? 1.5 : 1,
          ),
          boxShadow: isHovered
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: isHovered
                    ? color.withValues(alpha: 0.15)
                    : bgColor,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: color.withValues(alpha: 0.2)),
                boxShadow: isHovered
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.2),
                          blurRadius: 10,
                        ),
                      ]
                    : [],
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc.replaceAll('\n', ' '),
                    style: AppTheme.bodySmall.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 11,
              color: isHovered
                  ? color.withValues(alpha: 0.6)
                  : AppTheme.textMuted,
            ),
          ],
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: isHovered
              ? LinearGradient(
                  colors: [bgColor, AppTheme.bgSecondary.withValues(alpha: 0.5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [
                    AppTheme.bgSecondary.withValues(alpha: 0.8),
                    AppTheme.bgSecondary.withValues(alpha: 0.5),
                  ],
                ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isHovered
                ? color.withValues(alpha: 0.3)
                : AppTheme.borderSubtle,
            width: isHovered ? 1.5 : 1,
          ),
          boxShadow: isHovered
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.1),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: isHovered
                    ? color.withValues(alpha: 0.18)
                    : bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.22)),
                boxShadow: isHovered
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.25),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              desc,
              style: AppTheme.bodySmall.copyWith(height: 1.6),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  '더 알아보기',
                  style: GoogleFonts.inter(
                    color: isHovered ? color : AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  transform: isHovered
                      ? (Matrix4.identity()..translate(3.0, 0.0))
                      : Matrix4.identity(),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 11,
                    color: isHovered ? color : AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
