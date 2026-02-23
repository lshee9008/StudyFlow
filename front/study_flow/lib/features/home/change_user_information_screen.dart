import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_model.dart';
import '../../providers/user_provider.dart';

class ChangeUserInformationScreen extends StatefulWidget {
  const ChangeUserInformationScreen({super.key, required this.oldUser});
  final UserModel oldUser;
  @override
  State<ChangeUserInformationScreen> createState() =>
      _ChangeUserInformationScreenState();
}

class _ChangeUserInformationScreenState
    extends State<ChangeUserInformationScreen> {
  final _formKey = GlobalKey<FormState>();
  final newUserIdController = TextEditingController();
  final newUserPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    newUserIdController.text = widget.oldUser.name;
    newUserPasswordController.text = widget.oldUser.password;
  }

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
                          controller: newUserIdController,
                          decoration: InputDecoration(labelText: "새로운 아이디 입력"),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '새로운 아이디를 입력해주세요';
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
                      controller: newUserPasswordController,
                      decoration: InputDecoration(labelText: "새로운 비밀번호 입력"),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '새로운 비밀번호를 입력해주세요';
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
              builder: (context, ref, child) {
                return ElevatedButton(
                  onPressed: () async {
                    UserModel newUser = UserModel(
                      id: widget.oldUser.id,
                      name: newUserIdController.text,
                      join_path: widget.oldUser.join_path,
                      password: newUserPasswordController.text,
                      social_id: widget.oldUser.social_id,
                      is_login: 1,
                    );

                    String? errorMessage = await ref
                        .read(userProvider.notifier)
                        .updateUser(newUser);

                    if (errorMessage == null && context.mounted) {
                      Navigator.pop(context, newUser);
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
                    "저장",
                    style: TextStyle(
                      fontSize: screenWidth * 0.03,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
