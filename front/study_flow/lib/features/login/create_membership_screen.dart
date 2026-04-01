import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../home/home_screen.dart';

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

    if (id.isEmpty || pw.isEmpty) {
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

      // ✅ 반드시 loading 먼저 해제 후 이동
      setState(() => _loading = false);

      if (err == null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        );
      } else {
        setState(() => _error = '이미 사용 중인 아이디이거나 서버 오류가 발생했습니다.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '오류가 발생했습니다. 다시 시도해주세요.';
      });
    }
  }

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SFLogo(size: 28),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSecondary,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('계정 만들기', style: AppTheme.headingLarge),
                      const SizedBox(height: 6),
                      Text('30초면 충분해요.', style: AppTheme.bodyMedium),
                      const SizedBox(height: 32),
                      SFTextField(
                        label: '아이디',
                        hint: '사용할 아이디 (3자 이상)',
                        controller: _idCtrl,
                        prefixIcon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 16),
                      SFTextField(
                        label: '비밀번호',
                        hint: '비밀번호 (4자 이상)',
                        controller: _pwCtrl,
                        obscure: true,
                        prefixIcon: Icons.lock_outline_rounded,
                      ),
                      const SizedBox(height: 16),
                      SFTextField(
                        label: '비밀번호 확인',
                        hint: '비밀번호를 다시 입력하세요',
                        controller: _pw2Ctrl,
                        obscure: true,
                        prefixIcon: Icons.lock_outline_rounded,
                        onSubmitted: (_) => _signup(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.red.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 16,
                                color: AppTheme.red,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: AppTheme.red,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SFButton(
                        label: '계정 만들기',
                        width: double.infinity,
                        isLoading: _loading,
                        onPressed: _loading ? null : _signup,
                      ),
                    ],
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
