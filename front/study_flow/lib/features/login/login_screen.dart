import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers/user_provider.dart';
import '../home/home_screen.dart';
import 'auth_shared.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_idCtrl.text.isEmpty || _pwCtrl.text.isEmpty) {
      setState(() => _error = '아이디와 비밀번호를 모두 입력해주세요.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final err = await ref
        .read(userProvider.notifier)
        .loginUser(_idCtrl.text.trim(), _pwCtrl.text);

    if (!mounted) return;
    if (err == null) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
      return;
    }

    setState(() {
      _loading = false;
      _error = '아이디 또는 비밀번호가 올바르지 않습니다.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      onBack: () => Navigator.pop(context),
      child: AuthSplitLayout(
        left: const AuthHeroPanel(
          eyebrow: 'RETURNING USER',
          title: '이전 학습 세션을\n바로 이어받습니다',
          description:
              '로그인하면 마지막 프로젝트, 복습 큐, 검색 히스토리까지 한 번에 복원됩니다. '
              '다시 적응할 필요 없이 바로 몰입할 수 있게 설계했습니다.',
          bullets: [
            (Icons.history_toggle_off_rounded, '마지막으로 보던 프로젝트와 흐름을 자동 복원'),
            (Icons.quiz_outlined, '오답 위주 복습 큐를 우선 제안'),
            (Icons.travel_explore_outlined, '의미 기반 검색 기록도 함께 이어짐'),
          ],
        ),
        right: AuthFormPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AuthSectionTitle(
                icon: Icons.login_rounded,
                title: '로그인',
                subtitle: 'StudyFlow 학습 공간으로 다시 들어갑니다.',
              ),
              const SizedBox(height: 24),
              SFTextField(
                label: '아이디',
                hint: '아이디를 입력하세요',
                controller: _idCtrl,
                prefixIcon: Icons.person_outline_rounded,
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 14),
              SFTextField(
                label: '비밀번호',
                hint: '비밀번호를 입력하세요',
                controller: _pwCtrl,
                obscure: true,
                prefixIcon: Icons.lock_outline_rounded,
                onSubmitted: (_) => _login(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                AuthHelperBox(
                  message: _error!,
                  color: AppTheme.red,
                  icon: Icons.error_outline_rounded,
                ),
              ],
              const SizedBox(height: 22),
              SFButton(
                label: '로그인',
                width: double.infinity,
                height: 56,
                isLoading: _loading,
                onPressed: _loading ? null : _login,
              ),
              const SizedBox(height: 18),
              const AuthHelperBox(
                message: '계정 정보는 현재 기기 저장소와 사용자 데이터베이스를 통해 관리됩니다.',
                color: AppTheme.blue,
                icon: Icons.lock_person_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
