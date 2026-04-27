import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/provider_config.dart';
import '../../core/theme.dart';
import '../../core/ui/app_components.dart';
import '../../providers/user_provider.dart';
import '../file/file_screen.dart';

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

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _queryController = TextEditingController();
  final _focusNode = FocusNode();
  List<SearchResult> _results = const [];
  bool _loading = false;
  bool _searched = false;
  String _mode = 'semantic';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    final user = ref.read(userProvider);
    if (query.isEmpty || user == null) {
      return;
    }

    setState(() {
      _loading = true;
      _searched = true;
      _results = const [];
    });

    try {
      final endpoint = _mode == 'semantic'
          ? '/api/search/semantic'
          : '/api/search/keyword';
      final response = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'query': query, 'user_id': user.id, 'limit': 20}),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) {
        return;
      }

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
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      _showToast('검색에 실패했습니다.');
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final userName = ref.watch(userProvider)?.name ?? AppTheme.brandName;
    final isCompact = MediaQuery.of(context).size.width < 980;

    return AppWorkspaceShell(
      currentNav: 'search',
      title: '검색',
      subtitle: '워크스페이스 전체에서 노트, 태그, 개념을 검색합니다.',
      profileLabel: userName,
      compact: isCompact,
      onHome: () => Navigator.popUntil(context, (route) => route.isFirst),
      onWorkspace: () => Navigator.pop(context),
      onSearch: () {},
      onSettings: () {},
      primaryAction: AppButton(
        label: '검색',
        onPressed: _search,
        icon: LucideIcons.search,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              0,
              AppSpace.lg,
              AppSpace.md,
            ),
            child: Column(
              children: [
                _SearchBar(
                  controller: _queryController,
                  focusNode: _focusNode,
                  onSubmitted: (_) => _search(),
                  onSearch: _search,
                  onClear: () => setState(() {
                    _queryController.clear();
                    _results = const [];
                    _searched = false;
                  }),
                ),
                const SizedBox(height: AppSpace.sm),
                Row(
                  children: [
                    _ModeButton(
                      label: '의미',
                      selected: _mode == 'semantic',
                      onTap: () => setState(() => _mode = 'semantic'),
                    ),
                    const SizedBox(width: AppSpace.xs),
                    _ModeButton(
                      label: '키워드',
                      selected: _mode == 'keyword',
                      onTap: () => setState(() => _mode = 'keyword'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const _SearchSkeleton();
    }

    if (!_searched) {
      return Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: AppEmptyState(
          title: '검색어를 입력해 주세요.',
          actionLabel: '검색',
          onAction: _search,
        ),
      );
    }

    if (_results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: AppEmptyState(
          title: '결과가 없습니다.',
          actionLabel: '다시 검색',
          onAction: _search,
        ),
      );
    }

    return ListView.builder(
      key: const PageStorageKey('search-scroll'),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        0,
        AppSpace.lg,
        AppSpace.lg,
      ),
      itemCount: _results.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.md),
            child: Text(
              '${_results.length}개 결과',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          );
        }

        final result = _results[index - 1];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 8, end: 0),
          duration: Duration(milliseconds: 200 + ((index - 1) * 30)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, value),
              child: Opacity(
                opacity: 1 - (value / 8).clamp(0, 1),
                child: child,
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.only(
              bottom: index == _results.length ? 0 : AppSpace.sm,
            ),
            child: _SearchResultTile(
              result: result,
              onOpen: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FileScreen(fileId: result.fileId),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onSearch,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: focusNode.hasFocus ? colors.accent : colors.border,
            ),
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: AppSpace.md),
                child: Icon(LucideIcons.search, size: 16),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onSubmitted: onSubmitted,
                  onChanged: (_) => (context as Element).markNeedsBuild(),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: '노트 검색',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
              if (controller.text.isNotEmpty)
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(LucideIcons.x, size: 16),
                ),
              Padding(
                padding: const EdgeInsets.only(right: AppSpace.xs),
                child: AppButton(label: '검색', onPressed: onSearch),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return Material(
      color: selected ? colors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: selected ? colors.accent : colors.border),
          ),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected ? colors.textPrimary : colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onOpen;

  const _SearchResultTile({required this.result, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final tags = result.tags
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    result.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Text(
                  '${(result.score * 100).round()}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              result.contentPreview,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: AppSpace.sm),
              Wrap(
                spacing: AppSpace.xs,
                runSpacing: AppSpace.xs,
                children: tags
                    .take(3)
                    .map((tag) => AppBadge(label: tag))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchSkeleton extends StatelessWidget {
  const _SearchSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 4,
      padding: const EdgeInsets.all(AppSpace.lg),
      itemBuilder: (context, index) => Padding(
        padding: EdgeInsets.only(bottom: index == 3 ? 0 : AppSpace.sm),
        child: AppCard(
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeletonLine(width: 180),
              SizedBox(height: AppSpace.sm),
              AppSkeletonLine(width: double.infinity),
              SizedBox(height: AppSpace.xs),
              AppSkeletonLine(width: 220),
            ],
          ),
        ),
      ),
    );
  }
}
