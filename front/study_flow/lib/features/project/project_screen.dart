import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:study_flow/core/db_helper/files_db_helper.dart';
import 'package:study_flow/features/file/file_model.dart';
import 'package:study_flow/features/project/project_model.dart';
import 'package:uuid/uuid.dart';

import '../../core/provider_config.dart';
import '../../core/theme.dart';
import '../../core/ui/app_components.dart';
import '../file/file_screen.dart';
import 'project_provider.dart';

class ProjectScreen extends ConsumerStatefulWidget {
  final ProjectModel project;

  const ProjectScreen({super.key, required this.project});

  @override
  ConsumerState<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends ConsumerState<ProjectScreen> {
  final _nameController = TextEditingController();
  late Future<List<FileModel>> _filesFuture;
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.project.name;
    _tags = widget.project.tags
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    _filesFuture = _fetchFiles();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<List<FileModel>> _fetchFiles() async {
    if (!kIsWeb) {
      return FilesDBHelper.selectProjectFiles(widget.project.id);
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/files/project/${widget.project.id}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map(
              (item) =>
                  FileModel.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
      }
    } catch (error) {
      debugPrint('fetchFiles error: $error');
    }

    return [];
  }

  Future<void> _reloadFiles() async {
    setState(() {
      _filesFuture = _fetchFiles();
    });
  }

  Future<void> _updateName(String value) async {
    await ref
        .read(projectProvider.notifier)
        .updateProjectName(widget.project.id, value);
  }

  Future<void> _addTag(String tag) async {
    final trimmed = tag.trim();
    if (trimmed.isEmpty || _tags.contains(trimmed)) {
      return;
    }

    setState(() => _tags = [..._tags, trimmed]);
    await ref
        .read(projectProvider.notifier)
        .updateProjectTags(widget.project.id, _tags.join(','));
  }

  Future<void> _updateIcon(String icon) async {
    widget.project.icon = icon;
    await ref.read(projectProvider.notifier).updateProjectIcon(
      widget.project.id,
      icon,
    );
  }

  Future<void> _removeTag(String tag) async {
    setState(() => _tags.remove(tag));
    await ref
        .read(projectProvider.notifier)
        .updateProjectTags(widget.project.id, _tags.join(','));
  }

  Future<void> _deleteFile(FileModel file) async {
    if (!kIsWeb) {
      await FilesDBHelper.deleteFile(file.id);
    } else {
      try {
        await http.delete(Uri.parse('$baseUrl/api/files/${file.id}'));
      } catch (error) {
        debugPrint('deleteFile error: $error');
      }
    }

    await _reloadFiles();
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('${file.title} 삭제됨')));
  }

  Future<void> _renameFile(FileModel file) async {
    final controller = TextEditingController(text: file.title);

    final nextTitle = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TextEditSheet(
        title: '노트 이름',
        controller: controller,
        actionLabel: '저장',
      ),
    );

    if (nextTitle == null || nextTitle.trim().isEmpty) {
      return;
    }

    if (!kIsWeb) {
      await FilesDBHelper.updateFile(
        file.id,
        title: nextTitle.trim(),
        tags: file.tags,
        prompt: file.prompt,
        content: file.content,
        icon: file.icon,
      );
    } else {
      try {
        await http.put(
          Uri.parse('$baseUrl/api/files/${file.id}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'title': nextTitle.trim()}),
        );
      } catch (error) {
        debugPrint('renameFile error: $error');
      }
    }

    await _reloadFiles();
  }

  Future<void> _createFile() async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    final file = FileModel(
      id: id,
      project_id: widget.project.id,
      title: '제목 없음',
      content: '',
      tags: '',
      create_at: now,
      update_at: null,
      icon: '',
      prompt: '',
      summary: '',
      graph: '',
    );

    if (!kIsWeb) {
      await FilesDBHelper.insertFile(file);
    }

    try {
      await http.post(
        Uri.parse('$baseUrl/api/files/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': id,
          'project_id': widget.project.id,
          'title': '제목 없음',
          'content': '',
          'tags': '',
          'icon': '',
          'prompt': '',
          'summary': '',
          'graph': '',
          'create_at': now.toIso8601String(),
          'update_at': null,
        }),
      );
    } catch (error) {
      debugPrint('createFile error: $error');
    }

    if (!mounted) {
      return;
    }

    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, secondaryAnimation) =>
            FileScreen(fileId: id, projectId: widget.project.id),
        transitionsBuilder: (_, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 220),
      ),
    );

    await _reloadFiles();
  }

  Future<void> _openTagSheet() async {
    final controller = TextEditingController();
    final tag = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TextEditSheet(
        title: '태그 추가',
        controller: controller,
        actionLabel: '추가',
      ),
    );

    if (tag != null) {
      await _addTag(tag);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) return;
        widget.project.name = _nameController.text.trim();
        widget.project.tags = _tags.join(',');
        widget.project.update_at = DateTime.now();
        ref.read(projectProvider.notifier).updateProjectAll(widget.project);
      },
      child: Column(
        children: [
          _ProjectTopBar(
            projectName: widget.project.name,
            onBack: () => Navigator.pop(context),
            onAddTag: _openTagSheet,
            onCreateFile: _createFile,
          ),
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg,
                    AppSpace.md,
                    AppSpace.lg,
                    AppSpace.md,
                  ),
                  child: _ProjectHeader(
                    controller: _nameController,
                    icon: widget.project.icon,
                    tags: _tags,
                    onBack: () => Navigator.pop(context),
                    onUpdateName: _updateName,
                    onUpdateIcon: _updateIcon,
                    onAddTag: _openTagSheet,
                    onRemoveTag: _removeTag,
                    onCreateFile: _createFile,
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<FileModel>>(
                future: _filesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _ProjectFileSkeleton();
                  }

                  final files = snapshot.data ?? [];
                  if (files.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(AppSpace.lg),
                      child: AppEmptyState(
                        title: '노트를 추가하고 학습 흐름을 이어가보세요.',
                        actionLabel: '새 노트',
                        onAction: _createFile,
                      ),
                    );
                  }

                  return ListView.builder(
                    key: PageStorageKey('project-${widget.project.id}'),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.lg,
                      0,
                      AppSpace.lg,
                      AppSpace.lg,
                    ),
                    itemCount: files.length + 1,
                    itemBuilder: (context, index) {
                      if (index == files.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: AppSpace.sm),
                          child: AppButton(
                            label: '새 노트',
                            onPressed: _createFile,
                            primary: false,
                            icon: LucideIcons.plus,
                            width: double.infinity,
                          ),
                        );
                      }

                      final file = files[index];
                      return AppFadeSlide(
                        delay: Duration(milliseconds: 40 + index * 35),
                        beginOffset: const Offset(0, 12),
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: index == files.length - 1 ? 0 : AppSpace.sm,
                          ),
                          child: _FileTile(
                            file: file,
                            onOpen: () async {
                              await Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder:
                                      (_, animation, secondaryAnimation) =>
                                          FileScreen(
                                            fileId: file.id,
                                            projectId: widget.project.id,
                                          ),
                                  transitionsBuilder:
                                      (
                                        _,
                                        animation,
                                        secondaryAnimation,
                                        child,
                                      ) {
                                        final curved = CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeOutCubic,
                                        );
                                        return FadeTransition(
                                          opacity: curved,
                                          child: SlideTransition(
                                            position: Tween<Offset>(
                                              begin: const Offset(0, 0.02),
                                              end: Offset.zero,
                                            ).animate(curved),
                                            child: child,
                                          ),
                                        );
                                      },
                                  transitionDuration: AppMotion.normal,
                                ),
                              );
                              await _reloadFiles();
                            },
                            onRename: () => _renameFile(file),
                            onDelete: () => _deleteFile(file),
                          ),
                        ),
                      );
                    },
                  );
                },
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

// ─── Project top bar (breadcrumb + actions) ───────────────────────────────────

class _ProjectTopBar extends StatelessWidget {
  final String projectName;
  final VoidCallback onBack;
  final VoidCallback onAddTag;
  final VoidCallback onCreateFile;

  const _ProjectTopBar({
    required this.projectName,
    required this.onBack,
    required this.onAddTag,
    required this.onCreateFile,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.border.withValues(alpha: 0.7)),
        ),
      ),
      child: Row(
        children: [
          // Back + breadcrumb
          _HeaderButton(icon: LucideIcons.arrowLeft, onTap: onBack),
          const SizedBox(width: 10),
          Row(
            children: [
              Text(
                'WORKSPACE',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary.withValues(alpha: 0.55),
                  letterSpacing: 0.3,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  LucideIcons.chevronRight,
                  size: 12,
                  color: colors.textSecondary.withValues(alpha: 0.4),
                ),
              ),
              Text(
                projectName,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const Spacer(),
          AppButton(
            label: '태그',
            onPressed: onAddTag,
            primary: false,
            icon: LucideIcons.tags,
          ),
          const SizedBox(width: AppSpace.xs),
          AppButton(
            label: '새 노트',
            onPressed: onCreateFile,
            icon: LucideIcons.filePlus,
          ),
        ],
      ),
    );
  }
}

class _ProjectHeader extends StatelessWidget {
  final TextEditingController controller;
  final String icon;
  final List<String> tags;
  final VoidCallback onBack;
  final ValueChanged<String> onUpdateName;
  final ValueChanged<String> onUpdateIcon;
  final VoidCallback onAddTag;
  final ValueChanged<String> onRemoveTag;
  final VoidCallback onCreateFile;

  const _ProjectHeader({
    required this.controller,
    required this.icon,
    required this.tags,
    required this.onBack,
    required this.onUpdateName,
    required this.onUpdateIcon,
    required this.onAddTag,
    required this.onRemoveTag,
    required this.onCreateFile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppInput(
          controller: controller,
          hintText: '프로젝트 이름',
          onSubmitted: onUpdateName,
          onChanged: onUpdateName,
        ),
        const SizedBox(height: AppSpace.md),
        _ProjectIconRow(current: icon, onChanged: onUpdateIcon),
        const SizedBox(height: AppSpace.md),
        Wrap(
          spacing: AppSpace.xs,
          runSpacing: AppSpace.xs,
          children: [
            for (final tag in tags)
              _TagChip(label: tag, onRemove: () => onRemoveTag(tag)),
          ],
        ),
      ],
    );
  }
}

// ─── 아이콘 버튼 (버튼 클릭 → 모달 오픈) ───────────────────────

class _ProjectIconRow extends StatefulWidget {
  final String current;
  final ValueChanged<String> onChanged;

  const _ProjectIconRow({required this.current, required this.onChanged});

  @override
  State<_ProjectIconRow> createState() => _ProjectIconRowState();
}

class _ProjectIconRowState extends State<_ProjectIconRow> {
  bool _hovered = false;

  Future<void> _openPicker() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _IconPickerSheet(current: widget.current),
    );
    if (picked != null) widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final display = widget.current.isNotEmpty ? widget.current : '📁';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: _openPicker,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _hovered
                ? colors.accent.withValues(alpha: 0.06)
                : colors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered
                  ? colors.accent.withValues(alpha: 0.35)
                  : colors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(display, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Text(
                '아이콘 변경',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _hovered ? colors.accent : colors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                LucideIcons.chevronDown,
                size: 13,
                color: _hovered ? colors.accent : colors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 아이콘 피커 바텀시트 ──────────────────────────────────────────

class _IconPickerSheet extends StatefulWidget {
  final String current;
  const _IconPickerSheet({required this.current});

  @override
  State<_IconPickerSheet> createState() => _IconPickerSheetState();
}

class _IconPickerSheetState extends State<_IconPickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String _selected = '';

  static const _categories = [
    ('학습', ['📘', '📗', '📕', '📙', '📚', '📖', '🎓', '✏️', '🖊️', '📓']),
    ('과학·기술', ['🧠', '🔬', '🔭', '🧪', '💻', '🤖', '🔐', '🌐', '⚙️', '🛰️']),
    ('목표', ['💡', '⚡', '🎯', '🏆', '🚀', '🔥', '⭐', '💪', '🏅', '✅']),
    ('도구', ['🛠️', '📊', '📋', '🗂️', '📝', '📌', '🗓️', '📁', '🗃️', '📎']),
    ('감성', ['🎨', '🎵', '🌿', '☕', '🌸', '🌍', '🦋', '🎮', '🍀', '🌙']),
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
    _tabs = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  Text(
                    '아이콘 선택',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (_selected.isNotEmpty) ...[
                    Text(_selected, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                  ],
                  GestureDetector(
                    onTap: () => Navigator.pop(context, _selected),
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: AppGradients.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '선택',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Category tabs
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: colors.border,
              indicatorColor: colors.accent,
              labelColor: colors.accent,
              unselectedLabelColor: colors.textSecondary,
              labelStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              tabs: _categories
                  .map((c) => Tab(text: c.$1))
                  .toList(),
            ),
            // Emoji grid
            SizedBox(
              height: 200,
              child: TabBarView(
                controller: _tabs,
                children: _categories.map((cat) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: cat.$2.map((emoji) {
                        final isSelected = emoji == _selected;
                        return MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => setState(() => _selected = emoji),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 130),
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colors.accent.withValues(alpha: 0.14)
                                    : colors.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? colors.accent.withValues(alpha: 0.7)
                                      : colors.border.withValues(alpha: 0.5),
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  emoji,
                                  style: TextStyle(
                                    fontSize: isSelected ? 22 : 19,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _FileTile extends StatefulWidget {
  final FileModel file;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _FileTile({
    required this.file,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<_FileTile> createState() => _FileTileState();
}

class _FileTileState extends State<_FileTile>
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
    final tags = widget.file.tags
        .split(',')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();
    final updatedAt = widget.file.update_at ?? widget.file.create_at;
    final hasContent = widget.file.content.trim().isNotEmpty;

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
            scale: 1.0 - 0.015 * _pressCtrl.value,
            child: child,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _hovered
                    ? colors.accent.withValues(alpha: 0.35)
                    : colors.border,
                width: _hovered ? 1.5 : 1,
              ),
              boxShadow: _hovered
                  ? AppShadows.cardHover(colors.accent)
                  : AppShadows.elevation1,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.md),
              child: Row(
                children: [
                  // File type icon
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _hovered
                          ? colors.accent.withValues(alpha: 0.12)
                          : colors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _hovered
                            ? colors.accent.withValues(alpha: 0.25)
                            : colors.border,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        hasContent ? LucideIcons.fileText : LucideIcons.file,
                        size: 16,
                        color: _hovered ? colors.accent : colors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.file.title,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _relativeDate(updatedAt),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: colors.textSecondary.withValues(alpha: 0.6),
                          ),
                        ),
                        if (tags.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 4,
                            children: tags
                                .take(3)
                                .map(
                                  (t) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.border.withValues(
                                        alpha: 0.5,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      t,
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: colors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Chevron + menu
                  AnimatedOpacity(
                    opacity: _hovered ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      LucideIcons.chevronRight,
                      size: 14,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'rename') widget.onRename();
                      if (value == 'delete') widget.onDelete();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: 'rename',
                        child: Row(
                          children: [
                            const Icon(LucideIcons.pencil, size: 14),
                            const SizedBox(width: 8),
                            const Text('이름 변경'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.trash2,
                              size: 14,
                              color: AppTheme.red,
                            ),
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
                              ? colors.border.withValues(alpha: 0.35)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          LucideIcons.moreHorizontal,
                          size: 14,
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
    return DateFormat('M월 d일 HH:mm', 'ko_KR').format(dt);
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _TagChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(width: AppSpace.xs),
          GestureDetector(
            onTap: onRemove,
            child: Icon(LucideIcons.x, size: 14, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderButton({required this.icon, required this.onTap});

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

class _TextEditSheet extends StatelessWidget {
  final String title;
  final TextEditingController controller;
  final String actionLabel;

  const _TextEditSheet({
    required this.title,
    required this.controller,
    required this.actionLabel,
  });

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
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpace.lg),
            AppInput(
              controller: controller,
              hintText: title,
              autofocus: true,
              onSubmitted: (value) => Navigator.pop(context, value.trim()),
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
                    label: actionLabel,
                    onPressed: () =>
                        Navigator.pop(context, controller.text.trim()),
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

class _ProjectFileSkeleton extends StatelessWidget {
  const _ProjectFileSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return AppShimmer(
      child: ListView.builder(
        itemCount: 5,
        padding: const EdgeInsets.all(AppSpace.lg),
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.only(bottom: index == 4 ? 0 : AppSpace.sm),
          child: Container(
            height: 68,
            padding: const EdgeInsets.all(AppSpace.md),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.border.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 140 + (index % 3) * 30.0,
                      height: 13,
                      decoration: BoxDecoration(
                        color: colors.border.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 80,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colors.border.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(4),
                      ),
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
