import 'package:flutter/material.dart';
import '../../models/home_card_data.dart';

class Home extends StatelessWidget {
  final List<ProjectCardData> projects = [
    ProjectCardData(
      title: '(대학교 교양 강의) DB',
      items: ['1주차 강의 정리', '1주차 강의 정리', '1주차 강의 정리'],
    ),
    ProjectCardData(
      title: '(대학교 전공 강의) DB',
      items: ['1주차 강의 정리', '1주차 강의 정리', '1주차 강의 정리'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('이승희님의 HOME')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: GridView.count(
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              AddProjectCard(),
              ...projects.map((project) => ProjectCard(data: project)).toList(),
            ],
          ),
        ),
      ),
    );
  }
}

class AddProjectCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green[300],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 40, color: Colors.white),
            SizedBox(height: 8),
            Text('새프로젝트 추가', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}



class ProjectCard extends StatelessWidget {
  final ProjectCardData data;

  ProjectCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('데이터베이스', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(data.title, style: TextStyle(color: Colors.grey[700])),
            Divider(),
            ...data.items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Text(item),
            )),
          ],
        ),
      ),
    );
  }
}