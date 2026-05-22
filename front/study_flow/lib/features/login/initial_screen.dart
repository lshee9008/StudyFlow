import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/ui/app_components.dart';
import 'login_or_create_membership_screen.dart';

// ── Clean light palette (reference: univai.co.kr) ──────────────────────────
const _bg = Color(0xFFFFFFFF);
const _ink = Color(0xFF0B0B0F); // near-black
const _inkSoft = Color(0xFF3A3A42);
const _gray = Color(0xFF8A8F9A); // secondary text
const _line = Color(0xFFE7E8EC); // subtle border
const _highlight = Color(0xFFEDEEF1); // marker behind headline
const _accent = Color(0xFF5D7FFF);
const _surface = Color(0xFFF7F8FA); // feature card bg

class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _featuresKey = GlobalKey();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _openAuth() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const LoginOrCreateMembershipScreen(),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }

  void _scrollToFeatures() {
    final ctx = _featuresKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
      alignment: 0.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isCompact = w < 720;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top nav (fixed) ───────────────────────────────────────
            AppFadeSlide(
              beginOffset: const Offset(0, -8),
              duration: const Duration(milliseconds: 420),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 20 : 40,
                  vertical: 18,
                ),
                child: Row(
                  children: [
                    const _BrandMark(),
                    const Spacer(),
                    _PillButton(
                      label: '시작하기',
                      filled: true,
                      compact: true,
                      onTap: _openAuth,
                    ),
                  ],
                ),
              ),
            ),
            // ── Scrollable content ────────────────────────────────────
            Expanded(
              child: CustomScrollView(
                controller: _scroll,
                slivers: [
                  // First screen: centered hero + scroll hint
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 760),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 24 : 32,
                              ),
                              child: _Hero(
                                isCompact: isCompact,
                                onStart: _openAuth,
                                onSeeFeatures: _scrollToFeatures,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),
                        GestureDetector(
                          onTap: _scrollToFeatures,
                          behavior: HitTestBehavior.opaque,
                          child: const _ScrollHint(),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                  // Features section
                  SliverToBoxAdapter(
                    child: _FeaturesSection(
                      key: _featuresKey,
                      isCompact: isCompact,
                    ),
                  ),
                  // Closing CTA
                  SliverToBoxAdapter(
                    child: _FooterCta(isCompact: isCompact, onStart: _openAuth),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Hero
// ───────────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  final bool isCompact;
  final VoidCallback onStart;
  final VoidCallback onSeeFeatures;

  const _Hero({
    required this.isCompact,
    required this.onStart,
    required this.onSeeFeatures,
  });

  @override
  Widget build(BuildContext context) {
    final titleSize = isCompact ? 38.0 : 56.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AppFadeSlide(
          delay: const Duration(milliseconds: 60),
          child: const _PoweredByBadge(),
        ),
        const SizedBox(height: 28),
        AppFadeSlide(
          delay: const Duration(milliseconds: 120),
          child: Column(
            children: [
              _HighlightLine(text: '복잡한 학습 자료', fontSize: titleSize),
              SizedBox(height: titleSize * 0.12),
              Text(
                '한눈에 끝내보세요.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  height: 1.08,
                  letterSpacing: -1.6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AppFadeSlide(
          delay: const Duration(milliseconds: 180),
          child: Text(
            'PDF·노트를 요약, 퀴즈, 지식 그래프로 자동 변환합니다.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: isCompact ? 15 : 17,
              fontWeight: FontWeight.w400,
              color: _gray,
              height: 1.6,
              letterSpacing: -0.2,
            ),
          ),
        ),
        const SizedBox(height: 36),
        AppFadeSlide(
          delay: const Duration(milliseconds: 240),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              _PillButton(label: '기능 보기', filled: false, onTap: onSeeFeatures),
              _PillButton(label: '지금 시작하기', filled: true, onTap: onStart),
            ],
          ),
        ),
        const SizedBox(height: 32),
        AppFadeSlide(
          delay: const Duration(milliseconds: 320),
          child: const _SocialProof(),
        ),
      ],
    );
  }
}

class _HighlightLine extends StatelessWidget {
  final String text;
  final double fontSize;

  const _HighlightLine({required this.text, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: fontSize * 0.08,
          child: Container(
            height: fontSize * 0.42,
            margin: EdgeInsets.symmetric(horizontal: fontSize * 0.1),
            decoration: BoxDecoration(
              color: _highlight,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: _ink,
            height: 1.08,
            letterSpacing: -1.6,
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Features section
// ───────────────────────────────────────────────────────────────────────────

class _FeaturesSection extends StatelessWidget {
  final bool isCompact;
  const _FeaturesSection({super.key, required this.isCompact});

  static const _features = [
    (
      LucideIcons.fileText,
      'AI 요약',
      '긴 PDF·노트를 핵심만 추려 빠르게 정리합니다.',
    ),
    (
      LucideIcons.share2,
      '지식 그래프',
      '개념 사이의 연결을 마인드맵으로 한눈에 봅니다.',
    ),
    (
      LucideIcons.checkCircle,
      '퀴즈 · 암기',
      '자동 생성된 퀴즈와 암기 노트로 능동 복습합니다.',
    ),
    (
      LucideIcons.edit3,
      '메모',
      '자료마다 자유롭게 메모하고 어디서든 동기화합니다.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _bg,
      padding: EdgeInsets.fromLTRB(
        isCompact ? 24 : 40,
        isCompact ? 56 : 96,
        isCompact ? 24 : 40,
        isCompact ? 40 : 72,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              Text(
                '학습에 필요한 모든 것',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: isCompact ? 28 : 38,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  letterSpacing: -1.0,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '하나의 자료에서 요약부터 복습까지, 끊김 없이 이어집니다.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: isCompact ? 14 : 16,
                  fontWeight: FontWeight.w400,
                  color: _gray,
                  height: 1.6,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 44),
              Wrap(
                spacing: 18,
                runSpacing: 18,
                alignment: WrapAlignment.center,
                children: [
                  for (final f in _features)
                    _FeatureCard(
                      icon: f.$1,
                      title: f.$2,
                      desc: f.$3,
                      width: isCompact ? double.infinity : 320,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String desc;
  final double width;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.width,
  });

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: widget.width,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _hovered ? _accent.withValues(alpha: 0.4) : _line,
            width: 1.5,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: _ink.withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _ink,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.icon, size: 21, color: Colors.white),
            ),
            const SizedBox(height: 18),
            Text(
              widget.title,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _ink,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.desc,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: _gray,
                height: 1.6,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Footer CTA
// ───────────────────────────────────────────────────────────────────────────

class _FooterCta extends StatelessWidget {
  final bool isCompact;
  final VoidCallback onStart;
  const _FooterCta({required this.isCompact, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _ink,
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 24 : 40,
        vertical: isCompact ? 56 : 88,
      ),
      child: Column(
        children: [
          Text(
            '지금 바로 시작해보세요.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: isCompact ? 26 : 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1.0,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '몇 초면 충분합니다. 무료로 학습 흐름을 만들어 보세요.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: isCompact ? 14 : 16,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.6),
              height: 1.6,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 28),
          _PillButton(label: '지금 시작하기', filled: true, invert: true, onTap: onStart),
          const SizedBox(height: 40),
          Text(
            '© StudyFlow',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Brand mark
// ───────────────────────────────────────────────────────────────────────────

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: _ink,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(LucideIcons.zap, size: 17, color: Colors.white),
        ),
        const SizedBox(width: 9),
        Text(
          'StudyFlow',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _ink,
            letterSpacing: -0.6,
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Powered by badge
// ───────────────────────────────────────────────────────────────────────────

class _PoweredByBadge extends StatelessWidget {
  const _PoweredByBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(LucideIcons.sparkles, size: 14, color: _accent),
        const SizedBox(width: 7),
        Text(
          'Powered by Gemini',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _gray,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Social proof
// ───────────────────────────────────────────────────────────────────────────

class _SocialProof extends StatelessWidget {
  const _SocialProof();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 64,
          height: 28,
          child: Stack(
            children: [
              for (int i = 0; i < 3; i++)
                Positioned(
                  left: i * 18.0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: [
                        const Color(0xFFD8DEF8),
                        const Color(0xFFE3DAF6),
                        const Color(0xFFD7EEE4),
                      ][i],
                      border: Border.all(color: _bg, width: 2),
                    ),
                    child: Icon(LucideIcons.user, size: 13, color: _inkSoft),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: '이미 '),
              TextSpan(
                text: '많은 학생',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const TextSpan(text: '들이 사용 중'),
            ],
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: _gray,
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Scroll hint
// ───────────────────────────────────────────────────────────────────────────

class _ScrollHint extends StatelessWidget {
  const _ScrollHint();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'SCROLL',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: _gray.withValues(alpha: 0.7),
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 4),
        Icon(LucideIcons.chevronDown, size: 14, color: _gray.withValues(alpha: 0.7)),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Pill button (filled black / outline / inverted)
// ───────────────────────────────────────────────────────────────────────────

class _PillButton extends StatefulWidget {
  final String label;
  final bool filled;
  final bool compact;
  final bool invert; // dark background context → white pill
  final VoidCallback onTap;

  const _PillButton({
    required this.label,
    required this.filled,
    required this.onTap,
    this.compact = false,
    this.invert = false,
  });

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final filled = widget.filled;
    final hPad = widget.compact ? 18.0 : 26.0;
    final vPad = widget.compact ? 10.0 : 15.0;

    final Color bg;
    final Color fg;
    if (widget.invert) {
      // On dark footer: white pill, dark text
      bg = _hovered ? const Color(0xFFE9EAEE) : Colors.white;
      fg = _ink;
    } else if (filled) {
      bg = _hovered ? const Color(0xFF22232B) : _ink;
      fg = Colors.white;
    } else {
      bg = _hovered ? _highlight : _bg;
      fg = _ink;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: (!filled && !widget.invert)
                ? Border.all(color: _line, width: 1.5)
                : null,
            boxShadow: (filled && _hovered && !widget.invert)
                ? [
                    BoxShadow(
                      color: _ink.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.inter(
              fontSize: widget.compact ? 14 : 15,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }
}
