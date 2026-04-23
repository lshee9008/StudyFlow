import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color bgDeep = Color(0xFF060816);
  static const Color bgPrimary = Color(0xFF0B1020);
  static const Color bgSecondary = Color(0xFF121A2E);
  static const Color bgTertiary = Color(0xFF18233B);
  static const Color bgQuaternary = Color(0xFF213252);

  static const Color borderSubtle = Color(0xFF1F2A42);
  static const Color borderDefault = Color(0xFF2A3957);
  static const Color borderStrong = Color(0xFF45628E);
  static const Color borderFocus = Color(0xFF74F2CE);

  static const Color textPrimary = Color(0xFFF7FAFF);
  static const Color textSecondary = Color(0xFFAAB8D6);
  static const Color textTertiary = Color(0xFF7283A8);
  static const Color textMuted = Color(0xFF485776);

  static const Color accent = Color(0xFFB8FF5B);
  static const Color accentDim = Color(0xFF1E3211);
  static const Color accentMuted = Color(0xFF84D72B);
  static const Color accentHover = Color(0xFFD2FF89);
  static const Color accentGlow = Color(0x3DB8FF5B);

  static const Color blue = Color(0xFF67D6FF);
  static const Color blueDim = Color(0xFF0E2840);
  static const Color purple = Color(0xFF7F8CFF);
  static const Color purpleDim = Color(0xFF1B214B);
  static const Color red = Color(0xFFFF6E7D);
  static const Color redDim = Color(0xFF33151A);
  static const Color green = Color(0xFF40E7C2);
  static const Color greenDim = Color(0xFF0C2722);
  static const Color yellow = Color(0xFFFFC857);
  static const Color yellowDim = Color(0xFF392A09);

  static String get fontFamily => GoogleFonts.notoSansKr().fontFamily!;

  static ThemeData get darkTheme {
    final base = GoogleFonts.notoSansKrTextTheme();
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgPrimary,
      primaryColor: accent,
      fontFamily: fontFamily,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: blue,
        surface: bgSecondary,
        onSurface: textPrimary,
        error: red,
      ),
      textTheme: base.copyWith(
        displayLarge: _headline(58, FontWeight.w800, letterSpacing: -2.6),
        displayMedium: _headline(40, FontWeight.w800, letterSpacing: -1.8),
        headlineLarge: _headline(26, FontWeight.w700, letterSpacing: -0.9),
        headlineMedium: _headline(20, FontWeight.w700, letterSpacing: -0.4),
        bodyLarge: _body(15, textSecondary, 1.72),
        bodyMedium: _body(13, textSecondary, 1.6),
        labelMedium: _label(12, textSecondary, FontWeight.w600, 0.1),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: textSecondary, size: 20),
        titleTextStyle: _label(15, textPrimary, FontWeight.w700, -0.2),
      ),
      dividerTheme: const DividerThemeData(
        color: borderSubtle,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: _body(14, textMuted, 1.5),
        filled: true,
        fillColor: bgSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: borderFocus, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: _label(14, Colors.black, FontWeight.w800, -0.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: _label(14, textSecondary, FontWeight.w600, -0.1),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: bgSecondary,
        elevation: 20,
        shadowColor: Colors.black.withValues(alpha: 0.45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderDefault),
        ),
        textStyle: _body(13, textPrimary, 1.5),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(borderStrong),
        thickness: WidgetStateProperty.all(4),
        radius: const Radius.circular(4),
      ),
    );
  }

  static TextStyle _headline(
    double size,
    FontWeight weight, {
    double letterSpacing = 0,
  }) {
    return GoogleFonts.notoSansKr(
      fontSize: size,
      fontWeight: weight,
      color: textPrimary,
      letterSpacing: letterSpacing,
      height: 1.1,
    );
  }

  static TextStyle _body(double size, Color color, double height) {
    return GoogleFonts.notoSansKr(
      fontSize: size,
      fontWeight: FontWeight.w400,
      color: color,
      height: height,
    );
  }

  static TextStyle _label(
    double size,
    Color color,
    FontWeight weight,
    double letterSpacing,
  ) {
    return GoogleFonts.notoSansKr(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: 1.3,
    );
  }

  static TextStyle get displayLarge =>
      _headline(58, FontWeight.w800, letterSpacing: -2.6);
  static TextStyle get displayMedium =>
      _headline(40, FontWeight.w800, letterSpacing: -1.8);
  static TextStyle get headingLarge =>
      _headline(26, FontWeight.w700, letterSpacing: -0.9);
  static TextStyle get headingMedium =>
      _headline(20, FontWeight.w700, letterSpacing: -0.4);
  static TextStyle get headingSmall =>
      _label(14, textPrimary, FontWeight.w700, -0.1);
  static TextStyle get bodyLarge => _body(15, textSecondary, 1.72);
  static TextStyle get bodyMedium => _body(13, textSecondary, 1.6);
  static TextStyle get bodySmall => _body(12, textTertiary, 1.5);
  static TextStyle get labelMedium =>
      _label(12, textSecondary, FontWeight.w600, 0.1);
  static TextStyle get labelSmall =>
      _label(11, textTertiary, FontWeight.w600, 0.25);
  static TextStyle get caption => _body(11, textMuted, 1.45);
}

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
  State<SFTextField> createState() => _SFTextFieldState();
}

class _SFTextFieldState extends State<SFTextField> {
  bool _obscure = false;
  bool _focused = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscure;
    _focusNode = FocusNode()
      ..addListener(() => setState(() => _focused = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _focusNode.dispose();
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
          const SizedBox(height: 9),
        ],
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _focused ? AppTheme.borderFocus : AppTheme.borderDefault,
              width: _focused ? 1.4 : 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.bgSecondary,
                AppTheme.bgTertiary.withValues(alpha: 0.86),
              ],
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: AppTheme.accentGlow,
                      blurRadius: 26,
                      spreadRadius: -10,
                    ),
                  ]
                : null,
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            obscureText: _obscure,
            keyboardType: widget.keyboardType,
            autofocus: widget.autofocus,
            style: AppTheme.bodyLarge.copyWith(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: widget.hint,
              hintStyle: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textMuted,
              ),
              filled: false,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              prefixIcon: widget.prefixIcon == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(left: 8, right: 2),
                      child: Icon(
                        widget.prefixIcon,
                        color: _focused
                            ? AppTheme.borderFocus
                            : AppTheme.textMuted,
                        size: 19,
                      ),
                    ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 44,
                minHeight: 44,
              ),
              suffixIcon: widget.obscure
                  ? IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                        color: AppTheme.textMuted,
                      ),
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
  State<SFButton> createState() => _SFButtonState();
}

class _SFButtonState extends State<SFButton> {
  bool _hovering = false;
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    final bool primary = !widget.outlined && !widget.danger;
    final Color fg = widget.danger
        ? AppTheme.red
        : widget.outlined
        ? AppTheme.textPrimary
        : Colors.black;

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
          duration: const Duration(milliseconds: 140),
          width: widget.width,
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          transform: _pressing
              ? (Matrix4.identity()..scaleByDouble(0.985, 0.985, 1, 1))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            gradient: primary
                ? LinearGradient(
                    colors: _hovering
                        ? [AppTheme.accentHover, AppTheme.accent]
                        : [AppTheme.accent, AppTheme.accentMuted],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: widget.danger
                ? (_hovering
                      ? AppTheme.red.withValues(alpha: 0.16)
                      : AppTheme.red.withValues(alpha: 0.10))
                : widget.outlined
                ? (_hovering
                      ? AppTheme.bgTertiary.withValues(alpha: 0.82)
                      : AppTheme.bgSecondary.withValues(alpha: 0.62))
                : null,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.danger
                  ? AppTheme.red.withValues(alpha: 0.32)
                  : widget.outlined
                  ? (_hovering ? AppTheme.borderStrong : AppTheme.borderDefault)
                  : Colors.transparent,
            ),
            boxShadow: primary
                ? [
                    BoxShadow(
                      color: AppTheme.accent.withValues(
                        alpha: _hovering ? 0.30 : 0.18,
                      ),
                      blurRadius: _hovering ? 28 : 18,
                      offset: const Offset(0, 10),
                      spreadRadius: -10,
                    ),
                  ]
                : null,
          ),
          child: widget.isLoading
              ? SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 16, color: fg),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.label,
                      style: AppTheme.labelMedium.copyWith(
                        color: fg,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
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

  const SFLogo({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.30),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFD8FF8C), Color(0xFF91F126)],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.32),
                blurRadius: size * 0.75,
                offset: Offset(0, size * 0.18),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Center(
            child: Text(
              'S',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.black,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.58,
                letterSpacing: -1.2,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'StudyFlow',
          style: GoogleFonts.spaceGrotesk(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.54,
            letterSpacing: -0.9,
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

  const SFBadge({super.key, required this.label, this.color, this.bgColor});

  @override
  Widget build(BuildContext context) {
    final Color c = color ?? AppTheme.accent;
    final Color bg = bgColor ?? AppTheme.accentDim;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: AppTheme.labelSmall.copyWith(
          color: c,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class SFDivider extends StatelessWidget {
  final EdgeInsetsGeometry? margin;

  const SFDivider({super.key, this.margin});

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
