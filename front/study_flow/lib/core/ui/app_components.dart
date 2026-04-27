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
        color: colors.accent,
        borderRadius: BorderRadius.circular(10),
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

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const AppCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return RepaintBoundary(
      child: Container(
        padding: padding ?? const EdgeInsets.all(AppSpace.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.border),
        ),
        child: child,
      ),
    );
  }
}

class AppButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final disabled = onPressed == null || busy;
    final background = primary ? colors.accent : colors.surface;
    final foreground = primary ? Colors.white : colors.textPrimary;

    return SizedBox(
      width: width,
      height: 40,
      child: Material(
        color: disabled ? background.withValues(alpha: 0.45) : background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: disabled
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onPressed?.call();
                },
          borderRadius: BorderRadius.circular(AppRadius.md),
          onHighlightChanged: (_) {},
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 1, end: 1),
            duration: AppMotion.fast,
            curve: AppMotion.ease,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: primary ? colors.accent : colors.border,
                ),
              ),
              child: Center(
                child: busy
                    ? AppSkeletonLine(
                        width: 48,
                        height: 10,
                        color: foreground.withValues(alpha: 0.28),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            Icon(icon, size: 16, color: foreground),
                            const SizedBox(width: AppSpace.xs),
                          ],
                          Text(
                            label,
                            style: Theme.of(
                              context,
                            ).textTheme.labelLarge?.copyWith(color: foreground),
                          ),
                        ],
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

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.border.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(AppRadius.md),
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
      tween: Tween(begin: 0.25, end: 0.5),
      duration: AppMotion.slow,
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: (color ?? colors.border).withValues(alpha: value),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        );
      },
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
        _HeaderIconBadge(
          icon: LucideIcons.command,
          badge: 0,
          onTap: () {},
          label: '⌘K',
        ),
        const SizedBox(width: AppSpace.xs),
        _HeaderIconBadge(
          icon: LucideIcons.bell,
          badge: notificationCount,
          onTap: onNotifications ?? () {},
        ),
        const SizedBox(width: AppSpace.xs),
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

class AppWorkspaceShell extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Row(
          children: [
            if (!compact)
              Container(
                width: 220,
                padding: const EdgeInsets.all(AppSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpace.xs),
                    const AppWordmark(),
                    const SizedBox(height: AppSpace.xxl),
                    AppSidebarItem(
                      icon: LucideIcons.home,
                      selected: currentNav == 'home',
                      onTap: onHome,
                      label: 'Home',
                    ),
                    const SizedBox(height: AppSpace.xs),
                    AppSidebarItem(
                      icon: LucideIcons.folderKanban,
                      selected: currentNav == 'workspace',
                      onTap: onWorkspace,
                      label: 'Workspace',
                    ),
                    const SizedBox(height: AppSpace.xs),
                    AppSidebarItem(
                      icon: LucideIcons.search,
                      selected: currentNav == 'search',
                      onTap: onSearch,
                      label: 'Search',
                    ),
                    const Spacer(),
                    AppCard(
                      padding: const EdgeInsets.all(AppSpace.sm),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: colors.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colors.border),
                            ),
                            child: Center(
                              child: Text(
                                profileLabel.isEmpty
                                    ? 'S'
                                    : profileLabel[0].toUpperCase(),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpace.sm),
                          Expanded(
                            child: Text(
                              profileLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    InkWell(
                      onTap: onSettings,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.sm,
                          vertical: AppSpace.xs,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.settings,
                              size: 16,
                              color: colors.textSecondary,
                            ),
                            const SizedBox(width: AppSpace.sm),
                            Text(
                              'Settings',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    const AppFooterLinks(),
                  ],
                ),
              ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 20 : 16,
                      12,
                      compact ? 20 : 16,
                      16,
                    ),
                    child: Column(
                      children: [
                        Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            children: [
                              if (compact) ...[
                                const AppWordmark(),
                                const SizedBox(width: AppSpace.md),
                              ],
                              _TopTab(label: 'Drafts'),
                              const SizedBox(width: AppSpace.md),
                              _TopTab(label: 'Library'),
                              const SizedBox(width: AppSpace.md),
                              _TopTab(label: 'Sync'),
                              const Spacer(),
                              _HeaderIconBadge(
                                icon: LucideIcons.command,
                                badge: 0,
                                onTap: _noopAction,
                                label: '⌘K',
                              ),
                              const SizedBox(width: AppSpace.xs),
                              _HeaderIconBadge(
                                icon: LucideIcons.bell,
                                badge: 1,
                                onTap: _noopAction,
                              ),
                              const SizedBox(width: AppSpace.xs),
                              if (secondaryAction != null) ...[
                                secondaryAction!,
                                const SizedBox(width: AppSpace.xs),
                              ],
                              if (primaryAction != null) primaryAction!,
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpace.md),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: colors.background,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpace.lg,
                                    vertical: AppSpace.lg,
                                  ),
                                  child: AppServiceHeader(
                                    pageName: title,
                                    helper: subtitle,
                                    notificationCount: 1,
                                  ),
                                ),
                                Expanded(child: child),
                              ],
                            ),
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
      ),
    );
  }
}

class _TopTab extends StatelessWidget {
  final String label;

  const _TopTab({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label, style: Theme.of(context).textTheme.bodySmall);
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

void _noopAction() {}

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
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpace.xs),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: AppMotion.slow,
            curve: AppMotion.ease,
            builder: (context, animatedValue, child) {
              return Text(
                animatedValue.round().toString(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              );
            },
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

  const AppSidebarItem({
    super.key,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.label,
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
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? colors.border : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? colors.textPrimary : colors.textSecondary,
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? colors.textPrimary : colors.textSecondary,
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

// ── AppShimmer ────────────────────────────────────────────────────────────────
class AppShimmer extends StatefulWidget {
  final Widget child;

  const AppShimmer({super.key, required this.child});

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(opacity: _animation.value, child: child);
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
