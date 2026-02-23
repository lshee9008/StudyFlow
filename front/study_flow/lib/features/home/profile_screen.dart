import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'change_user_information_screen.dart';
import '../login/initial_screen.dart';
import '../login/registered_users_screen.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';

Widget profileScreen(BuildContext context, WidgetRef ref, UserModel user) {
  return Theme(
    data: Theme.of(context).copyWith(
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    ),
    child: PopupMenuButton<String>(
      constraints: BoxConstraints(minWidth: 300),
      offset: const Offset(0, kToolbarHeight),
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('유저 : ${user.name}'),
              TextButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all<Color>(
                    Color(0xFF3C3C3C),
                  ),
                  overlayColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.hovered)) {
                      return Colors.transparent; // hover 제거
                    }
                    if (states.contains(WidgetState.pressed)) {
                      return Colors.transparent;
                    }
                    return null;
                  }),
                ),
                onPressed: () async {
                  await Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ChangeUserInformationScreen(oldUser: user),
                    ),
                  );
                },
                child: Text(
                  "정보 수정",
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFFFFFFFF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          enabled: false,
          child: SizedBox(
            width: double.infinity,
            child: TextButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all<Color>(
                  Color(0xFF3C3C3C),
                ),
                overlayColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.hovered)) {
                    return Colors.transparent; // hover 제거
                  }
                  if (states.contains(WidgetState.pressed)) {
                    return Colors.transparent;
                  }
                  return null;
                }),
              ),
              onPressed: () async {
                ref.read(userProvider.notifier).logoutExistingUser(user.id!);
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RegisteredUsersScreen(),
                    ),
                    (route) => false,
                  );
                }
              },
              child: Text(
                "계정 전환하기",
                style: TextStyle(
                  fontSize: 20,
                  color: Color(0xFFFFFFFF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        PopupMenuItem(
          enabled: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all<Color>(
                    Color(0xFF3C3C3C),
                  ),
                  overlayColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.hovered)) {
                      return Colors.transparent; // hover 제거
                    }
                    if (states.contains(WidgetState.pressed)) {
                      return Colors.transparent;
                    }
                    return null;
                  }),
                ),
                onPressed: () async {
                  ref.read(userProvider.notifier).logoutExistingUser(user.id!);
                  print("ProfileScreen - clicked logout button");
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => InitialScreen()),
                    (route) => false,
                  );
                },
                child: Text(
                  "로그 아웃",
                  style: TextStyle(
                    fontSize: 20,
                    color: Color(0xFFFFFFFF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all<Color>(
                    Color(0xFF3C3C3C),
                  ),
                  overlayColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.hovered)) {
                      return Colors.transparent; // hover 제거
                    }
                    if (states.contains(WidgetState.pressed)) {
                      return Colors.transparent;
                    }
                    return null;
                  }),
                ),
                onPressed: () async {
                  await ref.read(userProvider.notifier).deleteUser(user.id!);
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: Text(
                  "탈퇴하기",
                  style: TextStyle(
                    fontSize: 20,
                    color: Color(0xFFFFFFFF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Icon(Icons.person),
      ),
    ),
  );
}
