import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:study_flow/features/project/project_model.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme.dart';

import 'profile_screen.dart';
import '../project/project_provider.dart';
import '../project/project_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppTheme.bgPrimary,
        elevation: 0,
        titleSpacing: 24,
        title: Row(
          children: [
            const Icon(
              Icons.dashboard_outlined,
              color: AppTheme.textPrimary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text("내 프로젝트", style: AppTheme.titleSmall.copyWith(fontSize: 18)),
          ],
        ),
        actions: [profileScreen(context)],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 360,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.4,
                ),
                itemCount: projects.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) return _buildAddProjectCard(context, ref);
                  final project = projects[index - 1];
                  return _buildProjectCard(context, ref, project);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widgets ---

  Widget _buildAddProjectCard(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => _showAddProjectDialog(context, ref),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.aiAccentColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.black, size: 24),
                ),
                const Spacer(),
                const Text(
                  "새 프로젝트\n만들기",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectCard(
    BuildContext context,
    WidgetRef ref,
    ProjectModel project,
  ) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProjectScreen(project: project)),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header (Title & Option)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    project.name,
                    style: AppTheme.titleSmall.copyWith(fontSize: 18),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () => _showProjectOptionMenu(context, ref, project),
                  child: const Icon(
                    Icons.more_horiz,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),
            Text(
              DateFormat('yyyy.MM.dd').format(project.createdAt),
              style: AppTheme.caption.copyWith(fontSize: 12),
            ),

            // 2. Space between header and tags
            const SizedBox(height: 12),

            // 3. Tags (최대한 많이 보여주기)
            Expanded(
              child: Align(
                alignment: Alignment.bottomLeft, // 태그가 적을 땐 하단 정렬
                child: project.tags.isNotEmpty
                    ? SingleChildScrollView(
                        // 스크롤을 막아 넘치는 부분은 자연스럽게 잘리도록 함 (Clip)
                        physics: const NeverScrollableScrollPhysics(),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: project.tags.split(',').map((tag) {
                            final t = tag.trim();
                            if (t.isEmpty) return const SizedBox.shrink();
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.bgPrimary,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppTheme.borderColor),
                              ),
                              child: Text(
                                "#$t",
                                style: AppTheme.caption.copyWith(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      )
                    : Text(
                        "태그 없음",
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.textHint,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddProjectDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final tagCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgSecondary,
        title: Text("새 프로젝트", style: AppTheme.titleSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: AppTheme.bodyText,
              decoration: const InputDecoration(hintText: "프로젝트 이름"),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: tagCtrl,
              style: AppTheme.bodyText,
              decoration: const InputDecoration(hintText: "태그 (쉼표로 구분)"),
            ),
          ],
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
              if (nameCtrl.text.isNotEmpty) {
                final newProject = ProjectModel(
                  id: const Uuid().v4(),
                  name: nameCtrl.text,
                  tags: tagCtrl.text,
                  createdAt: DateTime.now(),
                );
                ref.read(projectProvider.notifier).addProject(newProject);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.aiAccentColor,
              foregroundColor: Colors.black,
            ),
            child: const Text("생성"),
          ),
        ],
      ),
    );
  }

  void _showProjectOptionMenu(
    BuildContext context,
    WidgetRef ref,
    ProjectModel project,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgSecondary,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  "프로젝트 삭제",
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(projectProvider.notifier).deleteProject(project.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
