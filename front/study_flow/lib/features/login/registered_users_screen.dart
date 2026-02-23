import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_flow/models/user_model.dart';

import '../../core/db_helper/users_db_helper.dart';
import '../home/home_screen.dart';
import 'login_or_create_membership_screen.dart';
import '../../providers/user_provider.dart';

class RegisteredUsersScreen extends StatefulWidget {
  const RegisteredUsersScreen({super.key});

  @override
  State<RegisteredUsersScreen> createState() => _RegisteredUsersScreenState();
}

class _RegisteredUsersScreenState extends State<RegisteredUsersScreen> {
  String selectedId = "";

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.025),
            Text(
              "등록된 유저 목록",
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.025),
            SizedBox(
              width: screenWidth * 0.6,
              height: MediaQuery.sizeOf(context).height * 0.6,
              child: Material(
                color: Color(0xFF3C3C3C),
                borderRadius: BorderRadius.circular(20),
                child: FutureBuilder(
                  future: UsersDBHelper.selectUsers(),
                  builder: (context, asyncSnapshot) {
                    if (asyncSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    } else if (asyncSnapshot.hasError) {
                      return Center(child: Text('유저 목록을 불러오는 중 오류가 발생했습니다.'));
                    } else if (!asyncSnapshot.hasData ||
                        asyncSnapshot.data!.isEmpty) {
                      return Center(
                        child: Text(
                          "등록된 유저가 없습니다.",
                          style: TextStyle(
                            fontSize: screenWidth * 0.02,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      );
                    } else {
                      final users = asyncSnapshot.data!;
                      return Padding(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: ListView.builder(
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            final user = users[index];
                            final isSelected = selectedId == user.id;
                            return ListTile(
                              title: Text(
                                user.name,
                                style: TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                '가입 경로: ${user.join_path}',
                                style: TextStyle(color: Colors.white70),
                              ),
                              selected: isSelected,
                              tileColor: Color(0xFF3C3C3C),
                              hoverColor: Colors.white12,
                              selectedTileColor: Colors.red,
                              onTap: () {
                                setState(() {
                                  selectedId = user.id!;
                                });
                              },
                            );
                          },
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.02),
            Consumer(
              builder: (context, ref, child) => ElevatedButton(
                onPressed: () async {
                  selectedId.isEmpty
                      ? null
                      : await ref
                            .read(userProvider.notifier)
                            .loginExistingUser(selectedId);
                  UserModel? state = ref.watch(userProvider);
                  if (context.mounted) {
                    if (state!.id == '') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '유저를 선택해주세요.',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Color(0xFF3C3C3C),
                        ),
                      );
                    } else {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => HomeScreen()),
                        (route) => false,
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  fixedSize: Size(screenWidth * 0.2, screenWidth * 0.05),
                  backgroundColor: Color(0xFF3C3C3C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  "유저 선택",
                  style: TextStyle(
                    fontSize: screenWidth * 0.02,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.02),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LoginOrCreateMembershipScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                fixedSize: Size(screenWidth * 0.2, screenWidth * 0.05),
                backgroundColor: Color(0xFF3C3C3C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                "새 유저 추가",
                style: TextStyle(
                  fontSize: screenWidth * 0.018,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
