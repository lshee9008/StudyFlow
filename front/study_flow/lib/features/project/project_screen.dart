import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:study_flow/features/file/file_model.dart';
import 'package:study_flow/features/project/project_model.dart';
import 'package:uuid/uuid.dart';

import '../../core/local_db_helper.dart';
import '../file/file_screen.dart';
import '../../core/theme.dart'; // 테마 임포트

class ProjectScreen extends StatefulWidget {
  final ProjectModel project;
  const ProjectScreen({super.key, required this.project});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  final _projectNameController = TextEditingController();
  late Future<List<FileModel>> _filesFuture;

  @override
  void initState() {
    super.initState();
    _projectNameController.text = widget.project.name;
    _loadFiles();
  }

  void _loadFiles() {
    setState(() {
      _filesFuture = LocalDatabase.instance.selectProjectFiles(
        widget.project.id,
      );
    });
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
        // 배경색은 테마에서 자동 적용됨
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
            child: Text("취소", style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              await LocalDatabase.instance.updateFile(
                id: file.id,
                title: controller.text,
                tags: file.tags,
                content: file.content,
                icon: file.icon,
              );
              Navigator.pop(context);
              _loadFiles();
            },
            child: const Text("확인"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 배경색은 테마에서 자동 적용됨
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          color: AppTheme.textSecondary,
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Icon(
              Icons.folder_open_outlined,
              size: 22,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _projectNameController,
                style: AppTheme.titleSmall,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  filled: false, // 배경색 제거
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (value) {
                  widget.project.name = value;
                  // TODO: DB에 프로젝트 이름 업데이트 로직 추가 필요
                },
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_horiz, color: AppTheme.textSecondary),
            onPressed: () {},
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.project.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.project.tags.split(',').map((tag) {
                  final t = tag.trim();
                  if (t.isEmpty) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSecondary,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Text(
                      t,
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          const Divider(height: 1),

          Expanded(
            child: FutureBuilder<List<FileModel>>(
              future: _filesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.textSecondary,
                    ),
                  );
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                final files = snapshot.data ?? [];

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: files.length + 1,
                  itemBuilder: (context, index) {
                    if (index == files.length) {
                      return _buildAddPageButton();
                    }
                    final file = files[index];
                    return _buildFileItem(file);
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

  Widget _buildFileItem(FileModel file) {
    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => FileScreen(fileId: file.id)),
        );
        _loadFiles();
      },
      splashColor: AppTheme.bgHover,
      hoverColor: AppTheme.bgHover,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.dividerColor)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Center(
                child: file.icon != null && file.icon!.isNotEmpty
                    ? Text(file.icon!, style: const TextStyle(fontSize: 22))
                    : Icon(
                        Icons.description_outlined,
                        size: 22,
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
                  Text(
                    DateFormat('yyyy. MM. dd HH:mm').format(file.createdAt),
                    style: AppTheme.caption,
                  ),
                ],
              ),
            ),

            SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                icon: Icon(
                  Icons.more_horiz,
                  size: 20,
                  color: AppTheme.textSecondary,
                ),
                padding: EdgeInsets.zero,
                splashRadius: 20,
                onPressed: () => _showFileOptionMenu(file),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddPageButton() {
    return InkWell(
      onTap: _createNewFile,
      splashColor: AppTheme.bgHover,
      hoverColor: AppTheme.bgHover,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 22,
              color: AppTheme.textSecondary,
            ),
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

  void _showFileOptionMenu(FileModel file) {
    showModalBottomSheet(
      context: context,
      // 배경색은 테마에서 자동 적용됨
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
              ListTile(
                leading: const Icon(
                  Icons.content_copy,
                  color: AppTheme.textPrimary,
                ),
                title: const Text(
                  "복제",
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              Divider(color: AppTheme.dividerColor),
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
      projectId: widget.project.id,
      title: "제목 없음",
      content: "",
      tags: "",
      createdAt: DateTime.now(),
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
