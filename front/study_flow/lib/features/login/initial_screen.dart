import 'package:flutter/material.dart';
import 'login_or_create_membership_screen.dart';

class InitialScreen extends StatelessWidget {
  const InitialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.05),
          Text(
            "    Study Flow 에 오신 것을 환영합니다!",
            style: TextStyle(
              fontSize: screenWidth * 0.04,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
          Text(
            "    공부 & 지식의 흐름을 잡아주는 어플리케이션입니다~/",
            style: TextStyle(
              fontSize: screenWidth * 0.03,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            "    여러분들의 흐름을 찾아보세요!",
            style: TextStyle(
              fontSize: screenWidth * 0.03,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.3),
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginOrCreateMembershipScreen()),
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
    );
  }
}
