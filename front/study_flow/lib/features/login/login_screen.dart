import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../home/home_screen.dart';
import '../../providers/user_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final userIdController = TextEditingController();
  final userPasswordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.05),
            Text(
              "로그인",
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.1),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.05),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: screenWidth * 0.4,
                        child: TextFormField(
                          controller: userIdController,
                          decoration: InputDecoration(labelText: "아이디 입력"),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '아이디를 입력해주세요';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.05),
                  SizedBox(
                    width: screenWidth * 0.4,
                    child: TextFormField(
                      controller: userPasswordController,
                      decoration: InputDecoration(labelText: "비밀번호 입력"),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '비밀번호를 입력해주세요';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
            Consumer(
              builder: (context, ref, child) => ElevatedButton(
                onPressed: () async {
                  // 수정 : 현재 사용자 이름만 알면 로그인 가능
                  String? loginUser = await ref
                      .read(userProvider.notifier)
                      .loginUser(userIdController.text, userPasswordController.text);

                  if (loginUser == null && _formKey.currentState!.validate() && context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => HomeScreen()),
                      (route) => false,
                    );
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
                  "시작하기",
                  style: TextStyle(
                    fontSize: screenWidth * 0.03,
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
}
