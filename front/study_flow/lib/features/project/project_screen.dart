import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../providers/user_provider.dart';
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
    final userName = ref.watch(userProvider)?.name ?? AppTheme.brandName;
    final isCompact = MediaQuery.of(context).size.width < 980;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          return;
        }
        widget.project.name = _nameController.text.trim();
        widget.project.tags = _tags.join(',');
        widget.project.update_at = DateTime.now();
        ref.read(projectProvider.notifier).updateProjectAll(widget.project);
      },
      child: AppWorkspaceShell(
        currentNav: 'workspace',
        title: '프로젝트 노트',
        subtitle: '워크스페이스의 노트와 학습 자료를 관리합니다.',
        profileLabel: userName,
        compact: isCompact,
        onHome: () => Navigator.popUntil(context, (route) => route.isFirst),
        onWorkspace: () => Navigator.pop(context),
        onSearch: () {},
        onSettings: () {},
        secondaryAction: AppButton(
          label: '태그',
          onPressed: _openTagSheet,
          primary: false,
          icon: LucideIcons.tags,
        ),
        primaryAction: AppButton(
          label: '새 노트',
          onPressed: _createFile,
          icon: LucideIcons.filePlus,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg,
                0,
                AppSpace.lg,
                AppSpace.md,
              ),
              child: _ProjectHeader(
                controller: _nameController,
                tags: _tags,
                onBack: () => Navigator.pop(context),
                onUpdateName: _updateName,
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
                      return Padding(
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
                                    (_, animation, secondaryAnimation, child) {
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
                              ),
                            );
                            await _reloadFiles();
                          },
                          onRename: () => _renameFile(file),
                          onDelete: () => _deleteFile(file),
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
    );
  }
}

class _ProjectHeader extends StatelessWidget {
  final TextEditingController controller;
  final List<String> tags;
  final VoidCallback onBack;
  final ValueChanged<String> onUpdateName;
  final VoidCallback onAddTag;
  final ValueChanged<String> onRemoveTag;
  final VoidCallback onCreateFile;

  const _ProjectHeader({
    required this.controller,
    required this.tags,
    required this.onBack,
    required this.onUpdateName,
    required this.onAddTag,
    required this.onRemoveTag,
    required this.onCreateFile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTopBar(
          title: '프로젝트',
          leading: _HeaderButton(icon: LucideIcons.arrowLeft, onTap: onBack),
          actions: [
            AppButton(
              label: '태그',
              onPressed: onAddTag,
              primary: false,
              icon: LucideIcons.plus,
            ),
            const SizedBox(width: AppSpace.xs),
            AppButton(
              label: '새 노트',
              onPressed: onCreateFile,
              icon: LucideIcons.filePlus,
            ),
          ],
        ),
        AppInput(
          controller: controller,
          hintText: '프로젝트 이름',
          onSubmitted: onUpdateName,
          onChanged: onUpdateName,
        ),
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

class _FileTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final tags = file.tags
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final updatedAt = file.update_at ?? file.create_at;

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    file.title,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'rename') {
                      onRename();
                    }
                    if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'rename',
                      child: Text('이름 변경'),
                    ),
                    PopupMenuItem<String>(value: 'delete', child: Text('삭제')),
                  ],
                  icon: const Icon(LucideIcons.moreHorizontal, size: 16),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              DateFormat('yyyy.MM.dd HH:mm').format(updatedAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: AppSpace.sm),
              Wrap(
                spacing: AppSpace.xs,
                runSpacing: AppSpace.xs,
                children: tags
                    .take(3)
                    .map((tag) => AppBadge(label: tag))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
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
    return ListView.builder(
      itemCount: 4,
      padding: const EdgeInsets.all(AppSpace.lg),
      itemBuilder: (context, index) => Padding(
        padding: EdgeInsets.only(bottom: index == 3 ? 0 : AppSpace.sm),
        child: AppCard(
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeletonLine(width: 160),
              SizedBox(height: AppSpace.sm),
              AppSkeletonLine(width: 120),
            ],
          ),
        ),
      ),
    );
  }
}
