import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/provider_config.dart';
import '../../core/theme.dart';
import '../../core/ui/app_components.dart';
import '../../providers/user_provider.dart';
import '../file/file_screen.dart';
import '../settings/profile_settings_screen.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class SearchResult {
  final String fileId;
  final String projectId;
  final String title;
  final String contentPreview;
  final double score;
  final String tags;

  const SearchResult({
    required this.fileId,
    required this.projectId,
    required this.title,
    required this.contentPreview,
    required this.score,
    required this.tags,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
    fileId: json['file_id'] ?? '',
    projectId: json['project_id'] ?? '',
    title: json['title'] ?? '제목 없음',
    contentPreview: json['content_preview'] ?? '',
    score: (json['score'] ?? 0).toDouble(),
    tags: json['tags'] ?? '',
  );
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with TickerProviderStateMixin {
  final _queryController = TextEditingController();
  final _focusNode = FocusNode();
  List<SearchResult> _results = const [];
  bool _loading = false;
  bool _searched = false;
  String _mode = 'semantic';

  late AnimationController _bgCtrl;
  late AnimationController _enterCtrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _fade = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 24),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));

    _enterCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _enterCtrl.dispose();
    _queryController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    final user = ref.read(userProvider);
    if (query.isEmpty || user == null) return;

    HapticFeedback.lightImpact();
    setState(() {
      _loading = true;
      _searched = true;
      _results = const [];
    });

    try {
      final endpoint =
          _mode == 'semantic' ? '/api/search/semantic' : '/api/search/keyword';
      final response = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'query': query, 'user_id': user.id, 'limit': 20}),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _results = data.map((item) => SearchResult.fromJson(item)).toList();
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
        _showToast('검색에 실패했습니다.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showToast('검색에 실패했습니다.');
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
  }

  void _clearSearch() {
    setState(() {
      _queryController.clear();
      _results = const [];
      _searched = false;
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final user = ref.watch(userProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // ── Animated aurora background ───────────────────────────────────
          Positioned.fill(child: _SearchAurora(ctrl: _bgCtrl)),

          // ── Main content ─────────────────────────────────────────────────
          SafeArea(
            child: AnimatedBuilder(
              animation: _enterCtrl,
              builder: (context, child) => Transform.translate(
                offset: _slide.value,
                child: Opacity(opacity: _fade.value, child: child),
              ),
              child: Column(
                children: [
                  // Top bar
                  _SearchTopBar(
                    onBack: () => Navigator.pop(context),
                    onSettings: user == null
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProfileSettingsScreen(user: user),
                            ),
                          ),
                  ),

                  // Search input area
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Column(
                      children: [
                        _AnimatedSearchBar(
                          controller: _queryController,
                          focusNode: _focusNode,
                          onSubmitted: (_) => _search(),
                          onSearch: _search,
                          onClear: _clearSearch,
                        ),
                        const SizedBox(height: 12),
                        _ModePills(
                          selected: _mode,
                          onChanged: (m) => setState(() => _mode = m),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Results area
                  Expanded(child: _buildBody()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const _SearchSkeleton();

    if (!_searched) return _SearchIdleState(onSearch: (label) {
      _queryController.text = label;
      _search();
    });

    if (_results.isEmpty) {
      return _SearchEmptyState(
        query: _queryController.text.trim(),
        onClear: _clearSearch,
      );
    }

    return _SearchResultList(
      results: _results,
      onOpen: (result) => Navigator.push(
        context,
        _fadeRoute(FileScreen(fileId: result.fileId)),
      ),
    );
  }
}

// ─── Page route ───────────────────────────────────────────────────────────────

Route<T> _fadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (ctx, anim, __) => page,
    transitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (ctx, anim, sec, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.04, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

// ─── Aurora background ────────────────────────────────────────────────────────

class _SearchAurora extends StatelessWidget {
  final AnimationController ctrl;
  const _SearchAurora({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        final t = CurvedAnimation(parent: ctrl, curve: Curves.easeInOut).value;
        return IgnorePointer(
          child: Stack(
            children: [
              Container(color: colors.background),
              Positioned(
                top: lerpDouble(-120, -60, t),
                left: lerpDouble(-80, -20, t),
                child: _Orb(
                  color: colors.accent.withValues(alpha: 0.14),
                  size: 460,
                ),
              ),
              Positioned(
                bottom: lerpDouble(-100, -60, t),
                right: lerpDouble(-60, -10, t),
                child: _Orb(
                  color: const Color(0xFF9B8BFF).withValues(alpha: 0.09),
                  size: 380,
                ),
              ),
              Positioned(
                top: lerpDouble(200, 260, t),
                right: lerpDouble(-40, 20, t),
                child: _Orb(
                  color: colors.accent.withValues(alpha: 0.06),
                  size: 280,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Orb extends StatelessWidget {
  final Color color;
  final double size;
  const _Orb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

// ─── Top bar ──────────────────────────────────────────────────────────────────

class _SearchTopBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onSettings;

  const _SearchTopBar({required this.onBack, this.onSettings});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          // Back button
          AppPressable(
            scaleFactor: 0.93,
            onTap: onBack,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Icon(
                LucideIcons.arrowLeft,
                size: 15,
                color: colors.textSecondary,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Logo / wordmark
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [colors.accent, const Color(0xFF9B8BFF)],
            ).createShader(bounds),
            child: Text(
              AppTheme.brandName,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
          ),

          const Spacer(),

          // Hint chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.56),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.border.withValues(alpha: 0.7)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.command,
                  size: 11,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: 3),
                Text(
                  'K',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          if (onSettings != null) ...[
            const SizedBox(width: 8),
            AppPressable(
              scaleFactor: 0.93,
              onTap: onSettings!,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.border),
                ),
                child: Icon(
                  LucideIcons.settings2,
                  size: 15,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Animated search bar ──────────────────────────────────────────────────────

class _AnimatedSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  const _AnimatedSearchBar({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onSearch,
    required this.onClear,
  });

  @override
  State<_AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<_AnimatedSearchBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late Animation<double> _glow;
  bool _focused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _glow = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeOut);

    widget.focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChange);
  }

  void _onFocusChange() {
    final focused = widget.focusNode.hasFocus;
    setState(() => _focused = focused);
    if (focused) {
      _glowCtrl.forward();
    } else {
      _glowCtrl.reverse();
    }
  }

  void _onTextChange() {
    final hasText = widget.controller.text.isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    widget.controller.removeListener(_onTextChange);
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        final glowAlpha = (_glow.value * 0.32).clamp(0.0, 1.0);
        final borderAlpha = 0.18 + _glow.value * 0.44;

        return Container(
          height: 56,
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.accent.withValues(alpha: borderAlpha),
              width: _focused ? 1.5 : 1,
            ),
            boxShadow: [
              if (_focused)
                BoxShadow(
                  color: colors.accent.withValues(alpha: glowAlpha),
                  blurRadius: 24,
                  spreadRadius: -2,
                ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 18, right: 12),
                child: AnimatedBuilder(
                  animation: _glow,
                  builder: (context, _) {
                    final colors = AppTheme.colorsOf(context);
                    return Icon(
                      LucideIcons.search,
                      size: 18,
                      color: Color.lerp(
                        colors.textSecondary,
                        colors.accent,
                        _glow.value,
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  onSubmitted: widget.onSubmitted,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.colorsOf(context).textPrimary,
                    letterSpacing: -0.1,
                  ),
                  decoration: InputDecoration(
                    hintText: '문서, 노트, 개념을 검색해 보세요…',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 15,
                      color: AppTheme.colorsOf(
                        context,
                      ).textSecondary.withValues(alpha: 0.6),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),

              // Clear + search buttons
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: _hasText
                    ? Row(
                        key: const ValueKey('with-text'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _BarIconBtn(
                            icon: LucideIcons.x,
                            onTap: widget.onClear,
                            tooltip: '지우기',
                          ),
                          const SizedBox(width: 4),
                          _SearchEnterBtn(onTap: widget.onSearch),
                          const SizedBox(width: 6),
                        ],
                      )
                    : const SizedBox(key: ValueKey('empty'), width: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarIconBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  const _BarIconBtn({required this.icon, required this.onTap, this.tooltip});

  @override
  State<_BarIconBtn> createState() => _BarIconBtnState();
}

class _BarIconBtnState extends State<_BarIconBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final child = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: _hovered
                ? colors.accent.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(widget.icon, size: 14, color: colors.textSecondary),
        ),
      ),
    );
    return widget.tooltip != null
        ? Tooltip(message: widget.tooltip!, child: child)
        : child;
  }
}

class _SearchEnterBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _SearchEnterBtn({required this.onTap});

  @override
  State<_SearchEnterBtn> createState() => _SearchEnterBtnState();
}

class _SearchEnterBtnState extends State<_SearchEnterBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colors.accent, const Color(0xFF9B8BFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: AppShadows.accentGlow(colors.accent, intensity: 0.22),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '검색',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(LucideIcons.cornerDownLeft, size: 12, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mode pills ───────────────────────────────────────────────────────────────

class _ModePills extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _ModePills({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Pill(
          label: '의미 검색',
          icon: LucideIcons.sparkles,
          selected: selected == 'semantic',
          onTap: () => onChanged('semantic'),
          selectedColor: colors.accent,
        ),
        const SizedBox(width: 8),
        _Pill(
          label: '키워드 검색',
          icon: LucideIcons.type,
          selected: selected == 'keyword',
          onTap: () => onChanged('keyword'),
          selectedColor: const Color(0xFF9B8BFF),
        ),
      ],
    );
  }
}

class _Pill extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;

  const _Pill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.selectedColor,
  });

  @override
  State<_Pill> createState() => _PillState();
}

class _PillState extends State<_Pill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: widget.selected
                ? LinearGradient(
                    colors: [
                      widget.selectedColor.withValues(alpha: 0.22),
                      widget.selectedColor.withValues(alpha: 0.12),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: widget.selected
                ? null
                : (_hovered
                      ? colors.surface.withValues(alpha: 0.64)
                      : colors.surface.withValues(alpha: 0.38)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.selected
                  ? widget.selectedColor.withValues(alpha: 0.44)
                  : colors.border.withValues(alpha: 0.7),
              width: widget.selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 13,
                color: widget.selected
                    ? widget.selectedColor
                    : colors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight:
                      widget.selected ? FontWeight.w700 : FontWeight.w500,
                  color: widget.selected
                      ? widget.selectedColor
                      : colors.textSecondary,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Result list ──────────────────────────────────────────────────────────────

class _SearchResultList extends StatelessWidget {
  final List<SearchResult> results;
  final ValueChanged<SearchResult> onOpen;

  const _SearchResultList({required this.results, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return ListView.builder(
      key: const PageStorageKey('search-results'),
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
      itemCount: results.length + 1,
      itemBuilder: (ctx, index) {
        if (index == 0) {
          return AppFadeSlide(
            delay: const Duration(milliseconds: 60),
            beginOffset: const Offset(0, 10),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: colors.accent.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Text(
                      '${results.length}개',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colors.accent,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '검색 결과',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final result = results[index - 1];
        return AppFadeSlide(
          delay: Duration(milliseconds: 80 + (index - 1) * 38),
          beginOffset: const Offset(0, 16),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: index == results.length ? 0 : 10,
            ),
            child: _SearchResultTile(
              result: result,
              onOpen: () => onOpen(result),
            ),
          ),
        );
      },
    );
  }
}

class _SearchResultTile extends StatefulWidget {
  final SearchResult result;
  final VoidCallback onOpen;

  const _SearchResultTile({required this.result, required this.onOpen});

  @override
  State<_SearchResultTile> createState() => _SearchResultTileState();
}

class _SearchResultTileState extends State<_SearchResultTile>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late AnimationController _ctrl;
  late Animation<double> _hover;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _hover = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _enter() {
    setState(() => _hovered = true);
    _ctrl.forward();
  }

  void _exit() {
    setState(() => _hovered = false);
    _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final tags = widget.result.tags
        .split(',')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();

    final pct = (widget.result.score * 100).round();
    final scoreColor = pct >= 80
        ? const Color(0xFF4ADE80)
        : pct >= 60
        ? colors.accent
        : colors.textSecondary;

    return MouseRegion(
      onEnter: (_) => _enter(),
      onExit: (_) => _exit(),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onOpen,
        child: AnimatedBuilder(
          animation: _hover,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, -2 * _hover.value),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.lerp(
                        colors.surface.withValues(alpha: 0.82),
                        colors.surface.withValues(alpha: 0.96),
                        _hover.value,
                      )!,
                      Color.lerp(
                        colors.surface.withValues(alpha: 0.72),
                        colors.surface.withValues(alpha: 0.88),
                        _hover.value,
                      )!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Color.lerp(
                      colors.border,
                      colors.accent.withValues(alpha: 0.32),
                      _hover.value,
                    )!,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: lerpDouble(0.08, 0.18, _hover.value)!,
                      ),
                      blurRadius: lerpDouble(6, 20, _hover.value)!,
                      offset: Offset(0, lerpDouble(2, 8, _hover.value)!),
                    ),
                    if (_hovered)
                      BoxShadow(
                        color: colors.accent.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: child,
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                children: [
                  // File type icon
                  Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.colorsOf(
                        context,
                      ).accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.colorsOf(
                          context,
                        ).accent.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Icon(
                      LucideIcons.fileText,
                      size: 14,
                      color: AppTheme.colorsOf(context).accent,
                    ),
                  ),

                  Expanded(
                    child: Text(
                      widget.result.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.colorsOf(context).textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Score badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: scoreColor.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Text(
                      '$pct%',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: scoreColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),

                  // Arrow
                  AnimatedBuilder(
                    animation: _hover,
                    builder: (ctx, _) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Opacity(
                        opacity: _hover.value,
                        child: Icon(
                          LucideIcons.arrowUpRight,
                          size: 14,
                          color: AppTheme.colorsOf(ctx).accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              if (widget.result.contentPreview.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  widget.result.contentPreview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.colorsOf(
                      context,
                    ).textSecondary.withValues(alpha: 0.9),
                    height: 1.5,
                  ),
                ),
              ],

              if (tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags.take(4).map((tag) => _TagChip(label: tag)).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.border.withValues(alpha: 0.7)),
      ),
      child: Text(
        '#$label',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: colors.textSecondary,
        ),
      ),
    );
  }
}

// ─── Idle state ───────────────────────────────────────────────────────────────

class _SearchIdleState extends StatelessWidget {
  final ValueChanged<String> onSearch;

  const _SearchIdleState({required this.onSearch});

  static const _suggestions = [
    (LucideIcons.sparkles, '최근 학습한 개념 복습'),
    (LucideIcons.brain, '핵심 요약 찾기'),
    (LucideIcons.gitBranch, '연관 주제 탐색'),
    (LucideIcons.bookOpen, '강의 노트 검색'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppFadeSlide(
            delay: const Duration(milliseconds: 100),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                '검색 제안',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          ...List.generate(_suggestions.length, (i) {
            final (icon, label) = _suggestions[i];
            return AppFadeSlide(
              delay: Duration(milliseconds: 130 + i * 50),
              beginOffset: const Offset(0, 12),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SuggestionRow(
                  icon: icon,
                  label: label,
                  onTap: () => onSearch(label),
                ),
              ),
            );
          }),
          const SizedBox(height: 32),
          AppFadeSlide(
            delay: const Duration(milliseconds: 360),
            child: Center(
              child: Column(
                children: [
                  AppPulse(
                    duration: const Duration(milliseconds: 2200),
                    minOpacity: 0.3,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: AppGradients.accentSoft,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.accent.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(
                        LucideIcons.search,
                        size: 22,
                        color: colors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '워크스페이스 전체 검색',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '노트, 태그, 개념을 의미 기반으로 탐색합니다.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _SuggestionRow({required this.icon, required this.label, this.onTap});

  @override
  State<_SuggestionRow> createState() => _SuggestionRowState();
}

class _SuggestionRowState extends State<_SuggestionRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: _hovered
              ? colors.surface.withValues(alpha: 0.72)
              : colors.surface.withValues(alpha: 0.36),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hovered
                ? colors.accent.withValues(alpha: 0.22)
                : colors.border.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            Icon(
              widget.icon,
              size: 14,
              color: _hovered ? colors.accent : colors.textSecondary,
            ),
            const SizedBox(width: 10),
            Text(
              widget.label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _hovered ? colors.textPrimary : colors.textSecondary,
              ),
            ),
            const Spacer(),
            AnimatedOpacity(
              opacity: _hovered ? 1 : 0,
              duration: const Duration(milliseconds: 120),
              child: Icon(
                LucideIcons.arrowRight,
                size: 13,
                color: colors.accent,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _SearchEmptyState extends StatelessWidget {
  final String query;
  final VoidCallback onClear;

  const _SearchEmptyState({required this.query, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return Center(
      child: AppFadeSlide(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.72),
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.border),
                ),
                child: Icon(
                  LucideIcons.searchX,
                  size: 26,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '"$query"',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                '에 대한 결과를 찾지 못했습니다.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              AppButton(
                label: '검색어 지우기',
                onPressed: onClear,
                primary: false,
                icon: LucideIcons.x,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Skeleton ─────────────────────────────────────────────────────────────────

class _SearchSkeleton extends StatelessWidget {
  const _SearchSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      itemCount: 5,
      itemBuilder: (ctx, index) => AppFadeSlide(
        delay: Duration(milliseconds: index * 50),
        child: Padding(
          padding: EdgeInsets.only(bottom: index == 4 ? 0 : 10),
          child: AppShimmer(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppSkeletonLine(
                        width: 32,
                        height: 32,
                        color: colors.border,
                      ),
                      const SizedBox(width: 10),
                      AppSkeletonLine(
                        width: 160 + (index % 3) * 30.0,
                        height: 14,
                        color: colors.border,
                      ),
                      const Spacer(),
                      AppSkeletonLine(
                        width: 36,
                        height: 22,
                        color: colors.border,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AppSkeletonLine(
                    width: double.infinity,
                    height: 11,
                    color: colors.border,
                  ),
                  const SizedBox(height: 6),
                  AppSkeletonLine(
                    width: 200 + (index % 2) * 40.0,
                    height: 11,
                    color: colors.border,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      AppSkeletonLine(
                        width: 60,
                        height: 20,
                        color: colors.border,
                      ),
                      const SizedBox(width: 6),
                      AppSkeletonLine(
                        width: 50,
                        height: 20,
                        color: colors.border,
                      ),
                    ],
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
