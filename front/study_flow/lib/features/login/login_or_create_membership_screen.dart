import 'package:flutter/material.dart';
import 'package:study_flow/features/login/create_membership_screen.dart';
import 'login_screen.dart';

class LoginOrCreateMembershipScreen extends StatelessWidget {
  const LoginOrCreateMembershipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.05),
            Text(
              "로그인 및 회원가입하기",
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.1),
            Text(
              '''
            로그인 하여 다른 기기에도
            데이터를 공유할 수 있습니다.
      
            또한 Study Flow 를 삭제할 경우 사용하던 기기의 데이터는
            모두 남아있으며 탈퇴할 경우에 모두 사라집니다.
            ''',
              style: TextStyle(
                fontSize: screenWidth * 0.02,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.1),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
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
                "로그인 하기",
                style: TextStyle(
                  fontSize: screenWidth * 0.02,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.03),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CreateMembershipScreen()),
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
                "회원 가입하기",
                style: TextStyle(
                  fontSize: screenWidth * 0.02,
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
