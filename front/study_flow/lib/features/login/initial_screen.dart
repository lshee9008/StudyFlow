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
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _bgAnim;
  int _hoverFeature = -1;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _bgAnim = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _bgCtrl.dispose();
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
      transitionDuration: const Duration(milliseconds: 350),
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
          // 애니메이션 배경
          AnimatedBuilder(
            animation: _bgAnim,
            builder: (_, __) => CustomPaint(
              painter: _BgPainter(_bgAnim.value),
              size: MediaQuery.of(context).size,
            ),
          ),

          // 메인 콘텐츠
          SafeArea(
            bottom: false, // 하단은 SingleChildScrollView가 처리
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: isMobile ? 24 : 80,
                    right: isMobile ? 24 : 80,
                    top: isMobile ? 0 : 28,    // 모바일은 MobileLayout 내부에서 처리
                    bottom: isMobile ? 0 : 28,
                  ),
                  child: isMobile
                      ? _MobileLayout(
                          onStart: _goToAuth,
                          hoverFeature: _hoverFeature,
                          onHoverFeature: (i) =>
                              setState(() => _hoverFeature = i),
                        )
                      : _DesktopLayout(
                          onStart: _goToAuth,
                          hoverFeature: _hoverFeature,
                          onHoverFeature: (i) =>
                              setState(() => _hoverFeature = i),
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

// 배경 페인터
class _BgPainter extends CustomPainter {
  final double t;
  const _BgPainter(this.t);

  @override
  void paint(Canvas c, Size s) {
    void blob(double cx, double cy, double r, Color col, double a) {
      c.drawCircle(
        Offset(cx * s.width, cy * s.height),
        r,
        Paint()
          ..color = col.withOpacity(a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 160),
      );
    }

    blob(
      0.15 + t * 0.06,
      0.2 + math.sin(t * math.pi) * 0.06,
      340,
      AppTheme.blue,
      0.06,
    );
    blob(
      0.85 - t * 0.04,
      0.1 + math.cos(t * math.pi) * 0.04,
      280,
      AppTheme.accent,
      0.04,
    );
    blob(
      0.5 + math.sin(t * math.pi) * 0.08,
      0.85,
      360,
      AppTheme.purple,
      0.035,
    );
    blob(0.95, 0.6 + t * 0.08, 200, AppTheme.green, 0.025);
  }

  @override
  bool shouldRepaint(_BgPainter o) => (o.t - t).abs() > 0.004;
}

// 데스크톱 레이아웃
class _DesktopLayout extends StatelessWidget {
  final VoidCallback onStart;
  final int hoverFeature;
  final void Function(int) onHoverFeature;

  const _DesktopLayout({
    required this.onStart,
    required this.hoverFeature,
    required this.onHoverFeature,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 상단 로고 + nav
        Row(
          children: [
            const SFLogo(size: 26),
            const Spacer(),
            _NavLink(label: '기능 소개'),
            const SizedBox(width: 24),
            _NavLink(label: '데모'),
            const SizedBox(width: 24),
            SFButton(
              label: '시작하기',
              icon: Icons.arrow_forward_rounded,
              onPressed: onStart,
            ),
          ],
        ),

        const Spacer(),

        // 배지
        _StatusBadge(),
        const SizedBox(height: 28),

        // 헤드라인
        Text(
          '학습의 흐름을 끊지 않는\nAI 인지 보조 에이전트',
          style: GoogleFonts.inter(
            fontSize: 58,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -2.5,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 24),

        // 서브 텍스트
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
            const SizedBox(width: 16),
            _FeaturePill(),
          ],
        ),

        const Spacer(),

        // 기능 카드
        _FeatureCards(
          hoverFeature: hoverFeature,
          onHover: onHoverFeature,
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

// 모바일 레이아웃
class _MobileLayout extends StatelessWidget {
  final VoidCallback onStart;
  final int hoverFeature;
  final void Function(int) onHoverFeature;

  const _MobileLayout({
    required this.onStart,
    required this.hoverFeature,
    required this.onHoverFeature,
  });

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final topPad = screenH > 750 ? 24.0 : 12.0;
    final heroSpacing = screenH > 750 ? 32.0 : 20.0;
    final ctaSpacing = screenH > 750 ? 36.0 : 24.0;

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
          Text(
            '학습의 흐름을\n끊지 않는\nAI 노트',
            style: GoogleFonts.inter(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -2.0,
              height: 1.1,
            ),
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
          SFButton(
            label: '무료로 시작하기',
            icon: Icons.arrow_forward_rounded,
            width: double.infinity,
            onPressed: onStart,
          ),
          const SizedBox(height: 14),
          _FeaturePill(),
          const SizedBox(height: 28),
          _FeatureCards(
            hoverFeature: hoverFeature,
            onHover: onHoverFeature,
            compact: true,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

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
    child: Text(
      widget.label,
      style: GoogleFonts.inter(
        color: _hover ? AppTheme.textPrimary : AppTheme.textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
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
        color: AppTheme.accentDim,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: AppTheme.accent.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: AppTheme.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withOpacity(0.6),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
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

class _PrimaryBtn extends StatefulWidget {
  final VoidCallback onPressed;
  const _PrimaryBtn({required this.onPressed});
  @override
  State<_PrimaryBtn> createState() => _PrimaryBtnState();
}

class _PrimaryBtnState extends State<_PrimaryBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
          decoration: BoxDecoration(
            color: _hover ? AppTheme.accentHover : AppTheme.accent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withOpacity(_hover ? 0.35 : 0.2),
                blurRadius: _hover ? 24 : 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '무료로 시작하기',
                style: GoogleFonts.inter(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                transform: _hover
                    ? (Matrix4.identity()..translate(3.0, 0.0))
                    : Matrix4.identity(),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.black,
                  size: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle_rounded,
          size: 14,
          color: AppTheme.green,
        ),
        const SizedBox(width: 7),
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

// 기능 카드
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
      Icons.search_rounded,
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
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isHovered ? bgColor : AppTheme.bgSecondary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isHovered ? color.withOpacity(0.3) : AppTheme.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: color.withOpacity(0.2)),
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
                  Text(
                    desc.replaceAll('\n', ' '),
                    style: AppTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: isHovered ? bgColor : AppTheme.bgSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHovered ? color.withOpacity(0.3) : AppTheme.borderSubtle,
            width: isHovered ? 1.5 : 1,
          ),
          boxShadow: isHovered
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isHovered ? color.withOpacity(0.15) : bgColor,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              desc,
              style: AppTheme.bodySmall.copyWith(height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
