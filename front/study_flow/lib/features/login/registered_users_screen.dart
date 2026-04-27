import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/db_helper/users_db_helper.dart';
import '../../core/theme.dart';
import '../../core/ui/app_components.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../home/home_screen.dart';
import 'auth_shared.dart';

class RegisteredUsersScreen extends ConsumerStatefulWidget {
  const RegisteredUsersScreen({super.key});

  @override
  ConsumerState<RegisteredUsersScreen> createState() =>
      _RegisteredUsersScreenState();
}

class _RegisteredUsersScreenState extends ConsumerState<RegisteredUsersScreen> {
  String _selectedId = '';
  bool _busy = false;

  Future<void> _continue() async {
    if (_selectedId.isEmpty) {
      return;
    }

    setState(() => _busy = true);
    await ref.read(userProvider.notifier).loginExistingUser(_selectedId);

    if (!mounted) {
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      child: AuthSplitLayout(
        left: const AuthHero(
          eyebrow: '저장된 계정',
          title: '저장된 계정으로\n바로 들어갑니다.',
          body: '이 기기에 저장된 계정을 선택하면 로그인 단계를 다시 거치지 않습니다.',
          items: [
            (LucideIcons.user, '로컬 계정 확인'),
            (LucideIcons.zap, '선택 후 바로 홈으로 이동'),
            (LucideIcons.lock, '기존 데이터 유지'),
          ],
        ),
        right: AuthPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AuthHeader(title: '저장된 계정', subtitle: '하나를 선택합니다.'),
              const SizedBox(height: AppSpace.lg),
              FutureBuilder<List<UserModel>?>(
                future: UsersDBHelper.selectUsers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _SavedAccountSkeleton();
                  }

                  final users = snapshot.data ?? [];
                  if (users.isEmpty) {
                    return AppEmptyState(
                      title: '저장된 계정이 없습니다.',
                      actionLabel: '뒤로',
                      onAction: () => Navigator.pop(context),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == users.length - 1 ? 0 : AppSpace.sm,
                        ),
                        child: _SavedAccountTile(
                          user: user,
                          selected: _selectedId == user.id,
                          onTap: () => setState(() => _selectedId = user.id!),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: AppSpace.lg),
              AppButton(
                label: '계속',
                onPressed: _selectedId.isEmpty || _busy ? null : _continue,
                busy: _busy,
                width: double.infinity,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedAccountTile extends StatelessWidget {
  final UserModel user;
  final bool selected;
  final VoidCallback onTap;

  const _SavedAccountTile({
    required this.user,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(
            color: selected
                ? colors.accent.withValues(alpha: 0.08)
                : colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? colors.accent : colors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selected
                      ? colors.accent
                      : colors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected ? Colors.white : colors.accent,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              // Name + join path
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: AppSpace.xxs),
                    Text(
                      user.join_path.isEmpty ? '로컬 계정' : user.join_path,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              // Check indicator
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: selected
                    ? Container(
                        key: const ValueKey('checked'),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: colors.accent,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Icon(
                          LucideIcons.check,
                          size: 13,
                          color: Colors.white,
                        ),
                      )
                    : Container(
                        key: const ValueKey('unchecked'),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: colors.border),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedAccountSkeleton extends StatelessWidget {
  const _SavedAccountSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: index == 2 ? 0 : AppSpace.sm),
          child: AppCard(
            padding: const EdgeInsets.all(AppSpace.md),
            child: const Row(
              children: [
                AppSkeletonBlock(height: 28, width: 28),
                SizedBox(width: AppSpace.sm),
                AppSkeletonLine(width: 120),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
