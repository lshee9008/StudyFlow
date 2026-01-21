import 'package:flutter/material.dart';
import '../../core/theme.dart';

class FileScreen extends StatelessWidget {
  final String projectName;
  const FileScreen({
    Key? key,
    this.projectName = "새 프로젝트",
    required String projectId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("$projectName > 새 파일")),
      body: Row(
        children: [
          // Editor Section
          Expanded(
            flex: 2,
            child: Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.cardGrey,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: "파일 제목 기입 칸",
                      hintStyle: TextStyle(color: Colors.white30),
                      border: InputBorder.none,
                    ),
                  ),
                  Divider(color: Colors.grey),
                  SizedBox(height: 16),
                  Expanded(
                    child: TextField(
                      maxLines: null,
                      style: TextStyle(color: Colors.white, height: 1.5),
                      decoration: InputDecoration(
                        hintText: "내용을 입력하세요... (H1, H2, OCR, 사진 첨부 가능)",
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Sidebar / Preview Section
          Expanded(
            flex: 1,
            child: Container(
              margin: EdgeInsets.fromLTRB(0, 16, 16, 16),
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: Colors.grey[800]!),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  "기능 요약 및 미리보기\n(OCR 분석 대기 중)",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
