import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';
import 'auth_shared.dart';
import 'create_membership_screen.dart';
import 'login_screen.dart';
import 'registered_users_screen.dart';

class LoginOrCreateMembershipScreen extends StatelessWidget {
  const LoginOrCreateMembershipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      onBack: () => Navigator.pop(context),
      child: AuthSplitLayout(
        left: const AuthHeroPanel(
          eyebrow: 'ENTRY PORTAL',
          title: '학습 시스템에 접속해\n흐름을 계속 이어가세요',
          description:
              'StudyFlow는 로그인 직후부터 이전 학습 맥락, 퀴즈 기록, 검색 이력을 연결합니다. '
              '다시 들어와도 중간부터 바로 이어지는 경험을 목표로 합니다.',
          bullets: [
            (Icons.auto_graph_rounded, '학습 흐름과 오답 기록을 같은 타임라인으로 관리'),
            (Icons.layers_rounded, '강의 노트, 개념 연결, 복습 카드가 자동 동기화'),
            (Icons.shield_outlined, '기기 기반 저장과 계정 저장을 모두 지원'),
          ],
        ),
        right: AuthFormPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AuthSectionTitle(
                icon: Icons.waving_hand_rounded,
                title: '시작 방식을 선택하세요',
                subtitle: '바로 로그인하거나 새 계정을 만들 수 있습니다.',
              ),
              const SizedBox(height: 24),
              _PortalButton(
                title: '로그인',
                description: '기존 계정으로 들어가 이전 학습 상태를 이어받습니다.',
                icon: Icons.login_rounded,
                accent: AppTheme.accent,
                filled: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _PortalButton(
                title: '새 계정 만들기',
                description: '30초 안에 계정을 만들고 개인 학습 공간을 엽니다.',
                icon: Icons.person_add_alt_1_rounded,
                accent: AppTheme.blue,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateMembershipScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const _DividerLabel(label: '또는'),
              const SizedBox(height: 18),
              _PortalButton(
                title: '이 기기의 계정으로 계속하기',
                description: '로컬에 저장된 계정이 있다면 즉시 진입합니다.',
                icon: Icons.devices_rounded,
                accent: AppTheme.green,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RegisteredUsersScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const AuthHelperBox(
                message: '계정을 만들면 서비스 이용약관과 개인정보 처리방침에 동의한 것으로 간주됩니다.',
                color: AppTheme.textSecondary,
                icon: Icons.verified_user_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortalButton extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final bool filled;
  final VoidCallback onTap;

  const _PortalButton({
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.filled = false,
  });

  @override
  State<_PortalButton> createState() => _PortalButtonState();
}

class _PortalButtonState extends State<_PortalButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: widget.filled
                ? LinearGradient(
                    colors: [AppTheme.accentHover, AppTheme.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: widget.filled
                ? null
                : (_hover
                      ? AppTheme.bgTertiary.withValues(alpha: 0.92)
                      : AppTheme.bgSecondary.withValues(alpha: 0.78)),
            border: Border.all(
              color: widget.filled
                  ? Colors.transparent
                  : (_hover
                        ? widget.accent.withValues(alpha: 0.28)
                        : AppTheme.borderDefault),
            ),
            boxShadow: widget.filled
                ? [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.24),
                      blurRadius: 30,
                      offset: const Offset(0, 16),
                      spreadRadius: -12,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: widget.filled
                      ? Colors.black.withValues(alpha: 0.08)
                      : widget.accent.withValues(alpha: 0.12),
                  border: Border.all(
                    color: widget.filled
                        ? Colors.black.withValues(alpha: 0.08)
                        : widget.accent.withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.filled ? Colors.black : widget.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: AppTheme.headingMedium.copyWith(
                        color: widget.filled
                            ? Colors.black
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.description,
                      style: AppTheme.bodySmall.copyWith(
                        color: widget.filled
                            ? Colors.black.withValues(alpha: 0.72)
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward_rounded,
                color: widget.filled ? Colors.black : AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DividerLabel extends StatelessWidget {
  final String label;

  const _DividerLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: SFDivider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: AppTheme.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Expanded(child: SFDivider()),
      ],
    );
  }
}
