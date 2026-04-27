import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color background;
  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;

  const AppColors({
    required this.background,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
  });

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? accent,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      accent: accent ?? this.accent,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }

    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
    );
  }
}

class AppSpace {
  const AppSpace._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class AppMotion {
  const AppMotion._();

  static const Duration fast = Duration(milliseconds: 100);
  static const Duration normal = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 300);
  static const Curve ease = Curves.easeOutCubic;
}

class AppRadius {
  const AppRadius._();

  static const double md = 6;
}

class AppTheme {
  const AppTheme._();

  static const String brandName = 'StudyFlow';
  static const String brandVersion = 'v1.0.0';
  static const List<String> brandKeywords = ['집중', '성장', '흐름'];
  static const String brandTagline = '배움의 흐름을 이어가는 학습 워크스페이스';

  static const AppColors darkColors = AppColors(
    background: Color(0xFF0E1116),
    surface: Color(0xFF161B22),
    border: Color(0xFF2A313C),
    textPrimary: Color(0xFFF3F5F7),
    textSecondary: Color(0xFF97A1AE),
    accent: Color(0xFF6C8CFF),
  );

  static const AppColors lightColors = AppColors(
    background: Color(0xFFF6F8FB),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFE4E8EE),
    textPrimary: Color(0xFF141821),
    textSecondary: Color(0xFF697586),
    accent: Color(0xFF4B6BFF),
  );

  static ThemeData get darkTheme => _buildTheme(
    brightness: Brightness.dark,
    colors: darkColors,
  );

  static ThemeData get lightTheme => _buildTheme(
    brightness: Brightness.light,
    colors: lightColors,
  );

  static AppColors colorsOf(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ??
      (Theme.of(context).brightness == Brightness.dark
          ? darkColors
          : lightColors);

  static ThemeData _buildTheme({
    required Brightness brightness,
    required AppColors colors,
  }) {
    final base = GoogleFonts.interTextTheme(
      brightness == Brightness.dark
          ? ThemeData.dark().textTheme
          : ThemeData.light().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.accent,
        onPrimary: Colors.white,
        secondary: colors.accent,
        onSecondary: Colors.white,
        error: const Color(0xFFE26D5A),
        onError: Colors.white,
        surface: colors.surface,
        onSurface: colors.textPrimary,
      ),
      dividerColor: colors.border,
      fontFamily: GoogleFonts.inter().fontFamily,
      extensions: <ThemeExtension<dynamic>>[colors],
      textTheme: base.copyWith(
        bodySmall: _text(colors.textSecondary, 12, FontWeight.w400),
        bodyMedium: _text(colors.textSecondary, 14, FontWeight.w400),
        bodyLarge: _text(colors.textPrimary, 14, FontWeight.w400),
        titleSmall: _text(colors.textPrimary, 18, FontWeight.w500, -0.2),
        titleMedium: _text(colors.textPrimary, 24, FontWeight.w600, -0.5),
        titleLarge: _text(colors.textPrimary, 28, FontWeight.w600, -0.5),
        headlineSmall: _text(colors.textPrimary, 32, FontWeight.w600, -0.7),
        labelSmall: _text(colors.textSecondary.withValues(alpha: 0.55), 12, FontWeight.w400),
        labelMedium: _text(colors.textSecondary, 14, FontWeight.w500),
        labelLarge: _text(colors.textPrimary, 14, FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: _text(colors.textPrimary, 18, FontWeight.w500, -0.2),
        iconTheme: IconThemeData(color: colors.textSecondary, size: 20),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
        ),
        hintStyle: _text(colors.textSecondary, 14, FontWeight.w400),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colors.accent),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.surface,
        contentTextStyle: _text(colors.textPrimary, 14, FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: colors.border),
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: colors.border),
        ),
      ),
      iconTheme: IconThemeData(color: colors.textSecondary, size: 20),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: colors.border.withValues(alpha: 0.18),
    );
  }

  static TextStyle _text(
    Color color,
    double size,
    FontWeight weight, [
    double letterSpacing = 0,
  ]) {
    return GoogleFonts.inter(
      color: color,
      fontSize: size,
      fontWeight: weight,
      height: 1.6,
      letterSpacing: letterSpacing,
    );
  }

  // Compatibility aliases while remaining screens migrate.
  static const Color bgDeep = Color(0xFF0E1116);
  static const Color bgPrimary = Color(0xFF0E1116);
  static const Color bgSecondary = Color(0xFF161B22);
  static const Color bgTertiary = Color(0xFF11161D);
  static const Color bgQuaternary = Color(0xFF0C1016);
  static const Color borderSubtle = Color(0xFF2A313C);
  static const Color borderDefault = Color(0xFF2A313C);
  static const Color borderStrong = Color(0xFF3B4552);
  static const Color borderFocus = Color(0xFF6C8CFF);
  static const Color textPrimary = Color(0xFFF3F5F7);
  static const Color textSecondary = Color(0xFF97A1AE);
  static const Color textTertiary = Color(0xFF97A1AE);
  static const Color textMuted = Color(0xFF6E7886);
  static const Color accent = Color(0xFF6C8CFF);
  static const Color accentDim = Color(0x142F58FF);
  static const Color accentMuted = Color(0xFF93A8FF);
  static const Color accentHover = Color(0xFF7F99FF);
  static const Color accentGlow = Color(0x142F58FF);
  static const Color blue = Color(0xFF6C8CFF);
  static const Color blueDim = Color(0x142F58FF);
  static const Color purple = Color(0xFF9B8BFF);
  static const Color purpleDim = Color(0x149B8BFF);
  static const Color red = Color(0xFFE26D5A);
  static const Color redDim = Color(0x14E26D5A);
  static const Color green = Color(0xFF5FA36A);
  static const Color greenDim = Color(0x145FA36A);
  static const Color yellow = Color(0xFFB69155);
  static const Color yellowDim = Color(0x14B69155);

  static TextStyle get displayLarge => _text(textPrimary, 32, FontWeight.w600, -0.5);
  static TextStyle get displayMedium => _text(textPrimary, 28, FontWeight.w600, -0.5);
  static TextStyle get headingLarge => _text(textPrimary, 24, FontWeight.w600, -0.5);
  static TextStyle get headingMedium => _text(textPrimary, 18, FontWeight.w500, -0.2);
  static TextStyle get headingSmall => _text(textPrimary, 16, FontWeight.w500, -0.1);
  static TextStyle get bodyLarge => _text(textPrimary, 14, FontWeight.w400);
  static TextStyle get bodyMedium => _text(textSecondary, 14, FontWeight.w400);
  static TextStyle get bodySmall => _text(textSecondary.withValues(alpha: 0.55), 12, FontWeight.w400);
  static TextStyle get labelMedium => _text(textSecondary, 14, FontWeight.w500);
  static TextStyle get labelSmall => _text(textSecondary.withValues(alpha: 0.55), 12, FontWeight.w400);
  static TextStyle get caption => _text(textSecondary.withValues(alpha: 0.55), 12, FontWeight.w400);
}

class AppEmojiSet {
  const AppEmojiSet._();

  static const List<String> projectEmojis = [
    '📚', '🧠', '⚡', '🎯', '🔬', '💡', '🛠', '🌿',
    '🚀', '📝', '🎨', '🔢', '💻', '🌍', '🎵', '⭐',
  ];

  static String forIndex(int i) => projectEmojis[i % projectEmojis.length];
}

class SFButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool outlined;
  final bool danger;
  final IconData? icon;
  final double? width;
  final double? height;

  const SFButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.outlined = false,
    this.danger = false,
    this.icon,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final disabled = onPressed == null || isLoading;
    final background = danger
        ? AppTheme.red
        : outlined
        ? colors.surface
        : colors.accent;
    final foreground = danger || !outlined
        ? Colors.white
        : colors.textPrimary;

    return SizedBox(
      width: width,
      height: height ?? 40,
      child: Material(
        color: disabled ? background.withValues(alpha: 0.45) : background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: outlined ? colors.border : background,
              ),
            ),
            child: Center(
              child: isLoading
                  ? Container(
                      width: 44,
                      height: 10,
                      decoration: BoxDecoration(
                        color: foreground.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 16, color: foreground),
                          const SizedBox(width: AppSpace.xs),
                        ],
                        Text(
                          label,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: foreground,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class SFTextField extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  final bool obscure;
  final IconData? prefixIcon;
  final String? label;
  final TextInputType? keyboardType;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final bool autofocus;

  const SFTextField({
    super.key,
    required this.hint,
    required this.controller,
    this.obscure = false,
    this.prefixIcon,
    this.label,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: AppSpace.xs),
        ],
        TextField(
          controller: controller,
          autofocus: autofocus,
          obscureText: obscure,
          keyboardType: keyboardType,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, size: 16, color: colors.textSecondary),
          ),
        ),
      ],
    );
  }
}
