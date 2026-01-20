import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/local_db_helper.dart';
import '../../providers/project_provider.dart';
import '../../providers/user_provider.dart';
import '../project/add_project_dialog.dart';
import '../file/add_file_screen.dart';

class HomeScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectProvider);
    final user = ref.watch(userProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text("${user.name.isEmpty ? "로컬 사용자" : user.name}님의 HOME"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 300,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.4,
          ),
          itemCount: projects.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) return _buildAddButton(context);
            return _buildProjectCard(context, projects[index - 1]);
          },
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return Material(
      color: AppTheme.primaryGreen,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () =>
            showDialog(context: context, builder: (_) => AddProjectDialog()),
        splashColor: Colors.lightGreenAccent,

        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Stack(
            children: [
              Text(
                "새 프로젝트\n추가",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Icon(Icons.add, size: 48, color: Colors.black),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, project) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddFileScreen(projectName: project.name),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Text(
                    project.name,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  IconButton(
                    onPressed: () async {


                    },
                    icon: Icon(Icons.delete, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: SizedBox.expand(
                child: Wrap(
                  children: [
                    for (var tag in project.tags.split(','))
                      Container(
                        margin: EdgeInsets.only(right: 6, bottom: 6),
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                "• 1주차 강의 정리\n• 2주차 강의 정리",
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/*
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        project.tags,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
*/
