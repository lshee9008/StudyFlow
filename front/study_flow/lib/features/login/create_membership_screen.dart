import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme.dart';
import '../../core/ui/app_components.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../home/home_screen.dart';
import 'auth_shared.dart';

class CreateMembershipScreen extends ConsumerStatefulWidget {
  const CreateMembershipScreen({super.key});

  @override
  ConsumerState<CreateMembershipScreen> createState() =>
      _CreateMembershipScreenState();
}

class _CreateMembershipScreenState
    extends ConsumerState<CreateMembershipScreen> {
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    final id = _idController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (id.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _message = '모든 항목을 입력해 주세요.');
      return;
    }
    if (id.length < 3) {
      setState(() => _message = '아이디는 3자 이상이어야 합니다.');
      return;
    }
    if (password.length < 4) {
      setState(() => _message = '비밀번호는 4자 이상이어야 합니다.');
      return;
    }
    if (password != confirm) {
      setState(() => _message = '비밀번호가 일치하지 않습니다.');
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final user = UserModel(
        id: const Uuid().v4(),
        name: id,
        join_path: 'email',
        password: password,
        social_id: '',
        is_login: 1,
      );

      final error = await ref.read(userProvider.notifier).addUser(user);
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
        _message = '가입에 실패했습니다.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _busy = false;
        _message = '가입 중 오류가 발생했습니다.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      child: AuthSplitLayout(
        left: const AuthHero(
          eyebrow: '회원가입',
          title: '새 계정을 만들고\n바로 시작합니다.',
          body: '프로젝트와 노트를 바로 저장할 수 있는 개인 공간을 생성합니다.',
          items: [
            (LucideIcons.folderKanban, '프로젝트와 노트 저장'),
            (LucideIcons.sparkles, '요약과 복습 사용'),
            (LucideIcons.search, '검색 흐름 유지'),
          ],
        ),
        right: AuthPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AuthHeader(title: '계정 만들기', subtitle: '필수 정보만 입력합니다.'),
              const SizedBox(height: AppSpace.lg),
              AppInput(
                controller: _idController,
                hintText: '아이디',
                label: '아이디',
                icon: LucideIcons.user,
              ),
              const SizedBox(height: AppSpace.md),
              AppInput(
                controller: _passwordController,
                hintText: '비밀번호',
                label: '비밀번호',
                icon: LucideIcons.lock,
                obscureText: true,
              ),
              const SizedBox(height: AppSpace.md),
              AppInput(
                controller: _confirmController,
                hintText: '비밀번호 확인',
                label: '비밀번호 확인',
                icon: LucideIcons.shieldCheck,
                obscureText: true,
                onSubmitted: (_) => _signup(),
              ),
              if (_message != null) ...[
                const SizedBox(height: AppSpace.md),
                AppInlineMessage(message: _message!),
              ],
              const SizedBox(height: AppSpace.lg),
              AppButton(
                label: '가입',
                onPressed: _busy ? null : _signup,
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
