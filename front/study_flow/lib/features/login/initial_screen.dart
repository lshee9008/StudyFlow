import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';
import '../login/login_or_create_membership_screen.dart';

class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ambientController;
  late final AnimationController _shimmerController;
  late final Animation<double> _ambientAnimation;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    _ambientAnimation = CurvedAnimation(
      parent: _ambientController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _ambientController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _goToAuth() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginOrCreateMembershipScreen(),
        transitionDuration: const Duration(milliseconds: 420),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 860;

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientAnimation,
              builder: (context, child) => CustomPaint(
                painter: _LandingBackgroundPainter(_ambientAnimation.value),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.bgPrimary.withValues(alpha: 0.40),
                    Colors.transparent,
                    AppTheme.bgDeep.withValues(alpha: 0.72),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: isMobile
                ? _MobileLanding(
                    onStart: _goToAuth,
                    shimmer: _shimmerController,
                  )
                : _DesktopLanding(
                    onStart: _goToAuth,
                    shimmer: _shimmerController,
                  ),
          ),
        ],
      ),
    );
  }
}

class _DesktopLanding extends StatelessWidget {
  final VoidCallback onStart;
  final Animation<double> shimmer;

  const _DesktopLanding({required this.onStart, required this.shimmer});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(52, 28, 52, 32),
      child: Column(
        children: [
          Row(
            children: [
              const SFLogo(size: 30),
              const Spacer(),
              const _NavPill(label: 'Product'),
              const SizedBox(width: 12),
              const _NavPill(label: 'Live Demo'),
              const SizedBox(width: 12),
              SFButton(label: '시작하기', outlined: true, onPressed: onStart),
            ],
          ),
          const SizedBox(height: 34),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 11,
                  child: _HeroCopy(onStart: onStart, shimmer: shimmer),
                ),
                const SizedBox(width: 28),
                const Expanded(flex: 9, child: _ShowcasePanel()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileLanding extends StatelessWidget {
  final VoidCallback onStart;
  final Animation<double> shimmer;

  const _MobileLanding({required this.onStart, required this.shimmer});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SFLogo(size: 26),
              const Spacer(),
              SFButton(
                label: '입장',
                outlined: true,
                height: 42,
                onPressed: onStart,
              ),
            ],
          ),
          const SizedBox(height: 30),
          _HeroCopy(onStart: onStart, shimmer: shimmer, compact: true),
          const SizedBox(height: 22),
          const _ShowcasePanel(compact: true),
        ],
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  final VoidCallback onStart;
  final Animation<double> shimmer;
  final bool compact;

  const _HeroCopy({
    required this.onStart,
    required this.shimmer,
    this.compact = false,
  });

  static const _metrics = [
    ('실시간 요약', '0.8s'),
    ('학습 복기 유지율', '+34%'),
    ('노트 재탐색 시간', '-61%'),
  ];

  static const _signals = [
    ('Flow Memory', '강의 흐름이 끊기지 않게 맥락을 이어 붙입니다.'),
    ('Semantic Search', '질문형 탐색으로 필요한 개념을 즉시 재호출합니다.'),
    ('Adaptive Quiz', '이해가 부족한 구간만 다시 물어보는 복습 엔진입니다.'),
  ];

  @override
  Widget build(BuildContext context) {
    final titleSize = compact ? 42.0 : 68.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SFBadge(
          label: 'COGNITIVE LEARNING SYSTEM',
          bgColor: AppTheme.blueDim,
          color: AppTheme.blue,
        ),
        const SizedBox(height: 20),
        Text(
          '공부가 아니라\n작동하는 흐름을 설계합니다',
          style: AppTheme.displayLarge.copyWith(
            fontSize: titleSize,
            height: 1.02,
          ),
        ),
        const SizedBox(height: 16),
        _ShimmerTagline(shimmer: shimmer),
        const SizedBox(height: 22),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Text(
            'StudyFlow는 강의를 듣는 동안 요약, 구조화, 검색, 복습을 동시에 수행하는 학습 운영체제입니다. '
            '메모 앱이 아니라 학습자의 인지 부하를 줄이는 실시간 보조 인터페이스로 설계했습니다.',
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.textSecondary,
              fontSize: compact ? 14 : 16,
            ),
          ),
        ),
        const SizedBox(height: 26),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SFButton(
              label: '무료로 시작하기',
              icon: Icons.arrow_forward_rounded,
              onPressed: onStart,
              width: compact ? double.infinity : null,
            ),
            SFButton(
              label: '데모 체험',
              outlined: true,
              icon: Icons.play_arrow_rounded,
              onPressed: onStart,
              width: compact ? double.infinity : null,
            ),
          ],
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _metrics
              .map((item) => _MetricChip(label: item.$1, value: item.$2))
              .toList(),
        ),
        const SizedBox(height: 30),
        if (compact)
          Column(
            children: _signals
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SignalCard(
                      title: item.$1,
                      description: item.$2,
                    ),
                  ),
                )
                .toList(),
          )
        else
          Expanded(
            child: Row(
              children: _signals
                  .map(
                    (item) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: item == _signals.last ? 0 : 12,
                        ),
                        child: _SignalCard(
                          title: item.$1,
                          description: item.$2,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _ShowcasePanel extends StatelessWidget {
  final bool compact;

  const _ShowcasePanel({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final panel = Container(
      padding: EdgeInsets.all(compact ? 18 : 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: AppTheme.borderDefault.withValues(alpha: 0.7),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.06),
            AppTheme.bgSecondary.withValues(alpha: 0.78),
            AppTheme.bgPrimary.withValues(alpha: 0.96),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 50,
            offset: const Offset(0, 22),
            spreadRadius: -16,
          ),
          BoxShadow(
            color: AppTheme.blue.withValues(alpha: 0.08),
            blurRadius: 70,
            offset: const Offset(-20, -16),
            spreadRadius: -24,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SFBadge(
                label: 'LIVE LECTURE SESSION',
                color: AppTheme.accent,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.greenDim,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppTheme.green.withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Streaming',
                      style: AppTheme.labelSmall.copyWith(
                        color: AppTheme.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'AI가 지금 듣고 있는 강의의 논리 구조를 실시간으로 재편집합니다.',
            style: AppTheme.headingMedium,
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.black.withValues(alpha: 0.18),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              children: [
                const _InsightRow(
                  label: '핵심 테마',
                  value: 'Activation Energy / Catalysis',
                  color: AppTheme.yellow,
                ),
                const SizedBox(height: 12),
                const _InsightRow(
                  label: '현재 이해 공백',
                  value: '촉매가 경로만 바꾸고 평형은 유지하는 이유',
                  color: AppTheme.red,
                ),
                const SizedBox(height: 12),
                const _InsightRow(
                  label: '다음 추천 행동',
                  value: '30초 퀴즈 생성 후 오답 메모 연결',
                  color: AppTheme.blue,
                ),
                const SizedBox(height: 18),
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.bgTertiary, AppTheme.bgPrimary],
                    ),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Stack(
                    children: const [
                      Positioned(
                        left: 24,
                        top: 28,
                        child: _GraphNode(
                          title: 'Lecture',
                          subtitle: '핵심 개념 추출',
                          color: AppTheme.accent,
                        ),
                      ),
                      Positioned(
                        right: 24,
                        top: 44,
                        child: _GraphNode(
                          title: 'Quiz',
                          subtitle: '이해도 재확인',
                          color: AppTheme.blue,
                        ),
                      ),
                      Positioned(
                        left: 74,
                        bottom: 24,
                        child: _GraphNode(
                          title: 'Recall',
                          subtitle: '복습 카드 저장',
                          color: AppTheme.green,
                        ),
                      ),
                      Positioned.fill(child: _GraphLinks()),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (compact)
            const Column(
              children: [
                _MiniFeature(
                  icon: Icons.auto_awesome_rounded,
                  title: '실시간 요약',
                  description: '필기 직후 지식 단위로 재정렬',
                  color: AppTheme.accent,
                ),
                SizedBox(height: 10),
                _MiniFeature(
                  icon: Icons.psychology_alt_outlined,
                  title: '맥락 복기',
                  description: '이전 개념과 자동 연결',
                  color: AppTheme.blue,
                ),
              ],
            )
          else
            const Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _MiniFeature(
                      icon: Icons.auto_awesome_rounded,
                      title: '실시간 요약',
                      description: '필기 직후 지식 단위로 재정렬',
                      color: AppTheme.accent,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _MiniFeature(
                      icon: Icons.psychology_alt_outlined,
                      title: '맥락 복기',
                      description: '이전 개념과 자동 연결',
                      color: AppTheme.blue,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    return compact ? panel : Center(child: panel);
  }
}

class _SignalCard extends StatelessWidget {
  final String title;
  final String description;

  const _SignalCard({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.headingSmall),
          const SizedBox(height: 10),
          Text(description, style: AppTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderDefault),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTheme.headingMedium.copyWith(color: AppTheme.textPrimary),
          ),
          const SizedBox(width: 10),
          Text(label, style: AppTheme.bodySmall),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InsightRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 10),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTheme.labelSmall),
              const SizedBox(height: 4),
              Text(
                value,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _MiniFeature({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: color.withValues(alpha: 0.14),
              border: Border.all(color: color.withValues(alpha: 0.24)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.headingSmall),
                const SizedBox(height: 4),
                Text(description, style: AppTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GraphNode extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;

  const _GraphNode({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.18),
            AppTheme.bgTertiary.withValues(alpha: 0.95),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: AppTheme.caption),
        ],
      ),
    );
  }
}

class _GraphLinks extends StatelessWidget {
  const _GraphLinks();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GraphLinkPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _GraphLinkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [AppTheme.accent, AppTheme.blue, AppTheme.green],
      ).createShader(Offset.zero & size)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(150, 70)
      ..cubicTo(220, 70, 240, 90, 300, 82)
      ..moveTo(140, 100)
      ..cubicTo(130, 140, 155, 150, 195, 160)
      ..moveTo(336, 96)
      ..cubicTo(290, 122, 262, 135, 214, 150);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NavPill extends StatelessWidget {
  final String label;

  const _NavPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Text(
        label,
        style: AppTheme.labelMedium.copyWith(color: AppTheme.textSecondary),
      ),
    );
  }
}

class _ShimmerTagline extends StatelessWidget {
  final Animation<double> shimmer;

  const _ShimmerTagline({required this.shimmer});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmer,
      builder: (context, child) {
        final value = shimmer.value;
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.8 + value * 3.6, 0),
              end: Alignment(1.8 + value * 3.6, 0),
              colors: const [
                AppTheme.blue,
                AppTheme.textPrimary,
                AppTheme.accent,
                AppTheme.textPrimary,
              ],
              stops: const [0.0, 0.35, 0.65, 1.0],
            ).createShader(bounds);
          },
          child: Text(
            '노트 앱처럼 보이지만, 실제로는 학습을 운영하는 인터페이스입니다.',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.3,
            ),
          ),
        );
      },
    );
  }
}

class _LandingBackgroundPainter extends CustomPainter {
  final double t;

  const _LandingBackgroundPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppTheme.bgDeep);

    void blob(double x, double y, double radius, Color color, double opacity) {
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        radius,
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 140),
      );
    }

    blob(0.12 + t * 0.08, 0.16, 280, AppTheme.blue, 0.12);
    blob(
      0.82 - t * 0.04,
      0.18 + math.sin(t * math.pi) * 0.04,
      260,
      AppTheme.accent,
      0.09,
    );
    blob(0.56, 0.78 + math.cos(t * math.pi) * 0.04, 320, AppTheme.purple, 0.08);
    blob(0.98, 0.62, 240, AppTheme.green, 0.05);

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    const spacing = 42.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LandingBackgroundPainter oldDelegate) {
    return (oldDelegate.t - t).abs() > 0.003;
  }
}
