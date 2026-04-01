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

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);

    if (user == null) return const InitialScreen();
    if (user.id == '') {
      return const Scaffold(
        backgroundColor: AppTheme.bgDeep,
        body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }

    final projects = ref.watch(projectProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: Row(
        children: [
          // ── 사이드바 ──────────────────────────────
          _Sidebar(user: user),
          // ── 메인 콘텐츠 ───────────────────────────
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
      width: 240,
      decoration: const BoxDecoration(
        color: AppTheme.bgSecondary,
        border: Border(right: BorderSide(color: AppTheme.borderSubtle)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // 로고
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const SFLogo(size: 24),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentDim,
                    borderRadius: BorderRadius.circular(6),
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
          const SizedBox(height: 24),

          // 유저 프로필 영역
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _UserTile(user: user),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Divider(color: AppTheme.borderSubtle),
          ),
          const SizedBox(height: 8),

          // 네비게이션
          _NavItem(icon: Icons.home_rounded, label: '홈', selected: true),
          _NavItem(icon: Icons.search_rounded, label: '검색'),
          _NavItem(icon: Icons.settings_outlined, label: '설정'),

          const Spacer(),

          // 하단 디버그 버튼 (개발 중에만)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                const Divider(color: AppTheme.borderSubtle),
                const SizedBox(height: 8),
                _SmallButton(
                  icon: Icons.delete_sweep_outlined,
                  label: 'DB 초기화',
                  color: AppTheme.red,
                  onTap: () async {
                    await LocalDatabase.instance.deleteAppDatabase();
                    ref.invalidate(projectProvider);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
      offset: const Offset(0, 50),
      onSelected: (val) async {
        if (val == 'logout') {
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
          value: 'logout',
          child: Row(
            children: const [
              Icon(
                Icons.logout_rounded,
                size: 16,
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
                    fontWeight: FontWeight.w800,
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
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.unfold_more_rounded,
              size: 16,
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
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppTheme.bgTertiary
                : (_hover
                      ? AppTheme.bgTertiary.withOpacity(0.5)
                      : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 17,
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
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color.withOpacity(0.7)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color.withOpacity(0.7), fontSize: 12),
          ),
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
    final greeting = now.hour < 12
        ? '좋은 아침이에요'
        : now.hour < 18
        ? '안녕하세요'
        : '좋은 저녁이에요';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 상단 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting, ${user.name} 👋',
                    style: AppTheme.headingMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('yyyy.MM.dd').format(now),
                    style: AppTheme.bodySmall,
                  ),
                ],
              ),
              const Spacer(),
              // 새 프로젝트 버튼
              SFButton(
                label: '새 프로젝트',
                icon: Icons.add_rounded,
                onPressed: () => _showAddProjectDialog(context, ref, user),
              ),
            ],
          ),
        ),

        // 콘텐츠 영역
        Expanded(
          child: projects.isEmpty
              ? _EmptyState(
                  onAdd: () => _showAddProjectDialog(context, ref, user),
                )
              : _ProjectGrid(projects: projects, user: user),
        ),
      ],
    );
  }

  void _showAddProjectDialog(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
  ) {
    showDialog(
      context: context,
      builder: (_) => _AddProjectDialog(userId: user.id!),
    ).then((project) {
      if (project != null) {
        ref.read(projectProvider.notifier).addProject(project);
      }
    });
  }
}

// ─────────────────────────────────────────────────────────
// 빈 상태
// ─────────────────────────────────────────────────────────
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.bgSecondary,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.accentDim,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.folder_open_rounded,
                    size: 40,
                    color: AppTheme.accent,
                  ),
                ),
                const SizedBox(height: 20),
                Text('첫 프로젝트를 만들어보세요', style: AppTheme.headingMedium),
                const SizedBox(height: 8),
                Text(
                  '프로젝트는 관련 노트를 모아두는 공간이에요.',
                  style: AppTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
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

// ─────────────────────────────────────────────────────────
// 프로젝트 그리드
// ─────────────────────────────────────────────────────────
class _ProjectGrid extends ConsumerWidget {
  final List<ProjectModel> projects;
  final UserModel user;
  const _ProjectGrid({required this.projects, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(32),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate((ctx, i) {
              if (i == 0) {
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
              }
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
              maxCrossAxisExtent: 320,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// 카드들
// ─────────────────────────────────────────────────────────
class _AddCard extends StatefulWidget {
  final VoidCallback onTap;
  const _AddCard({required this.onTap});
  @override
  State<_AddCard> createState() => _AddCardState();
}

class _AddCardState extends State<_AddCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _hover ? AppTheme.accentDim : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hover
                  ? AppTheme.accent.withOpacity(0.4)
                  : AppTheme.borderDefault,
              width: _hover ? 1.5 : 1,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _hover
                      ? AppTheme.accent.withOpacity(0.2)
                      : AppTheme.bgTertiary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: 24,
                  color: _hover ? AppTheme.accent : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '새 프로젝트',
                style: TextStyle(
                  color: _hover ? AppTheme.accent : AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

  // 프로젝트 이름 기반으로 색상 생성
  Color get _accentColor {
    final colors = [
      const Color(0xFFCCFF66), // 라임
      const Color(0xFF4F8EFF), // 블루
      const Color(0xFF8B5CF6), // 퍼플
      const Color(0xFF34D399), // 그린
      const Color(0xFFFBBF24), // 옐로우
      const Color(0xFFF87171), // 레드
    ];
    return colors[widget.project.name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final tags = widget.project.tags.isNotEmpty
        ? widget.project.tags
              .split(',')
              .where((t) => t.trim().isNotEmpty)
              .toList()
        : <String>[];

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _hover ? AppTheme.bgTertiary : AppTheme.bgSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hover ? AppTheme.borderStrong : AppTheme.borderSubtle,
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
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
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Spacer(),
                  // 더보기 메뉴
                  _MoreMenu(onDelete: widget.onDelete),
                ],
              ),
              const Spacer(),
              Text(
                widget.project.name,
                style: AppTheme.headingSmall.copyWith(fontSize: 16),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                DateFormat('MM.dd').format(widget.project.create_at),
                style: AppTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (tags.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags
                      .take(3)
                      .map(
                        (t) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
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
                              fontSize: 11,
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
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: AppTheme.bgSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.borderDefault),
      ),
      padding: EdgeInsets.zero,
      icon: const Icon(
        Icons.more_horiz_rounded,
        size: 18,
        color: AppTheme.textMuted,
      ),
      onSelected: (val) {
        if (val == 'delete') onDelete();
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: const [
              Icon(Icons.delete_outline_rounded, size: 15, color: AppTheme.red),
              SizedBox(width: 8),
              Text('삭제', style: TextStyle(color: AppTheme.red, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// 프로젝트 추가 다이얼로그
// ─────────────────────────────────────────────────────────
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
              label: '프로젝트 이름',
              hint: '예: 운영체제 수업',
              controller: _nameCtrl,
            ),
            const SizedBox(height: 16),
            SFTextField(
              label: '태그 (선택)',
              hint: '예: CS, 2024, 과제',
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
                    final project = ProjectModel(
                      id: const Uuid().v4(),
                      user_id: widget.userId,
                      create_at: DateTime.now(),
                      update_at: DateTime.now(),
                      name: _nameCtrl.text.trim(),
                      tags: _tagCtrl.text.trim(),
                      is_sync: 0,
                    );
                    Navigator.pop(context, project);
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
