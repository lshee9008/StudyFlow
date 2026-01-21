import 'package:flutter/material.dart';

import '../../core/local_db_helper.dart';
import '../../core/theme.dart';
import '../file/file_screen.dart';
import '../../models/project_model.dart';
import '../../models/project_file_model.dart';

class ProjectScreen extends StatefulWidget {
  final ProjectModel project;
  const ProjectScreen({super.key, required this.project});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  final _projectNameController = TextEditingController();
  late Future<List<ProjectFileModel>> projectFiles;


  @override
  void initState() {
    projectFiles = LocalDatabase.instance.selectProjectFiles(widget.project.id);
    _projectNameController.text = widget.project.name;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _projectNameController,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
          ),
          onChanged: (value) {
            setState(() {
              widget.project.name = value;
            });
          },
        ),
        leading: BackButton(
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              children: [
                if (widget.project.tags.isNotEmpty)
                  for (var tag in widget.project.tags.split(','))
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(tag, style: TextStyle(color: Colors.white70)),
                    ),
                GestureDetector(
                  onTap: _addTag,
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "새 태그 추가 +",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Container(
                padding: EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  color: Color(0xFF262626),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FutureBuilder(
                  future: projectFiles,
                  builder:
                      (
                        BuildContext context,
                        AsyncSnapshot<List<ProjectFileModel>> snapshot,
                      ) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return ListView(children: [_addFileButton()]);
                        } else {
                          final files = snapshot.data!;
                          return ListView.builder(
                            shrinkWrap: true,
                            itemCount: files.length + 1,
                            itemBuilder: (context, index) {
                              final file = files[index];
                              return ListTile(title: Text(file.name));
                            },
                          );
                        }
                      },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addTag() async {
    await showDialog(
      context: context,
      builder: (context) {
        final tagController = TextEditingController();
        return AlertDialog(
          backgroundColor: AppTheme.cardGrey,
          title: Text("태그 추가", style: TextStyle(color: Colors.white)),
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
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("취소", style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  widget.project.tags += widget.project.tags.isEmpty
                      ? tagController.text
                      : ',${tagController.text}';
                });
                Navigator.pop(context);
              },
              child: Text("추가", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _addFileButton() {
    return GestureDetector(
      onTap: () async {
        Future<ProjectFileModel> newProjectFile =
            Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => FileScreen()),
                )
                as Future<ProjectFileModel>;

        setState(() {});
      },
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Color(0xFF3C3C3C),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: Text("+")),
      ),
    );
  }
}
