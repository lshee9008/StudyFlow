import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../core/theme.dart';
import '../../core/provider_config.dart';
import '../../providers/user_provider.dart';
import '../file/file_screen.dart';

// ─── 검색 결과 모델 ───────────────────────────────────────
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
    score: (json['score'] ?? 0.0).toDouble(),
    tags: json['tags'] ?? '',
  );
}

// ─── SearchScreen ─────────────────────────────────────────
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  List<SearchResult> _results = [];
  bool _loading = false;
  bool _hasSearched = false;
  String _mode = 'semantic'; // 'semantic' | 'keyword'

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    final user = ref.read(userProvider);
    if (user == null) return;

    setState(() {
      _loading = true;
      _hasSearched = true;
      _results = [];
    });

    try {
      final endpoint = _mode == 'semantic'
          ? '/api/search/semantic'
          : '/api/search/keyword';
      final response = await http
          .post(
            Uri.parse('http://127.0.0.1:8000$endpoint'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'query': query, 'user_id': user.id, 'limit': 20}),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      if (response.statusCode == 200) {
        final List data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _results = data.map((j) => SearchResult.fromJson(j)).toList();
          _loading = false;
        });
        _animCtrl.forward(from: 0);
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      body: Column(
        children: [
          // ── 검색 헤더 ──────────────────────────────────
          Container(
            color: AppTheme.bgPrimary,
            child: SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
                ),
                child: Column(
                  children: [
                    // 뒤로가기 + 제목
                    Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                      ),
                      onPressed: () => Navigator.pop(context),
                      color: AppTheme.textSecondary,
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 8),
                    Text('노트 검색', style: AppTheme.headingMedium),
                  ],
                ),
                const SizedBox(height: 20),

                // 검색창
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.bgSecondary,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _focusNode.hasFocus
                          ? AppTheme.accent
                          : AppTheme.borderDefault,
                    ),
                    boxShadow: _focusNode.hasFocus
                        ? [
                            BoxShadow(
                              color: AppTheme.accent.withOpacity(0.08),
                              blurRadius: 12,
                              spreadRadius: 0,
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 16),
                        child: Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          focusNode: _focusNode,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                          decoration: const InputDecoration(
                            hintText: '노트 내용, 제목, 태그로 검색...',
                            hintStyle: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 16,
                            ),
                          ),
                          onSubmitted: _search,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      if (_ctrl.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppTheme.textMuted,
                          ),
                          onPressed: () {
                            _ctrl.clear();
                            setState(() {});
                          },
                        ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => _search(_ctrl.text),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _ctrl.text.isNotEmpty
                                  ? AppTheme.accent
                                  : AppTheme.bgTertiary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '검색',
                              style: TextStyle(
                                color: _ctrl.text.isNotEmpty
                                    ? Colors.black
                                    : AppTheme.textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 검색 모드 토글
                Row(
                  children: [
                    _ModeChip(
                      label: '🧠 의미 검색',
                      selected: _mode == 'semantic',
                      onTap: () => setState(() => _mode = 'semantic'),
                    ),
                    const SizedBox(width: 8),
                    _ModeChip(
                      label: '🔤 키워드 검색',
                      selected: _mode == 'keyword',
                      onTap: () => setState(() => _mode = 'keyword'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),  // SafeArea 닫기
      ),  // 바깥 Container 닫기

          // ── 결과 영역 ─────────────────────────────────
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: AppTheme.accent,
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _mode == 'semantic' ? 'AI가 의미를 분석 중...' : '키워드 검색 중...',
              style: AppTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.bgSecondary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.manage_search_rounded,
                size: 40,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            Text('검색어를 입력하세요', style: AppTheme.headingSmall),
            const SizedBox(height: 8),
            Text(
              '정확한 키워드를 몰라도 의미 검색으로 찾을 수 있어요.',
              style: AppTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 16),
            Text('검색 결과가 없어요', style: AppTheme.headingSmall),
            const SizedBox(height: 8),
            Text('다른 검색어를 시도하거나 검색 모드를 바꿔보세요.', style: AppTheme.bodySmall),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _results.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accentDim,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppTheme.accent.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      '${_results.length}개 결과',
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          final r = _results[i - 1];
          return _SearchResultCard(result: r, query: _ctrl.text);
        },
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? AppTheme.accentDim : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected
              ? AppTheme.accent.withOpacity(0.4)
              : AppTheme.borderSubtle,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? AppTheme.accent : AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _SearchResultCard extends StatefulWidget {
  final SearchResult result;
  final String query;
  const _SearchResultCard({required this.result, required this.query});
  @override
  State<_SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<_SearchResultCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final score = widget.result.score;
    final scoreColor = score > 0.7
        ? AppTheme.green
        : score > 0.4
        ? AppTheme.accent
        : AppTheme.textSecondary;
    final tags = widget.result.tags
        .split(',')
        .where((t) => t.trim().isNotEmpty)
        .toList();

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FileScreen(fileId: widget.result.fileId),
          ),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _hover ? AppTheme.bgTertiary : AppTheme.bgSecondary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hover ? AppTheme.borderStrong : AppTheme.borderSubtle,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    size: 16,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.result.title,
                      style: AppTheme.headingSmall.copyWith(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 유사도 점수
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: scoreColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: scoreColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${(score * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: scoreColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                widget.result.contentPreview,
                style: AppTheme.bodySmall.copyWith(
                  height: 1.6,
                  color: AppTheme.textSecondary,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: tags
                      .map(
                        (t) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.bgPrimary,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.borderSubtle),
                          ),
                          child: Text(
                            '#${t.trim()}',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
