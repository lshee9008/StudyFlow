import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/project_model.dart';
import '../../core/theme.dart';
import '../../providers/project_provider.dart';

class AddProjectDialog extends ConsumerStatefulWidget {
  @override
  _AddProjectDialogState createState() => _AddProjectDialogState();
}

class _AddProjectDialogState extends ConsumerState<AddProjectDialog> {
  final _controller = TextEditingController();
  List<Chip> chipTags = []; 

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.cardGrey,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "새 프로젝트 제목",
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 24),
            TextField(
              controller: _controller,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "제목을 입력하세요",
                hintStyle: TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.black,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
            ),
            SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...chipTags,
                ActionChip(
                  label: Text(
                    "+ 태그 추가",
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Color(0xFF333333),
                  onPressed: _buildAddTag,
                ),
              ],
            ),
            SizedBox(height: 32),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  String tags = chipTags
                      .map((chip) => (chip.label as Text).data!)
                      .toList()
                      .join('*');
                  ProjectModel newProject = ProjectModel(
                    id: "임시 id",
                    name: _controller.text,
                    tags: tags,
                    createdAt: DateTime.now(),
                  );
                  if (_controller.text.isNotEmpty) {
                    ref
                        .read(projectProvider.notifier)
                        .addProject(newProject);
                    Navigator.pop(context);
                  }
                },
                child: Text(
                  "생성",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _buildAddTag() async {
    await showDialog(
      context: context,
      builder: (context) {
        final tagController = TextEditingController();
        return AlertDialog(
          backgroundColor: AppTheme.cardGrey,
          title: Text(
            "태그 추가",
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: tagController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "태그 이름을 입력하세요",
              hintStyle: TextStyle(color: Colors.grey),
              filled: true,
              fillColor: Colors.black,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                "취소",
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () {
                if (tagController.text.isNotEmpty) {
                  setState(() {
                    chipTags.add(_buildTagChip(tagController.text));
                  });
                  Navigator.pop(context);
                }
              },
              child: Text(
                "추가",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Chip _buildTagChip(String tag) {
    return Chip(
      label: Text(tag),
      backgroundColor: Color(0xFF555555),
      labelStyle: TextStyle(color: Colors.white),
      onDeleted: () => setState(() {
        chipTags.removeWhere( (chip) => (chip.label as Text).data == tag);
      },),
    );
  }
}
