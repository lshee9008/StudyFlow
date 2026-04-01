import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/db_helper/users_db_helper.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../home/home_screen.dart';
import 'login_or_create_membership_screen.dart';

class RegisteredUsersScreen extends ConsumerStatefulWidget {
  const RegisteredUsersScreen({super.key});
  @override
  ConsumerState<RegisteredUsersScreen> createState() =>
      _RegisteredUsersScreenState();
}

class _RegisteredUsersScreenState extends ConsumerState<RegisteredUsersScreen> {
  String _selectedId = '';
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
          color: AppTheme.textSecondary,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SFLogo(size: 28),
                const SizedBox(height: 40),

                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSecondary,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('계정 선택', style: AppTheme.headingMedium),
                      const SizedBox(height: 4),
                      Text('이 기기에 저장된 계정을 선택하세요.', style: AppTheme.bodySmall),
                      const SizedBox(height: 20),

                      FutureBuilder<List<UserModel>?>(
                        future: UsersDBHelper.selectUsers(),
                        builder: (ctx, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: CircularProgressIndicator(
                                  color: AppTheme.accent,
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          final users = snap.data;
                          if (users == null || users.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.person_off_outlined,
                                      size: 40,
                                      color: AppTheme.textMuted,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '저장된 계정이 없어요',
                                      style: AppTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          return Column(
                            children: users
                                .map(
                                  (u) => _UserTile(
                                    user: u,
                                    selected: _selectedId == u.id,
                                    onTap: () =>
                                        setState(() => _selectedId = u.id!),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),

                      const SizedBox(height: 20),
                      SFButton(
                        label: '선택한 계정으로 시작',
                        width: double.infinity,
                        isLoading: _loading,
                        onPressed: _selectedId.isEmpty
                            ? null
                            : () async {
                                setState(() => _loading = true);
                                await ref
                                    .read(userProvider.notifier)
                                    .loginExistingUser(_selectedId);
                                if (context.mounted) {
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const HomeScreen(),
                                    ),
                                    (_) => false,
                                  );
                                }
                              },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginOrCreateMembershipScreen(),
                    ),
                  ),
                  child: const Text(
                    '다른 계정으로 로그인',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final UserModel user;
  final bool selected;
  final VoidCallback onTap;
  const _UserTile({
    required this.user,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accentDim : AppTheme.bgTertiary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppTheme.accent.withOpacity(0.5)
                : AppTheme.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected ? AppTheme.accent : AppTheme.bgSecondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                  style: TextStyle(
                    color: selected ? Colors.black : AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: TextStyle(
                      color: selected ? AppTheme.accent : AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    user.join_path.isEmpty ? '로컬 계정' : user.join_path,
                    style: AppTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: AppTheme.accent,
              ),
          ],
        ),
      ),
    );
  }
}
