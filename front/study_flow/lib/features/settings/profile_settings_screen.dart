import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../login/initial_screen.dart';

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  final UserModel user;
  const ProfileSettingsScreen({super.key, required this.user});

  @override
  ConsumerState<ProfileSettingsScreen> createState() =>
      _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _nameCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pw2Ctrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _nameCtrl.text = widget.user.name;
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _nameCtrl.dispose();
    _pwCtrl.dispose();
    _pw2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    final name = _nameCtrl.text.trim();
    final pw = _pwCtrl.text;
    final pw2 = _pw2Ctrl.text;

    if (name.isEmpty) {
      setState(() => _error = '이름을 입력해주세요.');
      return;
    }
    if (pw.isNotEmpty && pw != pw2) {
      setState(() => _error = '비밀번호가 일치하지 않습니다.');
      return;
    }
    if (pw.isNotEmpty && pw.length < 4) {
      setState(() => _error = '비밀번호는 4자 이상이어야 합니다.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    final newUser = UserModel(
      id: widget.user.id,
      name: name,
      join_path: widget.user.join_path,
      password: pw.isNotEmpty ? pw : widget.user.password,
      social_id: widget.user.social_id,
      is_login: 1,
    );

    final err = await ref.read(userProvider.notifier).updateUser(newUser);
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (err == null) {
        _success = '프로필이 업데이트되었습니다.';
        _pwCtrl.clear();
        _pw2Ctrl.clear();
      } else {
        _error = err;
      }
    });
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppTheme.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: AppTheme.red,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('계정 삭제', style: AppTheme.headingSmall),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '계정을 삭제하면 모든 프로젝트와 노트가 영구적으로 삭제됩니다.\n이 작업은 취소할 수 없습니다.',
                style: AppTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SFButton(
                    label: '취소',
                    outlined: true,
                    onPressed: () => Navigator.pop(context, false),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '삭제',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm != true) return;

    setState(() {
      _loading = true;
    });
    final err = await ref
        .read(userProvider.notifier)
        .deleteUser(widget.user.id!);
    if (!mounted) return;

    if (err == null) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const InitialScreen()),
        (_) => false,
      );
    } else {
      setState(() {
        _loading = false;
        _error = err;
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
        title: Text('설정', style: AppTheme.headingSmall),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 프로필 헤더
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSecondary,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppTheme.accent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            widget.user.name.isNotEmpty
                                ? widget.user.name[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 28,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.user.name,
                              style: AppTheme.headingMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.user.join_path.isEmpty
                                  ? '로컬 계정'
                                  : widget.user.join_path,
                              style: AppTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 정보 수정 섹션
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSecondary,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('계정 정보', style: AppTheme.headingSmall),
                      const SizedBox(height: 20),
                      SFTextField(
                        label: '아이디',
                        hint: '새 아이디',
                        controller: _nameCtrl,
                        prefixIcon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 16),
                      SFTextField(
                        label: '새 비밀번호 (선택)',
                        hint: '변경할 비밀번호',
                        controller: _pwCtrl,
                        obscure: true,
                        prefixIcon: Icons.lock_outline_rounded,
                      ),
                      const SizedBox(height: 16),
                      SFTextField(
                        label: '비밀번호 확인',
                        hint: '비밀번호를 다시 입력',
                        controller: _pw2Ctrl,
                        obscure: true,
                        prefixIcon: Icons.lock_outline_rounded,
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        _StatusBanner(message: _error!, isError: true),
                      ],
                      if (_success != null) ...[
                        const SizedBox(height: 14),
                        _StatusBanner(message: _success!, isError: false),
                      ],

                      const SizedBox(height: 20),
                      SFButton(
                        label: '변경사항 저장',
                        width: double.infinity,
                        isLoading: _loading,
                        onPressed: _loading ? null : _updateProfile,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 위험 구역
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSecondary,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.red.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: AppTheme.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '위험 구역',
                            style: AppTheme.headingSmall.copyWith(
                              color: AppTheme.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '계정을 삭제하면 모든 데이터가 영구적으로 사라집니다.',
                        style: AppTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _deleteAccount,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.red.withOpacity(0.4),
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              '계정 삭제',
                              style: TextStyle(
                                color: AppTheme.red,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
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

class _StatusBanner extends StatelessWidget {
  final String message;
  final bool isError;
  const _StatusBanner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppTheme.red : AppTheme.green;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
