import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:study_flow/core/db_helper/files_db_helper.dart';
import 'package:study_flow/features/file/file_model.dart';
import 'package:study_flow/features/project/project_model.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme.dart';
import '../file/file_screen.dart';
import 'project_provider.dart';

class ProjectScreen extends ConsumerStatefulWidget {
  final ProjectModel project;
  const ProjectScreen({super.key, required this.project});

  @override
  ConsumerState<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends ConsumerState<ProjectScreen> {
  final _projectNameController = TextEditingController();
  late Future<List<FileModel>> _filesFuture;
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    _projectNameController.text = widget.project.name;
    _parseTags();
    _loadFiles();
  }

  @override
  void dispose() {
    _projectNameController.dispose();
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
      _filesFuture = FilesDBHelper.selectProjectFiles(widget.project.id);
    });
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
    await FilesDBHelper.deleteFile(fileId);
    _loadFiles();
  }

  Future<void> _renameFile(FileModel file) async {
    final ctrl = TextEditingController(text: file.title);
    await showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppTheme.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('이름 변경', style: AppTheme.headingSmall),
              const SizedBox(height: 16),
              SFTextField(hint: '새 이름 입력', controller: ctrl),
              const SizedBox(height: 20),
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
                    label: '확인',
                    onPressed: () async {
                      await FilesDBHelper.updateFile(
                        file.id,
                        title: ctrl.text,
                        tags: file.tags,
                        prompt: file.prompt,
                        content: file.content,
                        icon: file.icon,
                      );
                      if (context.mounted) Navigator.pop(context);
                      _loadFiles();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createNewFile() async {
    final newId = const Uuid().v4();
    final newFile = FileModel(
      id: newId,
      project_id: widget.project.id,
      title: '제목 없음',
      content: '',
      tags: '',
      create_at: DateTime.now(),
      update_at: null,
      icon: '',
      prompt: '',
      summary: '',
    );
    await FilesDBHelper.insertFile(newFile);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FileScreen(fileId: newId)),
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
          widget.project.name = _projectNameController.text;
          widget.project.tags = _tags.join(',');
          ref.read(projectProvider.notifier).updateProjectAll(widget.project);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.bgPrimary,
        appBar: AppBar(
          backgroundColor: AppTheme.bgPrimary,
          elevation: 0,
          leading: BackButton(
            color: AppTheme.textSecondary,
            onPressed: () {
              widget.project.update_at = DateTime.now();
              widget.project.name = _projectNameController.text;
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
                size: 18,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _projectNameController,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ..._tags.map(
                    (tag) =>
                        _TagChip(tag: tag, onRemove: () => _removeTag(tag)),
                  ),
                  _AddTagButton(onAdd: _showAddTagDialog),
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
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: files.length + 1,
                    itemBuilder: (_, i) {
                      if (i == files.length)
                        return _AddFileButton(onCreate: _createNewFile);
                      return _FileItem(
                        file: files[i],
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FileScreen(fileId: files[i].id),
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
      builder: (_) => Dialog(
        backgroundColor: AppTheme.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('태그 추가', style: AppTheme.headingSmall),
              const SizedBox(height: 16),
              SFTextField(
                hint: '태그 이름',
                controller: ctrl,
                onSubmitted: (val) {
                  _addTag(val);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 20),
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
                    label: '추가',
                    onPressed: () {
                      _addTag(ctrl.text);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 태그 칩 ───────────────────────────────────────────────
class _TagChip extends StatelessWidget {
  final String tag;
  final VoidCallback onRemove;
  const _TagChip({required this.tag, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
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
              size: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTagButton extends StatelessWidget {
  final VoidCallback onAdd;
  const _AddTagButton({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AppTheme.borderSubtle,
            style: BorderStyle.solid,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 14, color: AppTheme.textMuted),
            SizedBox(width: 4),
            Text(
              '태그 추가',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 파일 아이템 ───────────────────────────────────────────
class _FileItem extends StatefulWidget {
  final FileModel file;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  const _FileItem({
    required this.file,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });
  @override
  State<_FileItem> createState() => _FileItemState();
}

class _FileItemState extends State<_FileItem> {
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          decoration: BoxDecoration(
            color: _hover ? AppTheme.bgTertiary : Colors.transparent,
            border: const Border(
              bottom: BorderSide(color: AppTheme.borderSubtle),
            ),
          ),
          child: Row(
            children: [
              // 아이콘
              SizedBox(
                width: 28,
                child: Center(
                  child:
                      widget.file.icon != null && widget.file.icon!.isNotEmpty
                      ? Text(
                          widget.file.icon!,
                          style: const TextStyle(fontSize: 18),
                        )
                      : const Icon(
                          Icons.description_outlined,
                          size: 18,
                          color: AppTheme.textSecondary,
                        ),
                ),
              ),
              const SizedBox(width: 14),

              // 제목 + 메타
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.file.title.isEmpty ? '제목 없음' : widget.file.title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          DateFormat('MM월 dd일').format(widget.file.create_at),
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        if (widget.file.tags.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 1,
                            height: 10,
                            color: AppTheme.borderSubtle,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.file.tags,
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
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

              // 더보기 메뉴
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
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                  onSelected: (val) {
                    if (val == 'rename')
                      widget.onRename();
                    else if (val == 'delete')
                      widget.onDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: const [
                          Icon(
                            Icons.edit_outlined,
                            size: 15,
                            color: AppTheme.textSecondary,
                          ),
                          SizedBox(width: 8),
                          Text(
                            '이름 변경',
                            style: TextStyle(
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
                      child: Row(
                        children: const [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 15,
                            color: AppTheme.red,
                          ),
                          SizedBox(width: 8),
                          Text(
                            '삭제',
                            style: TextStyle(color: AppTheme.red, fontSize: 13),
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
    );
  }
}

// ── 빈 상태 ───────────────────────────────────────────────
class _EmptyFiles extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyFiles({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.note_add_outlined,
            size: 48,
            color: AppTheme.textMuted,
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
}

class _AddFileButton extends StatefulWidget {
  final VoidCallback onCreate;
  const _AddFileButton({required this.onCreate});
  @override
  State<_AddFileButton> createState() => _AddFileButtonState();
}

class _AddFileButtonState extends State<_AddFileButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onCreate,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          color: _hover ? AppTheme.bgTertiary : Colors.transparent,
          child: Row(
            children: [
              const SizedBox(
                width: 28,
                child: Center(
                  child: Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text('새 페이지 추가', style: AppTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
