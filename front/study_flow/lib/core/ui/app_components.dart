import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme.dart';

class AppBrandMark extends StatelessWidget {
  final double size;

  const AppBrandMark({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.accent, colors.accent.withValues(alpha: 0.76)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppShadows.accentGlow(colors.accent, intensity: 0.18),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(width: size * 0.42, height: 2, color: Colors.white),
            Positioned(
              top: size * 0.22,
              child: Container(
                width: size * 0.24,
                height: 2,
                color: Colors.white,
              ),
            ),
            Positioned(
              bottom: size * 0.22,
              child: Container(
                width: size * 0.24,
                height: 2,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppWordmark extends StatelessWidget {
  const AppWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppBrandMark(),
        const SizedBox(width: AppSpace.sm),
        Text(
          AppTheme.brandName,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool interactive;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.interactive = false,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: widget.interactive
            ? (_) => setState(() => _hovered = true)
            : null,
        onExit: widget.interactive
            ? (_) => setState(() => _hovered = false)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()
            ..translateByDouble(0.0, _hovered ? -2.0 : 0.0, 0.0, 1.0),
          padding: widget.padding ?? const EdgeInsets.all(AppSpace.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors.surface.withValues(alpha: 0.98),
                colors.surface.withValues(alpha: 0.88),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered
                  ? colors.accent.withValues(alpha: 0.28)
                  : colors.border,
            ),
            boxShadow: _hovered
                ? AppShadows.cardHover(colors.accent)
                : AppShadows.elevation1,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool busy;
  final IconData? icon;
  final double? width;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.primary = true,
    this.busy = false,
    this.icon,
    this.width,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final disabled = widget.onPressed == null || widget.busy;
    final primary = widget.primary;
    final background = primary ? colors.accent : colors.surface;
    final foreground = primary ? Colors.white : colors.textPrimary;

    return SizedBox(
      width: widget.width,
      height: 40,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: AnimatedScale(
          scale: _pressed ? 0.975 : 1,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: disabled
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      widget.onPressed?.call();
                    },
              onTapDown: disabled
                  ? null
                  : (_) => setState(() => _pressed = true),
              onTapCancel: disabled
                  ? null
                  : () => setState(() => _pressed = false),
              onTapUp: disabled
                  ? null
                  : (_) => setState(() => _pressed = false),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                decoration: BoxDecoration(
                  gradient: primary
                      ? LinearGradient(
                          colors: [
                            disabled
                                ? background.withValues(alpha: 0.45)
                                : (_hovered
                                      ? AppTheme.accentHover
                                      : background),
                            disabled
                                ? background.withValues(alpha: 0.36)
                                : background,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: primary
                      ? null
                      : (_hovered
                            ? colors.surface.withValues(alpha: 0.94)
                            : colors.surface),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: primary
                        ? background.withValues(alpha: 0.24)
                        : (_hovered
                              ? colors.accent.withValues(alpha: 0.24)
                              : colors.border),
                  ),
                  boxShadow: disabled
                      ? const []
                      : (primary
                            ? AppShadows.accentGlow(
                                colors.accent,
                                intensity: 0.18,
                              )
                            : (_hovered
                                  ? AppShadows.elevation2
                                  : AppShadows.elevation1)),
                ),
                child: Center(
                  child: widget.busy
                      ? AppSkeletonLine(
                          width: 48,
                          height: 10,
                          color: foreground.withValues(alpha: 0.28),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.icon != null) ...[
                              Icon(widget.icon, size: 16, color: foreground),
                              const SizedBox(width: AppSpace.xs),
                            ],
                            Text(
                              widget.label,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: foreground,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppInput extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String? label;
  final IconData? icon;
  final bool obscureText;
  final bool autofocus;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  const AppInput({
    super.key,
    required this.controller,
    required this.hintText,
    this.label,
    this.icon,
    this.obscureText = false,
    this.autofocus = false,
    this.keyboardType,
    this.onSubmitted,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppTheme.colorsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: theme.textTheme.labelMedium),
          const SizedBox(height: AppSpace.xs),
        ],
        TextField(
          controller: controller,
          autofocus: autofocus,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onSubmitted: onSubmitted,
          onChanged: onChanged,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: icon == null
                ? null
                : Icon(icon, size: 16, color: colors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class AppBadge extends StatelessWidget {
  final String label;

  const AppBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const AppEmptyState({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.md),
          AppButton(label: actionLabel, onPressed: onAction),
        ],
      ),
    );
  }
}

class AppInlineMessage extends StatelessWidget {
  final String message;

  const AppInlineMessage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.info, size: 16, color: colors.textSecondary),
          const SizedBox(width: AppSpace.xs),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class AppSkeletonBlock extends StatelessWidget {
  final double height;
  final double? width;

  const AppSkeletonBlock({super.key, required this.height, this.width});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return AppShimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colors.border.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class AppSkeletonLine extends StatelessWidget {
  final double width;
  final double height;
  final Color? color;

  const AppSkeletonLine({
    super.key,
    required this.width,
    this.height = 12,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.28, end: 0.5),
      duration: AppMotion.slow,
      curve: Curves.easeInOut,
      builder: (context, value, child) => AppShimmer(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: (color ?? colors.border).withValues(alpha: value),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
      onEnd: () {},
    );
  }
}

class AppServiceHeader extends StatelessWidget {
  final String pageName;
  final String? helper;
  final Widget? leading;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfile;
  final int notificationCount;

  const AppServiceHeader({
    super.key,
    required this.pageName,
    this.helper,
    this.leading,
    this.onNotifications,
    this.onProfile,
    this.notificationCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: AppSpace.sm)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pageName, style: Theme.of(context).textTheme.titleMedium),
              if (helper != null)
                Text(helper!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onProfile ?? () {},
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Icon(
                LucideIcons.user2,
                size: 16,
                color: colors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AppWorkspaceShell extends StatefulWidget {
  final String currentNav;
  final String title;
  final String? subtitle;
  final String profileLabel;
  final Widget child;
  final Widget? primaryAction;
  final Widget? secondaryAction;
  final VoidCallback onHome;
  final VoidCallback onWorkspace;
  final VoidCallback onSearch;
  final VoidCallback onSettings;
  final bool compact;

  const AppWorkspaceShell({
    super.key,
    required this.currentNav,
    required this.title,
    required this.profileLabel,
    required this.child,
    required this.onHome,
    required this.onWorkspace,
    required this.onSearch,
    required this.onSettings,
    this.subtitle,
    this.primaryAction,
    this.secondaryAction,
    this.compact = false,
  });

  @override
  State<AppWorkspaceShell> createState() => _AppWorkspaceShellState();
}

class _AppWorkspaceShellState extends State<AppWorkspaceShell> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: _ShellBackdrop()),
            Row(
              children: [
                if (!widget.compact)
                  Container(
                    width: _collapsed ? 88 : 228,
                    margin: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: 0.76),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colors.border.withValues(alpha: 0.9),
                      ),
                      boxShadow: AppShadows.elevation1,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpace.md,
                            AppSpace.md,
                            AppSpace.md,
                            AppSpace.sm,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Opacity(
                                  opacity: _collapsed ? 0.95 : 1,
                                  child: _collapsed
                                      ? const Align(
                                          alignment: Alignment.centerLeft,
                                          child: AppBrandMark(),
                                        )
                                      : const AppWordmark(),
                                ),
                              ),
                              AppPressable(
                                scaleFactor: 0.98,
                                onTap: () {
                                  setState(() => _collapsed = !_collapsed);
                                },
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: colors.border),
                                    color: colors.surface,
                                  ),
                                  child: Icon(
                                    _collapsed
                                        ? LucideIcons.panelLeftOpen
                                        : LucideIcons.panelLeftClose,
                                    size: 14,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpace.xs),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.xs,
                          ),
                          child: Column(
                            children: [
                              AppSidebarItem(
                                icon: LucideIcons.layoutDashboard,
                                selected: widget.currentNav == 'home',
                                onTap: widget.onHome,
                                label: '홈',
                                collapsed: _collapsed,
                              ),
                              const SizedBox(height: 2),
                              AppSidebarItem(
                                icon: LucideIcons.folderKanban,
                                selected: widget.currentNav == 'workspace',
                                onTap: widget.onWorkspace,
                                label: '워크스페이스',
                                collapsed: _collapsed,
                              ),
                              const SizedBox(height: 2),
                              AppSidebarItem(
                                icon: LucideIcons.search,
                                selected: widget.currentNav == 'search',
                                onTap: widget.onSearch,
                                label: '검색',
                                collapsed: _collapsed,
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.md,
                          ),
                          child: Divider(height: 1, color: colors.border),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpace.xs,
                            AppSpace.xs,
                            AppSpace.xs,
                            AppSpace.md,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: InkWell(
                              onTap: widget.onSettings,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpace.sm,
                                  vertical: AppSpace.xs,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: colors.accent,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Center(
                                        child: Text(
                                          widget.profileLabel.isEmpty
                                              ? 'S'
                                              : widget.profileLabel[0]
                                                    .toUpperCase(),
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                    ),
                                    if (!_collapsed) ...[
                                      const SizedBox(width: AppSpace.sm),
                                      Expanded(
                                        child: Text(
                                          widget.profileLabel,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.labelMedium,
                                        ),
                                      ),
                                      Icon(
                                        LucideIcons.settings,
                                        size: 13,
                                        color: colors.textSecondary,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      widget.compact ? 0 : 12,
                      12,
                      12,
                      12,
                    ),
                    child: Column(
                      children: [
                        Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.lg,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surface.withValues(alpha: 0.76),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: colors.border.withValues(alpha: 0.9),
                            ),
                            boxShadow: AppShadows.elevation1,
                          ),
                          child: Row(
                            children: [
                              if (widget.compact) ...[
                                const AppWordmark(),
                                const SizedBox(width: AppSpace.md),
                              ],
                              Expanded(
                                child: Text(
                                  widget.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontSize: 13,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                              if (widget.secondaryAction != null) ...[
                                widget.secondaryAction!,
                                const SizedBox(width: AppSpace.xs),
                              ],
                              if (widget.primaryAction != null)
                                widget.primaryAction!,
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpace.md),
                        Expanded(
                          child: AppFadeSlide(
                            beginOffset: const Offset(0, 14),
                            duration: const Duration(milliseconds: 320),
                            child: widget.child,
                          ),
                        ),
                      ],
                    ),
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

class _HeaderIconBadge extends StatelessWidget {
  final IconData icon;
  final int badge;
  final VoidCallback onTap;
  final String? label;

  const _HeaderIconBadge({
    required this.icon,
    required this.badge,
    required this.onTap,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: label == null ? 36 : 52,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (label != null)
                Text(label!, style: Theme.of(context).textTheme.labelSmall)
              else
                Icon(icon, size: 16, color: colors.textSecondary),
              if (badge > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: colors.accent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppFooterLinks extends StatelessWidget {
  const AppFooterLinks({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          AppTheme.brandVersion,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const Spacer(),
        Text('이용약관', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(width: AppSpace.md),
        Text('개인정보처리방침', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class AppMetricCard extends StatelessWidget {
  final String label;
  final int value;

  const AppMetricCard({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      interactive: true,
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpace.xs),
          AppCountUp(
            value: value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontFamily: 'monospace',
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class AppSidebarItem extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String label;
  final bool collapsed;

  const AppSidebarItem({
    super.key,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.label,
    this.collapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return AppPressable(
      scaleFactor: 0.985,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.normal,
        curve: AppMotion.ease,
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [
                    colors.accent.withValues(alpha: 0.18),
                    colors.surface.withValues(alpha: 0.96),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? colors.accent.withValues(alpha: 0.26)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? colors.textPrimary : colors.textSecondary,
            ),
            if (!collapsed) ...[
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? colors.textPrimary : colors.textSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShellBackdrop extends StatelessWidget {
  const _ShellBackdrop();

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          gradient: RadialGradient(
            center: const Alignment(-0.95, -0.95),
            radius: 1.45,
            colors: [colors.accent.withValues(alpha: 0.14), colors.background],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -70,
              right: -30,
              child: _AmbientOrb(
                color: colors.accent.withValues(alpha: 0.12),
                size: 240,
              ),
            ),
            Positioned(
              bottom: -100,
              left: -50,
              child: _AmbientOrb(
                color: colors.textSecondary.withValues(alpha: 0.07),
                size: 300,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _AmbientOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

// ── AppShimmer (sweep gradient shimmer) ──────────────────────────────────────
class AppShimmer extends StatefulWidget {
  final Widget child;

  const AppShimmer({super.key, required this.child});

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final shimmerPos = _ctrl.value * 3 - 1.0;
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(shimmerPos - 1, -0.3),
            end: Alignment(shimmerPos + 0.5, 0.3),
            colors: const [
              Color(0x003B4552),
              Color(0xAA4A5568),
              Color(0x003B4552),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(bounds),
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ── AppSidebarProjectItem ────────────────────────────────────────────────────
class AppSidebarProjectItem extends StatelessWidget {
  final String emoji;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const AppSidebarProjectItem({
    super.key,
    required this.emoji,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return Material(
      color: selected ? colors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: AppMotion.normal,
          curve: AppMotion.ease,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? colors.border : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? colors.textPrimary : colors.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── AppStaggerList ────────────────────────────────────────────────────────────
class AppStaggerList extends StatefulWidget {
  final List<Widget> children;
  final int delayMs;

  const AppStaggerList({super.key, required this.children, this.delayMs = 30});

  @override
  State<AppStaggerList> createState() => _AppStaggerListState();
}

class _AppStaggerListState extends State<AppStaggerList>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: 300 + widget.children.length * widget.delayMs,
      ),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(widget.children.length, (index) {
        final start = (index * widget.delayMs / 1000).clamp(0.0, 0.8);
        final end = (start + 0.4).clamp(0.0, 1.0);

        final slideAnim = Tween<double>(begin: 8, end: 0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(start, end, curve: Curves.easeOutCubic),
          ),
        );
        final fadeAnim = Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(start, end, curve: Curves.easeOut),
          ),
        );

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, slideAnim.value),
              child: Opacity(opacity: fadeAnim.value, child: child),
            );
          },
          child: widget.children[index],
        );
      }),
    );
  }
}

// ── AppTopBar ─────────────────────────────────────────────────────────────────
class AppTopBar extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final Widget? leading;

  const AppTopBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpace.sm),
          ],
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          ...actions,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Animation Utilities
// ═══════════════════════════════════════════════════════════════════════════════

// ── AppCountUp ────────────────────────────────────────────────────────────────
/// Animates a number from 0 to [value] when first built.
class AppCountUp extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;

  const AppCountUp({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        v.round().toString(),
        style: style ?? Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

// ── AppPressable ──────────────────────────────────────────────────────────────
/// Wraps [child] with a spring-scale press animation.
class AppPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;

  const AppPressable({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 0.97,
  });

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}

// ── AppFadeSlide ──────────────────────────────────────────────────────────────
/// Slides and fades in [child] on mount, with optional [delay].
class AppFadeSlide extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Offset beginOffset;
  final Duration duration;

  const AppFadeSlide({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.beginOffset = const Offset(0, 20),
    this.duration = const Duration(milliseconds: 420),
  });

  @override
  State<AppFadeSlide> createState() => _AppFadeSlideState();
}

class _AppFadeSlideState extends State<AppFadeSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: widget.beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Transform.translate(
        offset: _slide.value,
        child: Opacity(opacity: _fade.value, child: child),
      ),
      child: widget.child,
    );
  }
}

// ── AppPulse ──────────────────────────────────────────────────────────────────
/// Continuously pulses [child]'s opacity for subtle emphasis.
class AppPulse extends StatefulWidget {
  final Widget child;
  final double minOpacity;
  final double maxOpacity;
  final Duration duration;

  const AppPulse({
    super.key,
    required this.child,
    this.minOpacity = 0.5,
    this.maxOpacity = 1.0,
    this.duration = const Duration(milliseconds: 1600),
  });

  @override
  State<AppPulse> createState() => _AppPulseState();
}

class _AppPulseState extends State<AppPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: widget.minOpacity,
        end: widget.maxOpacity,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

// ── AppGlassCard ──────────────────────────────────────────────────────────────
/// A card with a frosted glass-like appearance and subtle gradient.
class AppGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;
  final Gradient? gradient;

  const AppGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.boxShadow,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final br = borderRadius ?? BorderRadius.circular(12);

    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding ?? const EdgeInsets.all(AppSpace.lg),
          decoration: BoxDecoration(
            gradient: gradient ?? AppGradients.heroCard,
            borderRadius: br,
            border: Border.all(color: colors.border.withValues(alpha: 0.6)),
            boxShadow: boxShadow ?? AppShadows.elevation2,
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── AppAuroraBackground ───────────────────────────────────────────────────────
/// Animated aurora/blob background for hero cards.
class AppAuroraBackground extends StatefulWidget {
  final Widget child;
  final Color color1;
  final Color color2;

  const AppAuroraBackground({
    super.key,
    required this.child,
    this.color1 = const Color(0xFF6C8CFF),
    this.color2 = const Color(0xFF9B8BFF),
  });

  @override
  State<AppAuroraBackground> createState() => _AppAuroraBackgroundState();
}

class _AppAuroraBackgroundState extends State<AppAuroraBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base gradient
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(gradient: AppGradients.heroCard),
          ),
        ),
        // Animated blob 1
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            final t = CurvedAnimation(
              parent: _ctrl,
              curve: Curves.easeInOut,
            ).value;
            return Positioned(
              left: lerpDouble(-80, -30, t),
              top: lerpDouble(-80, -40, t),
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color1.withValues(alpha: 0.13),
                ),
              ),
            );
          },
        ),
        // Animated blob 2
        AnimatedBuilder(
          animation: _ctrl,
          builder: (ctx, ch) {
            final t = CurvedAnimation(
              parent: _ctrl,
              curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
            ).value;
            return Positioned(
              right: lerpDouble(-60, -20, t),
              bottom: lerpDouble(-40, -70, t),
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color2.withValues(alpha: 0.10),
                ),
              ),
            );
          },
        ),
        // Blur overlay over blobs
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: const SizedBox.expand(),
          ),
        ),
        // Content on top
        widget.child,
      ],
    );
  }
}

double? lerpDouble(double a, double b, double t) => a + (b - a) * t;
