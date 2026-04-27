import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme.dart';
import '../../core/ui/app_components.dart';
import '../../providers/user_provider.dart';
import '../home/home_screen.dart';
import 'auth_shared.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_idController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() => _message = '아이디와 비밀번호를 입력해 주세요.');
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    final error = await ref
        .read(userProvider.notifier)
        .loginUser(_idController.text.trim(), _passwordController.text);

    if (!mounted) {
      return;
    }

    if (error == null) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
      return;
    }

    setState(() {
      _busy = false;
      _message = '로그인에 실패했습니다.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      child: AuthSplitLayout(
        left: const AuthHero(
          eyebrow: 'Login',
          title: '바로 이어서\n작업합니다.',
          body: '최근 프로젝트와 노트 흐름을 바로 복원합니다.',
          items: [
            (LucideIcons.folderOpen, '최근 프로젝트 이어가기'),
            (LucideIcons.sparkles, '요약과 노트 이어쓰기'),
            (LucideIcons.search, '검색 기록 유지'),
          ],
        ),
        right: AuthPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AuthHeader(title: '로그인', subtitle: '필수 정보만 입력합니다.'),
              const SizedBox(height: AppSpace.lg),
              AppInput(
                controller: _idController,
                hintText: '아이디',
                label: '아이디',
                icon: LucideIcons.user,
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: AppSpace.md),
              AppInput(
                controller: _passwordController,
                hintText: '비밀번호',
                label: '비밀번호',
                icon: LucideIcons.lock,
                obscureText: true,
                onSubmitted: (_) => _login(),
              ),
              if (_message != null) ...[
                const SizedBox(height: AppSpace.md),
                AppInlineMessage(message: _message!),
              ],
              const SizedBox(height: AppSpace.lg),
              AppButton(
                label: '로그인',
                onPressed: _busy ? null : _login,
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
