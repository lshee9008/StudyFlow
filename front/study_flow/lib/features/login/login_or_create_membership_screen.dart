import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme.dart';
import 'auth_shared.dart';
import 'create_membership_screen.dart';
import 'login_screen.dart';

class LoginOrCreateMembershipScreen extends StatelessWidget {
  const LoginOrCreateMembershipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      child: AuthSplitLayout(
        left: const AuthHero(
          eyebrow: '시작',
          title: '계정을 선택하고\n바로 시작합니다.',
          body: 'Google 또는 이메일로 로그인하거나, 새 계정을 만들 수 있습니다.',
          items: [
            (LucideIcons.logIn, 'Google · 이메일로 바로 로그인'),
            (LucideIcons.userPlus, '새 학습 공간 만들기'),
            (LucideIcons.shieldCheck, '안전하게 보호되는 계정'),
          ],
        ),
        right: AuthPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AuthHeader(title: '계정 선택', subtitle: '로그인 또는 새 계정 만들기'),
              const SizedBox(height: AppSpace.lg),
              _EntryTile(
                icon: LucideIcons.logIn,
                title: '로그인',
                subtitle: '기존 계정',
                selected: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              _EntryTile(
                icon: LucideIcons.userPlus,
                title: '가입',
                subtitle: '새 계정',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateMembershipScreen(),
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

class _EntryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool selected;

  const _EntryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return Material(
      color: selected ? colors.accent : colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: selected ? colors.accent : colors.border),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : colors.textSecondary,
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected ? Colors.white : colors.textPrimary,
                  ),
                ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.8)
                      : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
