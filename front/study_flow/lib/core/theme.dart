import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Color System ──────────────────────────────────
  // 기존 flat 회색 → 블루/바이올렛 틴트 다크 (Linear/Vercel/VS Code 계열)
  // 배경 레이어 간 명확한 구분, 더 풍부한 느낌

  static const Color bgDeep      = Color(0xFF0C0C11); // 앱 최하단 (near-black + blue)
  static const Color bgPrimary   = Color(0xFF12121A); // scaffold 메인
  static const Color bgSecondary = Color(0xFF1A1A26); // 카드 · 패널
  static const Color bgTertiary  = Color(0xFF22222F); // 호버 · 드롭다운
  static const Color bgQuaternary= Color(0xFF2C2C3C); // 선택 · 강조

  static const Color borderSubtle  = Color(0xFF252535);
  static const Color borderDefault = Color(0xFF363650);
  static const Color borderStrong  = Color(0xFF4E4E6A);
  static const Color borderFocus   = Color(0xFF7070A0);

  static const Color textPrimary   = Color(0xFFF0F0F8); // 약간 blue-white
  static const Color textSecondary = Color(0xFF9898B8); // blue-gray
  static const Color textTertiary  = Color(0xFF60607A); // muted
  static const Color textMuted     = Color(0xFF3E3E52); // 거의 안 보임

  // 액센트 — 라임 그린 유지, dim 더 밝게
  static const Color accent      = Color(0xFFCCFF66);
  static const Color accentDim   = Color(0xFF1E2E07); // 이전보다 더 보임
  static const Color accentMuted = Color(0xFF88CC00);
  static const Color accentHover = Color(0xFFD6FF7A);
  static const Color accentGlow  = Color(0x2ACCFF66); // 글로우 강화

  // 서포팅 컬러 — 채도 +10~15%
  static const Color blue       = Color(0xFF7AADFF);
  static const Color blueDim    = Color(0xFF0E1C38);
  static const Color purple     = Color(0xFFAA80FF);
  static const Color purpleDim  = Color(0xFF1A1240);
  static const Color red        = Color(0xFFFF6B8A);
  static const Color redDim     = Color(0xFF2A0D16);
  static const Color green      = Color(0xFF3DEAAA);
  static const Color greenDim   = Color(0xFF081E14);
  static const Color yellow     = Color(0xFFFFDA4D);
  static const Color yellowDim  = Color(0xFF231A00);

  // ── Font Family ───────────────────────────────────
  static String get fontFamily => GoogleFonts.inter().fontFamily!;

  // ── ThemeData ─────────────────────────────────────
  static ThemeData get darkTheme {
    final base = GoogleFonts.interTextTheme();
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgPrimary,
      primaryColor: accent,
      fontFamily: fontFamily,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: blue,
        background: bgPrimary,
        surface: bgSecondary,
        onBackground: textPrimary,
        onSurface: textPrimary,
        error: red,
      ),
      textTheme: base
          .copyWith(
            displayLarge: base.displayLarge?.copyWith(
              fontSize: 52,
              fontWeight: FontWeight.w800,
              color: textPrimary,
              letterSpacing: -2.0,
              height: 1.1,
            ),
            displayMedium: base.displayMedium?.copyWith(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: textPrimary,
              letterSpacing: -1.2,
              height: 1.2,
            ),
            headlineLarge: base.headlineLarge?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: textPrimary,
              letterSpacing: -0.5,
              height: 1.3,
            ),
            headlineMedium: base.headlineMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textPrimary,
              letterSpacing: -0.3,
              height: 1.4,
            ),
            bodyLarge: base.bodyLarge?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: textSecondary,
              height: 1.65,
            ),
            bodyMedium: base.bodyMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: textSecondary,
              height: 1.55,
            ),
            labelMedium: base.labelMedium?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textSecondary,
              letterSpacing: 0.1,
            ),
          )
          .apply(
            bodyColor: textSecondary,
            displayColor: textPrimary,
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgPrimary,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: textSecondary, size: 20),
        titleTextStyle: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderSubtle,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: GoogleFonts.inter(color: textMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        filled: true,
        fillColor: bgSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: bgSecondary,
        elevation: 16,
        shadowColor: const Color(0x66000018),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderDefault),
        ),
        textStyle: GoogleFonts.inter(color: textPrimary, fontSize: 13),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(borderStrong),
        thickness: WidgetStateProperty.all(4),
        radius: const Radius.circular(4),
      ),
    );
  }

  // ── Text Styles ───────────────────────────────────
  static TextStyle get displayLarge => GoogleFonts.inter(
    fontSize: 52, fontWeight: FontWeight.w800,
    color: textPrimary, letterSpacing: -2.0, height: 1.1,
  );
  static TextStyle get displayMedium => GoogleFonts.inter(
    fontSize: 36, fontWeight: FontWeight.w700,
    color: textPrimary, letterSpacing: -1.2, height: 1.2,
  );
  static TextStyle get headingLarge => GoogleFonts.inter(
    fontSize: 24, fontWeight: FontWeight.w700,
    color: textPrimary, letterSpacing: -0.5, height: 1.3,
  );
  static TextStyle get headingMedium => GoogleFonts.inter(
    fontSize: 18, fontWeight: FontWeight.w600,
    color: textPrimary, letterSpacing: -0.3, height: 1.4,
  );
  static TextStyle get headingSmall => GoogleFonts.inter(
    fontSize: 14, fontWeight: FontWeight.w600,
    color: textPrimary, letterSpacing: -0.1,
  );
  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 15, fontWeight: FontWeight.w400,
    color: textSecondary, height: 1.65,
  );
  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 13, fontWeight: FontWeight.w400,
    color: textSecondary, height: 1.55,
  );
  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 12, fontWeight: FontWeight.w400,
    color: textTertiary, height: 1.45,
  );
  static TextStyle get labelMedium => GoogleFonts.inter(
    fontSize: 12, fontWeight: FontWeight.w500,
    color: textSecondary, letterSpacing: 0.1,
  );
  static TextStyle get labelSmall => GoogleFonts.inter(
    fontSize: 11, fontWeight: FontWeight.w500,
    color: textTertiary, letterSpacing: 0.2,
  );
  static TextStyle get caption => GoogleFonts.inter(
    fontSize: 11, fontWeight: FontWeight.w400,
    color: textMuted, height: 1.4,
  );
}

// ══════════════════ 공통 위젯 ════════════════════════

class SFTextField extends StatefulWidget {
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
    Key? key,
    required this.hint,
    required this.controller,
    this.obscure = false,
    this.prefixIcon,
    this.label,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  }) : super(key: key);

  @override
  State<SFTextField> createState() => _SFTextFieldState();
}

class _SFTextFieldState extends State<SFTextField> {
  bool _obscure = false;
  bool _focused = false;
  late FocusNode _fn;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscure;
    _fn = FocusNode()
      ..addListener(() => setState(() => _focused = _fn.hasFocus));
  }

  @override
  void dispose() {
    _fn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppTheme.labelMedium.copyWith(
              color: _focused ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
        ],
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _focused ? AppTheme.accent : AppTheme.borderDefault,
              width: _focused ? 1.5 : 1,
            ),
            color: AppTheme.bgSecondary,
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.10),
                      blurRadius: 16,
                      spreadRadius: -2,
                    ),
                  ]
                : [],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _fn,
            obscureText: _obscure,
            keyboardType: widget.keyboardType,
            autofocus: widget.autofocus,
            style: GoogleFonts.inter(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: GoogleFonts.inter(
                color: AppTheme.textMuted,
                fontSize: 14,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              prefixIcon: widget.prefixIcon != null
                  ? Icon(
                      widget.prefixIcon,
                      size: 18,
                      color: _focused ? AppTheme.accent : AppTheme.textMuted,
                    )
                  : null,
              suffixIcon: widget.obscure
                  ? IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                        color: AppTheme.textMuted,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    )
                  : null,
            ),
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
          ),
        ),
      ],
    );
  }
}

class SFButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool outlined;
  final bool danger;
  final IconData? icon;
  final double? width;
  final double? height;

  const SFButton({
    Key? key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.outlined = false,
    this.danger = false,
    this.icon,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  State<SFButton> createState() => _SFButtonState();
}

class _SFButtonState extends State<SFButton> {
  bool _hovering = false;
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    Border? border;

    if (widget.danger) {
      bg = widget.outlined
          ? Colors.transparent
          : AppTheme.red.withValues(alpha: 0.15);
      fg = AppTheme.red;
      border = Border.all(
        color: AppTheme.red.withValues(
          alpha: widget.outlined ? 0.45 : 0.3,
        ),
      );
    } else if (widget.outlined) {
      bg = Colors.transparent;
      fg = AppTheme.textSecondary;
      border = Border.all(color: AppTheme.borderDefault);
    } else {
      bg = AppTheme.accent;
      fg = Colors.black;
      border = null;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() {
        _hovering = false;
        _pressing = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressing = true),
        onTapUp: (_) => setState(() => _pressing = false),
        onTapCancel: () => setState(() => _pressing = false),
        onTap: widget.isLoading ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: widget.width,
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          transform: _pressing
              ? (Matrix4.identity()..scale(0.97))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: widget.danger
                ? (_hovering
                    ? AppTheme.red.withValues(alpha: 0.22)
                    : bg)
                : widget.outlined
                ? (_hovering ? AppTheme.bgTertiary : Colors.transparent)
                : (_hovering ? AppTheme.accentHover : AppTheme.accent),
            borderRadius: BorderRadius.circular(10),
            border: border,
            boxShadow: !widget.outlined && !widget.danger && _hovering
                ? [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: widget.isLoading
              ? SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: fg,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 15, color: fg),
                      const SizedBox(width: 7),
                    ],
                    Text(
                      widget.label,
                      style: GoogleFonts.inter(
                        color: fg,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class SFLogo extends StatelessWidget {
  final double size;
  const SFLogo({Key? key, this.size = 32}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFD4FF77), Color(0xFF88FF00)],
            ),
            borderRadius: BorderRadius.circular(size * 0.26),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.35),
                blurRadius: size * 0.6,
                offset: Offset(0, size * 0.12),
              ),
            ],
          ),
          child: Center(
            child: Text(
              'S',
              style: GoogleFonts.inter(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.55,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'StudyFlow',
          style: GoogleFonts.inter(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.52,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class SFBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? bgColor;

  const SFBadge({Key? key, required this.label, this.color, this.bgColor})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.accent;
    final bg = bgColor ?? AppTheme.accentDim;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: c,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class SFDivider extends StatelessWidget {
  final EdgeInsetsGeometry? margin;
  const SFDivider({Key? key, this.margin}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? EdgeInsets.zero,
      height: 1,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            AppTheme.borderSubtle,
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
