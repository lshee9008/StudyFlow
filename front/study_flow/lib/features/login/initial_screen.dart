import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme.dart';
import '../../core/ui/app_components.dart';
import 'login_or_create_membership_screen.dart';

class InitialScreen extends StatelessWidget {
  const InitialScreen({super.key});

  void _openAuth(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) =>
            const LoginOrCreateMembershipScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 960;
    final colors = AppTheme.colorsOf(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: isCompact
                  ? _CompactIntro(onStart: () => _openAuth(context))
                  : _WideIntro(onStart: () => _openAuth(context)),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Wide layout ───────────────────────────────────────────────────────────────
class _WideIntro extends StatelessWidget {
  final VoidCallback onStart;

  const _WideIntro({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Nav bar
        _NavBar(onStart: onStart),
        const SizedBox(height: AppSpace.xxl),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 10, child: _HeroCopy(onStart: onStart)),
              const SizedBox(width: AppSpace.xl),
              const Expanded(flex: 9, child: _MockPreview()),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Compact layout ────────────────────────────────────────────────────────────
class _CompactIntro extends StatelessWidget {
  final VoidCallback onStart;

  const _CompactIntro({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _NavBar(onStart: onStart),
        const SizedBox(height: AppSpace.xxl),
        _HeroCopy(onStart: onStart, compact: true),
        const SizedBox(height: AppSpace.xl),
        const _MockPreview(),
      ],
    );
  }
}

// ── Nav bar ───────────────────────────────────────────────────────────────────
class _NavBar extends StatelessWidget {
  final VoidCallback onStart;

  const _NavBar({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const AppWordmark(),
        const SizedBox(width: AppSpace.sm),
        const AppBadge(label: AppTheme.brandVersion),
        const Spacer(),
        AppButton(
          label: '로그인',
          onPressed: onStart,
          icon: LucideIcons.arrowRight,
        ),
      ],
    );
  }
}

// ── Hero copy ─────────────────────────────────────────────────────────────────
class _HeroCopy extends StatelessWidget {
  final VoidCallback onStart;
  final bool compact;

  const _HeroCopy({required this.onStart, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppTheme.colorsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.sm,
            vertical: AppSpace.xxs,
          ),
          decoration: BoxDecoration(
            color: colors.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: colors.accent.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.sparkles, size: 12, color: colors.accent),
              const SizedBox(width: AppSpace.xxs),
              Text(
                '학습 워크스페이스',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Text(
          '배움의 흐름을\n한 곳에서.',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: compact ? 32 : 44,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
            height: 1.15,
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Text(
          '노트 작성부터 요약, 복습까지 — 흐름이 끊기지 않는 개인 학습 워크스페이스.',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 15,
            height: 1.7,
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        // Feature pills
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: const [
            _FeaturePill(icon: LucideIcons.fileText, label: '스마트 노트'),
            _FeaturePill(icon: LucideIcons.brain, label: 'AI 요약'),
            _FeaturePill(icon: LucideIcons.timer, label: '포모도로'),
            _FeaturePill(icon: LucideIcons.search, label: '시맨틱 검색'),
          ],
        ),
        const SizedBox(height: AppSpace.xl),
        // CTAs
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            AppButton(
              label: '무료로 시작하기',
              onPressed: onStart,
              icon: LucideIcons.arrowRight,
              width: compact ? double.infinity : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeaturePill({required this.icon, required this.label});

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
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colors.textSecondary),
          const SizedBox(width: AppSpace.xxs),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

// ── Mock Preview ──────────────────────────────────────────────────────────────
class _MockPreview extends StatelessWidget {
  const _MockPreview();

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Window chrome
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.md,
              vertical: AppSpace.sm,
            ),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.border)),
            ),
            child: Row(
              children: [
                _WindowDot(color: AppTheme.red),
                const SizedBox(width: AppSpace.xs),
                _WindowDot(color: AppTheme.yellow),
                const SizedBox(width: AppSpace.xs),
                _WindowDot(color: AppTheme.green),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Container(
                    height: 22,
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: colors.border),
                    ),
                    child: Center(
                      child: Text(
                        'studyflow.app',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // App layout mock
          Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sidebar
                SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: colors.accent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: AppSpace.xs),
                          Text(
                            'StudyFlow',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.md),
                      _SidebarRow(icon: LucideIcons.home, label: '홈', selected: true),
                      const SizedBox(height: AppSpace.xxs),
                      _SidebarRow(icon: LucideIcons.search, label: '검색'),
                      const SizedBox(height: AppSpace.xxs),
                      _SidebarRow(icon: LucideIcons.timer, label: '포커스'),
                      const SizedBox(height: AppSpace.sm),
                      Container(height: 1, color: colors.border),
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        '워크스페이스',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: AppSpace.xs),
                      for (final item in ['📚 React', '🧠 알고리즘', '⚡ 영어'])
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.xxs),
                          child: Text(
                            item,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(fontSize: 10),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(width: 1, color: colors.border),
                const SizedBox(width: AppSpace.md),
                // Main panel
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '안녕하세요, 사용자님',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontSize: 11),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Row(
                        children: [
                          _MiniMetric(label: '프로젝트', value: '3'),
                          const SizedBox(width: AppSpace.xs),
                          _MiniMetric(label: '오늘 학습', value: '—'),
                        ],
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        '최근 프로젝트',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpace.xs),
                      for (final item in [
                        ('📚', 'React 학습'),
                        ('🧠', '알고리즘'),
                        ('⚡', '영어 회화'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.xxs),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.sm,
                              vertical: AppSpace.xxs,
                            ),
                            decoration: BoxDecoration(
                              color: colors.background,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: colors.border),
                            ),
                            child: Row(
                              children: [
                                Text(item.$1,
                                    style:
                                        const TextStyle(fontSize: 10)),
                                const SizedBox(width: AppSpace.xxs),
                                Text(
                                  item.$2,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WindowDot extends StatelessWidget {
  final Color color;

  const _WindowDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _SidebarRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;

  const _SidebarRow({
    required this.icon,
    required this.label,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: selected
          ? BoxDecoration(
              color: colors.border.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            )
          : null,
      child: Row(
        children: [
          Icon(icon, size: 10, color: colors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: selected ? colors.textPrimary : colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;

  const _MiniMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpace.xs),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontSize: 12),
            ),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}
