import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/db_helper/all_db_helper.dart';
import '../../core/theme.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../login/initial_screen.dart';
import '../project/project_model.dart';
import '../project/project_provider.dart';
import '../project/project_screen.dart';
import '../search/search_screen.dart';
import '../settings/profile_settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);

    if (user == null) {
      return const InitialScreen();
    }

    if (user.id == '') {
      return Scaffold(
        backgroundColor: AppTheme.bgDeep,
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SFLogo(size: 38),
              SizedBox(height: 24),
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: AppTheme.accent,
                  strokeWidth: 1.8,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final projects = [...ref.watch(projectProvider)]
      ..sort((a, b) => b.update_at.compareTo(a.update_at));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 760;
        final isTablet =
            constraints.maxWidth >= 760 && constraints.maxWidth < 1180;

        return Scaffold(
          backgroundColor: AppTheme.bgDeep,
          floatingActionButton: isMobile
              ? FloatingActionButton(
                  onPressed: () => _showAddDialog(context, ref, user),
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  child: const Icon(Icons.add_rounded),
                )
              : null,
          bottomNavigationBar: isMobile
              ? _MobileDock(
                  onSearch: () =>
                      Navigator.push(context, _fadeRoute(const SearchScreen())),
                  onSettings: () => Navigator.push(
                    context,
                    _fadeRoute(ProfileSettingsScreen(user: user)),
                  ),
                  onAdd: () => _showAddDialog(context, ref, user),
                )
              : null,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF050711),
                  Color(0xFF090D1B),
                  Color(0xFF0D1121),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                const Positioned(
                  top: -120,
                  left: -60,
                  child: _AuraOrb(color: AppTheme.blue, size: 320),
                ),
                const Positioned(
                  top: 60,
                  right: -80,
                  child: _AuraOrb(color: AppTheme.accent, size: 280),
                ),
                const Positioned(
                  bottom: -160,
                  left: 120,
                  child: _AuraOrb(color: AppTheme.purple, size: 380),
                ),
                SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      if (!isMobile)
                        _Sidebar(
                          user: user,
                          collapsed: isTablet,
                          onSearch: () => Navigator.push(
                            context,
                            _fadeRoute(const SearchScreen()),
                          ),
                          onSettings: () => Navigator.push(
                            context,
                            _fadeRoute(ProfileSettingsScreen(user: user)),
                          ),
                        ),
                      Expanded(
                        child: _MainContent(
                          user: user,
                          projects: projects,
                          isMobile: isMobile,
                          onSearch: () => Navigator.push(
                            context,
                            _fadeRoute(const SearchScreen()),
                          ),
                          onSettings: () => Navigator.push(
                            context,
                            _fadeRoute(ProfileSettingsScreen(user: user)),
                          ),
                          onAdd: () => _showAddDialog(context, ref, user),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref, UserModel user) {
    showDialog<ProjectModel>(
      context: context,
      builder: (_) => _AddProjectDialog(userId: user.id!),
    ).then((project) {
      if (project != null) {
        ref.read(projectProvider.notifier).addProject(project);
      }
    });
  }
}

PageRoute _fadeRoute(Widget page) => PageRouteBuilder(
  pageBuilder: (context, animation, secondaryAnimation) => page,
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    return FadeTransition(opacity: animation, child: child);
  },
  transitionDuration: const Duration(milliseconds: 180),
);

class _AuraOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _AuraOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.22),
              color.withValues(alpha: 0.08),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  final UserModel user;
  final bool collapsed;
  final VoidCallback onSearch;
  final VoidCallback onSettings;

  const _Sidebar({
    required this.user,
    required this.collapsed,
    required this.onSearch,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: collapsed ? 96 : 280,
      margin: const EdgeInsets.fromLTRB(18, 18, 0, 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.26),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: collapsed
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          if (collapsed)
            const SFLogo(size: 42)
          else
            Row(
              children: const [
                SFLogo(size: 34),
                Spacer(),
                SFBadge(label: 'Studio'),
              ],
            ),
          SizedBox(height: collapsed ? 24 : 28),
          if (!collapsed) _WorkspaceCard(user: user),
          if (collapsed) ...[
            _SidebarIconButton(
              icon: Icons.search_rounded,
              label: '검색',
              onTap: onSearch,
            ),
            const SizedBox(height: 8),
            _SidebarIconButton(
              icon: Icons.settings_outlined,
              label: '설정',
              onTap: onSettings,
            ),
          ] else ...[
            _SidebarNavTile(
              icon: Icons.space_dashboard_rounded,
              title: 'Overview',
              subtitle: '오늘의 학습 흐름',
              selected: true,
              onTap: () {},
            ),
            const SizedBox(height: 10),
            _SidebarNavTile(
              icon: Icons.search_rounded,
              title: 'Search',
              subtitle: '노트와 키워드 찾기',
              onTap: onSearch,
            ),
            const SizedBox(height: 10),
            _SidebarNavTile(
              icon: Icons.settings_outlined,
              title: 'Settings',
              subtitle: '프로필과 환경 설정',
              onTap: onSettings,
            ),
          ],
          const Spacer(),
          if (!collapsed)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accent.withValues(alpha: 0.12),
                    AppTheme.blue.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Realtime workspace', style: AppTheme.headingSmall),
                  const SizedBox(height: 6),
                  Text(
                    '프로젝트를 빠르게 훑고 바로 새 노트로 들어갈 수 있게 구조를 정리했어요.',
                    style: AppTheme.bodySmall,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          if (!collapsed)
            _DevButton(ref: ref)
          else
            IconButton(
              onPressed: () async {
                await LocalDatabase.instance.deleteAppDatabase();
                ref.invalidate(projectProvider);
              },
              icon: Icon(
                Icons.delete_sweep_outlined,
                color: AppTheme.red.withValues(alpha: 0.8),
              ),
            ),
        ],
      ),
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  final UserModel user;

  const _WorkspaceCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgPrimary.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.accent, AppTheme.blue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                initial,
                style: AppTheme.headingMedium.copyWith(
                  color: Colors.black,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: AppTheme.headingSmall),
                const SizedBox(height: 4),
                Text('Personal knowledge cockpit', style: AppTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarNavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarNavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.bgPrimary.withValues(alpha: 0.84)
                : AppTheme.bgSecondary.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? AppTheme.borderStrong : AppTheme.borderSubtle,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.accent.withValues(alpha: 0.16)
                      : AppTheme.bgTertiary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: selected ? AppTheme.accent : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTheme.headingSmall),
                    const SizedBox(height: 3),
                    Text(subtitle, style: AppTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SidebarIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Ink(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.bgPrimary.withValues(alpha: 0.76),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Icon(icon, color: AppTheme.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _MainContent extends StatelessWidget {
  final UserModel user;
  final List<ProjectModel> projects;
  final bool isMobile;
  final VoidCallback onSearch;
  final VoidCallback onSettings;
  final VoidCallback onAdd;

  const _MainContent({
    required this.user,
    required this.projects,
    required this.isMobile,
    required this.onSearch,
    required this.onSettings,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hPad = isMobile ? 18.0 : 28.0;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 22),
          sliver: SliverToBoxAdapter(
            child: _HeroPanel(
              user: user,
              projects: projects,
              now: now,
              isMobile: isMobile,
              onSearch: onSearch,
              onSettings: onSettings,
              onAdd: onAdd,
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          sliver: SliverToBoxAdapter(
            child: _InsightStrip(
              projectCount: projects.length,
              activeTagCount: projects
                  .expand((project) => project.tags.split(','))
                  .where((tag) => tag.trim().isNotEmpty)
                  .toSet()
                  .length,
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(hPad, 22, hPad, 10),
          sliver: SliverToBoxAdapter(
            child: _SectionHeader(
              eyebrow: 'Projects',
              title: projects.isEmpty ? '새 캔버스를 시작해보세요' : '계속 이어서 작업하기',
              subtitle: projects.isEmpty
                  ? '강의, 과목, 연구 주제를 프로젝트 단위로 모아두면 훨씬 빠르게 찾을 수 있어요.'
                  : '최근 업데이트된 프로젝트부터 바로 들어갈 수 있게 정렬했어요.',
            ),
          ),
        ),
        if (projects.isEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 120),
            sliver: SliverToBoxAdapter(child: _EmptyState(onAdd: onAdd)),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, isMobile ? 120 : 36),
            sliver: _ProjectGrid(projects: projects, user: user, onAdd: onAdd),
          ),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  final UserModel user;
  final List<ProjectModel> projects;
  final DateTime now;
  final bool isMobile;
  final VoidCallback onSearch;
  final VoidCallback onSettings;
  final VoidCallback onAdd;

  const _HeroPanel({
    required this.user,
    required this.projects,
    required this.now,
    required this.isMobile,
    required this.onSearch,
    required this.onSettings,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final greeting = _greetingFor(now.hour);
    final projectName = projects.isEmpty ? '새 스페이스' : projects.first.name;

    return Container(
      padding: EdgeInsets.all(isMobile ? 22 : 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppTheme.borderSubtle),
        gradient: LinearGradient(
          colors: [
            AppTheme.bgSecondary.withValues(alpha: 0.96),
            const Color(0xFF10172D).withValues(alpha: 0.94),
            const Color(0xFF11131F).withValues(alpha: 0.92),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 42,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const SFBadge(label: 'Knowledge OS'),
              SFBadge(
                label: DateFormat('M월 d일 EEEE', 'ko_KR').format(now),
                color: AppTheme.blue,
                bgColor: AppTheme.blueDim,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '$greeting, ${user.name}',
            style: AppTheme.displayMedium.copyWith(
              fontSize: isMobile ? 32 : 44,
              height: 1.02,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '노트 앱처럼 보이기보다, 지금은 하나의 연구 조종석처럼 느껴지도록 구조를 바꿨어요. 가장 최근 프로젝트인 "$projectName"부터 바로 이어갈 수 있어요.',
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.textSecondary,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SFButton(
                label: projects.isEmpty ? '첫 프로젝트 만들기' : '새 프로젝트 만들기',
                icon: Icons.add_rounded,
                onPressed: onAdd,
              ),
              SFButton(
                label: '검색 열기',
                icon: Icons.search_rounded,
                outlined: true,
                onPressed: onSearch,
              ),
              if (isMobile)
                SFButton(
                  label: '설정',
                  icon: Icons.settings_outlined,
                  outlined: true,
                  onPressed: onSettings,
                ),
            ],
          ),
          const SizedBox(height: 24),
          _FocusPanel(
            title: projects.isEmpty ? 'Quick Start' : 'Next Up',
            headline: projects.isEmpty ? '프로젝트 구조부터 세팅' : projectName,
            subtitle: projects.isEmpty
                ? '프로젝트를 만들면 태그, 노트, AI 요약 흐름이 한 공간에서 이어집니다.'
                : '가장 최근에 편집된 프로젝트를 전면에 두고 진입 흐름을 단순하게 정리했습니다.',
          ),
        ],
      ),
    );
  }
}

class _FocusPanel extends StatelessWidget {
  final String title;
  final String headline;
  final String subtitle;

  const _FocusPanel({
    required this.title,
    required this.headline,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppTheme.borderSubtle),
        gradient: LinearGradient(
          colors: [
            AppTheme.accent.withValues(alpha: 0.08),
            AppTheme.blue.withValues(alpha: 0.05),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [AppTheme.accent, AppTheme.blue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.black),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: AppTheme.labelSmall.copyWith(
                    color: AppTheme.textMuted,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(headline, style: AppTheme.headingLarge),
                const SizedBox(height: 6),
                Text(subtitle, style: AppTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightStrip extends StatelessWidget {
  final int projectCount;
  final int activeTagCount;

  const _InsightStrip({
    required this.projectCount,
    required this.activeTagCount,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _InsightCard(
          title: 'Projects',
          value: '$projectCount',
          accent: AppTheme.accent,
          description: '활성 학습 공간',
        ),
        _InsightCard(
          title: 'Tags',
          value: '$activeTagCount',
          accent: AppTheme.blue,
          description: '구조화된 주제 흐름',
        ),
        const _InsightCard(
          title: 'Mode',
          value: 'Live',
          accent: AppTheme.green,
          description: '즉시 편집 가능한 상태',
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String title;
  final String value;
  final Color accent;
  final String description;

  const _InsightCard({
    required this.title,
    required this.value,
    required this.accent,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: AppTheme.labelSmall.copyWith(
              color: AppTheme.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTheme.displayMedium.copyWith(fontSize: 28, color: accent),
          ),
          const SizedBox(height: 8),
          Text(description, style: AppTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: AppTheme.labelSmall.copyWith(
            color: AppTheme.textMuted,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(title, style: AppTheme.headingLarge),
        const SizedBox(height: 6),
        Text(subtitle, style: AppTheme.bodyMedium),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppTheme.borderSubtle),
        gradient: LinearGradient(
          colors: [
            AppTheme.bgSecondary.withValues(alpha: 0.92),
            AppTheme.bgPrimary.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [AppTheme.accent, AppTheme.blue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(
              Icons.dashboard_customize_rounded,
              color: Colors.black,
              size: 34,
            ),
          ),
          const SizedBox(height: 18),
          Text('빈 공간부터도 서비스처럼 시작하게', style: AppTheme.headingLarge),
          const SizedBox(height: 8),
          Text(
            '과목명이나 작업 흐름 이름으로 프로젝트를 만들면, 이후 노트와 AI 요약이 하나의 작업 공간처럼 이어집니다.',
            style: AppTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          SFButton(label: '프로젝트 생성', icon: Icons.add_rounded, onPressed: onAdd),
        ],
      ),
    );
  }
}

class _ProjectGrid extends ConsumerWidget {
  final List<ProjectModel> projects;
  final UserModel user;
  final VoidCallback onAdd;

  const _ProjectGrid({
    required this.projects,
    required this.user,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index == 0) {
          return _AddProjectTile(onTap: onAdd);
        }

        final project = projects[index - 1];
        return _ProjectTile(
          project: project,
          onTap: () => Navigator.push(
            context,
            _fadeRoute(ProjectScreen(project: project)),
          ),
          onDelete: () =>
              ref.read(projectProvider.notifier).deleteProject(project),
        );
      }, childCount: projects.length + 1),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 360,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.16,
      ),
    );
  }
}

class _ProjectTile extends ConsumerWidget {
  final ProjectModel project;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ProjectTile({
    required this.project,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = project.tags
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
    final accent = _palette[project.name.hashCode.abs() % _palette.length];

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppTheme.borderSubtle),
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.18),
                  AppTheme.bgSecondary.withValues(alpha: 0.95),
                  AppTheme.bgPrimary.withValues(alpha: 0.92),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Icon(Icons.auto_stories_rounded, color: accent),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      color: AppTheme.bgSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppTheme.borderDefault),
                      ),
                      onSelected: (value) {
                        if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('삭제'),
                        ),
                      ],
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.bgPrimary.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.borderSubtle),
                        ),
                        child: const Icon(
                          Icons.more_horiz_rounded,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  project.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.headingLarge.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 10),
                Text(
                  '최근 편집 ${DateFormat('M.d').format(project.update_at)}',
                  style: AppTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (tags.isEmpty)
                      _ProjectChip(
                        label: '태그 없음',
                        color: AppTheme.textMuted,
                        background: AppTheme.bgPrimary.withValues(alpha: 0.72),
                      ),
                    for (final tag in tags.take(3))
                      _ProjectChip(
                        label: '#$tag',
                        color: accent,
                        background: accent.withValues(alpha: 0.1),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddProjectTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddProjectTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppTheme.accent.withValues(alpha: 0.28),
              style: BorderStyle.solid,
            ),
            gradient: LinearGradient(
              colors: [
                AppTheme.accent.withValues(alpha: 0.08),
                AppTheme.blue.withValues(alpha: 0.04),
                AppTheme.bgSecondary.withValues(alpha: 0.92),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [AppTheme.accent, AppTheme.blue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.add_rounded, color: Colors.black),
              ),
              const Spacer(),
              Text(
                '새 프로젝트',
                style: AppTheme.headingLarge.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 8),
              Text(
                '새 학습 흐름이나 과목 공간을 추가하고 바로 노트 작성으로 이어가세요.',
                style: AppTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;

  const _ProjectChip({
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTheme.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MobileDock extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onSettings;
  final VoidCallback onAdd;

  const _MobileDock({
    required this.onSearch,
    required this.onSettings,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.bgSecondary.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Row(
            children: [
              Expanded(
                child: _DockButton(
                  icon: Icons.search_rounded,
                  label: '검색',
                  onTap: onSearch,
                ),
              ),
              Expanded(
                child: _DockButton(
                  icon: Icons.add_box_rounded,
                  label: '추가',
                  onTap: onAdd,
                ),
              ),
              Expanded(
                child: _DockButton(
                  icon: Icons.settings_outlined,
                  label: '설정',
                  onTap: onSettings,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DockButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: AppTheme.textSecondary),
              const SizedBox(height: 4),
              Text(label, style: AppTheme.caption),
            ],
          ),
        ),
      ),
    );
  }
}

class _DevButton extends ConsumerWidget {
  final WidgetRef ref;

  const _DevButton({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef _) {
    return TextButton.icon(
      onPressed: () async {
        await LocalDatabase.instance.deleteAppDatabase();
        ref.invalidate(projectProvider);
      },
      icon: Icon(
        Icons.delete_sweep_outlined,
        size: 14,
        color: AppTheme.red.withValues(alpha: 0.8),
      ),
      label: Text(
        'DB 초기화',
        style: AppTheme.caption.copyWith(
          color: AppTheme.red.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

class _AddProjectDialog extends StatefulWidget {
  final String userId;

  const _AddProjectDialog({required this.userId});

  @override
  State<_AddProjectDialog> createState() => _AddProjectDialogState();
}

class _AddProjectDialogState extends State<_AddProjectDialog> {
  final _nameCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppTheme.bgSecondary,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppTheme.borderDefault),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.34),
              blurRadius: 42,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [AppTheme.accent, AppTheme.blue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(
                    Icons.create_new_folder_rounded,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('새 프로젝트', style: AppTheme.headingLarge),
                      const SizedBox(height: 4),
                      Text(
                        '새로운 학습 공간을 만들고 노트를 연결하세요.',
                        style: AppTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SFTextField(
              label: '프로젝트 이름',
              hint: '예: 운영체제, HCI 리서치',
              controller: _nameCtrl,
              autofocus: true,
            ),
            const SizedBox(height: 14),
            SFTextField(label: '태그', hint: '쉼표로 구분해서 입력', controller: _tagCtrl),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SFButton(
                  label: '취소',
                  outlined: true,
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 10),
                SFButton(
                  label: '생성',
                  icon: Icons.add_rounded,
                  onPressed: () {
                    final name = _nameCtrl.text.trim();
                    if (name.isEmpty) {
                      return;
                    }

                    final now = DateTime.now();
                    Navigator.pop(
                      context,
                      ProjectModel(
                        id: const Uuid().v4(),
                        user_id: widget.userId,
                        create_at: now,
                        update_at: now,
                        name: name,
                        tags: _tagCtrl.text.trim(),
                        is_sync: 0,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _greetingFor(int hour) {
  if (hour < 6) return '깊게 몰입 중이네요';
  if (hour < 12) return '좋은 아침이에요';
  if (hour < 18) return '오늘 흐름이 좋네요';
  return '저녁 집중 모드네요';
}

const _palette = [
  AppTheme.accent,
  AppTheme.blue,
  AppTheme.purple,
  AppTheme.green,
  AppTheme.yellow,
  AppTheme.red,
];
