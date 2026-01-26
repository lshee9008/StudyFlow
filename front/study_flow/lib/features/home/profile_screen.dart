import 'package:flutter/material.dart';

Widget profileScreen(BuildContext context) {
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
          child: Row(children: const [Text('유저 : '), Text('홍길동')]),
        ),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                style: ButtonStyle(
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
                onPressed: () {
                  /*로그아웃 서버 함수 예정
                  */
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
                onPressed: () {
                  /* 탈퇴 하기 서버 함수 예정
                  */
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
      onSelected: (value) {
        if (value == 'logout') {
          // 로그아웃 처리
        }
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Icon(Icons.person),
      ),
    ),
  );
}
