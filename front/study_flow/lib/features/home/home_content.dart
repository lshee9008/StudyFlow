// ╔════════════════════════════════════════════════════════════╗
// ║  HomeContent — Dashboard Widgets                           ║
// ║  Self-contained, no circular dependencies with shell       ║
// ╚════════════════════════════════════════════════════════════╝
import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../../core/provider_config.dart';
import '../../core/theme.dart';
import '../../core/ui/app_components.dart';
import '../../models/user_model.dart';
import '../file/file_screen.dart';
import '../project/project_model.dart';
import '../project/project_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// HomeContent — top-level dashboard widget
// ═══════════════════════════════════════════════════════════════════════════════

// ── 최근 파일 모델 ────────────────────────────────────────────
class _RecentFile {
  final String id;
  final String projectId;
  final String title;
  final String tags;
  final String icon;
  final String content;
  final DateTime? updateAt;

  const _RecentFile({
    required this.id,
    required this.projectId,
    required this.title,
    required this.tags,
    required this.icon,
    required this.content,
    this.updateAt,
  });

  int get charCount => content.length;

  factory _RecentFile.fromJson(Map<String, dynamic> j) => _RecentFile(
    id: j['id'] ?? '',
    projectId: j['project_id'] ?? '',
    title: j['title'] ?? '제목 없음',
    tags: j['tags'] ?? '',
    icon: j['icon'] ?? '',
    content: j['content'] ?? '',
    updateAt: j['update_at'] != null ? DateTime.tryParse(j['update_at']) : null,
  );
}

class HomeContent extends ConsumerStatefulWidget {
  final UserModel user;
  final ValueChanged<ProjectModel> onOpenProject;
  final ValueChanged<ProjectModel> onDeleteProject;
  final VoidCallback onNewProject;

  const HomeContent({
    super.key,
    required this.user,
    required this.onOpenProject,
    required this.onDeleteProject,
    required this.onNewProject,
  });

  @override
  ConsumerState<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends ConsumerState<HomeContent> {
  List<_RecentFile> _recentFiles = [];
  bool _loadingRecent = true;
  Map<String, dynamic>? _flowSummary;
  bool _loadingFlow = false;

  @override
  void initState() {
    super.initState();
    _loadRecentFiles();
    _loadFlowSummary();
  }

  Future<void> _loadRecentFiles() async {
    if (widget.user.id == null || widget.user.id!.isEmpty) return;
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/files/user/${widget.user.id}/recent?limit=6'),
      ).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final List data = jsonDecode(utf8.decode(res.bodyBytes));
        setState(() {
          _recentFiles = data.map((j) => _RecentFile.fromJson(j)).toList();
          _loadingRecent = false;
        });
      } else {
        setState(() => _loadingRecent = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRecent = false);
    }
  }

  Future<void> _loadFlowSummary() async {
    final uid = widget.user.id;
    if (uid == null || uid.isEmpty) return;
    setState(() => _loadingFlow = true);
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/flow/summary/$uid'),
      ).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() {
          _flowSummary = jsonDecode(utf8.decode(res.bodyBytes));
          _loadingFlow = false;
        });
      } else {
        setState(() => _loadingFlow = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFlow = false);
    }
  }

  void _openFile(String fileId) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => FileScreen(fileId: fileId),
        transitionDuration: const Duration(milliseconds: 260),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // projectProvider를 직접 watch → 로드 후에도 실시간 반영
    final projects = [...ref.watch(projectProvider)]
      ..sort((a, b) => b.update_at.compareTo(a.update_at));

    final w = MediaQuery.of(context).size.width;
    final twoCol = w > 1100;

    return ListView(
      key: const PageStorageKey('home-scroll'),
      padding: const EdgeInsets.all(24),
      children: [
        AppFadeSlide(
          delay: const Duration(milliseconds: 60),
          beginOffset: const Offset(0, 16),
          child: _HeroGreetingCard(user: widget.user, projectCount: projects.length),
        ),
        const SizedBox(height: 28),

        // ── 전체 통계 스트립 ──────────────────────────────────────
        if (projects.isNotEmpty || _recentFiles.isNotEmpty)
          AppFadeSlide(
            delay: const Duration(milliseconds: 80),
            beginOffset: const Offset(0, 8),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _GlobalStatsRow(
                projects: projects,
                recentFiles: _recentFiles,
              ),
            ),
          ),

        // ── 최근 이용 파일 섹션 ─────────────────────────────────
        if (_loadingRecent || _recentFiles.isNotEmpty) ...[
          AppFadeSlide(
            delay: const Duration(milliseconds: 100),
            beginOffset: const Offset(0, 10),
            child: _SectionLabel(label: '최근 파일'),
          ),
          const SizedBox(height: 10),
          if (_loadingRecent)
            _RecentFilesShimmer()
          else
            _RecentFilesList(files: _recentFiles, onOpen: _openFile),
          const SizedBox(height: 28),
        ],

        // ── 학습 흐름 대시보드 ─────────────────────────────────
        if (_loadingFlow || _flowSummary != null)
          AppFadeSlide(
            delay: const Duration(milliseconds: 110),
            beginOffset: const Offset(0, 10),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: _loadingFlow
                  ? const _FlowShimmer()
                  : _FlowDashboard(
                      summary: _flowSummary!,
                      onOpenFile: _openFile,
                    ),
            ),
          ),

        AppFadeSlide(
          delay: const Duration(milliseconds: 120),
          beginOffset: const Offset(0, 10),
          child: _SectionHeader(
            label: '이어서 작업',
            count: projects.length,
            onNewProject: widget.onNewProject,
          ),
        ),
        const SizedBox(height: 12),
        if (projects.isEmpty)
          AppFadeSlide(
            delay: const Duration(milliseconds: 160),
            child: _EmptyProjectsState(onNewProject: widget.onNewProject),
          )
        else if (twoCol)
          _ProjectGrid(
            projects: projects,
            onOpen: widget.onOpenProject,
            onDelete: widget.onDeleteProject,
          )
        else
          _ProjectList(
            projects: projects,
            onOpen: widget.onOpenProject,
            onDelete: widget.onDeleteProject,
          ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ── 섹션 라벨 (단순) ──────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
        letterSpacing: -0.2,
      ),
    );
  }
}

// ── 최근 파일 카드 리스트 ─────────────────────────────────────
class _RecentFilesList extends StatelessWidget {
  final List<_RecentFile> files;
  final ValueChanged<String> onOpen;
  const _RecentFilesList({required this.files, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: files.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) => AppFadeSlide(
          delay: Duration(milliseconds: 80 + i * 40),
          beginOffset: const Offset(16, 0),
          child: _RecentFileCard(file: files[i], onOpen: () => onOpen(files[i].id)),
        ),
      ),
    );
  }
}

class _RecentFileCard extends StatefulWidget {
  final _RecentFile file;
  final VoidCallback onOpen;
  const _RecentFileCard({required this.file, required this.onOpen});

  @override
  State<_RecentFileCard> createState() => _RecentFileCardState();
}

class _RecentFileCardState extends State<_RecentFileCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final dt = widget.file.updateAt;
    final timeStr = dt == null ? '' : _relativeDate(dt);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 190,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered ? colors.accent.withValues(alpha: 0.35) : colors.border,
              width: _hovered ? 1.5 : 1,
            ),
            boxShadow: _hovered ? AppShadows.cardHover(colors.accent) : AppShadows.elevation1,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  widget.file.icon.isNotEmpty
                      ? Text(widget.file.icon, style: const TextStyle(fontSize: 14))
                      : Icon(LucideIcons.fileText, size: 13, color: colors.accent),
                  const Spacer(),
                  if (timeStr.isNotEmpty)
                    Text(
                      timeStr,
                      style: GoogleFonts.inter(fontSize: 10, color: colors.textSecondary.withValues(alpha: 0.6)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.file.title.isEmpty ? '제목 없음' : widget.file.title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                  letterSpacing: -0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Row(
                children: [
                  if (widget.file.tags.isNotEmpty) ...[
                    Expanded(
                      child: Text(
                        widget.file.tags.split(',').first.trim(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: colors.accent.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else
                    const Spacer(),
                  if (widget.file.charCount > 0)
                    Text(
                      '${(widget.file.charCount / 300).ceil()}분',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: colors.textSecondary.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays == 1) return '어제';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return DateFormat('M/d').format(dt);
  }
}

// ─── Global stats row ─────────────────────────────────────────────────────────

class _GlobalStatsRow extends StatelessWidget {
  final List<ProjectModel> projects;
  final List<_RecentFile> recentFiles;

  const _GlobalStatsRow({required this.projects, required this.recentFiles});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final totalChars = recentFiles.fold<int>(0, (s, f) => s + f.charCount);
    final latestUpdate = recentFiles.isEmpty ? null : recentFiles.first.updateAt;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          _MiniStat(
            icon: LucideIcons.folder,
            label: '프로젝트',
            value: '${projects.length}개',
            color: AppTheme.accent,
            colors: colors,
          ),
          _MiniStatDivider(colors: colors),
          _MiniStat(
            icon: LucideIcons.fileText,
            label: '최근 노트',
            value: '${recentFiles.length}개',
            color: AppTheme.green,
            colors: colors,
          ),
          _MiniStatDivider(colors: colors),
          _MiniStat(
            icon: LucideIcons.type,
            label: '분량',
            value: totalChars > 0 ? '${(totalChars / 300).ceil()}분' : '-',
            color: AppTheme.purple,
            colors: colors,
          ),
          _MiniStatDivider(colors: colors),
          _MiniStat(
            icon: LucideIcons.clock,
            label: '마지막 활동',
            value: latestUpdate != null ? _shortDate(latestUpdate) : '-',
            color: AppTheme.yellow,
            colors: colors,
          ),
        ],
      ),
    );
  }

  String _shortDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays == 1) return '어제';
    return '${diff.inDays}일 전';
  }
}

class _MiniStatDivider extends StatelessWidget {
  final AppColors colors;
  const _MiniStatDivider({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: colors.border.withValues(alpha: 0.5),
      margin: const EdgeInsets.symmetric(horizontal: 12),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final AppColors colors;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 11, color: color.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: colors.textSecondary.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentFilesShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return SizedBox(
      height: 88,
      child: Row(
        children: List.generate(4, (i) => Padding(
          padding: EdgeInsets.only(right: i < 3 ? 10 : 0),
          child: AppShimmer(
            child: Container(
              width: 180,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        )),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HomeTopBar
// ═══════════════════════════════════════════════════════════════════════════════

class HomeTopBar extends StatelessWidget {
  final bool isCompact;
  final VoidCallback onSearch;
  final VoidCallback onSettings;
  final VoidCallback onNewProject;

  const HomeTopBar({
    super.key,
    required this.isCompact,
    required this.onSearch,
    required this.onSettings,
    required this.onNewProject,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.border.withValues(alpha: 0.7)),
        ),
      ),
      child: Row(
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.sparkles,
                size: 13,
                color: colors.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 6),
              Text(
                '이어서 작업',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const Spacer(),
          _TopBarIconBtn(icon: LucideIcons.search, onTap: onSearch, tooltip: '검색'),
          const SizedBox(width: 6),
          if (isCompact) ...[
            _TopBarIconBtn(icon: LucideIcons.settings, onTap: onSettings, tooltip: '설정'),
            const SizedBox(width: 8),
          ],
          _NewProjectButton(onTap: onNewProject),
        ],
      ),
    );
  }
}

// ─── Top bar icon button ──────────────────────────────────────────────────────

class _TopBarIconBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _TopBarIconBtn({required this.icon, required this.onTap, this.tooltip});

  @override
  State<_TopBarIconBtn> createState() => _TopBarIconBtnState();
}

class _TopBarIconBtnState extends State<_TopBarIconBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip ?? '',
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _hovered ? colors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: _hovered ? colors.border : Colors.transparent,
              ),
            ),
            child: Icon(
              widget.icon,
              size: 15,
              color: _hovered ? colors.textPrimary : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── New project button ───────────────────────────────────────────────────────

class _NewProjectButton extends StatefulWidget {
  final VoidCallback onTap;
  const _NewProjectButton({required this.onTap});

  @override
  State<_NewProjectButton> createState() => _NewProjectButtonState();
}

class _NewProjectButtonState extends State<_NewProjectButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.03 * _ctrl.value, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              gradient: _hovered
                  ? const LinearGradient(
                      colors: [Color(0xFF7A96FF), Color(0xFF9E8FFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : AppGradients.accent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: _hovered
                  ? AppShadows.accentGlow(AppTheme.accent, intensity: 0.35)
                  : AppShadows.accentGlow(AppTheme.accent, intensity: 0.18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.plus, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  '새 프로젝트',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Section header
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final VoidCallback onNewProject;

  const _SectionHeader({
    required this.label,
    required this.count,
    required this.onNewProject,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: colors.border.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
        ),
        const Spacer(),
        _TopBarIconBtn(
          icon: LucideIcons.plus,
          onTap: onNewProject,
          tooltip: '새 프로젝트',
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Hero Greeting Card
// ═══════════════════════════════════════════════════════════════════════════════

class _HeroGreetingCard extends StatefulWidget {
  final UserModel user;
  final int projectCount;

  const _HeroGreetingCard({required this.user, required this.projectCount});

  @override
  State<_HeroGreetingCard> createState() => _HeroGreetingCardState();
}

class _HeroGreetingCardState extends State<_HeroGreetingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _blobCtrl;

  @override
  void initState() {
    super.initState();
    _blobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blobCtrl.dispose();
    super.dispose();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return '야심한 밤이네요,';
    if (h < 12) return '좋은 아침이에요,';
    if (h < 18) return '안녕하세요,';
    if (h < 21) return '좋은 저녁이에요,';
    return '오늘도 수고했어요,';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekday = DateFormat('EEEE', 'ko_KR').format(now);
    final dateStr = DateFormat('M월 d일', 'ko_KR').format(now);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 208,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(decoration: const BoxDecoration(gradient: AppGradients.heroCard)),
            ),
            // Aurora blobs
            AnimatedBuilder(
              animation: _blobCtrl,
              builder: (ctx, ch) {
                final t = CurvedAnimation(parent: _blobCtrl, curve: Curves.easeInOut).value;
                return Positioned(
                  left: lerpDouble(-100, -50, t),
                  top: lerpDouble(-100, -60, t),
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.accent.withValues(alpha: 0.14),
                    ),
                  ),
                );
              },
            ),
            AnimatedBuilder(
              animation: _blobCtrl,
              builder: (ctx, ch) {
                final t = CurvedAnimation(
                  parent: _blobCtrl,
                  curve: const Interval(0.2, 1.0, curve: Curves.easeInOut),
                ).value;
                return Positioned(
                  right: lerpDouble(-80, -30, t),
                  bottom: lerpDouble(-60, -90, t),
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.purple.withValues(alpha: 0.10),
                    ),
                  ),
                );
              },
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                child: const SizedBox.expand(),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        ShaderMask(
                          shaderCallback: (bounds) => AppGradients.accent.createShader(bounds),
                          blendMode: BlendMode.srcIn,
                          child: Text(
                            '${widget.user.name}님',
                            style: GoogleFonts.inter(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                          ),
                          child: Text(
                            '$dateStr $weekday',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _StatChip(
                              icon: LucideIcons.folder,
                              value: widget.projectCount,
                              label: '진행 중',
                              color: AppTheme.accent,
                            ),
                            _StatChip(
                              icon: LucideIcons.zap,
                              value: 0,
                              label: '오늘 집중',
                              color: AppTheme.green,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  _CalendarWidget(date: now),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          AppCountUp(
            value: value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarWidget extends StatelessWidget {
  final DateTime date;
  const _CalendarWidget({required this.date});

  @override
  Widget build(BuildContext context) {
    final dayStr = DateFormat('d').format(date);
    final monthStr = DateFormat('MMM', 'ko_KR').format(date).toUpperCase();
    final weekStr = DateFormat('EEE', 'ko_KR').format(date).toUpperCase();

    return Container(
      width: 66,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: const BoxDecoration(gradient: AppGradients.accent),
              child: Center(
                child: Text(
                  monthStr,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                dayStr,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                weekStr,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.55),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Project List / Grid
// ═══════════════════════════════════════════════════════════════════════════════

class _ProjectList extends StatelessWidget {
  final List<ProjectModel> projects;
  final ValueChanged<ProjectModel> onOpen;
  final ValueChanged<ProjectModel> onDelete;

  const _ProjectList({
    required this.projects,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(projects.length, (i) {
        return AppFadeSlide(
          delay: Duration(milliseconds: 160 + i * 45),
          beginOffset: const Offset(0, 14),
          child: Padding(
            padding: EdgeInsets.only(bottom: i == projects.length - 1 ? 0 : 8),
            child: _ProjectCard(
              project: projects[i],
              index: i,
              onOpen: () => onOpen(projects[i]),
              onDelete: () => onDelete(projects[i]),
            ),
          ),
        );
      }),
    );
  }
}

class _ProjectGrid extends StatelessWidget {
  final List<ProjectModel> projects;
  final ValueChanged<ProjectModel> onOpen;
  final ValueChanged<ProjectModel> onDelete;

  const _ProjectGrid({
    required this.projects,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate((projects.length / 2).ceil(), (row) {
        final left = row * 2;
        final right = row * 2 + 1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: AppFadeSlide(
                  delay: Duration(milliseconds: 160 + left * 40),
                  beginOffset: const Offset(0, 14),
                  child: _ProjectCard(
                    project: projects[left],
                    index: left,
                    onOpen: () => onOpen(projects[left]),
                    onDelete: () => onDelete(projects[left]),
                  ),
                ),
              ),
              if (right < projects.length) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: AppFadeSlide(
                    delay: Duration(milliseconds: 180 + right * 40),
                    beginOffset: const Offset(0, 14),
                    child: _ProjectCard(
                      project: projects[right],
                      index: right,
                      onOpen: () => onOpen(projects[right]),
                      onDelete: () => onDelete(projects[right]),
                    ),
                  ),
                ),
              ] else
                const Expanded(child: SizedBox()),
            ],
          ),
        );
      }),
    );
  }
}

// ─── Project card ─────────────────────────────────────────────────────────────

class _ProjectCard extends StatefulWidget {
  final ProjectModel project;
  final int index;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _ProjectCard({
    required this.project,
    required this.index,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final emoji = widget.project.icon.isNotEmpty
        ? widget.project.icon
        : AppEmojiSet.forIndex(widget.index);
    final iconBg = AppProjectColors.forIndex(widget.index);
    final tags = widget.project.tags
        .split(',')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => _pressCtrl.forward(),
        onTapUp: (_) {
          _pressCtrl.reverse();
          widget.onOpen();
        },
        onTapCancel: () => _pressCtrl.reverse(),
        child: AnimatedBuilder(
          animation: _pressCtrl,
          builder: (_, child) => Transform.scale(
            scale: 1.0 - 0.018 * _pressCtrl.value,
            child: child,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hovered
                    ? colors.accent.withValues(alpha: 0.40)
                    : colors.border,
                width: _hovered ? 1.5 : 1,
              ),
              boxShadow: _hovered
                  ? AppShadows.cardHover(colors.accent)
                  : AppShadows.elevation1,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _hovered
                          ? [
                              BoxShadow(
                                color: iconBg.withValues(alpha: 0.4),
                                blurRadius: 12,
                                spreadRadius: -2,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: TextStyle(fontSize: _hovered ? 22 : 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.project.name,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _relativeDate(widget.project.update_at),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: colors.textSecondary.withValues(alpha: 0.65),
                          ),
                        ),
                        if (tags.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 4,
                            children: tags
                                .take(3)
                                .map((t) => _TagPill(label: t))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'delete') widget.onDelete();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'open',
                        onTap: widget.onOpen,
                        child: const Row(
                          children: [
                            Icon(LucideIcons.externalLink, size: 14),
                            SizedBox(width: 8),
                            Text('열기'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(LucideIcons.trash2, size: 14, color: AppTheme.red),
                            const SizedBox(width: 8),
                            Text('삭제', style: TextStyle(color: AppTheme.red)),
                          ],
                        ),
                      ),
                    ],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: colors.border),
                    ),
                    color: colors.surface,
                    child: AnimatedOpacity(
                      opacity: _hovered ? 1.0 : 0.4,
                      duration: const Duration(milliseconds: 150),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _hovered
                              ? colors.border.withValues(alpha: 0.4)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          LucideIcons.moreHorizontal,
                          size: 15,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays == 1) return '어제';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return DateFormat('M월 d일', 'ko_KR').format(dt);
  }
}

class _TagPill extends StatelessWidget {
  final String label;
  const _TagPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: colors.border.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: colors.textSecondary,
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyProjectsState extends StatelessWidget {
  final VoidCallback onNewProject;
  const _EmptyProjectsState({required this.onNewProject});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppPulse(
            duration: const Duration(milliseconds: 2000),
            minOpacity: 0.4,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: AppGradients.accentSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.25),
                ),
              ),
              child: const Center(
                child: Icon(LucideIcons.folder, size: 22, color: AppTheme.accent),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '첫 프로젝트를 만들어보세요',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '배움의 흐름을 기록하고 관리해보세요.',
            style: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _NewProjectButton(onTap: onNewProject),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HomeSkeleton (loading state while user is being resolved)
// ═══════════════════════════════════════════════════════════════════════════════

class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: Row(
        children: [
          Container(
            width: 220,
            color: colors.surface.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppShimmer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 208,
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        const SizedBox(height: 24),
                        AppSkeletonLine(width: 120, height: 16, color: colors.border),
                        const SizedBox(height: 16),
                        for (var i = 0; i < 3; i++) ...[
                          Container(
                            height: 76,
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ProjectCreateSheet (used by AppShell)
// ═══════════════════════════════════════════════════════════════════════════════

class ProjectCreateSheet extends StatefulWidget {
  final String userId;
  const ProjectCreateSheet({super.key, required this.userId});

  @override
  State<ProjectCreateSheet> createState() => _ProjectCreateSheetState();
}

class _ProjectCreateSheetState extends State<ProjectCreateSheet>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _tagsController = TextEditingController();
  String _icon = '📘';
  late AnimationController _sheetCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _sheetCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _sheetCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _sheetCtrl, curve: Curves.easeOut);
    _sheetCtrl.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tagsController.dispose();
    _sheetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: AppGradients.accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(LucideIcons.folderPlus, size: 15, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '새 프로젝트',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SheetInput(
                    controller: _nameController,
                    hint: '프로젝트 이름',
                    label: '이름',
                    icon: LucideIcons.type,
                    autofocus: true,
                    onSubmitted: (_) => _submit(context),
                  ),
                  const SizedBox(height: 14),
                  _SheetInput(
                    controller: _tagsController,
                    hint: 'flutter, 알고리즘, CS...',
                    label: '태그 (쉼표로 구분)',
                    icon: LucideIcons.tags,
                  ),
                  const SizedBox(height: 14),
                  _ProjectEmojiPicker(
                    current: _icon,
                    onChanged: (v) => setState(() => _icon = v),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _OutlineButton(
                          label: '취소',
                          onTap: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _NewProjectButton(onTap: () => _submit(context))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit(BuildContext context) {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    HapticFeedback.lightImpact();
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
        icon: _icon,
        is_sync: 0,
      ),
    );
  }
}

class _ProjectEmojiPicker extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _ProjectEmojiPicker({required this.current, required this.onChanged});
  static const _choices = [
    // 학습 / Study
    '📘', '📗', '📕', '📙', '📚', '📖', '🎓', '✏️',
    // 과학 / Science & Tech
    '🧠', '🔬', '🔭', '🧪', '💻', '🤖', '🔐', '🌐',
    // 에너지 / Goals
    '💡', '⚡', '🎯', '🏆', '🚀', '🔥', '⭐', '💪',
    // 도구 / Tools & Work
    '🛠️', '📊', '📋', '🗂️', '📝', '📌', '🗓️', '📁',
    // 감성 / Life
    '🎨', '🎵', '🌿', '☕', '🌸', '🌍', '🦋', '🎮',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '아이콘',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: colors.textSecondary.withValues(alpha: 0.7),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _choices
              .map((e) => _SheetEmojiChip(
                    emoji: e,
                    selected: e == current,
                    onTap: () => onChanged(e),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

// ─── Sheet emoji chip ─────────────────────────────────────────────────────────

class _SheetEmojiChip extends StatefulWidget {
  final String emoji;
  final bool selected;
  final VoidCallback onTap;
  const _SheetEmojiChip({
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_SheetEmojiChip> createState() => _SheetEmojiChipState();
}

class _SheetEmojiChipState extends State<_SheetEmojiChip>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late AnimationController _scale;

  @override
  void initState() {
    super.initState();
    _scale = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final accent = AppTheme.accent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _hovered = true);
        _scale.forward();
      },
      onExit: (_) {
        setState(() => _hovered = false);
        _scale.reverse();
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _scale,
          builder: (_, child) => Transform.scale(
            scale: 1.0 + _scale.value * 0.08,
            child: child,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: widget.selected
                  ? accent.withValues(alpha: 0.14)
                  : _hovered
                  ? colors.border.withValues(alpha: 0.35)
                  : colors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.selected
                    ? accent.withValues(alpha: 0.7)
                    : _hovered
                    ? colors.border
                    : colors.border.withValues(alpha: 0.5),
                width: widget.selected ? 1.5 : 1.0,
              ),
              boxShadow: widget.selected
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.22),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  widget.emoji,
                  style: TextStyle(fontSize: widget.selected ? 20 : 18),
                ),
                if (widget.selected)
                  Positioned(
                    bottom: 4,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.5),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sheet input ──────────────────────────────────────────────────────────────

class _SheetInput extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final String label;
  final IconData icon;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  const _SheetInput({
    required this.controller,
    required this.hint,
    required this.label,
    required this.icon,
    this.autofocus = false,
    this.onSubmitted,
  });

  @override
  State<_SheetInput> createState() => _SheetInputState();
}

class _SheetInputState extends State<_SheetInput> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: colors.textSecondary.withValues(alpha: 0.7),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        Focus(
          onFocusChange: (v) => setState(() => _focused = v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _focused
                    ? AppTheme.accent.withValues(alpha: 0.5)
                    : colors.border,
                width: _focused ? 1.5 : 1,
              ),
              boxShadow: _focused
                  ? AppShadows.accentGlow(AppTheme.accent, intensity: 0.12)
                  : null,
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: Icon(
                    widget.icon,
                    size: 15,
                    color: _focused ? AppTheme.accent : colors.textSecondary,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    autofocus: widget.autofocus,
                    onSubmitted: widget.onSubmitted,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      hintStyle: GoogleFonts.inter(
                        fontSize: 14,
                        color: colors.textSecondary.withValues(alpha: 0.5),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OutlineButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineButton({required this.label, required this.onTap});

  @override
  State<_OutlineButton> createState() => _OutlineButtonState();
}

class _OutlineButtonState extends State<_OutlineButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          height: 42,
          decoration: BoxDecoration(
            color: _hovered ? colors.border.withValues(alpha: 0.3) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border),
          ),
          child: Center(
            child: Text(
              widget.label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ── 학습 흐름 대시보드 ──────────────────────────────────
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// 색상 참조
const _fBg2 = AppTheme.bgSecondary;
const _fBg3 = AppTheme.bgTertiary;
const _fBdr = AppTheme.borderSubtle;
const _fBdr2 = AppTheme.borderDefault;
const _fTxt0 = AppTheme.textPrimary;
const _fTxt1 = AppTheme.textSecondary;
const _fTxt2 = AppTheme.textTertiary;
const _fAcc = AppTheme.accent;
const _fAccD = AppTheme.accentDim;
const _fGrn = AppTheme.green;
const _fRed = AppTheme.red;
const _fYel = AppTheme.yellow;
const _fPur = AppTheme.purple;

class _FlowShimmer extends StatelessWidget {
  const _FlowShimmer();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: _fBg2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _fBdr),
      ),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: _fAcc),
        ),
      ),
    );
  }
}

class _FlowDashboard extends StatefulWidget {
  final Map<String, dynamic> summary;
  final void Function(String) onOpenFile;
  const _FlowDashboard({required this.summary, required this.onOpenFile});

  @override
  State<_FlowDashboard> createState() => _FlowDashboardState();
}

class _FlowDashboardState extends State<_FlowDashboard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final stats = widget.summary['stats'] as Map<String, dynamic>? ?? {};
    final dueReviews = widget.summary['due_reviews'] as List? ?? [];
    final noQuizFiles = widget.summary['no_quiz_files'] as List? ?? [];
    final weakFiles = widget.summary['weak_files'] as List? ?? [];
    final nextActions = widget.summary['next_actions'] as List? ?? [];

    final dueCount = stats['due_count'] ?? dueReviews.length;
    final noQuizCount = stats['no_quiz_count'] ?? noQuizFiles.length;
    final totalQuizzes = stats['total_quizzes'] ?? 0;
    final avgScore = (stats['avg_score'] ?? 0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 헤더
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _fPur.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _fPur.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.psychology_rounded, size: 13, color: _fPur),
                  const SizedBox(width: 5),
                  Text(
                    '학습 흐름',
                    style: GoogleFonts.inter(
                      color: _fPur,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '학습 현황',
              style: GoogleFonts.inter(
                color: _fTxt0,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _fBg3,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _fBdr2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _expanded ? '접기' : '자세히',
                      style: GoogleFonts.inter(
                        color: _fTxt2,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 14,
                      color: _fTxt2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 통계 스트립
        Row(
          children: [
            _FlowStat(
              icon: Icons.quiz_rounded,
              label: '총 퀴즈',
              value: '$totalQuizzes회',
              color: _fAcc,
            ),
            const SizedBox(width: 8),
            _FlowStat(
              icon: Icons.score_rounded,
              label: '평균 점수',
              value: totalQuizzes > 0 ? '${avgScore.toStringAsFixed(0)}%' : '-',
              color: avgScore >= 70 ? _fGrn : (avgScore > 0 ? _fYel : _fTxt2),
            ),
            const SizedBox(width: 8),
            _FlowStat(
              icon: Icons.alarm_rounded,
              label: '복습 대기',
              value: '$dueCount건',
              color: dueCount > 0 ? _fRed : _fGrn,
            ),
            const SizedBox(width: 8),
            _FlowStat(
              icon: Icons.radio_button_unchecked_rounded,
              label: '미퀴즈',
              value: '$noQuizCount개',
              color: noQuizCount > 0 ? _fYel : _fGrn,
            ),
          ],
        ),

        // 확장 영역
        if (_expanded) ...[
          const SizedBox(height: 16),

          // 복습 필요 파일
          if (dueReviews.isNotEmpty) ...[
            _FlowSubHeader(
              icon: Icons.alarm_rounded,
              label: '복습 필요',
              color: _fRed,
            ),
            const SizedBox(height: 8),
            ...dueReviews.take(3).map((f) => _FlowFileChip(
              title: f['file_title'] ?? '노트',
              subtitle: '${f['interval_days'] ?? 1}일 경과',
              color: _fRed,
              onTap: () => widget.onOpenFile(f['file_id']),
            )),
            const SizedBox(height: 14),
          ],

          // 퀴즈 안 푼 파일
          if (noQuizFiles.isNotEmpty) ...[
            _FlowSubHeader(
              icon: Icons.lightbulb_outline_rounded,
              label: '퀴즈 미완료',
              color: _fYel,
            ),
            const SizedBox(height: 8),
            ...noQuizFiles.take(3).map((f) => _FlowFileChip(
              title: f['title'] ?? '노트',
              subtitle: '퀴즈 없음',
              color: _fYel,
              onTap: () => widget.onOpenFile(f['id']),
            )),
            const SizedBox(height: 14),
          ],

          // 취약 파일
          if (weakFiles.isNotEmpty) ...[
            _FlowSubHeader(
              icon: Icons.trending_down_rounded,
              label: '점수 낮은 노트',
              color: _fPur,
            ),
            const SizedBox(height: 8),
            ...weakFiles.take(3).map((f) {
              final sc = f['avg_score']?.toDouble() ?? 0;
              return _FlowFileChip(
                title: f['file_title'] ?? '노트',
                subtitle: '평균 ${sc.toStringAsFixed(0)}%',
                color: _fPur,
                onTap: () => widget.onOpenFile(f['file_id']),
              );
            }),
            const SizedBox(height: 14),
          ],

          // AI 다음 행동
          if (nextActions.isNotEmpty) ...[
            _FlowSubHeader(
              icon: Icons.auto_awesome_rounded,
              label: 'AI 추천 다음 행동',
              color: _fAcc,
            ),
            const SizedBox(height: 8),
            ...nextActions.take(3).toList().asMap().entries.map((e) {
              final idx = e.key;
              final action = e.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _fAccD,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _fAcc.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: _fAcc.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${idx + 1}',
                          style: GoogleFonts.inter(
                            color: _fAcc,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        action.toString(),
                        style: GoogleFonts.inter(
                          color: _fTxt1,
                          fontSize: 12,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ],
    );
  }
}

class _FlowStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _FlowStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(color: _fTxt2, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowSubHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _FlowSubHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _FlowFileChip extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _FlowFileChip({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _fBg3,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _fBdr),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  color: _fTxt0,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.inter(color: color, fontSize: 11),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 14, color: _fTxt2),
          ],
        ),
      ),
    );
  }
}
