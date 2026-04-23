import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:study_flow/core/db_helper/files_db_helper.dart';
import 'package:study_flow/features/file/file_model.dart';
import 'package:study_flow/features/project/project_model.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme.dart';
import '../../core/provider_config.dart';
import '../file/file_screen.dart';
import 'project_provider.dart';

class ProjectScreen extends ConsumerStatefulWidget {
  final ProjectModel project;
  const ProjectScreen({super.key, required this.project});

  @override
  ConsumerState<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends ConsumerState<ProjectScreen>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  late Future<List<FileModel>> _filesFuture;
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.project.name;
    _parseTags();
    _loadFiles();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _parseTags() {
    _tags = widget.project.tags.isEmpty
        ? []
        : widget.project.tags
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
  }

  void _loadFiles() {
    setState(() {
      _filesFuture = _fetchFiles();
    });
  }

  Future<List<FileModel>> _fetchFiles() async {
    if (!kIsWeb) {
      return FilesDBHelper.selectProjectFiles(widget.project.id);
    }
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/files/project/${widget.project.id}'),
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((j) => FileModel.fromJson(j)).toList();
      }
    } catch (e) {
      debugPrint('fetchFiles error: $e');
    }
    return [];
  }

  Future<void> _addTag(String tag) async {
    if (tag.trim().isEmpty || _tags.contains(tag.trim())) return;
    setState(() => _tags.add(tag.trim()));
    await ref
        .read(projectProvider.notifier)
        .updateProjectTags(widget.project.id, _tags.join(','));
  }

  Future<void> _removeTag(String tag) async {
    setState(() => _tags.remove(tag));
    await ref
        .read(projectProvider.notifier)
        .updateProjectTags(widget.project.id, _tags.join(','));
  }

  Future<void> _updateName(String value) async {
    await ref
        .read(projectProvider.notifier)
        .updateProjectName(widget.project.id, value);
  }

  Future<void> _deleteFile(String fileId) async {
    if (!kIsWeb) {
      await FilesDBHelper.deleteFile(fileId);
    } else {
      try {
        await http.delete(Uri.parse('$baseUrl/api/files/$fileId'));
      } catch (e) {
        debugPrint('deleteFile error: $e');
      }
    }
    _loadFiles();
  }

  Future<void> _renameFile(FileModel file) async {
    final ctrl = TextEditingController(text: file.title);
    await showDialog(
      context: context,
      builder: (dialogContext) => _SFDialog(
        title: '이름 변경',
        icon: Icons.edit_outlined,
        actions: [
          SFButton(
            label: '취소',
            outlined: true,
            onPressed: () => Navigator.pop(dialogContext),
          ),
          SFButton(
            label: '확인',
            onPressed: () async {
              if (!kIsWeb) {
                await FilesDBHelper.updateFile(
                  file.id,
                  title: ctrl.text,
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
                    body: jsonEncode({'title': ctrl.text}),
                  );
                } catch (e) {
                  debugPrint('renameFile error: $e');
                }
              }
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
              _loadFiles();
            },
          ),
        ],
        child: SFTextField(hint: '새 이름 입력', controller: ctrl, autofocus: true),
      ),
    );
  }

  Future<void> _createNewFile() async {
    final newId = const Uuid().v4();
    final now = DateTime.now();
    final newFile = FileModel(
      id: newId,
      project_id: widget.project.id,
      title: '제목 없음',
      content: '',
      tags: '',
      create_at: now,
      update_at: null,
      icon: '',
      prompt: '',
      summary: '',
    );

    if (!kIsWeb) {
      await FilesDBHelper.insertFile(newFile);
    }

    try {
      await http.post(
        Uri.parse('$baseUrl/api/files/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': newId,
          'project_id': widget.project.id,
          'title': '제목 없음',
          'content': '',
          'tags': '',
          'icon': '',
          'prompt': '',
          'summary': '',
          'create_at': now.toIso8601String(),
          'update_at': null,
        }),
      );
    } catch (e) {
      debugPrint('createNewFile server sync error: $e');
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (routeContext, animation, secondaryAnimation) =>
            FileScreen(fileId: newId, projectId: widget.project.id),
        transitionsBuilder:
            (routeContext, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 220),
      ),
    );
    _loadFiles();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          widget.project.update_at = DateTime.now();
          widget.project.name = _nameCtrl.text;
          widget.project.tags = _tags.join(',');
          ref.read(projectProvider.notifier).updateProjectAll(widget.project);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.bgDeep,
        floatingActionButton: MediaQuery.of(context).size.width < 600
            ? FloatingActionButton(
                onPressed: _createNewFile,
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.add_rounded, size: 26),
              )
            : null,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProjectHeader(
              project: widget.project,
              nameCtrl: _nameCtrl,
              tags: _tags,
              onBack: () {
                widget.project.update_at = DateTime.now();
                widget.project.name = _nameCtrl.text;
                widget.project.tags = _tags.join(',');
                ref
                    .read(projectProvider.notifier)
                    .updateProjectAll(widget.project);
                Navigator.pop(context);
              },
              onUpdateName: _updateName,
              onRemoveTag: _removeTag,
              onAddTag: _showAddTagDialog,
            ),

            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppTheme.borderSubtle,
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            Expanded(
              child: FutureBuilder<List<FileModel>>(
                future: _filesFuture,
                builder: (_, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: AppTheme.accent,
                          strokeWidth: 1.5,
                        ),
                      ),
                    );
                  }
                  final files = snap.data ?? [];
                  if (files.isEmpty) {
                    return _EmptyFiles(onCreate: _createNewFile);
                  }
                  return _FileList(
                    files: files,
                    onOpenFile: (file) async {
                      await Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (routeContext, animation, secondaryAnimation) =>
                                  FileScreen(
                                    fileId: file.id,
                                    projectId: widget.project.id,
                                  ),
                          transitionsBuilder:
                              (
                                routeContext,
                                animation,
                                secondaryAnimation,
                                child,
                              ) => FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                          transitionDuration: const Duration(milliseconds: 220),
                        ),
                      );
                      _loadFiles();
                    },
                    onRename: _renameFile,
                    onDelete: _deleteFile,
                    onCreate: _createNewFile,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTagDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => _SFDialog(
        title: '태그 추가',
        icon: Icons.label_outline_rounded,
        actions: [
          SFButton(
            label: '취소',
            outlined: true,
            onPressed: () => Navigator.pop(context),
          ),
          SFButton(
            label: '추가',
            icon: Icons.add_rounded,
            onPressed: () {
              _addTag(ctrl.text);
              Navigator.pop(context);
            },
          ),
        ],
        child: SFTextField(
          hint: '태그 이름',
          controller: ctrl,
          autofocus: true,
          onSubmitted: (v) {
            _addTag(v);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}

// ─── 프로젝트 헤더 ─────────────────────────────────────────
class _ProjectHeader extends StatelessWidget {
  final ProjectModel project;
  final TextEditingController nameCtrl;
  final List<String> tags;
  final VoidCallback onBack;
  final void Function(String) onUpdateName;
  final void Function(String) onRemoveTag;
  final VoidCallback onAddTag;

  const _ProjectHeader({
    required this.project,
    required this.nameCtrl,
    required this.tags,
    required this.onBack,
    required this.onUpdateName,
    required this.onRemoveTag,
    required this.onAddTag,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final hPad = w < 600 ? 16.0 : 24.0;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(hPad, 18, hPad, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(w < 600 ? 18 : 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppTheme.borderSubtle),
                gradient: LinearGradient(
                  colors: [
                    AppTheme.bgSecondary.withValues(alpha: 0.96),
                    const Color(0xFF10172D).withValues(alpha: 0.94),
                    AppTheme.bgPrimary.withValues(alpha: 0.92),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.24),
                    blurRadius: 34,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _BackBtn(onTap: onBack),
                      const SizedBox(width: 12),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [AppTheme.accent, AppTheme.blue],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(
                          Icons.folder_copy_rounded,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PROJECT SPACE',
                              style: AppTheme.labelSmall.copyWith(
                                color: AppTheme.textMuted,
                                letterSpacing: 1.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: nameCtrl,
                              style: AppTheme.displayMedium.copyWith(
                                fontSize: w < 600 ? 26 : 34,
                                height: 1.05,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                hintText: '프로젝트 이름',
                                hintStyle: AppTheme.displayMedium.copyWith(
                                  color: AppTheme.textMuted,
                                  fontSize: w < 600 ? 26 : 34,
                                ),
                              ),
                              onChanged: onUpdateName,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _MetaPill(
                        icon: Icons.schedule_rounded,
                        label:
                            '생성 ${DateFormat('M.d').format(project.create_at)}',
                      ),
                      _MetaPill(
                        icon: Icons.update_rounded,
                        label:
                            '최근 수정 ${DateFormat('M.d').format(project.update_at)}',
                      ),
                      _MetaPill(
                        icon: Icons.label_rounded,
                        label: tags.isEmpty ? '태그 없음' : '${tags.length} tags',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final tag in tags)
                        _TagChip(tag: tag, onRemove: () => onRemoveTag(tag)),
                      _AddTagBtn(onAdd: onAddTag),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _BackBtn({required this.onTap});
  @override
  State<_BackBtn> createState() => _BackBtnState();
}

class _BackBtnState extends State<_BackBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _hover
              ? AppTheme.bgPrimary.withValues(alpha: 0.8)
              : AppTheme.bgPrimary.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hover ? AppTheme.borderStrong : AppTheme.borderSubtle,
          ),
        ),
        child: Icon(
          Icons.arrow_back_rounded,
          size: 18,
          color: _hover ? AppTheme.textPrimary : AppTheme.textSecondary,
        ),
      ),
    ),
  );
}

// ─── 파일 목록 ─────────────────────────────────────────────
class _FileList extends StatelessWidget {
  final List<FileModel> files;
  final void Function(FileModel) onOpenFile;
  final void Function(FileModel) onRename;
  final void Function(String) onDelete;
  final VoidCallback onCreate;

  const _FileList({
    required this.files,
    required this.onOpenFile,
    required this.onRename,
    required this.onDelete,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final aiCount = files
        .where((file) => file.summary?.isNotEmpty == true)
        .length;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        MediaQuery.of(context).size.width < 600 ? 16 : 24,
        8,
        MediaQuery.of(context).size.width < 600 ? 16 : 24,
        MediaQuery.of(context).size.width < 600 ? 100 : 32,
      ),
      children: [
        _FilesOverviewCard(
          fileCount: files.length,
          aiCount: aiCount,
          onCreate: onCreate,
        ),
        const SizedBox(height: 18),
        Text(
          'NOTES',
          style: AppTheme.labelSmall.copyWith(
            color: AppTheme.textMuted,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        ...[
          for (final file in files) ...[
            _FileRow(
              file: file,
              onTap: () => onOpenFile(file),
              onRename: () => onRename(file),
              onDelete: () => onDelete(file.id),
            ),
            const SizedBox(height: 10),
          ],
        ],
        _AddFileBtn(onCreate: onCreate),
      ],
    );
  }
}

// ─── 공통 다이얼로그 ──────────────────────────────────────
class _SFDialog extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget child;
  final List<Widget> actions;

  const _SFDialog({
    required this.title,
    this.icon,
    required this.child,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    child: Container(
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderDefault),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 36,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.bgTertiary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Icon(icon, size: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(width: 10),
              ],
              Text(title, style: AppTheme.headingSmall),
            ],
          ),
          const SizedBox(height: 16),
          child,
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: actions
                .map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: a,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    ),
  );
}

// ─── 태그 칩 ─────────────────────────────────────────────
class _TagChip extends StatelessWidget {
  final String tag;
  final VoidCallback onRemove;
  const _TagChip({required this.tag, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: AppTheme.bgPrimary.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppTheme.borderSubtle),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '#$tag',
          style: AppTheme.labelSmall.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onRemove,
          child: const Icon(
            Icons.close_rounded,
            size: 11,
            color: AppTheme.textTertiary,
          ),
        ),
      ],
    ),
  );
}

class _AddTagBtn extends StatefulWidget {
  final VoidCallback onAdd;
  const _AddTagBtn({required this.onAdd});
  @override
  State<_AddTagBtn> createState() => _AddTagBtnState();
}

class _AddTagBtnState extends State<_AddTagBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: GestureDetector(
      onTap: widget.onAdd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.bgPrimary.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: _hover ? AppTheme.borderStrong : AppTheme.borderSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_rounded,
              size: 12,
              color: _hover ? AppTheme.textPrimary : AppTheme.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              '태그 추가',
              style: AppTheme.labelSmall.copyWith(
                color: _hover ? AppTheme.textSecondary : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ─── 파일 행 ─────────────────────────────────────────────
class _FileRow extends StatefulWidget {
  final FileModel file;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _FileRow({
    required this.file,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<_FileRow> createState() => _FileRowState();
}

class _FileRowState extends State<_FileRow> {
  bool _hover = false;

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return '오늘';
    if (diff.inDays == 1) return '어제';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return DateFormat('MM.dd').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _hover
                  ? AppTheme.bgSecondary.withValues(alpha: 0.96)
                  : AppTheme.bgSecondary.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _hover ? AppTheme.borderStrong : AppTheme.borderSubtle,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _hover ? AppTheme.accentDim : AppTheme.bgPrimary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _hover
                          ? AppTheme.accent.withValues(alpha: 0.28)
                          : AppTheme.borderSubtle,
                    ),
                  ),
                  child: Center(
                    child: widget.file.icon?.isNotEmpty == true
                        ? Text(
                            widget.file.icon!,
                            style: const TextStyle(fontSize: 16),
                          )
                        : Icon(
                            Icons.article_outlined,
                            color: _hover
                                ? AppTheme.accent
                                : AppTheme.textTertiary,
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.file.title.isEmpty ? '제목 없음' : widget.file.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.headingSmall.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.file.tags.isEmpty
                            ? _formatDate(widget.file.create_at)
                            : '${_formatDate(widget.file.create_at)} · ${widget.file.tags}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (widget.file.summary?.isNotEmpty == true) ...[
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accentDim,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppTheme.accent.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Text(
                      'AI',
                      style: AppTheme.labelSmall.copyWith(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
                PopupMenuButton<String>(
                  color: AppTheme.bgSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppTheme.borderDefault),
                  ),
                  onSelected: (value) {
                    if (value == 'rename') {
                      widget.onRename();
                    } else if (value == 'delete') {
                      widget.onDelete();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem<String>(
                      value: 'rename',
                      child: Text('이름 변경'),
                    ),
                    PopupMenuItem<String>(value: 'delete', child: Text('삭제')),
                  ],
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.bgPrimary.withValues(alpha: 0.72),
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
          ),
        ),
      ),
    );
  }
}

// ─── 빈 상태 / 추가 버튼 ──────────────────────────────────
class _EmptyFiles extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyFiles({required this.onCreate});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.bgSecondary,
                AppTheme.bgPrimary,
                AppTheme.bgTertiary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppTheme.borderSubtle),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            Icons.note_add_outlined,
            size: 36,
            color: AppTheme.textTertiary,
          ),
        ),
        const SizedBox(height: 20),
        Text('아직 노트가 없어요', style: AppTheme.headingLarge),
        const SizedBox(height: 8),
        Text(
          '새 노트를 만들면 이 프로젝트가 하나의 작업 스튜디오처럼 움직이기 시작합니다.',
          style: AppTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SFButton(label: '노트 만들기', icon: Icons.add_rounded, onPressed: onCreate),
      ],
    ),
  );
}

class _AddFileBtn extends StatefulWidget {
  final VoidCallback onCreate;
  const _AddFileBtn({required this.onCreate});
  @override
  State<_AddFileBtn> createState() => _AddFileBtnState();
}

class _AddFileBtnState extends State<_AddFileBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: GestureDetector(
      onTap: widget.onCreate,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: _hover
              ? AppTheme.bgSecondary.withValues(alpha: 0.92)
              : AppTheme.bgSecondary.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _hover ? AppTheme.borderStrong : AppTheme.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _hover ? AppTheme.accentDim : AppTheme.bgPrimary,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _hover
                      ? AppTheme.accent.withValues(alpha: 0.24)
                      : AppTheme.borderSubtle,
                ),
              ),
              child: Icon(
                Icons.add_rounded,
                color: _hover ? AppTheme.accent : AppTheme.textMuted,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                '새 페이지 만들기',
                style: AppTheme.headingSmall.copyWith(
                  color: _hover ? AppTheme.textPrimary : AppTheme.textSecondary,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              color: _hover ? AppTheme.textPrimary : AppTheme.textMuted,
            ),
          ],
        ),
      ),
    ),
  );
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgPrimary.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: AppTheme.labelSmall),
        ],
      ),
    );
  }
}

class _FilesOverviewCard extends StatelessWidget {
  final int fileCount;
  final int aiCount;
  final VoidCallback onCreate;

  const _FilesOverviewCard({
    required this.fileCount,
    required this.aiCount,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.borderSubtle),
        gradient: LinearGradient(
          colors: [
            AppTheme.accent.withValues(alpha: 0.08),
            AppTheme.blue.withValues(alpha: 0.05),
            AppTheme.bgSecondary.withValues(alpha: 0.92),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Workspace pulse', style: AppTheme.headingSmall),
          const SizedBox(height: 6),
          Text(
            '이 프로젝트의 노트 흐름을 한 번에 훑고 바로 새 페이지를 만들 수 있게 정리했습니다.',
            style: AppTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetaPill(
                icon: Icons.description_outlined,
                label: '$fileCount notes',
              ),
              _MetaPill(
                icon: Icons.auto_awesome_rounded,
                label: '$aiCount AI summaries',
              ),
            ],
          ),
          const SizedBox(height: 16),
          SFButton(
            label: '새 노트 만들기',
            icon: Icons.add_rounded,
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }
}
