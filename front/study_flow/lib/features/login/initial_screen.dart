import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme.dart';
import '../../core/ui/app_components.dart';
import 'login_or_create_membership_screen.dart';

class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen>
    with TickerProviderStateMixin {
  late final AnimationController _bgCtrl;
  late final AnimationController _enterCtrl;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  void _openAuth() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) =>
            const LoginOrCreateMembershipScreen(),
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
    final colors = AppTheme.colorsOf(context);
    final isCompact = MediaQuery.of(context).size.width < 960;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // ── Aurora background ────────────────────────────────────────────
          _AuroraLayer(ctrl: _bgCtrl),
          // ── Content ──────────────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1160),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 20,
                  ),
                  child: Column(
                    children: [
                      _TopNav(
                        enterCtrl: _enterCtrl,
                        onStart: _openAuth,
                      ),
                      const SizedBox(height: 48),
                      Expanded(
                        child: isCompact
                            ? _CompactBody(
                                enterCtrl: _enterCtrl,
                                onStart: _openAuth,
                              )
                            : _WideBody(
                                enterCtrl: _enterCtrl,
                                onStart: _openAuth,
                              ),
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Aurora layer
// ─────────────────────────────────────────────────────────────────────────────

class _AuroraLayer extends StatelessWidget {
  final AnimationController ctrl;
  const _AuroraLayer({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final t = CurvedAnimation(
          parent: ctrl,
          curve: Curves.easeInOut,
        ).value;
        return Stack(
          children: [
            // blob 1 — top left blue
            Positioned(
              left: lerpDouble(-200, -80, t),
              top: lerpDouble(-180, -100, t),
              child: Container(
                width: 600,
                height: 600,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accent.withValues(alpha: 0.07),
                ),
              ),
            ),
            // blob 2 — bottom right purple
            Positioned(
              right: lerpDouble(-160, -60, 1 - t),
              bottom: lerpDouble(-160, -80, t),
              child: Container(
                width: 480,
                height: 480,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.purple.withValues(alpha: 0.06),
                ),
              ),
            ),
            // blur pass
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top nav
// ─────────────────────────────────────────────────────────────────────────────

class _TopNav extends StatelessWidget {
  final AnimationController enterCtrl;
  final VoidCallback onStart;
  const _TopNav({required this.enterCtrl, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return AppFadeSlide(
      delay: const Duration(milliseconds: 0),
      beginOffset: const Offset(0, -10),
      duration: const Duration(milliseconds: 500),
      child: Row(
        children: [
          // Logo with glow
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: AppGradients.accent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: AppShadows.accentGlow(
                    AppTheme.accent,
                    intensity: 0.3,
                  ),
                ),
                child: Center(
                child: Image.asset(
                  'assets/images/logo_icon.png',
                  width: 20,
                  height: 20,
                  fit: BoxFit.contain,
                ),
              ),
              ),
              const SizedBox(width: 10),
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppGradients.accent.createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: Text(
                  AppTheme.brandName,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: colors.border.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              AppTheme.brandVersion,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ),
          const Spacer(),
          // Nav links (wide only)
          if (MediaQuery.of(context).size.width > 640) ...[
            _NavLink(label: '회원가입', onTap: onStart),
            const SizedBox(width: 20),
          ],
          _GlowButton(label: '로그인', onTap: onStart),
        ],
      ),
    );
  }
}

class _NavLink extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  const _NavLink({required this.label, this.onTap});

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 150),
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _hovered ? colors.textPrimary : colors.textSecondary,
          ),
          child: Text(widget.label),
        ),
      ),
    );
  }
}

class _GlowButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _GlowButton({required this.label, required this.onTap});

  @override
  State<_GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<_GlowButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => _pressCtrl.forward(),
        onTapUp: (_) {
          _pressCtrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _pressCtrl.reverse(),
        child: AnimatedBuilder(
          animation: _pressCtrl,
          builder: (_, child) => Transform.scale(
            scale: 1.0 - 0.03 * _pressCtrl.value,
            child: child,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: AppGradients.accent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: _hovered
                  ? AppShadows.accentGlow(AppTheme.accent, intensity: 0.4)
                  : AppShadows.accentGlow(AppTheme.accent, intensity: 0.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(LucideIcons.arrowRight, size: 13, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wide / Compact body
// ─────────────────────────────────────────────────────────────────────────────

class _WideBody extends StatelessWidget {
  final AnimationController enterCtrl;
  final VoidCallback onStart;

  const _WideBody({required this.enterCtrl, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 10, child: _HeroCopy(onStart: onStart)),
        const SizedBox(width: 40),
        Expanded(flex: 9, child: _PreviewPanel()),
      ],
    );
  }
}

class _CompactBody extends StatelessWidget {
  final AnimationController enterCtrl;
  final VoidCallback onStart;

  const _CompactBody({required this.enterCtrl, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _HeroCopy(onStart: onStart),
        const SizedBox(height: 32),
        SizedBox(height: 420, child: _PreviewPanel()),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero copy
// ─────────────────────────────────────────────────────────────────────────────

class _HeroCopy extends StatelessWidget {
  final VoidCallback onStart;

  const _HeroCopy({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final isCompact = MediaQuery.of(context).size.width < 960;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge
        AppFadeSlide(
          delay: const Duration(milliseconds: 100),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppTheme.green,
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.accentGlow(AppTheme.green),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'AI 기반 학습 노트',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accent,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Title
        AppFadeSlide(
          delay: const Duration(milliseconds: 160),
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '배움의 흐름을\n',
                  style: GoogleFonts.inter(
                    fontSize: isCompact ? 34 : 48,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                    letterSpacing: -1.5,
                    height: 1.12,
                  ),
                ),
                WidgetSpan(
                  child: ShaderMask(
                    shaderCallback: (bounds) =>
                        AppGradients.accent.createShader(bounds),
                    blendMode: BlendMode.srcIn,
                    child: Text(
                      '한 곳에서.',
                      style: GoogleFonts.inter(
                        fontSize: isCompact ? 34 : 48,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.5,
                        height: 1.12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        // Body
        AppFadeSlide(
          delay: const Duration(milliseconds: 220),
          child: Text(
            '노트를 쓰면 AI가 자동으로 요약하고,\n다음 학습으로 자연스럽게 이어주는 워크스페이스.',
            style: GoogleFonts.inter(
              fontSize: 15,
              color: colors.textSecondary,
              height: 1.75,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(height: 28),
        // Feature pills
        AppFadeSlide(
          delay: const Duration(milliseconds: 280),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _FeaturePill(icon: LucideIcons.fileText, label: '노트 작성'),
              _FeaturePill(icon: LucideIcons.brain, label: 'AI 요약'),
              _FeaturePill(icon: LucideIcons.search, label: '전체 검색'),
              _FeaturePill(icon: LucideIcons.folderKanban, label: '프로젝트 관리'),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // CTA
        AppFadeSlide(
          delay: const Duration(milliseconds: 340),
          child: _PrimaryCTA(onTap: onStart),
        ),
        const SizedBox(height: 32),
        // Social proof
        AppFadeSlide(
          delay: const Duration(milliseconds: 400),
          child: _SocialProofRow(colors: colors),
        ),
      ],
    );
  }
}

class _FeaturePill extends StatefulWidget {
  final IconData icon;
  final String label;

  const _FeaturePill({required this.icon, required this.label});

  @override
  State<_FeaturePill> createState() => _FeaturePillState();
}

class _FeaturePillState extends State<_FeaturePill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: _hovered
              ? colors.accent.withValues(alpha: 0.10)
              : colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _hovered
                ? colors.accent.withValues(alpha: 0.35)
                : colors.border,
          ),
          boxShadow: _hovered ? AppShadows.elevation1 : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.icon,
              size: 12,
              color: _hovered ? colors.accent : colors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              widget.label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _hovered ? colors.textPrimary : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryCTA extends StatefulWidget {
  final VoidCallback onTap;
  const _PrimaryCTA({required this.onTap});

  @override
  State<_PrimaryCTA> createState() => _PrimaryCTAState();
}

class _PrimaryCTAState extends State<_PrimaryCTA>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => _pressCtrl.forward(),
        onTapUp: (_) {
          _pressCtrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _pressCtrl.reverse(),
        child: AnimatedBuilder(
          animation: _pressCtrl,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.03 * _pressCtrl.value, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _hovered
                    ? [const Color(0xFF7A96FF), const Color(0xFF9E8FFF)]
                    : [const Color(0xFF5A7BFF), const Color(0xFF8B7BFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.45),
                        blurRadius: 24,
                        spreadRadius: -4,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : AppShadows.accentGlow(AppTheme.accent, intensity: 0.22),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '무료로 시작하기',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: _hovered ? 22 : 18,
                  child: Row(
                    children: const [
                      SizedBox(width: 6),
                      Icon(LucideIcons.arrowRight, size: 14, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialProofRow extends StatelessWidget {
  final AppColors colors;
  const _SocialProofRow({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Avatar stack
        SizedBox(
          width: 70,
          height: 24,
          child: Stack(
            children: List.generate(4, (i) {
              const avatarColors = [
                Color(0xFF5A7BFF),
                Color(0xFF8B7BFF),
                Color(0xFF5FA36A),
                Color(0xFFB69155),
              ];
              return Positioned(
                left: i * 16.0,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: avatarColors[i],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.background,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      ['김', '이', '박', '최'][i],
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '지금 바로 무료로 시작하세요',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: colors.textSecondary.withValues(alpha: 0.7),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Preview panel (right side mock UI)
// ─────────────────────────────────────────────────────────────────────────────

class _PreviewPanel extends StatefulWidget {
  @override
  State<_PreviewPanel> createState() => _PreviewPanelState();
}

class _PreviewPanelState extends State<_PreviewPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _floatCtrl;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return AppFadeSlide(
      delay: const Duration(milliseconds: 200),
      beginOffset: const Offset(24, 0),
      duration: const Duration(milliseconds: 600),
      child: AnimatedBuilder(
        animation: _floatCtrl,
        builder: (_, child) {
          final t = CurvedAnimation(
            parent: _floatCtrl,
            curve: Curves.easeInOut,
          ).value;
          return Transform.translate(
            offset: Offset(0, lerpDouble(-4, 4, t)!),
            child: child,
          );
        },
        child: _MockAppPreview(colors: colors),
      ),
    );
  }
}

class _MockAppPreview extends StatelessWidget {
  final AppColors colors;
  const _MockAppPreview({required this.colors});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppGradients.heroCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border.withValues(alpha: 0.6)),
          boxShadow: AppShadows.floating,
        ),
        child: Column(
          children: [
            // Window chrome
            _WindowChrome(colors: colors),
            // App mock content
            Expanded(
              child: Row(
                children: [
                  // Mini sidebar
                  _MockSidebar(colors: colors),
                  Container(width: 1, color: colors.border.withValues(alpha: 0.5)),
                  // Main area
                  Expanded(child: _MockMainArea(colors: colors)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowChrome extends StatelessWidget {
  final AppColors colors;
  const _WindowChrome({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: const Color(0xFFFF5F57), shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Container(width: 10, height: 10, decoration: BoxDecoration(color: const Color(0xFFFFBD2E), shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Container(width: 10, height: 10, decoration: BoxDecoration(color: const Color(0xFF28C840), shape: BoxShape.circle)),
          const Spacer(),
          Container(
            width: 120,
            height: 20,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: colors.border.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                'StudyFlow',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: colors.textSecondary.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _MockSidebar extends StatelessWidget {
  final AppColors colors;
  const _MockSidebar({required this.colors});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo
            Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    gradient: AppGradients.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/images/logo_icon.png',
                      width: 14,
                      height: 14,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                ShaderMask(
                  shaderCallback: (b) => AppGradients.accent.createShader(b),
                  blendMode: BlendMode.srcIn,
                  child: Text(
                    'StudyFlow',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Nav items
            for (var i = 0; i < 3; i++) ...[
              _MockNavItem(colors: colors, selected: i == 0),
              const SizedBox(height: 3),
            ],
            const SizedBox(height: 12),
            Container(height: 0.5, color: colors.border),
            const SizedBox(height: 10),
            Text(
              'WORKSPACE',
              style: GoogleFonts.inter(
                fontSize: 7,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < 4; i++) ...[
              _MockProjectItem(colors: colors, index: i),
              const SizedBox(height: 2),
            ],
          ],
        ),
      ),
    );
  }
}

class _MockNavItem extends StatelessWidget {
  final AppColors colors;
  final bool selected;
  const _MockNavItem({required this.colors, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: selected ? AppTheme.accent.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          if (selected)
            Container(
              width: 2,
              height: 12,
              decoration: BoxDecoration(
                gradient: AppGradients.accent,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          SizedBox(width: selected ? 6 : 8),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: selected ? AppTheme.accent : colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 5),
          Container(
            width: 40 + (selected ? 0.0 : 10.0),
            height: 7,
            decoration: BoxDecoration(
              color: selected
                  ? colors.textPrimary.withValues(alpha: 0.8)
                  : colors.border.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockProjectItem extends StatelessWidget {
  final AppColors colors;
  final int index;
  const _MockProjectItem({required this.colors, required this.index});

  @override
  Widget build(BuildContext context) {
    const emojis = ['📚', '🧠', '⚡', '🎯'];

    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Text(emojis[index], style: const TextStyle(fontSize: 9)),
          const SizedBox(width: 4),
          Container(
            width: 50 + index * 8.0,
            height: 7,
            decoration: BoxDecoration(
              color: colors.border.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockMainArea extends StatelessWidget {
  final AppColors colors;
  const _MockMainArea({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero greeting card mock
          Container(
            height: 90,
            decoration: BoxDecoration(
              gradient: AppGradients.heroCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border.withValues(alpha: 0.5)),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 60,
                        height: 7,
                        decoration: BoxDecoration(
                          color: colors.textSecondary.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 5),
                      ShaderMask(
                        shaderCallback: (b) => AppGradients.accent.createShader(b),
                        blendMode: BlendMode.srcIn,
                        child: Container(
                          width: 90,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Container(
                            height: 16,
                            width: 55,
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.accent.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            height: 16,
                            width: 55,
                            decoration: BoxDecoration(
                              color: AppTheme.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.green.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Section header
          Row(
            children: [
              Container(width: 80, height: 8, decoration: BoxDecoration(color: colors.textPrimary.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(3))),
              const Spacer(),
              Container(width: 60, height: 22, decoration: BoxDecoration(gradient: AppGradients.accent, borderRadius: BorderRadius.circular(5))),
            ],
          ),
          const SizedBox(height: 10),
          // Project cards
          for (var i = 0; i < 3; i++) ...[
            _MockProjectCard(colors: colors, index: i),
            const SizedBox(height: 7),
          ],
        ],
      ),
    );
  }
}

class _MockProjectCard extends StatelessWidget {
  final AppColors colors;
  final int index;
  const _MockProjectCard({required this.colors, required this.index});

  @override
  Widget build(BuildContext context) {
    final bgColors = [
      AppTheme.accent.withValues(alpha: 0.15),
      AppTheme.purple.withValues(alpha: 0.15),
      AppTheme.green.withValues(alpha: 0.12),
    ];

    return Container(
      height: 50,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: bgColors[index % bgColors.length],
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80 + index * 15.0,
                height: 8,
                decoration: BoxDecoration(
                  color: colors.textPrimary.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 50,
                height: 6,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
