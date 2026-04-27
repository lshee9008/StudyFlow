import 'package:flutter/material.dart';
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
    final isCompact = MediaQuery.of(context).size.width < 960;

    return Scaffold(
      backgroundColor: AppTheme.colorsOf(context).background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            children: [
              Row(
                children: [
                  if (showBack) ...[
                    _AuthIconButton(
                      icon: LucideIcons.arrowLeft,
                      onTap: onBack ?? () => Navigator.pop(context),
                    ),
                    const SizedBox(width: AppSpace.sm),
                  ],
                  Text(
                    'StudyFlow',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Spacer(),
                  const AppBadge(label: 'Account'),
                ],
              ),
              const SizedBox(height: AppSpace.xl),
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
    );
  }
}

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
        children: [left, const SizedBox(height: AppSpace.lg), right],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 10, child: left),
        const SizedBox(width: AppSpace.xl),
        Expanded(flex: 8, child: right),
      ],
    );
  }
}

class AuthHero extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppBadge(label: eyebrow),
          const SizedBox(height: AppSpace.lg),
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpace.md),
          Text(body, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpace.xl),
          for (final item in items) ...[
            _AuthListItem(icon: item.$1, label: item.$2),
            const SizedBox(height: AppSpace.sm),
          ],
        ],
      ),
    );
  }
}

class AuthPanel extends StatelessWidget {
  final Widget child;

  const AuthPanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AppCard(child: child);
  }
}

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpace.xs),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _AuthIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _AuthIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: colors.border),
          ),
          child: Icon(icon, size: 16, color: colors.textSecondary),
        ),
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
    final colors = AppTheme.colorsOf(context);

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: colors.border),
          ),
          child: Icon(icon, size: 16, color: colors.textSecondary),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}
