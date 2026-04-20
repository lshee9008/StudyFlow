import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _nameCtrl.text = widget.project.name;
    _parseTags();
    _loadFiles();
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _animCtrl.dispose();
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
      builder: (_) => _SFDialog(
        title: '이름 변경',
        icon: Icons.edit_outlined,
        child: SFTextField(hint: '새 이름 입력', controller: ctrl, autofocus: true),
        actions: [
          SFButton(
            label: '취소',
            outlined: true,
            onPressed: () => Navigator.pop(context),
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
              if (context.mounted) Navigator.pop(context);
              _loadFiles();
            },
          ),
        ],
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
        pageBuilder: (_, a, __) => FileScreen(
          fileId: newId,
          projectId: widget.project.id,
        ),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: a,
          child: child,
        ),
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
        backgroundColor: AppTheme.bgPrimary,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProjectHeader(
              nameCtrl: _nameCtrl,
              tags: _tags,
              onBack: () {
                widget.project.update_at = DateTime.now();
                widget.project.name = _nameCtrl.text;
                widget.project.tags = _tags.join(',');
                ref.read(projectProvider.notifier).updateProjectAll(widget.project);
                Navigator.pop(context);
              },
              onUpdateName: _updateName,
              onRemoveTag: _removeTag,
              onAddTag: _showAddTagDialog,
            ),

            // 구분선
            Container(height: 1, color: AppTheme.borderSubtle),

            // 파일 목록
            Expanded(
              child: FutureBuilder<List<FileModel>>(
                future: _filesFuture,
                builder: (_, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppTheme.accent,
                          strokeWidth: 2,
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
                    animCtrl: _animCtrl,
                    project: widget.project,
                    onOpenFile: (file) async {
                      await Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, a, __) => FileScreen(
                            fileId: file.id,
                            projectId: widget.project.id,
                          ),
                          transitionsBuilder: (_, a, __, child) =>
                              FadeTransition(opacity: a, child: child),
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
        child: SFTextField(
          hint: '태그 이름',
          controller: ctrl,
          autofocus: true,
          onSubmitted: (v) {
            _addTag(v);
            Navigator.pop(context);
          },
        ),
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
      ),
    );
  }
}

// ─── 프로젝트 헤더 ──────────────────────────────────────
class _ProjectHeader extends StatelessWidget {
  final TextEditingController nameCtrl;
  final List<String> tags;
  final VoidCallback onBack;
  final void Function(String) onUpdateName;
  final void Function(String) onRemoveTag;
  final VoidCallback onAddTag;

  const _ProjectHeader({
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
    final hPad = w < 600 ? 12.0 : 16.0;
    return Container(
      padding: EdgeInsets.fromLTRB(hPad, 16, hPad + 4, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 앱바 행
          Row(
            children: [
              _BackBtn(onTap: onBack),
              const SizedBox(width: 8),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.bgTertiary,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: const Icon(
                  Icons.folder_rounded,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: nameCtrl,
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: '프로젝트 이름',
                    hintStyle: GoogleFonts.inter(
                      color: AppTheme.textMuted,
                      fontSize: 15,
                    ),
                  ),
                  onChanged: onUpdateName,
                ),
              ),
            ],
          ),

          // 태그 행
          if (tags.isNotEmpty || true)
            Padding(
              padding: const EdgeInsets.only(top: 10, left: 2),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...tags.map(
                    (t) => _TagChip(tag: t, onRemove: () => onRemoveTag(t)),
                  ),
                  _AddTagBtn(onAdd: onAddTag),
                ],
              ),
            ),
        ],
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
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: _hover ? AppTheme.bgTertiary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: _hover
              ? Border.all(color: AppTheme.borderSubtle)
              : null,
        ),
        child: Icon(
          Icons.arrow_back_rounded,
          size: 16,
          color: _hover ? AppTheme.textPrimary : AppTheme.textSecondary,
        ),
      ),
    ),
  );
}

// ─── 파일 목록 ───────────────────────────────────────────
class _FileList extends StatelessWidget {
  final List<FileModel> files;
  final AnimationController animCtrl;
  final ProjectModel project;
  final void Function(FileModel) onOpenFile;
  final void Function(FileModel) onRename;
  final void Function(String) onDelete;
  final VoidCallback onCreate;

  const _FileList({
    required this.files,
    required this.animCtrl,
    required this.project,
    required this.onOpenFile,
    required this.onRename,
    required this.onDelete,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: files.length + 1,
      itemBuilder: (_, i) {
        if (i == files.length) {
          return _AddFileBtn(onCreate: onCreate);
        }
        return _FileRow(
          file: files[i],
          index: i,
          onTap: () => onOpenFile(files[i]),
          onRename: () => onRename(files[i]),
          onDelete: () => onDelete(files[i].id),
        );
      },
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
    backgroundColor: AppTheme.bgSecondary,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppTheme.borderDefault),
    ),
    elevation: 24,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.bgTertiary,
                    borderRadius: BorderRadius.circular(7),
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
                .map((a) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: a,
                    ))
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
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: AppTheme.bgTertiary,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: AppTheme.borderDefault),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tag,
          style: GoogleFonts.inter(
            color: AppTheme.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 5),
        GestureDetector(
          onTap: onRemove,
          child: const Icon(
            Icons.close_rounded,
            size: 11,
            color: AppTheme.textSecondary,
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
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
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
              style: GoogleFonts.inter(
                color: _hover ? AppTheme.textSecondary : AppTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
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
  final int index;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _FileRow({
    required this.file,
    required this.index,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<_FileRow> createState() => _FileRowState();
}

class _FileRowState extends State<_FileRow>
    with SingleTickerProviderStateMixin {
  bool _hover = false;
  late AnimationController _ac;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 250 + widget.index * 35),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

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
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              decoration: BoxDecoration(
                color: _hover ? AppTheme.bgSecondary : Colors.transparent,
                border: const Border(
                  bottom: BorderSide(color: AppTheme.borderSubtle, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  // 파일 아이콘
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _hover
                          ? AppTheme.accentDim
                          : AppTheme.bgTertiary,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _hover
                            ? AppTheme.accent.withOpacity(0.2)
                            : AppTheme.borderSubtle,
                      ),
                    ),
                    child: Center(
                      child: widget.file.icon?.isNotEmpty == true
                          ? Text(
                              widget.file.icon!,
                              style: const TextStyle(fontSize: 14),
                            )
                          : Icon(
                              Icons.article_outlined,
                              size: 15,
                              color: _hover
                                  ? AppTheme.accent
                                  : AppTheme.textSecondary,
                            ),
                    ),
                  ),
                  const SizedBox(width: 13),

                  // 제목 + 메타
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.file.title.isEmpty
                              ? '제목 없음'
                              : widget.file.title,
                          style: GoogleFonts.inter(
                            color: widget.file.title.isEmpty
                                ? AppTheme.textTertiary
                                : AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              _formatDate(widget.file.create_at),
                              style: AppTheme.caption,
                            ),
                            if (widget.file.tags.isNotEmpty) ...[
                              Text(' · ', style: AppTheme.caption),
                              Expanded(
                                child: Text(
                                  widget.file.tags,
                                  style: AppTheme.caption.copyWith(
                                    color: AppTheme.textTertiary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 요약 있으면 배지
                  if (widget.file.summary?.isNotEmpty == true)
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accentDim,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppTheme.accent.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: 9,
                            color: AppTheme.accent,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'AI',
                            style: AppTheme.caption.copyWith(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 더보기 메뉴
                  AnimatedOpacity(
                    opacity: _hover ? 1 : 0,
                    duration: const Duration(milliseconds: 130),
                    child: PopupMenuButton<String>(
                      color: AppTheme.bgSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: AppTheme.borderDefault),
                      ),
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.more_horiz_rounded,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                      elevation: 12,
                      onSelected: (v) {
                        if (v == 'rename') widget.onRename();
                        else if (v == 'delete') widget.onDelete();
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'rename',
                          height: 36,
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 13, color: AppTheme.textSecondary),
                              const SizedBox(width: 8),
                              Text(
                                '이름 변경',
                                style: GoogleFonts.inter(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(height: 1),
                        PopupMenuItem(
                          value: 'delete',
                          height: 36,
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 13, color: AppTheme.red),
                              const SizedBox(width: 8),
                              Text(
                                '삭제',
                                style: GoogleFonts.inter(
                                  color: AppTheme.red,
                                  fontSize: 13,
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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.bgSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: const Icon(
            Icons.note_add_outlined,
            size: 32,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 16),
        Text('아직 노트가 없어요', style: AppTheme.headingSmall),
        const SizedBox(height: 6),
        Text('첫 번째 노트를 작성해보세요.', style: AppTheme.bodySmall),
        const SizedBox(height: 24),
        SFButton(
          label: '노트 만들기',
          icon: Icons.add_rounded,
          onPressed: onCreate,
        ),
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
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        color: _hover ? AppTheme.bgSecondary : Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _hover ? AppTheme.accentDim : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _hover
                      ? AppTheme.accent.withOpacity(0.2)
                      : AppTheme.borderSubtle,
                ),
              ),
              child: Icon(
                Icons.add_rounded,
                size: 16,
                color: _hover ? AppTheme.accent : AppTheme.textMuted,
              ),
            ),
            const SizedBox(width: 13),
            Text(
              '새 페이지',
              style: GoogleFonts.inter(
                color: _hover ? AppTheme.accent : AppTheme.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
