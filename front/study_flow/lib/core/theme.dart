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

  static const double sm = 8;
  static const double md = 10;
  static const double lg = 14;
}

class AppTheme {
  const AppTheme._();

  static const String brandName = 'StudyFlow';
  static const String brandVersion = 'v1.0.0';
  static const List<String> brandKeywords = ['집중', '성장', '흐름'];
  static const String brandTagline = '배움의 흐름을 이어가는 학습 워크스페이스';

  static const AppColors darkColors = AppColors(
    background: Color(0xFF0B0E14),
    surface: Color(0xFF151922),
    border: Color(0xFF242A36),
    textPrimary: Color(0xFFF3F5F9),
    textSecondary: Color(0xFF99A2B2),
    accent: Color(0xFF6E83FF),
  );

  static const AppColors lightColors = AppColors(
    background: Color(0xFFF5F7FC),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFE3E8F3),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF66748B),
    accent: Color(0xFF5E79FF),
  );

  static ThemeData get darkTheme =>
      _buildTheme(brightness: Brightness.dark, colors: darkColors);

  static ThemeData get lightTheme =>
      _buildTheme(brightness: Brightness.light, colors: lightColors);

  static AppColors colorsOf(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ??
      (Theme.of(context).brightness == Brightness.dark
          ? darkColors
          : lightColors);

  static ThemeData _buildTheme({
    required Brightness brightness,
    required AppColors colors,
  }) {
    final base = GoogleFonts.notoSansKrTextTheme(
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
        error: const Color(0xFFE8705E),
        onError: Colors.white,
        surface: colors.surface,
        onSurface: colors.textPrimary,
      ),
      dividerColor: colors.border,
      fontFamily: GoogleFonts.notoSansKr().fontFamily,
      extensions: <ThemeExtension<dynamic>>[colors],
      textTheme: base.copyWith(
        bodySmall: _text(colors.textSecondary, 12, FontWeight.w400),
        bodyMedium: _text(colors.textSecondary, 14, FontWeight.w400),
        bodyLarge: _text(colors.textPrimary, 14, FontWeight.w400),
        titleSmall: _text(colors.textPrimary, 18, FontWeight.w500, -0.2),
        titleMedium: _text(colors.textPrimary, 24, FontWeight.w600, -0.5),
        titleLarge: _text(colors.textPrimary, 28, FontWeight.w600, -0.5),
        headlineSmall: _text(colors.textPrimary, 32, FontWeight.w600, -0.7),
        labelSmall: _text(
          colors.textSecondary.withValues(alpha: 0.55),
          12,
          FontWeight.w400,
        ),
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
          borderSide: BorderSide(color: colors.accent, width: 1.4),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.accent,
        selectionColor: colors.accent.withValues(alpha: 0.22),
        selectionHandleColor: colors.accent,
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
      hoverColor: colors.accent.withValues(alpha: 0.08),
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
  // 정제된 중성 슬레이트 팔레트 (탁한 푸른기 제거)
  static const Color bgDeep = Color(0xFF0B0E14);
  static const Color bgPrimary = Color(0xFF0B0E14);
  static const Color bgSecondary = Color(0xFF151922);
  static const Color bgTertiary = Color(0xFF11151D);
  static const Color bgQuaternary = Color(0xFF0E121A);
  static const Color borderSubtle = Color(0xFF20262F);
  static const Color borderDefault = Color(0xFF242A36);
  static const Color borderStrong = Color(0xFF323948);
  static const Color borderFocus = Color(0xFF6E83FF);
  static const Color textPrimary = Color(0xFFF3F5F9);
  static const Color textSecondary = Color(0xFF99A2B2);
  static const Color textTertiary = Color(0xFF8A93A4);
  static const Color textMuted = Color(0xFF687085);
  static const Color accent = Color(0xFF6E83FF);
  static const Color accentDim = Color(0x1A6E83FF);
  static const Color accentMuted = Color(0xFFA6B4FF);
  static const Color accentHover = Color(0xFF8497FF);
  static const Color accentGlow = Color(0x246E83FF);
  static const Color blue = Color(0xFF6E83FF);
  static const Color blueDim = Color(0x1A6E83FF);
  static const Color purple = Color(0xFF9B8BFF);
  static const Color purpleDim = Color(0x149B8BFF);
  static const Color red = Color(0xFFE8705E);
  static const Color redDim = Color(0x14E8705E);
  static const Color green = Color(0xFF54B98A);
  static const Color greenDim = Color(0x1454B98A);
  static const Color yellow = Color(0xFFD2A24A);
  static const Color yellowDim = Color(0x14D2A24A);

  static TextStyle get displayLarge =>
      _text(textPrimary, 32, FontWeight.w600, -0.5);
  static TextStyle get displayMedium =>
      _text(textPrimary, 28, FontWeight.w600, -0.5);
  static TextStyle get headingLarge =>
      _text(textPrimary, 24, FontWeight.w600, -0.5);
  static TextStyle get headingMedium =>
      _text(textPrimary, 18, FontWeight.w500, -0.2);
  static TextStyle get headingSmall =>
      _text(textPrimary, 16, FontWeight.w500, -0.1);
  static TextStyle get bodyLarge => _text(textPrimary, 14, FontWeight.w400);
  static TextStyle get bodyMedium => _text(textSecondary, 14, FontWeight.w400);
  static TextStyle get bodySmall =>
      _text(textSecondary.withValues(alpha: 0.55), 12, FontWeight.w400);
  static TextStyle get labelMedium => _text(textSecondary, 14, FontWeight.w500);
  static TextStyle get labelSmall =>
      _text(textSecondary.withValues(alpha: 0.55), 12, FontWeight.w400);
  static TextStyle get caption =>
      _text(textSecondary.withValues(alpha: 0.55), 12, FontWeight.w400);
}

// ─────────────────────────────────────────────────────────────────────────────
// Gradients
// ─────────────────────────────────────────────────────────────────────────────

class AppGradients {
  const AppGradients._();

  static const LinearGradient accent = LinearGradient(
    colors: [Color(0xFF6E83FF), Color(0xFF8E7BFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentSoft = LinearGradient(
    colors: [Color(0x226E83FF), Color(0x229B8BFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroCard = LinearGradient(
    colors: [Color(0xFF1A1F2C), Color(0xFF10131B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surface = LinearGradient(
    colors: [Color(0xFF1A1F2A), Color(0xFF151922)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shadows
// ─────────────────────────────────────────────────────────────────────────────

class AppShadows {
  const AppShadows._();

  // 부드럽고 확산되는 2-레이어 그림자 (앰비언트 + 키)
  static List<BoxShadow> get elevation1 => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.18),
      blurRadius: 12,
      spreadRadius: -2,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.10),
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get elevation2 => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.22),
      blurRadius: 28,
      spreadRadius: -6,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 8,
      spreadRadius: -2,
      offset: const Offset(0, 3),
    ),
  ];

  static List<BoxShadow> get floating => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.30),
      blurRadius: 40,
      spreadRadius: -8,
      offset: const Offset(0, 18),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.14),
      blurRadius: 12,
      spreadRadius: -2,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> accentGlow(Color color, {double intensity = 0.28}) => [
    BoxShadow(
      color: color.withValues(alpha: intensity),
      blurRadius: 28,
      spreadRadius: -4,
    ),
  ];

  static List<BoxShadow> cardHover(Color accentColor) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.18),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: accentColor.withValues(alpha: 0.10),
      blurRadius: 32,
      spreadRadius: -6,
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Project palette  (emoji icon backgrounds)
// ─────────────────────────────────────────────────────────────────────────────

class AppProjectColors {
  const AppProjectColors._();

  // 슬레이트+인디고 테마에 어울리는 정제된 조화 팔레트
  static const List<Color> palette = [
    Color(0xFF2C3578), // indigo
    Color(0xFF43307E), // violet
    Color(0xFF1C5A45), // emerald
    Color(0xFF6E2A44), // rose
    Color(0xFF5C4420), // amber
    Color(0xFF1E4E6E), // sky
    Color(0xFF562462), // fuchsia
    Color(0xFF1F5454), // teal
  ];

  static Color forIndex(int i) => palette[i % palette.length];
}

class AppEmojiSet {
  const AppEmojiSet._();

  static const List<String> projectEmojis = [
    '📚',
    '🧠',
    '⚡',
    '🎯',
    '🔬',
    '💡',
    '🛠',
    '🌿',
    '🚀',
    '📝',
    '🎨',
    '🔢',
    '💻',
    '🌍',
    '🎵',
    '⭐',
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
    final foreground = danger || !outlined ? Colors.white : colors.textPrimary;

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
              border: Border.all(color: outlined ? colors.border : background),
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
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(color: foreground),
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
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
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
