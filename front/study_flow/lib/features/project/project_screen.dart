import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:study_flow/features/file/file_model.dart';
import 'package:study_flow/features/project/project_model.dart';
import 'package:uuid/uuid.dart';

import '../../core/local_db_helper.dart';
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

  // 로컬 태그 리스트
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    _projectNameController.text = widget.project.name;
    _parseTags();
    _loadFiles();
  }

  void _parseTags() {
    if (widget.project.tags.isEmpty) {
      _tags = [];
    } else {
      _tags = widget.project.tags
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
  }

  void _loadFiles() {
    setState(() {
      _filesFuture = LocalDatabase.instance.selectProjectFiles(
        widget.project.id,
      );
    });
  }

  // --- [핵심] 태그 추가 로직 ---
  Future<void> _addTag(String newTag) async {
    if (newTag.trim().isEmpty) return;
    if (_tags.contains(newTag.trim())) return;

    setState(() {
      _tags.add(newTag.trim());
    });

    // DB 및 홈 화면 Provider 동기화
    await ref
        .read(projectProvider.notifier)
        .updateProjectTags(widget.project.id, _tags.join(','));
  }

  // --- [핵심] 태그 삭제 로직 ---
  Future<void> _removeTag(String tag) async {
    setState(() {
      _tags.remove(tag);
    });

    // DB 및 홈 화면 Provider 동기화
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
    final db = await LocalDatabase.instance.database;
    await db.delete('files', where: 'id = ?', whereArgs: [fileId]);
    _loadFiles();
  }

  Future<void> _renameFile(FileModel file) async {
    final controller = TextEditingController(text: file.title);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgSecondary,
        title: Text("이름 변경", style: AppTheme.titleSmall),
        content: TextField(
          controller: controller,
          style: AppTheme.bodyText,
          decoration: const InputDecoration(hintText: "새 이름 입력"),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "취소",
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await LocalDatabase.instance.updateFile(
                file.id,
                title: controller.text,
                tags: file.tags,
                prompt: file.prompt,
                content: file.content,
                icon: file.icon,
              );
              Navigator.pop(context);
              _loadFiles();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.aiAccentColor,
              foregroundColor: Colors.black,
            ),
            child: const Text("확인"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppTheme.bgPrimary,
        elevation: 0,
        leading: BackButton(
          color: AppTheme.textSecondary,
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.folder_open,
              size: 20,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _projectNameController,
                style: AppTheme.titleSmall.copyWith(fontSize: 16),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: _updateName,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: AppTheme.textSecondary),
            onPressed: () {},
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Tag Management (바로 반영되도록 수정됨)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ..._tags.map((tag) => _buildTagChip(tag)),
                _buildAddTagButton(),
              ],
            ),
          ),

          const Divider(height: 1, color: AppTheme.borderColor),

          // 2. File List
          Expanded(
            child: FutureBuilder<List<FileModel>>(
              future: _filesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.aiAccentColor,
                    ),
                  );
                }
                final files = snapshot.data ?? [];
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: files.length + 1,
                  itemBuilder: (context, index) {
                    if (index == files.length) return _buildAddPageButton();
                    return _buildFileItem(files[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Widgets ---

  Widget _buildTagChip(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF4A4A5A),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tag,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => _removeTag(tag),
            child: const Icon(Icons.close, size: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildAddTagButton() {
    return InkWell(
      onTap: _showAddTagDialog,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF4A4A5A).withOpacity(0.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "새 태그 추가",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            SizedBox(width: 4),
            Icon(Icons.add, size: 16, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildFileItem(FileModel file) {
    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => FileScreen(fileId: file.id)),
        );
        _loadFiles();
      },
      hoverColor: AppTheme.bgHover,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.dividerColor)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Center(
                child: file.icon != null && file.icon!.isNotEmpty
                    ? Text(file.icon!, style: const TextStyle(fontSize: 20))
                    : const Icon(
                        Icons.description_outlined,
                        size: 20,
                        color: AppTheme.textSecondary,
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.title.isEmpty ? "제목 없음" : file.title,
                    style: AppTheme.bodyText.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        DateFormat('MM월 dd일').format(file.create_at),
                        style: AppTheme.caption.copyWith(fontSize: 12),
                      ),
                      if (file.tags.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 1,
                          height: 10,
                          color: AppTheme.borderColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            file.tags,
                            style: AppTheme.caption.copyWith(
                              fontSize: 12,
                              color: AppTheme.textHint,
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
            IconButton(
              icon: const Icon(
                Icons.more_horiz,
                size: 20,
                color: AppTheme.textSecondary,
              ),
              onPressed: () => _showFileOptionMenu(file),
              splashRadius: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddPageButton() {
    return InkWell(
      onTap: _createNewFile,
      hoverColor: AppTheme.bgHover,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            const Icon(Icons.add, size: 20, color: AppTheme.textSecondary),
            const SizedBox(width: 16),
            Text(
              "새 페이지 추가",
              style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTagDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgSecondary,
        title: Text("태그 추가", style: AppTheme.titleSmall),
        content: TextField(
          controller: controller,
          style: AppTheme.bodyText,
          decoration: const InputDecoration(hintText: "태그 입력"),
          autofocus: true,
          onSubmitted: (val) {
            _addTag(val);
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "취소",
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _addTag(controller.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.aiAccentColor,
              foregroundColor: Colors.black,
            ),
            child: const Text("추가"),
          ),
        ],
      ),
    );
  }

  void _showFileOptionMenu(FileModel file) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgSecondary,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.edit_outlined,
                  color: AppTheme.textPrimary,
                ),
                title: const Text(
                  "이름 변경",
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _renameFile(file);
                },
              ),
              const Divider(color: AppTheme.dividerColor),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  "삭제",
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteFile(file.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createNewFile() async {
    final newFileId = const Uuid().v4();
    final newFile = FileModel(
      id: newFileId,
      project_id: widget.project.id,
      title: "제목 없음",
      content: "",
      tags: "",
      create_at: DateTime.now(),
      update_at: null,
      icon: '',
      prompt: '',
      summary: '',
    );
    await LocalDatabase.instance.insertFile(newFile);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FileScreen(fileId: newFileId)),
    );
    _loadFiles();
  }
}
