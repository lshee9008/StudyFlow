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
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
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

  /// 로컬 DB 우선, 웹이면 서버에서 가져옴
  Future<List<FileModel>> _fetchFiles() async {
    if (!kIsWeb) {
      return FilesDBHelper.selectProjectFiles(widget.project.id);
    }
    // 웹: 서버에서 로드
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/files/project/${widget.project.id}'),
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((j) => FileModel.fromJson(j)).toList();
      }
    } catch (e) {
      print('fetchFiles error: $e');
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
        print('deleteFile error: $e');
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
        child: SFTextField(hint: '새 이름 입력', controller: ctrl),
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
                  print('renameFile error: $e');
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

  /// ✅ 핵심 수정: 파일 생성 시 로컬 + 서버 동기화
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

    // 1. 로컬 저장 (모바일/데스크톱)
    if (!kIsWeb) {
      await FilesDBHelper.insertFile(newFile);
    }

    // 2. ✅ 서버 동기화 (항상 - 웹/모바일 모두)
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
      print('createNewFile server sync error: $e');
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FileScreen(fileId: newId, projectId: widget.project.id),
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
        appBar: AppBar(
          backgroundColor: AppTheme.bgPrimary,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppTheme.borderSubtle),
          ),
          leading: BackButton(
            color: AppTheme.textSecondary,
            onPressed: () {
              widget.project.update_at = DateTime.now();
              widget.project.name = _nameCtrl.text;
              widget.project.tags = _tags.join(',');
              ref
                  .read(projectProvider.notifier)
                  .updateProjectAll(widget.project);
              Navigator.pop(context);
            },
          ),
          title: Row(
            children: [
              const Icon(
                Icons.folder_open_rounded,
                size: 17,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  style: AppTheme.headingSmall,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: _updateName,
                ),
              ),
            ],
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 태그 영역
            if (_tags.isNotEmpty || true)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ..._tags.map(
                      (t) => _TagChip(tag: t, onRemove: () => _removeTag(t)),
                    ),
                    _AddTagBtn(onAdd: _showAddTagDialog),
                  ],
                ),
              ),
            const Divider(height: 1, color: AppTheme.borderSubtle),

            // 파일 목록
            Expanded(
              child: FutureBuilder<List<FileModel>>(
                future: _filesFuture,
                builder: (_, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.accent,
                        strokeWidth: 2,
                      ),
                    );
                  }
                  final files = snap.data ?? [];
                  if (files.isEmpty) {
                    return _EmptyFiles(onCreate: _createNewFile);
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: files.length + 1,
                    itemBuilder: (_, i) {
                      if (i == files.length) {
                        return _AddFileBtn(onCreate: _createNewFile);
                      }
                      return _FileRow(
                        file: files[i],
                        index: i,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FileScreen(
                                fileId: files[i].id,
                                projectId: widget.project.id,
                              ),
                            ),
                          );
                          _loadFiles();
                        },
                        onRename: () => _renameFile(files[i]),
                        onDelete: () => _deleteFile(files[i].id),
                      );
                    },
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
        child: SFTextField(
          hint: '태그 이름',
          controller: ctrl,
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

// ─── 공통 다이얼로그 ───────────────────────────────────────
class _SFDialog extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;
  const _SFDialog({
    required this.title,
    required this.child,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: AppTheme.bgSecondary,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.headingSmall),
          const SizedBox(height: 16),
          child,
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: actions
                .map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(left: 10),
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

// ─── 태그 칩 ────────────────────────────────────────────────
class _TagChip extends StatelessWidget {
  final String tag;
  final VoidCallback onRemove;
  const _TagChip({required this.tag, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onRemove,
          child: const Icon(
            Icons.close_rounded,
            size: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    ),
  );
}

class _AddTagBtn extends StatelessWidget {
  final VoidCallback onAdd;
  const _AddTagBtn({required this.onAdd});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onAdd,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_rounded, size: 13, color: AppTheme.textMuted),
          SizedBox(width: 4),
          Text('태그', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ],
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
      duration: Duration(milliseconds: 300 + widget.index * 40),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
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
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: _hover ? AppTheme.bgTertiary : Colors.transparent,
                border: const Border(
                  bottom: BorderSide(color: AppTheme.borderSubtle, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  // 아이콘
                  SizedBox(
                    width: 28,
                    child: Center(
                      child: widget.file.icon?.isNotEmpty == true
                          ? Text(
                              widget.file.icon!,
                              style: const TextStyle(fontSize: 16),
                            )
                          : Icon(
                              Icons.article_outlined,
                              size: 17,
                              color: _hover
                                  ? AppTheme.accent
                                  : AppTheme.textSecondary,
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // 제목 + 날짜
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.file.title.isEmpty
                              ? '제목 없음'
                              : widget.file.title,
                          style: TextStyle(
                            color: _hover
                                ? AppTheme.textPrimary
                                : AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              DateFormat('MM.dd').format(widget.file.create_at),
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                              ),
                            ),
                            if (widget.file.tags.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              const Text(
                                '·',
                                style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  widget.file.tags,
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 11,
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
                  // 메뉴
                  AnimatedOpacity(
                    opacity: _hover ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: PopupMenuButton<String>(
                      color: AppTheme.bgSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: AppTheme.borderDefault),
                      ),
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.more_horiz_rounded,
                        size: 17,
                        color: AppTheme.textSecondary,
                      ),
                      onSelected: (v) {
                        if (v == 'rename')
                          widget.onRename();
                        else if (v == 'delete')
                          widget.onDelete();
                      },
                      itemBuilder: (_) => [
                        _mi(
                          'rename',
                          Icons.edit_outlined,
                          '이름 변경',
                          AppTheme.textPrimary,
                        ),
                        const PopupMenuDivider(height: 1),
                        _mi(
                          'delete',
                          Icons.delete_outline_rounded,
                          '삭제',
                          AppTheme.red,
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

  PopupMenuItem<String> _mi(String v, IconData icon, String txt, Color c) =>
      PopupMenuItem(
        value: v,
        height: 36,
        child: Row(
          children: [
            Icon(icon, size: 14, color: c),
            const SizedBox(width: 8),
            Text(txt, style: TextStyle(color: c, fontSize: 13)),
          ],
        ),
      );
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
        const Icon(
          Icons.note_add_outlined,
          size: 44,
          color: AppTheme.textMuted,
        ),
        const SizedBox(height: 16),
        Text('아직 노트가 없어요', style: AppTheme.headingSmall),
        const SizedBox(height: 6),
        Text('첫 번째 노트를 작성해보세요.', style: AppTheme.bodySmall),
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
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        color: _hover ? AppTheme.bgTertiary : Colors.transparent,
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Center(
                child: Icon(
                  Icons.add_rounded,
                  size: 17,
                  color: _hover ? AppTheme.accent : AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              '새 페이지',
              style: TextStyle(
                color: _hover ? AppTheme.accent : AppTheme.textSecondary,
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
