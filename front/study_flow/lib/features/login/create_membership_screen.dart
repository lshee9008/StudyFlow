import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme.dart';
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
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pw2Ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    _pw2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    final id = _idCtrl.text.trim();
    final pw = _pwCtrl.text;
    final pw2 = _pw2Ctrl.text;

    if (id.isEmpty || pw.isEmpty || pw2.isEmpty) {
      setState(() => _error = '모든 항목을 입력해주세요.');
      return;
    }
    if (id.length < 3) {
      setState(() => _error = '아이디는 3자 이상이어야 합니다.');
      return;
    }
    if (pw.length < 4) {
      setState(() => _error = '비밀번호는 4자 이상이어야 합니다.');
      return;
    }
    if (pw != pw2) {
      setState(() => _error = '비밀번호가 일치하지 않습니다.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final newUser = UserModel(
        id: const Uuid().v4(),
        name: id,
        join_path: 'email',
        password: pw,
        social_id: '',
        is_login: 1,
      );

      final err = await ref.read(userProvider.notifier).addUser(newUser);
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
        _error = '이미 사용 중인 아이디이거나 저장 과정에서 오류가 발생했습니다.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '계정을 만드는 중 오류가 발생했습니다.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      onBack: () => Navigator.pop(context),
      child: AuthSplitLayout(
        left: const AuthHeroPanel(
          eyebrow: 'NEW ACCOUNT',
          title: '당신만의 학습 운영체제를\n지금 생성합니다',
          description:
              '새 계정을 만들면 개인 프로젝트, 검색 메모리, 복습 기록이 하나의 학습 공간으로 묶입니다. '
              '단순 가입이 아니라 개인 학습 환경을 초기화하는 과정입니다.',
          bullets: [
            (Icons.folder_copy_outlined, '프로젝트별 노트와 강의 자료를 분리 저장'),
            (Icons.psychology_alt_outlined, '이해가 부족한 개념만 골라내는 복습 큐 구성'),
            (Icons.cloud_sync_outlined, '이후 로그인 시 동일한 흐름을 자연스럽게 복원'),
          ],
        ),
        right: AuthFormPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AuthSectionTitle(
                icon: Icons.person_add_alt_1_rounded,
                title: '계정 만들기',
                subtitle: '30초 안에 개인 학습 공간을 열 수 있습니다.',
                color: AppTheme.blue,
              ),
              const SizedBox(height: 24),
              SFTextField(
                label: '아이디',
                hint: '사용할 아이디를 입력하세요',
                controller: _idCtrl,
                prefixIcon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 14),
              SFTextField(
                label: '비밀번호',
                hint: '비밀번호를 입력하세요',
                controller: _pwCtrl,
                obscure: true,
                prefixIcon: Icons.lock_outline_rounded,
              ),
              const SizedBox(height: 14),
              SFTextField(
                label: '비밀번호 확인',
                hint: '비밀번호를 한 번 더 입력하세요',
                controller: _pw2Ctrl,
                obscure: true,
                prefixIcon: Icons.verified_user_outlined,
                onSubmitted: (_) => _signup(),
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
                label: '계정 만들기',
                width: double.infinity,
                height: 56,
                isLoading: _loading,
                onPressed: _loading ? null : _signup,
              ),
              const SizedBox(height: 18),
              Row(
                children: const [
                  Expanded(
                    child: AuthHelperBox(
                      message: '로컬 저장 지원',
                      color: AppTheme.green,
                      icon: Icons.devices_outlined,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: AuthHelperBox(
                      message: 'AI 요약 준비 완료',
                      color: AppTheme.blue,
                      icon: Icons.auto_awesome_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
