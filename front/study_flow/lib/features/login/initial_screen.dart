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

class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
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

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isCompact = w < 720;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top nav ───────────────────────────────────────────────
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
            // ── Hero ──────────────────────────────────────────────────
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 24 : 32,
                        vertical: 28,
                      ),
                      child: _Hero(
                        isCompact: isCompact,
                        onStart: _openAuth,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // ── Scroll hint ──────────────────────────────────────────
            const _ScrollHint(),
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

  const _Hero({required this.isCompact, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final titleSize = isCompact ? 38.0 : 56.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Eyebrow — "Powered by" badge
        AppFadeSlide(
          delay: const Duration(milliseconds: 60),
          child: const _PoweredByBadge(),
        ),
        const SizedBox(height: 28),
        // Headline
        AppFadeSlide(
          delay: const Duration(milliseconds: 120),
          child: Column(
            children: [
              _HighlightLine(
                text: '복잡한 학습 자료',
                fontSize: titleSize,
              ),
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
        // Subtitle
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
        // CTAs
        AppFadeSlide(
          delay: const Duration(milliseconds: 240),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              _PillButton(
                label: '기능 보기',
                filled: false,
                onTap: () {},
              ),
              _PillButton(
                label: '지금 시작하기',
                filled: true,
                onTap: onStart,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // Social proof
        AppFadeSlide(
          delay: const Duration(milliseconds: 320),
          child: const _SocialProof(),
        ),
      ],
    );
  }
}

// Headline line with a soft marker highlight behind the text.
class _HighlightLine extends StatelessWidget {
  final String text;
  final double fontSize;

  const _HighlightLine({required this.text, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Marker bar behind the lower half of the text
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
// Brand mark (black logo + wordmark)
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 18, top: 4),
      child: Column(
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
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Pill button (filled black / outline)
// ───────────────────────────────────────────────────────────────────────────

class _PillButton extends StatefulWidget {
  final String label;
  final bool filled;
  final bool compact;
  final VoidCallback onTap;

  const _PillButton({
    required this.label,
    required this.filled,
    required this.onTap,
    this.compact = false,
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

    final bg = filled
        ? (_hovered ? const Color(0xFF22232B) : _ink)
        : (_hovered ? _highlight : _bg);
    final fg = filled ? Colors.white : _ink;

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
            border: filled ? null : Border.all(color: _line, width: 1.5),
            boxShadow: filled && _hovered
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
