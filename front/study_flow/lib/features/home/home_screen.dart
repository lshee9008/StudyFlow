import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme.dart';
import '../../core/db_helper/all_db_helper.dart';
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
    if (user == null) return const InitialScreen();
    if (user.id == '') {
      return Scaffold(
        backgroundColor: AppTheme.bgDeep,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SFLogo(size: 36),
              const SizedBox(height: 24),
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: AppTheme.accent,
                  strokeWidth: 2,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final projects = ref.watch(projectProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final isMobile = w < 600;
        final isTablet = w >= 600 && w < 1024;

        if (isMobile) {
          return Scaffold(
            backgroundColor: AppTheme.bgPrimary,
            bottomNavigationBar: _MobileNavBar(
              onSearch: () => Navigator.push(context, _fadeRoute(const SearchScreen())),
              onSettings: () => Navigator.push(context, _fadeRoute(ProfileSettingsScreen(user: user))),
              onNewProject: () => showDialog(
                context: context,
                builder: (_) => _AddProjectDialog(userId: user.id!),
              ).then((p) {
                if (p != null) ref.read(projectProvider.notifier).addProject(p);
              }),
            ),
            body: SafeArea(
              bottom: false,
              child: _MainContent(user: user, projects: projects, showMenu: false),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.bgPrimary,
          body: Row(
            children: [
              _Sidebar(user: user, collapsed: isTablet),
              Expanded(
                child: _MainContent(user: user, projects: projects),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
// 사이드바
// ─────────────────────────────────────────────────────────
class _Sidebar extends ConsumerWidget {
  final UserModel user;
  final bool collapsed;
  const _Sidebar({required this.user, this.collapsed = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: collapsed ? 64 : 240,
      decoration: BoxDecoration(
        color: AppTheme.bgDeep,
        border: Border(
          right: BorderSide(color: AppTheme.borderSubtle, width: 1),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 18),
          // 로고 영역
          if (!collapsed) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const SFLogo(size: 22),
                  const Spacer(),
                  SFBadge(label: 'Beta'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _UserTile(user: user),
            ),
            const SizedBox(height: 8),
          ] else ...[
            const SizedBox(height: 16),
            Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: Text(
                    'S',
                    style: GoogleFonts.inter(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: AppTheme.borderSubtle,
          ),
          const SizedBox(height: 8),

          // 네비게이션
          _NavItem(
            icon: Icons.home_rounded,
            label: '홈',
            selected: true,
            collapsed: collapsed,
          ),
          _NavItem(
            icon: Icons.search_rounded,
            label: '검색',
            collapsed: collapsed,
            onTap: () => Navigator.push(
              context,
              _fadeRoute(const SearchScreen()),
            ),
          ),
          _NavItem(
            icon: Icons.settings_outlined,
            label: '설정',
            collapsed: collapsed,
            onTap: () => Navigator.push(
              context,
              _fadeRoute(ProfileSettingsScreen(user: user)),
            ),
          ),

          const Spacer(),

          // 하단 영역
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Container(
                    height: 1,
                    color: AppTheme.borderSubtle,
                    margin: const EdgeInsets.only(bottom: 8),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 12,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text('v2.0 · StudyFlow', style: AppTheme.caption),
                      ],
                    ),
                  ),
                  _DevButton(ref: ref),
                ],
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

PageRoute _fadeRoute(Widget page) => PageRouteBuilder(
  pageBuilder: (_, a, __) => page,
  transitionsBuilder: (_, a, __, child) =>
      FadeTransition(opacity: a, child: child),
  transitionDuration: const Duration(milliseconds: 200),
);

class _DevButton extends ConsumerWidget {
  const _DevButton({required this.ref});
  final WidgetRef ref;
  @override
  Widget build(BuildContext context, WidgetRef _) {
    return GestureDetector(
      onTap: () async {
        await LocalDatabase.instance.deleteAppDatabase();
        ref.invalidate(projectProvider);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: Row(
          children: [
            Icon(
              Icons.delete_sweep_outlined,
              size: 12,
              color: AppTheme.red.withOpacity(0.5),
            ),
            const SizedBox(width: 6),
            Text(
              'DB 초기화',
              style: AppTheme.caption.copyWith(
                color: AppTheme.red.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserTile extends ConsumerWidget {
  final UserModel user;
  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U';
    return PopupMenuButton<String>(
      color: AppTheme.bgSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.borderDefault),
      ),
      offset: const Offset(0, 54),
      elevation: 12,
      shadowColor: Colors.black.withOpacity(0.4),
      onSelected: (val) async {
        if (val == 'settings') {
          Navigator.push(
            context,
            _fadeRoute(ProfileSettingsScreen(user: user)),
          );
        } else if (val == 'logout') {
          await ref.read(userProvider.notifier).logoutExistingUser(user.id!);
          if (context.mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              _fadeRoute(const InitialScreen()),
              (_) => false,
            );
          }
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'settings',
          height: 38,
          child: Row(
            children: [
              Icon(Icons.settings_outlined, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 10),
              Text('설정', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: 'logout',
          height: 38,
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 14, color: AppTheme.red.withOpacity(0.8)),
              const SizedBox(width: 10),
              Text('로그아웃', style: GoogleFonts.inter(color: AppTheme.red, fontSize: 13)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Row(
          children: [
            // 아바타
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.accent, AppTheme.accentMuted],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: GoogleFonts.inter(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: GoogleFonts.inter(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '워크스페이스',
                    style: AppTheme.caption,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.unfold_more_rounded,
              size: 13,
              color: AppTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool collapsed;
  final VoidCallback? onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.collapsed = false,
    this.onTap,
  });
  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          margin: EdgeInsets.symmetric(
            horizontal: widget.collapsed ? 6 : 8,
            vertical: 1,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: widget.collapsed ? 0 : 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppTheme.bgTertiary
                : _hover
                ? AppTheme.bgSecondary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: widget.selected
                ? Border.all(color: AppTheme.borderSubtle)
                : null,
          ),
          child: widget.collapsed
              ? Center(
                  child: Icon(
                    widget.icon,
                    size: 18,
                    color: widget.selected
                        ? AppTheme.accent
                        : _hover
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                  ),
                )
              : Row(
                  children: [
                    Icon(
                      widget.icon,
                      size: 15,
                      color: widget.selected
                          ? AppTheme.accent
                          : _hover
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.label,
                      style: GoogleFonts.inter(
                        color: widget.selected
                            ? AppTheme.textPrimary
                            : _hover
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight:
                            widget.selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    if (widget.selected) ...[
                      const Spacer(),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// 메인 콘텐츠
// ─────────────────────────────────────────────────────────
class _MainContent extends ConsumerWidget {
  final UserModel user;
  final List<ProjectModel> projects;
  final bool showMenu;
  const _MainContent({
    required this.user,
    required this.projects,
    this.showMenu = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 6
        ? '밤늦게까지'
        : hour < 12
        ? '좋은 아침이에요'
        : hour < 18
        ? '안녕하세요'
        : '좋은 저녁이에요';
    final greetEmoji = hour < 6
        ? '🌙'
        : hour < 12
        ? '☀️'
        : hour < 18
        ? '👋'
        : '🌙';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        _Header(
          user: user,
          greeting: '$greeting, ${user.name} $greetEmoji',
          dateStr: DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(now),
          onSearch: () => Navigator.push(context, _fadeRoute(const SearchScreen())),
          onAdd: () => _showAddDialog(context, ref, user),
          showMenu: showMenu,
        ),

        // 통계 행
        if (projects.isNotEmpty)
          _StatsRow(projectCount: projects.length),

        // 섹션 헤더
        if (projects.isNotEmpty)
          LayoutBuilder(builder: (ctx, cons) {
            final hPad = cons.maxWidth < 600 ? 16.0 : 32.0;
            return Padding(
            padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 0),
            child: Row(
              children: [
                Text(
                  '프로젝트',
                  style: AppTheme.headingSmall.copyWith(
                    color: AppTheme.textTertiary,
                    letterSpacing: 0.5,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.bgTertiary,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Text(
                    '${projects.length}',
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
          }),  // end LayoutBuilder

        // 프로젝트 그리드
        Expanded(
          child: projects.isEmpty
              ? _EmptyState(onAdd: () => _showAddDialog(context, ref, user))
              : _ProjectGrid(projects: projects, user: user),
        ),
      ],
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref, UserModel user) {
    showDialog(
      context: context,
      builder: (_) => _AddProjectDialog(userId: user.id!),
    ).then((p) {
      if (p != null) ref.read(projectProvider.notifier).addProject(p);
    });
  }
}

// 헤더
class _Header extends StatelessWidget {
  final UserModel user;
  final String greeting;
  final String dateStr;
  final VoidCallback onSearch;
  final VoidCallback onAdd;
  final bool showMenu;

  const _Header({
    required this.user,
    required this.greeting,
    required this.dateStr,
    required this.onSearch,
    required this.onAdd,
    this.showMenu = false,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final hPad = isMobile ? 16.0 : 32.0;
    return Container(
      padding: EdgeInsets.fromLTRB(hPad, isMobile ? 18 : 28, hPad - 4, 18),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
      ),
      child: Row(
        children: [
          if (showMenu) ...[
            IconButton(
              icon: const Icon(Icons.menu_rounded),
              color: AppTheme.textSecondary,
              onPressed: () => Scaffold.of(context).openDrawer(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: AppTheme.headingMedium.copyWith(
                    fontSize: isMobile ? 17 : 20,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(dateStr, style: AppTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 모바일: 검색 아이콘만, 데스크톱: 전체 검색 버튼
          if (isMobile)
            GestureDetector(
              onTap: onSearch,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.bgSecondary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderDefault),
                ),
                child: const Icon(Icons.search_rounded, size: 18, color: AppTheme.textSecondary),
              ),
            )
          else
            _SearchBtn(onTap: onSearch),
          const SizedBox(width: 8),
          // 모바일: + 아이콘만
          if (isMobile)
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_rounded, size: 20, color: Colors.black),
              ),
            )
          else
            SFButton(
              label: '새 프로젝트',
              icon: Icons.add_rounded,
              onPressed: onAdd,
            ),
        ],
      ),
    );
  }
}

class _SearchBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _SearchBtn({required this.onTap});
  @override
  State<_SearchBtn> createState() => _SearchBtnState();
}

class _SearchBtnState extends State<_SearchBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _hover ? AppTheme.bgTertiary : AppTheme.bgSecondary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _hover ? AppTheme.borderStrong : AppTheme.borderDefault,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_rounded,
              size: 15,
              color: _hover ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
            const SizedBox(width: 7),
            Text(
              '검색',
              style: GoogleFonts.inter(
                color: _hover ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.bgTertiary,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Text(
                '⌘K',
                style: AppTheme.caption.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// 통계 행
class _StatsRow extends StatelessWidget {
  final int projectCount;
  const _StatsRow({required this.projectCount});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final hPad = isMobile ? 16.0 : 32.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 0),
      child: Row(
        children: [
          _StatCard(
            icon: Icons.folder_rounded,
            label: '프로젝트',
            value: '$projectCount',
            color: AppTheme.accent,
          ),
          const SizedBox(width: 8),
          _StatCard(
            icon: Icons.auto_awesome_rounded,
            label: isMobile ? 'AI' : 'AI 노트',
            value: '활성',
            color: AppTheme.blue,
          ),
          const SizedBox(width: 8),
          _StatCard(
            icon: Icons.local_fire_department_rounded,
            label: isMobile ? '학습 중' : '계속 학습 중',
            value: '🔥',
            color: AppTheme.yellow,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color.withOpacity(0.8)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
              ),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 빈 상태
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.bgSecondary,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 아이콘 그라디언트
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.accent.withOpacity(0.15),
                        AppTheme.blue.withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                  ),
                  child: const Icon(
                    Icons.folder_open_rounded,
                    size: 36,
                    color: AppTheme.accent,
                  ),
                ),
                const SizedBox(height: 24),
                Text('첫 프로젝트를 만들어보세요', style: AppTheme.headingMedium),
                const SizedBox(height: 8),
                Text(
                  '프로젝트는 관련 노트를 묶어두는 공간이에요.\n강의명, 과목명으로 만들어보세요.',
                  style: AppTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SFButton(
                  label: '프로젝트 만들기',
                  icon: Icons.add_rounded,
                  onPressed: onAdd,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 프로젝트 그리드
class _ProjectGrid extends ConsumerWidget {
  final List<ProjectModel> projects;
  final UserModel user;
  const _ProjectGrid({required this.projects, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            MediaQuery.of(context).size.width < 600 ? 16 : 32,
            12,
            MediaQuery.of(context).size.width < 600 ? 16 : 32,
            32,
          ),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                if (i == 0) {
                  return _AddCard(
                    onTap: () => showDialog(
                      context: ctx,
                      builder: (_) => _AddProjectDialog(userId: user.id!),
                    ).then((p) {
                      if (p != null)
                        ref.read(projectProvider.notifier).addProject(p);
                    }),
                  );
                }
                return _ProjectCard(
                  project: projects[i - 1],
                  onTap: () => Navigator.push(
                    ctx,
                    _fadeRoute(ProjectScreen(project: projects[i - 1])),
                  ),
                  onDelete: () => ref
                      .read(projectProvider.notifier)
                      .deleteProject(projects[i - 1]),
                );
              },
              childCount: projects.length + 1,
            ),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: MediaQuery.of(context).size.width < 600
                  ? MediaQuery.of(context).size.width * 0.9
                  : MediaQuery.of(context).size.width < 1024
                  ? 260
                  : 280,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

// 프로젝트 색상 팔레트
const _projectColors = [
  Color(0xFFCCFF66), // lime
  Color(0xFF5B8EFF), // blue
  Color(0xFF9B6CF8), // purple
  Color(0xFF3AE0A0), // green
  Color(0xFFFFD166), // yellow
  Color(0xFFFF6B6B), // red
  Color(0xFF60D4FA), // sky
  Color(0xFFF472B6), // pink
];

const _projectGradients = [
  [Color(0xFF1E2A0A), Color(0xFF13131C)],
  [Color(0xFF0A1230), Color(0xFF13131C)],
  [Color(0xFF140E28), Color(0xFF13131C)],
  [Color(0xFF051A10), Color(0xFF13131C)],
  [Color(0xFF1E1505), Color(0xFF13131C)],
  [Color(0xFF1E0810), Color(0xFF13131C)],
  [Color(0xFF051820), Color(0xFF13131C)],
  [Color(0xFF200B18), Color(0xFF13131C)],
];

class _AddCard extends StatefulWidget {
  final VoidCallback onTap;
  const _AddCard({required this.onTap});
  @override
  State<_AddCard> createState() => _AddCardState();
}

class _AddCardState extends State<_AddCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: _hover ? AppTheme.accentDim : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hover
                ? AppTheme.accent.withOpacity(0.4)
                : AppTheme.borderDefault,
            width: _hover ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _hover
                    ? AppTheme.accent.withOpacity(0.15)
                    : AppTheme.bgTertiary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _hover
                      ? AppTheme.accent.withOpacity(0.3)
                      : AppTheme.borderSubtle,
                ),
              ),
              child: Icon(
                Icons.add_rounded,
                size: 22,
                color: _hover ? AppTheme.accent : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '새 프로젝트',
              style: GoogleFonts.inter(
                color: _hover ? AppTheme.accent : AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProjectCard extends StatefulWidget {
  final ProjectModel project;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _ProjectCard({
    required this.project,
    required this.onTap,
    required this.onDelete,
  });
  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  bool _hover = false;

  int get _colorIdx =>
      widget.project.name.hashCode.abs() % _projectColors.length;
  Color get _color => _projectColors[_colorIdx];
  List<Color> get _gradient => _projectGradients[_colorIdx];

  @override
  Widget build(BuildContext context) {
    final tags = widget.project.tags.isEmpty
        ? <String>[]
        : widget.project.tags
              .split(',')
              .where((t) => t.trim().isNotEmpty)
              .toList();

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _hover
                  ? [_gradient[0].withOpacity(1.0), _gradient[1]]
                  : [AppTheme.bgSecondary, AppTheme.bgSecondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hover
                  ? _color.withOpacity(0.25)
                  : AppTheme.borderSubtle,
              width: _hover ? 1.5 : 1,
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: _color.withOpacity(0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 컬러 도트
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _color.withOpacity(0.2),
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _color.withOpacity(0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  _MoreMenu(onDelete: widget.onDelete),
                ],
              ),
              const Spacer(),
              Text(
                widget.project.name,
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 5),
              Text(
                DateFormat('MM.dd').format(widget.project.create_at),
                style: AppTheme.caption,
              ),
              const SizedBox(height: 10),
              if (tags.isNotEmpty)
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: tags.take(2).map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.bgPrimary,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: Text(
                        '#${t.trim()}',
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ),
                  ).toList(),
                )
              else
                Text('태그 없음', style: AppTheme.caption),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  final VoidCallback onDelete;
  const _MoreMenu({required this.onDelete});
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    color: AppTheme.bgSecondary,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: const BorderSide(color: AppTheme.borderDefault),
    ),
    padding: EdgeInsets.zero,
    icon: const Icon(
      Icons.more_horiz_rounded,
      size: 15,
      color: AppTheme.textMuted,
    ),
    iconSize: 15,
    elevation: 12,
    shadowColor: Colors.black.withOpacity(0.4),
    onSelected: (val) {
      if (val == 'delete') onDelete();
    },
    itemBuilder: (_) => [
      PopupMenuItem(
        value: 'delete',
        height: 36,
        child: Row(
          children: [
            Icon(Icons.delete_outline_rounded, size: 13, color: AppTheme.red),
            const SizedBox(width: 8),
            Text(
              '삭제',
              style: GoogleFonts.inter(color: AppTheme.red, fontSize: 13),
            ),
          ],
        ),
      ),
    ],
  );
}

// 프로젝트 추가 다이얼로그
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
      backgroundColor: AppTheme.bgSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.borderDefault),
      ),
      elevation: 24,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentDim,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                  ),
                  child: const Icon(
                    Icons.folder_outlined,
                    size: 16,
                    color: AppTheme.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('새 프로젝트', style: AppTheme.headingSmall),
                    Text(
                      '관련 노트를 묶을 공간을 만드세요.',
                      style: AppTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            SFTextField(
              label: '프로젝트 이름 *',
              hint: '예: 운영체제 수업',
              controller: _nameCtrl,
              autofocus: true,
              onSubmitted: (_) {
                if (_nameCtrl.text.trim().isNotEmpty) _submit();
              },
            ),
            const SizedBox(height: 14),
            SFTextField(
              label: '태그 (선택)',
              hint: '예: CS, 2024, 중간고사',
              controller: _tagCtrl,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
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
                  label: '만들기',
                  icon: Icons.add_rounded,
                  onPressed: _submit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (_nameCtrl.text.trim().isEmpty) return;
    Navigator.pop(
      context,
      ProjectModel(
        id: const Uuid().v4(),
        user_id: widget.userId,
        create_at: DateTime.now(),
        update_at: DateTime.now(),
        name: _nameCtrl.text.trim(),
        tags: _tagCtrl.text.trim(),
        is_sync: 0,
      ),
    );
  }
}

// ─── 모바일 하단 네비게이션 ─────────────────────────────────
class _MobileNavBar extends StatelessWidget {
  final VoidCallback onSearch, onSettings, onNewProject;
  const _MobileNavBar({
    required this.onSearch,
    required this.onSettings,
    required this.onNewProject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgDeep,
        border: const Border(top: BorderSide(color: AppTheme.borderSubtle, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              // 홈 (항상 선택됨)
              Expanded(
                child: _MNavItem(
                  icon: Icons.home_rounded,
                  label: '홈',
                  selected: true,
                ),
              ),
              // 검색
              Expanded(
                child: _MNavItem(
                  icon: Icons.search_rounded,
                  label: '검색',
                  onTap: onSearch,
                ),
              ),
              // + 새 프로젝트 (중앙 강조 버튼)
              GestureDetector(
                onTap: onNewProject,
                child: Container(
                  width: 52,
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.black, size: 22),
                ),
              ),
              // 설정
              Expanded(
                child: _MNavItem(
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

class _MNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const _MNavItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 22,
          color: selected ? AppTheme.accent : AppTheme.textMuted,
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: GoogleFonts.inter(
            color: selected ? AppTheme.accent : AppTheme.textMuted,
            fontSize: 10,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    ),
  );
}
