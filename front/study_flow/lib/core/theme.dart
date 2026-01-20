import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryGreen = Color(0xFFCCFF66); // PDF의 포인트 컬러
  static const Color darkBg = Colors.black;
  static const Color cardGrey = Color(0xFF1E1E1E);
  static const Color textWhite = Colors.white;

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: darkBg,
      primaryColor: primaryGreen,
      // GoogleFonts 제거 후 기본 다크 테마 텍스트 스타일 적용
      textTheme: ThemeData.dark().textTheme,
      colorScheme: ColorScheme.dark(
        primary: primaryGreen,
        secondary: primaryGreen,
        surface: cardGrey,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBg,
        elevation: 0,
        // GoogleFonts 제거 후 기본 TextStyle 적용
        titleTextStyle: TextStyle(
          color: textWhite,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
