import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';

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
    final isMobile = MediaQuery.of(context).size.width < 960;

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      body: Stack(
        children: [
          const Positioned.fill(child: _AuthBackground()),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 18 : 28),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (showBack) ...[
                        AuthBackButton(
                          onTap: onBack ?? () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 14),
                      ],
                      const SFLogo(size: 28),
                      const Spacer(),
                      const SFBadge(
                        label: 'PRIVATE BETA',
                        color: AppTheme.green,
                        bgColor: AppTheme.greenDim,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Expanded(
                    child: isMobile
                        ? SingleChildScrollView(child: child)
                        : Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1220),
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

class AuthSplitLayout extends StatelessWidget {
  final Widget left;
  final Widget right;

  const AuthSplitLayout({super.key, required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 960;
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [left, const SizedBox(height: 18), right],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 10, child: left),
        const SizedBox(width: 20),
        Expanded(flex: 8, child: right),
      ],
    );
  }
}

class AuthHeroPanel extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String description;
  final List<(IconData, String)> bullets;

  const AuthHeroPanel({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.bullets,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 960;

    return Container(
      padding: EdgeInsets.all(isMobile ? 22 : 30),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: AppTheme.bgSecondary.withValues(alpha: 0.88),
        border: Border.all(
          color: AppTheme.borderDefault.withValues(alpha: 0.72),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SFBadge(
            label: eyebrow,
            color: AppTheme.blue,
            bgColor: AppTheme.blueDim,
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: AppTheme.displayMedium.copyWith(
              fontSize: isMobile ? 30 : 44,
              height: 1.06,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            description,
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.textSecondary,
              fontSize: isMobile ? 14 : 16,
            ),
          ),
          const SizedBox(height: 24),
          ...bullets.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _HeroBullet(icon: item.$1, label: item.$2),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: isMobile ? 176 : 196,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: AppTheme.bgPrimary.withValues(alpha: 0.72),
                border: Border.all(
                  color: AppTheme.borderSubtle.withValues(alpha: 0.9),
                ),
              ),
              child: const _HeroPreview(),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthFormPanel extends StatelessWidget {
  final Widget child;

  const AuthFormPanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            AppTheme.bgSecondary.withValues(alpha: 0.94),
            AppTheme.bgPrimary.withValues(alpha: 0.98),
          ],
        ),
        border: Border.all(
          color: AppTheme.borderDefault.withValues(alpha: 0.9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 48,
            offset: const Offset(0, 24),
            spreadRadius: -18,
          ),
        ],
      ),
      child: child,
    );
  }
}

class AuthSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const AuthSectionTitle({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color = AppTheme.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color.withValues(alpha: 0.24)),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTheme.headingLarge),
              const SizedBox(height: 4),
              Text(subtitle, style: AppTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class AuthHelperBox extends StatelessWidget {
  final String message;
  final Color color;
  final IconData icon;

  const AuthHelperBox({
    super.key,
    required this.message,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: color.withValues(alpha: 0.09),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTheme.bodyMedium.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthBackButton extends StatefulWidget {
  final VoidCallback onTap;

  const AuthBackButton({super.key, required this.onTap});

  @override
  State<AuthBackButton> createState() => _AuthBackButtonState();
}

class _AuthBackButtonState extends State<AuthBackButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _hover
                ? AppTheme.bgTertiary.withValues(alpha: 0.92)
                : AppTheme.bgSecondary.withValues(alpha: 0.68),
            border: Border.all(
              color: _hover ? AppTheme.borderStrong : AppTheme.borderDefault,
            ),
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: _hover ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _HeroBullet extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroBullet({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: AppTheme.accentDim,
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.22)),
          ),
          child: Icon(icon, color: AppTheme.accent, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
          ),
        ),
      ],
    );
  }
}

class _HeroPreview extends StatelessWidget {
  const _HeroPreview();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 210;
        final titleSize = compact ? 17.0 : 20.0;
        final topGap = compact ? 10.0 : 14.0;
        final rowGap = compact ? 8.0 : 12.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Learning cockpit',
              style: GoogleFonts.spaceGrotesk(
                color: AppTheme.textPrimary,
                fontSize: titleSize,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: topGap),
            _PreviewBar(
              label: '강의 맥락 유지',
              value: 0.86,
              color: AppTheme.accent,
              compact: compact,
            ),
            SizedBox(height: rowGap),
            _PreviewBar(
              label: '핵심 개념 회수',
              value: 0.72,
              color: AppTheme.blue,
              compact: compact,
            ),
            SizedBox(height: rowGap),
            _PreviewBar(
              label: '오답 보정 루프',
              value: 0.64,
              color: AppTheme.green,
              compact: compact,
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: _MiniTile(
                    title: 'Recall',
                    value: '+34%',
                    compact: compact,
                  ),
                ),
                SizedBox(width: compact ? 8 : 10),
                Expanded(
                  child: _MiniTile(
                    title: 'Search',
                    value: '0.8s',
                    compact: compact,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _PreviewBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool compact;

  const _PreviewBar({
    required this.label,
    required this.value,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: AppTheme.labelMedium.copyWith(fontSize: compact ? 11 : 12),
            ),
            const Spacer(),
            Text(
              '${(value * 100).round()}%',
              style: AppTheme.labelSmall.copyWith(fontSize: compact ? 10 : 11),
            ),
          ],
        ),
        SizedBox(height: compact ? 5 : 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: compact ? 6 : 8,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            backgroundColor: AppTheme.bgTertiary,
          ),
        ),
      ],
    );
  }
}

class _MiniTile extends StatelessWidget {
  final String title;
  final String value;
  final bool compact;

  const _MiniTile({
    required this.title,
    required this.value,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 16 : 18),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.labelSmall.copyWith(fontSize: compact ? 10 : 11),
          ),
          SizedBox(height: compact ? 4 : 6),
          Text(
            value,
            style: AppTheme.headingMedium.copyWith(fontSize: compact ? 16 : 18),
          ),
        ],
      ),
    );
  }
}

class _AuthBackground extends StatefulWidget {
  const _AuthBackground();

  @override
  State<_AuthBackground> createState() => _AuthBackgroundState();
}

class _AuthBackgroundState extends State<_AuthBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          CustomPaint(painter: _AuthBackgroundPainter(_controller.value)),
    );
  }
}

class _AuthBackgroundPainter extends CustomPainter {
  final double t;

  const _AuthBackgroundPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppTheme.bgDeep);

    void blob(double x, double y, double radius, Color color, double opacity) {
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        radius,
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 150),
      );
    }

    blob(0.14 + t * 0.06, 0.18, 260, AppTheme.blue, 0.10);
    blob(
      0.86 - t * 0.05,
      0.18 + math.sin(t * math.pi) * 0.03,
      260,
      AppTheme.accent,
      0.08,
    );
    blob(0.50, 0.84 + math.cos(t * math.pi) * 0.04, 340, AppTheme.purple, 0.08);

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    const step = 46.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuthBackgroundPainter oldDelegate) {
    return (oldDelegate.t - t).abs() > 0.003;
  }
}
