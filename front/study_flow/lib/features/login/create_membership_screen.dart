import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../home/home_screen.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';

class CreateMembershipScreen extends StatefulWidget {
  const CreateMembershipScreen({super.key});

  @override
  State<CreateMembershipScreen> createState() => _CreateMembershipScreenState();
}

class _CreateMembershipScreenState extends State<CreateMembershipScreen> {
  bool serverPossibleId = false;
  bool serverPossiblePassword = false;
  String possibleId = "";
  String possiblePassword = "";
  final _formKey = GlobalKey<FormState>();
  final newUserIdController = TextEditingController();
  final newUserPasswordController = TextEditingController();

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
              "회원가입",
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: screenWidth * 0.4,
                        child: TextFormField(
                          controller: newUserIdController,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          decoration: InputDecoration(labelText: "사용할 아이디 입력"),
                          onChanged: (value) {
                            if (serverPossibleId && possibleId != value) {
                              serverPossibleId = false;
                              setState(() {});
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '사용할 아이디를 입력해주세요';
                            }
                            if (serverPossibleId &&
                                    possibleId != newUserIdController.text ||
                                !serverPossibleId) {
                              return '사용 가능한 아이디인지 확인해 주십시오';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.01),
                      IconButton(
                        icon: Icon(
                          Icons.search,
                          color: serverPossibleId
                              ? Colors.lightGreenAccent
                              : Colors.red,
                        ),
                        onPressed: () {
                          serverPossibleId = true;
                          if (serverPossibleId == true) {
                            possibleId = newUserIdController.text;
                          }
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.05),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: screenWidth * 0.4,
                        child: TextFormField(
                          controller: newUserPasswordController,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          decoration: InputDecoration(labelText: "사용할 비밀번호 입력"),
                          onChanged: (value) {
                            if (serverPossiblePassword &&
                                possiblePassword != value) {
                              serverPossiblePassword = false;
                              setState(() {});
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '사용할 아이디를 입력해주세요';
                            }
                            if (serverPossiblePassword &&
                                    possiblePassword !=
                                        newUserPasswordController.text ||
                                !serverPossiblePassword) {
                              return '사용 가능한 아이디인지 확인해 주십시오';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: MediaQuery.sizeOf(context).width * 0.005),
                      IconButton(
                        icon: Icon(
                          Icons.search,
                          color: serverPossiblePassword
                              ? Colors.lightGreenAccent
                              : Colors.red,
                        ),
                        onPressed: () {
                          serverPossiblePassword = true;
                          if (serverPossiblePassword == true) {
                            possiblePassword = newUserPasswordController.text;
                          }
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
            Consumer(
              builder: (context, ref, child) {
                return ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate() &&
                        serverPossibleId &&
                        serverPossiblePassword) {
                      UserModel newUser = UserModel(
                        id: Uuid().v4(),
                        name: newUserIdController.text,
                        join_path: '',
                        password: newUserPasswordController.text,
                        social_id: '',
                        is_login: 1,
                      );
                      print('create_user: ${newUser.password}');
                      String? state = await ref.watch(userProvider.notifier).addUser(newUser);
                      if (context.mounted) {
                        if (state == null) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HomeScreen(),
                            ),
                            (route) => false,
                          );
                        } else {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: Text('회원가입 실패'),
                                content: Text(state),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Text('확인'),
                                  ),
                                ],
                              );
                            },
                          );
                        }
                      }
                    }
                    setState(() {});
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
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
