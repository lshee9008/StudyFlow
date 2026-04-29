// ╔════════════════════════════════════════════════════════════╗
// ║  AppShell — Persistent Navigation Shell                    ║
// ║  Collapsible sidebar · Inner Navigator · Active state      ║
// ╚════════════════════════════════════════════════════════════╝
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/firebase_auth_service.dart';
import '../../core/theme.dart';
import '../../core/ui/app_components.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../home/home_content.dart';
import '../login/initial_screen.dart';
import '../project/project_model.dart';
import '../project/project_provider.dart';
import '../project/project_screen.dart';
import '../search/search_screen.dart';
import '../settings/profile_settings_screen.dart';

// ─── AppShell ─────────────────────────────────────────────────────────────────

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with SingleTickerProviderStateMixin {
  final _innerNavKey = GlobalKey<NavigatorState>();

  bool _sidebarCollapsed = false;
  // 'home' | 'search' | 'workspace'
  String _activeNav = 'home';
  ProjectModel? _activeProject;

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _goHome() {
    _innerNavKey.currentState?.popUntil((r) => r.isFirst);
    if (mounted) setState(() { _activeNav = 'home'; _activeProject = null; });
  }

  void _goProject(ProjectModel project) {
    _innerNavKey.currentState?.popUntil((r) => r.isFirst);
    _innerNavKey.currentState?.push(_buildContentRoute(
      ProjectScreen(project: project),
    ));
    if (mounted) setState(() { _activeNav = 'workspace'; _activeProject = project; });
  }

  void _goSearch() {
    _innerNavKey.currentState?.popUntil((r) => r.isFirst);
    _innerNavKey.currentState?.push(_buildContentRoute(const SearchScreen()));
    if (mounted) setState(() { _activeNav = 'search'; _activeProject = null; });
  }

  void _toggleSidebar() {
    setState(() => _sidebarCollapsed = !_sidebarCollapsed);
    HapticFeedback.selectionClick();
  }

  Future<void> _logout() async {
    final user = ref.read(userProvider);
    await FirebaseAuthService.signOut();
    await ref.read(userProvider.notifier).logoutExistingUser(user?.id ?? '');
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const InitialScreen()),
      (_) => false,
    );
  }

  Future<void> _showNewProjectSheet(BuildContext ctx, UserModel user) async {
    final project = await showModalBottomSheet<ProjectModel>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProjectCreateSheet(userId: user.id!),
    );
    if (project != null && mounted) {
      await ref.read(projectProvider.notifier).addProject(project);
    }
  }

  Future<void> _deleteProject(BuildContext ctx, ProjectModel project) async {
    await ref.read(projectProvider.notifier).deleteProject(project);
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(ctx)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${project.name} 삭제됨'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          action: SnackBarAction(
            label: '실행취소',
            onPressed: () => ref.read(projectProvider.notifier).addProject(project),
          ),
        ),
      );
  }

  PageRoute<T> _buildContentRoute<T>(Widget page) => PageRouteBuilder<T>(
    pageBuilder: (_, anim, __) => page,
    transitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (_, anim, __, child) {
      final c = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: c,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.02, 0),
            end: Offset.zero,
          ).animate(c),
          child: child,
        ),
      );
    },
  );

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final projects = [...ref.watch(projectProvider)]
      ..sort((a, b) => b.update_at.compareTo(a.update_at));
    final user = ref.watch(userProvider);
    if (user == null) return const SizedBox.shrink();

    final isCompact = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Row(
          children: [
            // ── Persistent sidebar ──────────────────────────────────────
            if (!isCompact)
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                width: _sidebarCollapsed ? 64 : 220,
                clipBehavior: Clip.hardEdge,
                decoration: const BoxDecoration(),
                child: _ShellSidebar(
                  user: user,
                  projects: projects,
                  collapsed: _sidebarCollapsed,
                  activeNav: _activeNav,
                  activeProject: _activeProject,
                  onToggleCollapse: _toggleSidebar,
                  onHome: _goHome,
                  onSearch: _goSearch,
                  onOpenProject: _goProject,
                  onNewProject: () => _showNewProjectSheet(context, user),
                  onSettings: () => Navigator.of(
                    context,
                    rootNavigator: true,
                  ).push(MaterialPageRoute(
                    builder: (_) => ProfileSettingsScreen(user: user),
                  )),
                  onLogout: _logout,
                ),
              ),

            // ── Separator ───────────────────────────────────────────────
            if (!isCompact)
              Container(width: 1, color: colors.border.withValues(alpha: 0.7)),

            // ── Content (inner navigator) ────────────────────────────────
            Expanded(
              child: Navigator(
                key: _innerNavKey,
                onGenerateInitialRoutes: (navState, initialRoute) {
                  return [
                    PageRouteBuilder(
                      pageBuilder: (ctx, anim, _) => Column(
                        children: [
                          HomeTopBar(
                            isCompact: isCompact,
                            onSearch: _goSearch,
                            onSettings: () => Navigator.of(
                              ctx,
                              rootNavigator: true,
                            ).push(MaterialPageRoute(
                              builder: (_) => ProfileSettingsScreen(user: user),
                            )),
                            onNewProject: () => _showNewProjectSheet(ctx, user),
                          ),
                          Expanded(
                            child: HomeContent(
                              user: user,
                              projects: projects,
                              onOpenProject: _goProject,
                              onDeleteProject: (p) => _deleteProject(ctx, p),
                              onNewProject: () => _showNewProjectSheet(ctx, user),
                            ),
                          ),
                        ],
                      ),
                      transitionsBuilder: (_, anim, __, child) =>
                          FadeTransition(opacity: anim, child: child),
                    ),
                  ];
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shell Sidebar
// ═══════════════════════════════════════════════════════════════════════════════

class _ShellSidebar extends StatefulWidget {
  final UserModel user;
  final List<ProjectModel> projects;
  final bool collapsed;
  final String activeNav;
  final ProjectModel? activeProject;
  final VoidCallback onToggleCollapse;
  final VoidCallback onHome;
  final VoidCallback onSearch;
  final ValueChanged<ProjectModel> onOpenProject;
  final VoidCallback onNewProject;
  final VoidCallback onSettings;
  final VoidCallback onLogout;

  const _ShellSidebar({
    required this.user,
    required this.projects,
    required this.collapsed,
    required this.activeNav,
    required this.activeProject,
    required this.onToggleCollapse,
    required this.onHome,
    required this.onSearch,
    required this.onOpenProject,
    required this.onNewProject,
    required this.onSettings,
    required this.onLogout,
  });

  @override
  State<_ShellSidebar> createState() => _ShellSidebarState();
}

class _ShellSidebarState extends State<_ShellSidebar>
    with SingleTickerProviderStateMixin {
  late AnimationController _enterCtrl;
  bool _workspaceHovered = false;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    )..forward();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return AnimatedBuilder(
      animation: _enterCtrl,
      builder: (context, child) {
        final t = CurvedAnimation(
          parent: _enterCtrl,
          curve: Curves.easeOutCubic,
        ).value;
        return Transform.translate(
          offset: Offset(-16 * (1 - t), 0),
          child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Logo + collapse toggle ────────────────────────────────────
          if (widget.collapsed)
            // Collapsed: mini logo icon + toggle, vertically stacked
            SizedBox(
              height: 62,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: AppGradients.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/logo_icon.png',
                        width: 20,
                        height: 20,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _CollapseToggle(
                    collapsed: widget.collapsed,
                    onTap: widget.onToggleCollapse,
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 10),
              child: Row(
                children: [
                  Expanded(child: _GlowWordmark()),
                  _CollapseToggle(
                    collapsed: widget.collapsed,
                    onTap: widget.onToggleCollapse,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),

          // ── Primary nav ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              children: [
                _SidebarNavItem(
                  icon: LucideIcons.layoutDashboard,
                  label: '홈',
                  selected: widget.activeNav == 'home',
                  collapsed: widget.collapsed,
                  onTap: widget.onHome,
                ),
                const SizedBox(height: 2),
                _SidebarNavItem(
                  icon: LucideIcons.search,
                  label: '검색',
                  selected: widget.activeNav == 'search',
                  collapsed: widget.collapsed,
                  onTap: widget.onSearch,
                ),
                const SizedBox(height: 2),
                _SidebarNavItem(
                  icon: LucideIcons.timer,
                  label: '포커스',
                  selected: false,
                  collapsed: widget.collapsed,
                  onTap: () {},
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.collapsed ? 8 : 16,
            ),
            child: Divider(height: 1, color: colors.border),
          ),
          const SizedBox(height: 8),

          // ── Workspace header ──────────────────────────────────────────
          if (!widget.collapsed)
            MouseRegion(
              onEnter: (_) => setState(() => _workspaceHovered = true),
              onExit: (_) => setState(() => _workspaceHovered = false),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 6),
                child: Row(
                  children: [
                    Text(
                      'WORKSPACE',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary.withValues(alpha: 0.42),
                      ),
                    ),
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: _workspaceHovered ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 160),
                      child: _SidebarCircleBtn(
                        icon: LucideIcons.plus,
                        onTap: widget.onNewProject,
                        tooltip: '새 프로젝트',
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Center(
                child: _SidebarCircleBtn(
                  icon: LucideIcons.plus,
                  onTap: widget.onNewProject,
                  tooltip: '새 프로젝트',
                ),
              ),
            ),

          // ── Project list ──────────────────────────────────────────────
          Expanded(
            child: widget.projects.isEmpty
                ? widget.collapsed
                    ? const SizedBox.shrink()
                    : _SidebarEmptyProjects(onTap: widget.onNewProject)
                : _SidebarProjectList(
                    projects: widget.projects,
                    activeProject: widget.activeProject,
                    collapsed: widget.collapsed,
                    onTap: widget.onOpenProject,
                  ),
          ),

          // ── Profile ───────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.collapsed ? 8 : 16,
            ),
            child: Divider(height: 1, color: colors.border),
          ),
          _SidebarProfile(
            user: widget.user,
            collapsed: widget.collapsed,
            onSettings: widget.onSettings,
            onLogout: widget.onLogout,
          ),
        ],
      ),
    );
  }
}

// ─── Collapse toggle ──────────────────────────────────────────────────────────

class _CollapseToggle extends StatefulWidget {
  final bool collapsed;
  final VoidCallback onTap;
  const _CollapseToggle({required this.collapsed, required this.onTap});

  @override
  State<_CollapseToggle> createState() => _CollapseToggleState();
}

class _CollapseToggleState extends State<_CollapseToggle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.collapsed ? '사이드바 펼치기' : '사이드바 접기',
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: _hovered
                  ? colors.accent.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: _hovered
                    ? colors.accent.withValues(alpha: 0.24)
                    : Colors.transparent,
              ),
            ),
            child: AnimatedRotation(
              turns: widget.collapsed ? 0.5 : 0,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: Icon(
                LucideIcons.panelLeftClose,
                size: 14,
                color: _hovered ? colors.accent : colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Glow wordmark ────────────────────────────────────────────────────────────

class _GlowWordmark extends StatefulWidget {
  @override
  State<_GlowWordmark> createState() => _GlowWordmarkState();
}

class _GlowWordmarkState extends State<_GlowWordmark>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _GlowWordmarkIcon(ctrl: _ctrl),
        const SizedBox(width: 10),
        ShaderMask(
          shaderCallback: (bounds) => AppGradients.accent.createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: Text(
            AppTheme.brandName,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _GlowWordmarkIcon extends StatefulWidget {
  final AnimationController? ctrl;
  const _GlowWordmarkIcon({this.ctrl});

  @override
  State<_GlowWordmarkIcon> createState() => _GlowWordmarkIconState();
}

class _GlowWordmarkIconState extends State<_GlowWordmarkIcon>
    with SingleTickerProviderStateMixin {
  AnimationController? _ownCtrl;
  AnimationController get _ctrl => widget.ctrl ?? _ownCtrl!;

  @override
  void initState() {
    super.initState();
    if (widget.ctrl == null) {
      _ownCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2400),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ownCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final t = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut).value;
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            gradient: AppGradients.accent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.15 + 0.20 * t),
                blurRadius: 10 + 8 * t,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Center(
            child: Image.asset(
              'assets/images/logo_icon.png',
              width: 20,
              height: 20,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }
}


// ─── Sidebar nav item ─────────────────────────────────────────────────────────

class _SidebarNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    // ── Collapsed: perfectly-centered icon ───────────────────────────────────
    if (widget.collapsed) {
      return Tooltip(
        message: widget.label,
        preferBelow: false,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 34,
              width: double.infinity,
              decoration: BoxDecoration(
                color: widget.selected
                    ? colors.accent.withValues(alpha: 0.12)
                    : _hovered
                    ? colors.border.withValues(alpha: 0.28)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Center(
                child: Icon(
                  widget.icon,
                  size: 16,
                  color: widget.selected
                      ? colors.accent
                      : _hovered
                      ? colors.textPrimary
                      : colors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // ── Expanded: active bar + label ──────────────────────────────────────────
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 34,
          decoration: BoxDecoration(
            color: widget.selected
                ? colors.accent.withValues(alpha: 0.10)
                : _hovered
                ? colors.border.withValues(alpha: 0.28)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: 3,
                height: widget.selected ? 20 : 0,
                margin: const EdgeInsets.only(left: 4, right: 8),
                decoration: BoxDecoration(
                  gradient: AppGradients.accent,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: widget.selected
                      ? AppShadows.accentGlow(AppTheme.accent, intensity: 0.4)
                      : null,
                ),
              ),
              if (!widget.selected) const SizedBox(width: 15),
              Icon(
                widget.icon,
                size: 15,
                color: widget.selected
                    ? colors.accent
                    : _hovered
                    ? colors.textPrimary
                    : colors.textSecondary,
              ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
                  color: widget.selected
                      ? colors.textPrimary
                      : _hovered
                      ? colors.textPrimary
                      : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sidebar circle button ────────────────────────────────────────────────────

class _SidebarCircleBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _SidebarCircleBtn({required this.icon, required this.onTap, this.tooltip});

  @override
  State<_SidebarCircleBtn> createState() => _SidebarCircleBtnState();
}

class _SidebarCircleBtnState extends State<_SidebarCircleBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 160));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final btn = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _ctrl.forward(),
      onExit: (_) => _ctrl.reverse(),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (ctx, ch) => Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: ColorTween(
                begin: Colors.transparent,
                end: colors.border.withValues(alpha: 0.6),
              ).evaluate(_ctrl),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: ColorTween(
                      begin: Colors.transparent,
                      end: colors.border,
                    ).evaluate(_ctrl) ??
                    Colors.transparent,
              ),
            ),
            child: Icon(widget.icon, size: 13, color: colors.textSecondary),
          ),
        ),
      ),
    );

    return widget.tooltip != null
        ? Tooltip(message: widget.tooltip!, child: btn)
        : btn;
  }
}

// ─── Sidebar project list ─────────────────────────────────────────────────────

class _SidebarProjectList extends StatelessWidget {
  final List<ProjectModel> projects;
  final ProjectModel? activeProject;
  final bool collapsed;
  final ValueChanged<ProjectModel> onTap;

  const _SidebarProjectList({
    required this.projects,
    required this.activeProject,
    required this.collapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      itemCount: projects.length,
      itemBuilder: (context, i) => AppFadeSlide(
        delay: Duration(milliseconds: 80 + i * 28),
        beginOffset: const Offset(0, 8),
        duration: const Duration(milliseconds: 280),
        child: _SidebarProjectTile(
          project: projects[i],
          index: i,
          collapsed: collapsed,
          active: activeProject?.id == projects[i].id,
          onTap: () => onTap(projects[i]),
        ),
      ),
    );
  }
}

class _SidebarProjectTile extends StatefulWidget {
  final ProjectModel project;
  final int index;
  final bool collapsed;
  final bool active;
  final VoidCallback onTap;

  const _SidebarProjectTile({
    required this.project,
    required this.index,
    required this.collapsed,
    required this.active,
    required this.onTap,
  });

  @override
  State<_SidebarProjectTile> createState() => _SidebarProjectTileState();
}

class _SidebarProjectTileState extends State<_SidebarProjectTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final emoji = widget.project.icon.isNotEmpty
        ? widget.project.icon
        : AppEmojiSet.forIndex(widget.index);

    final tile = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 34,
          padding: EdgeInsets.symmetric(horizontal: widget.collapsed ? 0 : 10),
          decoration: BoxDecoration(
            color: widget.active
                ? colors.accent.withValues(alpha: 0.12)
                : _hovered
                ? colors.border.withValues(alpha: 0.28)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: widget.active
                  ? colors.accent.withValues(alpha: 0.24)
                  : Colors.transparent,
            ),
          ),
          child: widget.collapsed
              ? Center(child: Text(emoji, style: const TextStyle(fontSize: 14)))
              : Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        widget.project.name,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: widget.active ? FontWeight.w600 : FontWeight.w500,
                          color: widget.active
                              ? colors.textPrimary
                              : _hovered
                              ? colors.textPrimary
                              : colors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: _hovered ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        LucideIcons.arrowRight,
                        size: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );

    return widget.collapsed
        ? Tooltip(message: widget.project.name, child: tile)
        : tile;
  }
}

class _SidebarEmptyProjects extends StatelessWidget {
  final VoidCallback onTap;
  const _SidebarEmptyProjects({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '프로젝트가 없습니다',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: colors.textSecondary.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onTap,
            child: Text(
              '+ 새 프로젝트',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sidebar profile ──────────────────────────────────────────────────────────

class _SidebarProfile extends StatefulWidget {
  final UserModel user;
  final bool collapsed;
  final VoidCallback onSettings;
  final VoidCallback onLogout;

  const _SidebarProfile({
    required this.user,
    required this.collapsed,
    required this.onSettings,
    required this.onLogout,
  });

  @override
  State<_SidebarProfile> createState() => _SidebarProfileState();
}

class _SidebarProfileState extends State<_SidebarProfile> {
  bool _hovered = false;

  // collapsed 상태에서 팝업 메뉴
  void _showPopup(BuildContext ctx) async {
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
    final result = await showMenu<String>(
      context: ctx,
      position: RelativeRect.fromLTRB(
        pos.dx + size.width,
        pos.dy,
        pos.dx,
        pos.dy + size.height,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      items: [
        const PopupMenuItem(value: 'settings', child: Text('설정')),
        const PopupMenuItem(value: 'logout', child: Text('로그아웃')),
      ],
    );
    if (result == 'settings') widget.onSettings();
    if (result == 'logout') widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final initials =
        widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : 'S';

    final avatar = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        gradient: AppGradients.accent,
        borderRadius: BorderRadius.circular(7),
        boxShadow: AppShadows.accentGlow(AppTheme.accent, intensity: 0.25),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    // ── 접힌 상태: 아바타 탭 → 팝업 ─────────────────────────────────
    if (widget.collapsed) {
      return Builder(
        builder: (ctx) => MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: () => _showPopup(ctx),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.fromLTRB(8, 8, 8, 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _hovered
                    ? colors.border.withValues(alpha: 0.22)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Tooltip(message: widget.user.name, child: Center(child: avatar)),
            ),
          ),
        ),
      );
    }

    // ── 펼쳐진 상태: 이름 클릭 → 설정 / 로그아웃 버튼 ───────────────
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _hovered
              ? colors.border.withValues(alpha: 0.22)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // 아바타 + 이름 (설정으로)
            Expanded(
              child: GestureDetector(
                onTap: widget.onSettings,
                child: Row(
                  children: [
                    avatar,
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: AppTheme.green,
                                  shape: BoxShape.circle,
                                  boxShadow: AppShadows.accentGlow(
                                    AppTheme.green,
                                    intensity: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '온라인',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: colors.textSecondary.withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 로그아웃 버튼
            _SidebarLogoutBtn(onTap: widget.onLogout, hovered: _hovered),
          ],
        ),
      ),
    );
  }
}

// ─── 사이드바 로그아웃 버튼 ───────────────────────────────────────
class _SidebarLogoutBtn extends StatefulWidget {
  final VoidCallback onTap;
  final bool hovered;
  const _SidebarLogoutBtn({required this.onTap, required this.hovered});

  @override
  State<_SidebarLogoutBtn> createState() => _SidebarLogoutBtnState();
}

class _SidebarLogoutBtnState extends State<_SidebarLogoutBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return AnimatedOpacity(
      opacity: (widget.hovered || _hovered) ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 150),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Tooltip(
          message: '로그아웃',
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: _hovered
                    ? Colors.red.withValues(alpha: 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _hovered
                      ? Colors.red.withValues(alpha: 0.30)
                      : Colors.transparent,
                ),
              ),
              child: Icon(
                LucideIcons.logOut,
                size: 12,
                color: _hovered
                    ? Colors.red.withValues(alpha: 0.8)
                    : colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
