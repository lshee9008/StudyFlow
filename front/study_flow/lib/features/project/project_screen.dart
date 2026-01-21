import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/local_db_helper.dart';
import '../../core/theme.dart';
import '../file/file_screen.dart';
import 'project_model.dart';
import '../file/file_model.dart';

class ProjectScreen extends StatefulWidget {
  final ProjectModel project;
  const ProjectScreen({super.key, required this.project});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  final _projectNameController = TextEditingController();
  late Future<List<FileModel>> projectFiles;

  @override
  void initState() {
    super.initState();
    _loadFiles(); // 파일 로드 함수 분리
    _projectNameController.text = widget.project.name;
  }

  // 파일 목록 새로고침을 위한 함수
  void _loadFiles() {
    setState(() {
      projectFiles = LocalDatabase.instance.selectProjectFiles(
        widget.project.id,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg, // 배경색 지정 권장
      appBar: AppBar(
        backgroundColor: AppTheme.darkBg,
        title: TextField(
          controller: _projectNameController,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(border: InputBorder.none),
          onChanged: (value) {
            // TODO: DB에 프로젝트 이름 업데이트 로직 필요
            setState(() {
              widget.project.name = value;
            });
          },
        ),
        leading: BackButton(
          color: Colors.white,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 태그 영역
            Wrap(
              spacing: 8,
              children: [
                if (widget.project.tags.isNotEmpty)
                  for (var tag in widget.project.tags.split(','))
                    if (tag.trim().isNotEmpty) // 빈 태그 방지
                      Chip(
                        label: Text(
                          tag,
                          style: TextStyle(color: Colors.white70),
                        ),
                        backgroundColor: Colors.grey[800],
                      ),
                ActionChip(
                  label: Text(
                    "새 태그 추가 +",
                    style: TextStyle(color: Colors.white70),
                  ),
                  backgroundColor: Colors.grey[800],
                  onPressed: _addTag,
                ),
              ],
            ),
            SizedBox(height: 20),
            // 파일 리스트 영역
            Expanded(
              child: Container(
                padding: EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  color: Color(0xFF262626),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FutureBuilder<List<FileModel>>(
                  future: projectFiles,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    }

                    final files = snapshot.data ?? [];

                    return ListView.builder(
                      // 파일 개수 + 1 (추가 버튼)
                      itemCount: files.length + 1,
                      itemBuilder: (context, index) {
                        // 마지막 아이템은 '추가 버튼'으로 표시
                        if (index == files.length) {
                          return _addFileButton();
                        }

                        // 그 외에는 파일 목록 표시
                        final file = files[index];
                        return ListTile(
                          title: Text(
                            file.title ?? "제목 없음",
                            style: TextStyle(color: Colors.white),
                          ), // ProjectFileModel에 name이 있다고 가정
                          // onTap: () => 파일 상세 이동 로직,
                        );
                      },
                    );
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
    final tagController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardGrey,
          title: Text("태그 추가", style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: tagController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "태그 입력",
              hintStyle: TextStyle(color: Colors.grey),
              filled: true,
              fillColor: Colors.black,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("취소"),
            ),
            TextButton(
              onPressed: () {
                if (tagController.text.isNotEmpty) {
                  setState(() {
                    // 태그가 있을 때만 콤마 추가
                    if (widget.project.tags.isNotEmpty) {
                      widget.project.tags += ',${tagController.text}';
                    } else {
                      widget.project.tags = tagController.text;
                    }
                    // TODO: DB에 태그 업데이트 로직 필요
                  });
                }
                Navigator.pop(context);
              },
              child: Text("추가"),
            ),
          ],
        );
      },
    );
  }

  Widget _addFileButton() {
    return GestureDetector(
      onTap: () async {
        // 1. 고유 ID 생성 (uuid가 없으면 DateTime.now().toString() 사용)
        final String newFileId = const Uuid().v4();

        // 2. 초기 파일 모델 생성 (DB에 넣을 껍데기)
        final newFile = FileModel(
          id: newFileId,
          projectId: widget.project.id, // 현재 프로젝트 ID 연결
          title: "제목 없음",
          content: "", // 내용은 비어있음 -> Editor에서 초기화됨
          tags: "",
          createdAt: DateTime.now(),
        );

        // 3. DB에 저장 (이래야 FileScreen에서 load/save가 가능)
        await LocalDatabase.instance.insertFile(newFile);

        // 4. 화면 이동 (fileId 전달)
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            // ✅ 수정된 부분: projectId 대신 fileId 전달
            builder: (_) => FileScreen(fileId: newFileId),
          ),
        );

        // 5. 돌아오면 목록 새로고침
        _loadFiles();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFF3C3C3C),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(child: Icon(Icons.add, color: Colors.white70)),
      ),
    );
  }
}
