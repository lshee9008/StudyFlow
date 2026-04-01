import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      return const Scaffold(
        backgroundColor: AppTheme.bgDeep,
        body: Center(
          child: CircularProgressIndicator(
            color: AppTheme.accent,
            strokeWidth: 2,
          ),
        ),
      );
    }
    final projects = ref.watch(projectProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: Row(
        children: [
          _Sidebar(user: user),
          Expanded(
            child: _MainContent(user: user, projects: projects),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// 사이드바
// ─────────────────────────────────────────────────────────
class _Sidebar extends ConsumerWidget {
  final UserModel user;
  const _Sidebar({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 248,
      decoration: const BoxDecoration(
        color: AppTheme.bgSecondary,
        border: Border(right: BorderSide(color: AppTheme.borderSubtle)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // 로고
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                const SFLogo(size: 24),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentDim,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text(
                    'Beta',
                    style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 유저 프로필
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _UserTile(user: user),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Divider(color: AppTheme.borderSubtle, height: 16),
          ),

          // 네비게이션
          _NavItem(icon: Icons.home_rounded, label: '홈', selected: true),
          _NavItem(
            icon: Icons.search_rounded,
            label: '검색',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
          _NavItem(
            icon: Icons.settings_outlined,
            label: '설정',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileSettingsScreen(user: user),
              ),
            ),
          ),

          const Spacer(),

          // 하단
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                const Divider(color: AppTheme.borderSubtle),
                const SizedBox(height: 4),
                // 앱 버전
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Text('StudyFlow v2.0', style: AppTheme.bodySmall),
                    ],
                  ),
                ),
                // DB 초기화 (개발용)
                _SmallButton(
                  icon: Icons.delete_sweep_outlined,
                  label: 'DB 초기화',
                  color: AppTheme.red.withOpacity(0.7),
                  onTap: () async {
                    await LocalDatabase.instance.deleteAppDatabase();
                    ref.invalidate(projectProvider);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _UserTile extends ConsumerWidget {
  final UserModel user;
  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      color: AppTheme.bgSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.borderDefault),
      ),
      offset: const Offset(0, 52),
      elevation: 8,
      onSelected: (val) async {
        if (val == 'settings') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfileSettingsScreen(user: user),
            ),
          );
        } else if (val == 'logout') {
          await ref.read(userProvider.notifier).logoutExistingUser(user.id!);
          if (context.mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const InitialScreen()),
              (_) => false,
            );
          }
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'settings',
          child: Row(
            children: const [
              Icon(
                Icons.settings_outlined,
                size: 15,
                color: AppTheme.textSecondary,
              ),
              SizedBox(width: 10),
              Text(
                '설정',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: const [
              Icon(
                Icons.logout_rounded,
                size: 15,
                color: AppTheme.textSecondary,
              ),
              SizedBox(width: 10),
              Text(
                '로그아웃',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.bgTertiary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
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
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    '개인 워크스페이스',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.unfold_more_rounded,
              size: 14,
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
  final VoidCallback? onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    this.selected = false,
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
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppTheme.bgTertiary
                : _hover
                ? AppTheme.bgTertiary.withOpacity(0.6)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: widget.selected
                    ? AppTheme.textPrimary
                    : AppTheme.textSecondary,
              ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.selected
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: widget.selected
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SmallButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────
// 메인 콘텐츠
// ─────────────────────────────────────────────────────────
class _MainContent extends ConsumerWidget {
  final UserModel user;
  final List<ProjectModel> projects;
  const _MainContent({required this.user, required this.projects});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? '좋은 아침이에요 ☀️'
        : hour < 18
        ? '안녕하세요 👋'
        : '좋은 저녁이에요 🌙';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Container(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 20),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting, ${user.name}',
                      style: AppTheme.headingMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      DateFormat('yyyy.MM.dd').format(now),
                      style: AppTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              // 검색 버튼
              _HeaderButton(
                icon: Icons.search_rounded,
                label: '검색',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                ),
              ),
              const SizedBox(width: 10),
              SFButton(
                label: '새 프로젝트',
                icon: Icons.add_rounded,
                onPressed: () => _showAddDialog(context, ref, user),
              ),
            ],
          ),
        ),

        // 통계 배너 (프로젝트 있을 때만)
        if (projects.isNotEmpty) _StatsBanner(projectCount: projects.length),

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

class _HeaderButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _HeaderButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  State<_HeaderButton> createState() => _HeaderButtonState();
}

class _HeaderButtonState extends State<_HeaderButton> {
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
            color: _hover ? AppTheme.borderStrong : AppTheme.borderSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(widget.label, style: AppTheme.labelMedium),
          ],
        ),
      ),
    ),
  );
}

// ─── 통계 배너 ────────────────────────────────────────────
class _StatsBanner extends StatelessWidget {
  final int projectCount;
  const _StatsBanner({required this.projectCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(32, 20, 32, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.accentDim,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder_rounded, size: 16, color: AppTheme.accent),
          const SizedBox(width: 10),
          Text(
            '프로젝트 $projectCount개',
            style: const TextStyle(
              color: AppTheme.accent,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '계속 공부하고 있어요! 🎯',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.accent.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 빈 상태 ────────────────────────────────────────────
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
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.bgSecondary,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppTheme.accentDim,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.folder_open_rounded,
                    size: 44,
                    color: AppTheme.accent,
                  ),
                ),
                const SizedBox(height: 22),
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

// ─── 프로젝트 그리드 ────────────────────────────────────
class _ProjectGrid extends ConsumerWidget {
  final List<ProjectModel> projects;
  final UserModel user;
  const _ProjectGrid({required this.projects, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate((ctx, i) {
              if (i == 0)
                return _AddCard(
                  onTap: () =>
                      showDialog(
                        context: ctx,
                        builder: (_) => _AddProjectDialog(userId: user.id!),
                      ).then((p) {
                        if (p != null)
                          ref.read(projectProvider.notifier).addProject(p);
                      }),
                );
              return _ProjectCard(
                project: projects[i - 1],
                onTap: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => ProjectScreen(project: projects[i - 1]),
                  ),
                ),
                onDelete: () => ref
                    .read(projectProvider.notifier)
                    .deleteProject(projects[i - 1]),
              );
            }, childCount: projects.length + 1),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 카드들 ────────────────────────────────────────────
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hover
                ? AppTheme.accent.withOpacity(0.5)
                : AppTheme.borderDefault,
            width: _hover ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _hover
                    ? AppTheme.accent.withOpacity(0.2)
                    : AppTheme.bgTertiary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_rounded,
                size: 26,
                color: _hover ? AppTheme.accent : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '새 프로젝트',
              style: TextStyle(
                color: _hover ? AppTheme.accent : AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// 프로젝트 컬러 팔레트
const _projectColors = [
  Color(0xFFCCFF66),
  Color(0xFF4F8EFF),
  Color(0xFF8B5CF6),
  Color(0xFF34D399),
  Color(0xFFFBBF24),
  Color(0xFFF87171),
  Color(0xFF60A5FA),
  Color(0xFFA78BFA),
];

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
  Color get _color =>
      _projectColors[widget.project.name.hashCode.abs() %
          _projectColors.length];

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
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _hover ? AppTheme.bgTertiary : AppTheme.bgSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hover ? AppTheme.borderStrong : AppTheme.borderSubtle,
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 16,
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
                  // 컬러 인디케이터
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _color.withOpacity(0.4),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _MoreMenu(onDelete: widget.onDelete),
                ],
              ),
              const Spacer(),
              Text(
                widget.project.name,
                style: AppTheme.headingSmall.copyWith(fontSize: 15),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 5),
              Text(
                DateFormat('MM.dd').format(widget.project.create_at),
                style: AppTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              if (tags.isNotEmpty)
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: tags
                      .take(2)
                      .map(
                        (t) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.bgPrimary,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.borderSubtle),
                          ),
                          child: Text(
                            '#${t.trim()}',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                )
              else
                Text('태그 없음', style: AppTheme.bodySmall),
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
      size: 16,
      color: AppTheme.textMuted,
    ),
    iconSize: 16,
    onSelected: (val) {
      if (val == 'delete') onDelete();
    },
    itemBuilder: (_) => [
      PopupMenuItem(
        value: 'delete',
        child: Row(
          children: const [
            Icon(Icons.delete_outline_rounded, size: 14, color: AppTheme.red),
            SizedBox(width: 8),
            Text('삭제', style: TextStyle(color: AppTheme.red, fontSize: 13)),
          ],
        ),
      ),
    ],
  );
}

// ─── 프로젝트 추가 다이얼로그 ──────────────────────────
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('새 프로젝트', style: AppTheme.headingMedium),
            const SizedBox(height: 4),
            Text('관련 노트를 묶을 프로젝트를 만드세요.', style: AppTheme.bodySmall),
            const SizedBox(height: 24),
            SFTextField(
              label: '프로젝트 이름 *',
              hint: '예: 운영체제 수업',
              controller: _nameCtrl,
            ),
            const SizedBox(height: 14),
            SFTextField(
              label: '태그 (선택)',
              hint: '예: CS, 2024, 중간고사',
              controller: _tagCtrl,
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SFButton(
                  label: '취소',
                  outlined: true,
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                SFButton(
                  label: '만들기',
                  onPressed: () {
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
