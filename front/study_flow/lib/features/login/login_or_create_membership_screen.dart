import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'login_screen.dart';
import 'create_membership_screen.dart';
import 'registered_users_screen.dart';

class LoginOrCreateMembershipScreen extends StatelessWidget {
  const LoginOrCreateMembershipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SFLogo(size: 32),
                const SizedBox(height: 48),

                // 카드
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSecondary,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Column(
                    children: [
                      Text('계정이 있으신가요?', style: AppTheme.headingLarge),
                      const SizedBox(height: 8),
                      Text(
                        '로그인하거나 새 계정을 만들어 시작하세요.',
                        style: AppTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // 로그인 버튼
                      SFButton(
                        label: '로그인',
                        width: double.infinity,
                        onPressed: () => Navigator.push(
                          context,
                          _route(const LoginScreen()),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 회원가입 버튼
                      SFButton(
                        label: '새 계정 만들기',
                        width: double.infinity,
                        outlined: true,
                        onPressed: () => Navigator.push(
                          context,
                          _route(const CreateMembershipScreen()),
                        ),
                      ),

                      const SizedBox(height: 28),
                      Row(
                        children: [
                          const Expanded(
                            child: Divider(color: AppTheme.borderSubtle),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text('또는', style: AppTheme.bodySmall),
                          ),
                          const Expanded(
                            child: Divider(color: AppTheme.borderSubtle),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 기존 유저 선택
                      InkWell(
                        onTap: () => Navigator.push(
                          context,
                          _route(const RegisteredUsersScreen()),
                        ),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.borderSubtle),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.person_outline_rounded,
                                size: 16,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '이 기기의 계정으로 계속하기',
                                style: AppTheme.labelMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),
                Text(
                  '계정을 만들면 서비스 이용약관에 동의하는 것입니다.',
                  style: AppTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PageRoute _route(Widget page) => MaterialPageRoute(builder: (_) => page);
}
