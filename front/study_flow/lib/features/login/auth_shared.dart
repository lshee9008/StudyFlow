import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme.dart';
import '../../core/ui/app_components.dart';

class AuthScaffold extends StatelessWidget {
  final Widget child;
  final VoidCallback? onBack;
  final bool showBack;

  const AuthScaffold({
    super.key,
    required this.child,
    this.onBack,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final isCompact = MediaQuery.of(context).size.width < 960;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // Subtle aurora
          Positioned(
            top: -200,
            left: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accent.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            right: -80,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.purple.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: const SizedBox.expand(),
            ),
          ),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              child: Column(
                children: [
                  // Top bar
                  AppFadeSlide(
                    beginOffset: const Offset(0, -8),
                    duration: const Duration(milliseconds: 400),
                    child: Row(
                      children: [
                        if (showBack) ...[
                          _AuthBackButton(
                            onTap: onBack ?? () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // Brand wordmark
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                gradient: AppGradients.accent,
                                borderRadius: BorderRadius.circular(7),
                                boxShadow: AppShadows.accentGlow(
                                  AppTheme.accent,
                                  intensity: 0.25,
                                ),
                              ),
                              child: const Center(
                                child: _MiniIcon(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ShaderMask(
                              shaderCallback: (bounds) =>
                                  AppGradients.accent.createShader(bounds),
                              blendMode: BlendMode.srcIn,
                              child: Text(
                                AppTheme.brandName,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.border.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Account',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: isCompact
                        ? SingleChildScrollView(child: child)
                        : Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1120),
                              child: child,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniIcon extends StatelessWidget {
  const _MiniIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 13,
      height: 13,
      child: CustomPaint(painter: _MiniIconPainter()),
    );
  }
}

class _MiniIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    canvas.drawLine(Offset(w * 0.15, h * 0.28), Offset(w * 0.85, h * 0.28), paint);
    canvas.drawLine(Offset(w * 0.15, h * 0.54), Offset(w * 0.62, h * 0.54), paint);
    canvas.drawLine(Offset(w * 0.15, h * 0.78), Offset(w * 0.74, h * 0.78), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AuthBackButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AuthBackButton({required this.onTap});

  @override
  State<_AuthBackButton> createState() => _AuthBackButtonState();
}

class _AuthBackButtonState extends State<_AuthBackButton> {
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _hovered ? colors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered ? colors.border : colors.border.withValues(alpha: 0.5),
            ),
          ),
          child: Icon(
            LucideIcons.arrowLeft,
            size: 15,
            color: _hovered ? colors.textPrimary : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Split layout
// ─────────────────────────────────────────────────────────────────────────────

class AuthSplitLayout extends StatelessWidget {
  final Widget left;
  final Widget right;

  const AuthSplitLayout({super.key, required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 960;

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [left, const SizedBox(height: 20), right],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 10, child: left),
        const SizedBox(width: 32),
        Expanded(flex: 8, child: right),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Auth hero card
// ─────────────────────────────────────────────────────────────────────────────

class AuthHero extends StatefulWidget {
  final String eyebrow;
  final String title;
  final String body;
  final List<(IconData, String)> items;

  const AuthHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.items,
  });

  @override
  State<AuthHero> createState() => _AuthHeroState();
}

class _AuthHeroState extends State<AuthHero>
    with SingleTickerProviderStateMixin {
  late AnimationController _blobCtrl;

  @override
  void initState() {
    super.initState();
    _blobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blobCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return AppFadeSlide(
      delay: const Duration(milliseconds: 80),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Background
            Positioned.fill(
              child: Container(decoration: const BoxDecoration(gradient: AppGradients.heroCard)),
            ),
            // Aurora blobs
            AnimatedBuilder(
              animation: _blobCtrl,
              builder: (_, __) {
                final t = CurvedAnimation(parent: _blobCtrl, curve: Curves.easeInOut).value;
                return Stack(
                  children: [
                    Positioned(
                      left: lerpDouble(-80, -30, t),
                      top: lerpDouble(-80, -40, t),
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.accent.withValues(alpha: 0.10),
                        ),
                      ),
                    ),
                    Positioned(
                      right: lerpDouble(-60, -20, 1 - t),
                      bottom: lerpDouble(-40, -70, t),
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.purple.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            // Blur
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: const SizedBox.expand(),
              ),
            ),
            // Border
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border.withValues(alpha: 0.5)),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: AppTheme.accent,
                                shape: BoxShape.circle,
                                boxShadow: AppShadows.accentGlow(AppTheme.accent),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              widget.eyebrow,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: AppGradients.accentSoft,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
                        ),
                        child: const Center(
                          child: Icon(LucideIcons.sparkles, size: 15, color: AppTheme.accent),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.title,
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.8,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.body,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.6),
                      height: 1.65,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Stats
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _AuthStatItem(
                            label: '작업 흐름',
                            value: 'Single view',
                            icon: LucideIcons.layers,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 32,
                          color: Colors.white.withValues(alpha: 0.09),
                        ),
                        Expanded(
                          child: _AuthStatItem(
                            label: '복원 속도',
                            value: 'Instant',
                            icon: LucideIcons.zap,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Feature list
                  for (var i = 0; i < widget.items.length; i++) ...[
                    AppFadeSlide(
                      delay: Duration(milliseconds: 200 + i * 60),
                      child: _AuthListItem(
                        icon: widget.items[i].$1,
                        label: widget.items[i].$2,
                      ),
                    ),
                    if (i < widget.items.length - 1) const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthStatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _AuthStatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 12, color: AppTheme.accent),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuthListItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _AuthListItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            gradient: AppGradients.accentSoft,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, size: 14, color: AppTheme.accent),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.75),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Auth panel (right side form container)
// ─────────────────────────────────────────────────────────────────────────────

class AuthPanel extends StatelessWidget {
  final Widget child;

  const AuthPanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return AppFadeSlide(
      delay: const Duration(milliseconds: 140),
      beginOffset: const Offset(16, 0),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
          boxShadow: AppShadows.elevation2,
        ),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Auth header
// ─────────────────────────────────────────────────────────────────────────────

class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: colors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
