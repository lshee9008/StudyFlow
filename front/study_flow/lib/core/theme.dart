import 'package:flutter/material.dart';

class AppTheme {
  // --- Color Palette (Notion Dark Mode Inspired) ---
  static const Color bgPrimary = Color(0xFF191919); // 메인 배경색
  static const Color bgSecondary = Color(0xFF252525); // 사이드바, 카드 배경색
  static const Color bgHover = Color(0xFF2F2F2F); // 호버/클릭 시 배경색

  static const Color textPrimary = Color(0xFFFFFFFF); // 기본 텍스트 (흰색)
  static const Color textSecondary = Color(0xFF9A9A9A); // 보조 텍스트 (회색)
  static const Color textHint = Color(0xFF5A5A5A); // 힌트 텍스트

  static const Color accentColor = Color(0xFF007AFF); // 강조색 (파랑)
  static const Color aiAccentColor = Color(0xFFCCFF66); // AI 기능 강조색 (라임)

  static const Color borderColor = Color(0xFF333333); // 은은한 테두리 선
  static const Color dividerColor = Color(0xFF2A2A2A); // 구분선
  // [NEW] primaryGreen 추가 (aiAccentColor와 같은 색으로 연결)
  static const Color primaryGreen = aiAccentColor;
  // --- Text Styles ---
  static const TextStyle titleHuge = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.3,
    height: 1.4,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.4,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.4,
  );

  static const TextStyle bodyText = TextStyle(
    fontSize: 16,
    color: textPrimary,
    height: 1.6,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 13,
    color: textSecondary,
    height: 1.4,
  );

  static const TextStyle codeText = TextStyle(
    fontSize: 14,
    fontFamily: 'Courier',
    color: Color(0xFFFF5252),
    height: 1.4,
  );

  // --- ThemeData ---
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgPrimary,
      primaryColor: bgPrimary,

      colorScheme: const ColorScheme.dark(
        primary: accentColor,
        secondary: aiAccentColor,
        background: bgPrimary,
        surface: bgSecondary,
        onBackground: textPrimary,
        onSurface: textPrimary,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: bgPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: textSecondary),
      ),

      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),

      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: accentColor,
        selectionColor: Color(0xFF004C99),
      ),

      inputDecorationTheme: InputDecorationTheme(
        hintStyle: const TextStyle(color: textHint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: bgSecondary,
        contentPadding: const EdgeInsets.all(12),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: bgSecondary,
        foregroundColor: textPrimary,
        elevation: 4,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: bgSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
      ),
    );
  }
}
