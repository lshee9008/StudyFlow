import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme.dart';
import '../../core/ui/app_components.dart';
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
      return const _HomeSkeleton();
    }

    final projects = [...ref.watch(projectProvider)]
      ..sort((a, b) => b.update_at.compareTo(a.update_at));
    final isCompact = MediaQuery.of(context).size.width < 980;

    return AppWorkspaceShell(
      currentNav: 'home',
      title: '워크스페이스',
      subtitle: AppTheme.brandTagline,
      profileLabel: user.name,
      compact: isCompact,
      onHome: () {},
      onWorkspace: () {},
      onSearch: () => Navigator.push(context, _fadeRoute(const SearchScreen())),
      onSettings: () => Navigator.push(
        context,
        _fadeRoute(ProfileSettingsScreen(user: user)),
      ),
      secondaryAction: AppButton(
        label: '검색',
        onPressed: () => Navigator.push(
          context,
          _fadeRoute(const SearchScreen()),
        ),
        primary: false,
        icon: LucideIcons.search,
      ),
      primaryAction: AppButton(
        label: '새 프로젝트',
        onPressed: () => _showCreateSheet(context, ref, user),
        icon: LucideIcons.plus,
      ),
      child: ListView(
        key: const PageStorageKey('home-scroll'),
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          0,
          AppSpace.lg,
          AppSpace.lg,
        ),
        children: [
          _HeroOverview(user: user, projectCount: projects.length),
          const SizedBox(height: 56),
          Text('최근 프로젝트', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpace.sm),
          if (projects.isEmpty)
            AppEmptyState(
              title: '첫 프로젝트를 만들고 학습 흐름을 시작해보세요.',
              actionLabel: '새 프로젝트 만들기',
              onAction: () => _showCreateSheet(context, ref, user),
            )
          else
            ...List.generate(projects.length, (index) {
              final project = projects[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == projects.length - 1 ? 0 : AppSpace.sm,
                ),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 8, end: 0),
                  duration: Duration(
                    milliseconds: 180 + (index * 40),
                  ),
                  curve: AppMotion.ease,
                  builder: (context, offset, child) {
                    return Transform.translate(
                      offset: Offset(0, offset),
                      child: Opacity(
                        opacity: 1 - (offset / 8).clamp(0, 1),
                        child: child,
                      ),
                    );
                  },
                  child: _ProjectCard(
                    project: project,
                    onOpen: () => Navigator.push(
                      context,
                      _fadeRoute(ProjectScreen(project: project)),
                    ),
                    onDelete: () async {
                      await ref.read(projectProvider.notifier).deleteProject(project);
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text('${project.name} 삭제됨'),
                            action: SnackBarAction(
                              label: '실행취소',
                              onPressed: () {
                                ref.read(projectProvider.notifier).addProject(project);
                              },
                            ),
                          ),
                        );
                    },
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _showCreateSheet(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
  ) async {
    final project = await showModalBottomSheet<ProjectModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProjectCreateSheet(userId: user.id!),
    );

    if (project != null) {
      await ref.read(projectProvider.notifier).addProject(project);
    }
  }
}

PageRoute _fadeRoute(Widget page) => PageRouteBuilder(
  pageBuilder: (_, animation, secondaryAnimation) => page,
  transitionsBuilder: (_, animation, secondaryAnimation, child) {
    return FadeTransition(
      opacity: animation,
      child: Transform.translate(
        offset: Tween<Offset>(
          begin: const Offset(0, 0.02),
          end: Offset.zero,
        ).evaluate(animation),
        child: child,
      ),
    );
  },
  transitionDuration: AppMotion.normal,
);

class _HeroOverview extends StatelessWidget {
  final UserModel user;
  final int projectCount;

  const _HeroOverview({required this.user, required this.projectCount});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${user.name}님의 워크스페이스',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  DateFormat('M월 d일 EEEE', 'ko_KR').format(DateTime.now()),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.md),
          AppMetricCard(label: '프로젝트', value: projectCount),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatefulWidget {
  final ProjectModel project;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _ProjectCard({
    required this.project,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final tags = widget.project.tags
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? 1.01 : 1,
        duration: AppMotion.fast,
        curve: AppMotion.ease,
        child: AppCard(
          padding: const EdgeInsets.all(AppSpace.md),
          child: InkWell(
            onTap: widget.onOpen,
            borderRadius: BorderRadius.circular(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.project.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'delete') {
                          widget.onDelete();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('삭제'),
                        ),
                      ],
                      icon: const Icon(LucideIcons.moreHorizontal, size: 16),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  '수정됨 ${DateFormat('M월 d일', 'ko_KR').format(widget.project.update_at)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpace.md),
                Wrap(
                  spacing: AppSpace.xs,
                  runSpacing: AppSpace.xs,
                  children: tags.isEmpty
                      ? const [AppBadge(label: '태그 없음')]
                      : tags.take(3).map((tag) => AppBadge(label: tag)).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectCreateSheet extends StatefulWidget {
  final String userId;

  const _ProjectCreateSheet({required this.userId});

  @override
  State<_ProjectCreateSheet> createState() => _ProjectCreateSheetState();
}

class _ProjectCreateSheetState extends State<_ProjectCreateSheet> {
  final _nameController = TextEditingController();
  final _tagsController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpace.md,
        right: AppSpace.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpace.md,
      ),
      child: AppCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('새 프로젝트', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpace.lg),
            AppInput(
              controller: _nameController,
              hintText: '프로젝트 이름',
              label: '프로젝트 이름',
              icon: LucideIcons.folder,
              autofocus: true,
            ),
            const SizedBox(height: AppSpace.md),
            AppInput(
              controller: _tagsController,
              hintText: '태그',
              label: '태그',
              icon: LucideIcons.tags,
            ),
            const SizedBox(height: AppSpace.lg),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: '취소',
                    onPressed: () => Navigator.pop(context),
                    primary: false,
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: AppButton(
                    label: '만들기',
                    onPressed: () {
                      final name = _nameController.text.trim();
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
                          tags: _tagsController.text.trim(),
                          is_sync: 0,
                        ),
                      );
                    },
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

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.colorsOf(context).background,
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(AppSpace.lg),
          itemCount: 5,
          itemBuilder: (context, index) => Padding(
            padding: EdgeInsets.only(bottom: index == 4 ? 0 : AppSpace.sm),
            child: AppCard(
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeletonLine(width: 160),
                  SizedBox(height: AppSpace.sm),
                  AppSkeletonLine(width: 220),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
