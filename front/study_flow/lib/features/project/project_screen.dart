import 'package:flutter/material.dart';
import 'package:study_flow/features/file/file_model.dart';
import 'package:study_flow/features/project/project_model.dart';
import 'package:uuid/uuid.dart'; // 패키지 없으면 flutter pub add uuid

import '../../core/local_db_helper.dart';
import '../../core/theme.dart';
import '../file/file_screen.dart'; // FileScreen import

class ProjectScreen extends StatefulWidget {
  final ProjectModel project;
  const ProjectScreen({super.key, required this.project});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  final _projectNameController = TextEditingController();

  // DB에서 불러올 파일 리스트를 담을 Future 변수
  late Future<List<FileModel>> _filesFuture;

  @override
  void initState() {
    super.initState();
    _projectNameController.text = widget.project.name;
    _loadFiles(); // 시작할 때 파일 목록 불러오기
  }

  // DB에서 파일 목록 새로고침
  void _loadFiles() {
    setState(() {
      // widget.project.id(문자열)를 사용하여 DB 조회
      _filesFuture = LocalDatabase.instance.selectProjectFiles(
        widget.project.id,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg, // 배경색 (테마에 맞게)
      appBar: AppBar(
        backgroundColor: AppTheme.darkBg,
        title: TextField(
          controller: _projectNameController,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          decoration: const InputDecoration(border: InputBorder.none),
          onChanged: (value) {
            // 프로젝트 이름 변경 로직 (필요시 구현)
            widget.project.name = value;
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
            // 태그 영역 (기존 코드 유지)
            Wrap(
              spacing: 8,
              children: [
                if (widget.project.tags.isNotEmpty)
                  for (var tag in widget.project.tags.split(
                    '*',
                  )) // 구분자 확인 (* 또는 ,)
                    if (tag.trim().isNotEmpty)
                      Chip(
                        label: Text(
                          tag,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        backgroundColor: Colors.grey[800],
                      ),
              ],
            ),
            const SizedBox(height: 20),

            // [핵심] 파일 리스트 영역
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF262626),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FutureBuilder<List<FileModel>>(
                  future: _filesFuture, // DB 요청 결과 대기
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }

                    // 데이터가 없으면 빈 리스트
                    final files = snapshot.data ?? [];

                    return ListView.builder(
                      // 파일 개수 + 1 (맨 마지막에 추가 버튼 표시)
                      itemCount: files.length + 1,
                      itemBuilder: (context, index) {
                        // 1. 마지막 아이템: '새 파일 추가' 버튼
                        if (index == files.length) {
                          return _addFileButton();
                        }

                        // 2. 일반 아이템: 저장된 파일 표시
                        final file = files[index];
                        return ListTile(
                          title: Text(
                            file.title, // 저장된 제목 표시
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            "작성일: ${file.createdAt.toString().split(' ')[0]}",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Colors.grey,
                          ),

                          // [중요] 클릭 시 해당 파일 열기
                          onTap: () async {
                            // FileScreen으로 이동 (fileId 전달)
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FileScreen(fileId: file.id),
                              ),
                            );
                            // 돌아오면 목록 새로고침 (제목이나 내용이 변했을 수 있으므로)
                            _loadFiles();
                          },
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

  // 새 파일 추가 버튼
  Widget _addFileButton() {
    return GestureDetector(
      onTap: () async {
        // 1. 새 ID 생성
        final newFileId = const Uuid().v4();

        // 2. 빈 파일 모델 생성
        final newFile = FileModel(
          id: newFileId,
          projectId: widget.project.id,
          title: "제목 없음",
          content: "", // 내용은 빈 상태로 시작
          tags: "",
          createdAt: DateTime.now(),
        );

        // 3. DB에 먼저 저장 (그래야 FileScreen에서 불러올 수 있음)
        await LocalDatabase.instance.insertFile(newFile);

        if (!mounted) return;

        // 4. 에디터 화면으로 이동
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => FileScreen(fileId: newFileId)),
        );

        // 5. 돌아오면 목록 갱신
        _loadFiles();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFF3C3C3C),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: Colors.white70),
              SizedBox(width: 8),
              Text("새 페이지 추가", style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}
