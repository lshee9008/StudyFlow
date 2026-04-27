import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme.dart';
import '../../core/ui/app_components.dart';
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

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.user.name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (name.isEmpty) {
      setState(() => _message = '이름을 입력해 주세요.');
      return;
    }
    if (password.isNotEmpty && password.length < 4) {
      setState(() => _message = '비밀번호는 4자 이상이어야 합니다.');
      return;
    }
    if (password.isNotEmpty && password != confirm) {
      setState(() => _message = '비밀번호가 일치하지 않습니다.');
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    final newUser = UserModel(
      id: widget.user.id,
      name: name,
      join_path: widget.user.join_path,
      password: password.isNotEmpty ? password : widget.user.password,
      social_id: widget.user.social_id,
      is_login: 1,
    );

    final error = await ref.read(userProvider.notifier).updateUser(newUser);
    if (!mounted) {
      return;
    }

    setState(() {
      _busy = false;
      _passwordController.clear();
      _confirmController.clear();
    });

    if (error == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Saved successfully.')));
      return;
    }

    setState(() => _message = error);
  }

  Future<void> _requestDelete() async {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('계정을 삭제할까요?'),
          action: SnackBarAction(
            label: 'Delete',
            onPressed: () async {
              final error = await ref
                  .read(userProvider.notifier)
                  .deleteUser(widget.user.id!);

              if (!mounted) {
                return;
              }

              if (error == null) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const InitialScreen()),
                  (_) => false,
                );
                return;
              }

              setState(() => _message = error);
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final accountType = widget.user.join_path.isEmpty
        ? '로컬 계정'
        : widget.user.join_path;
    final isCompact = MediaQuery.of(context).size.width < 980;

    return AppWorkspaceShell(
      currentNav: 'settings',
      title: 'Secure Your Access',
      subtitle: 'Manage your account, credentials, and workspace provisioning.',
      profileLabel: widget.user.name,
      compact: isCompact,
      onHome: () => Navigator.popUntil(context, (route) => route.isFirst),
      onWorkspace: () => Navigator.pop(context),
      onSearch: () {},
      onSettings: () {},
      primaryAction: AppButton(
        label: 'Save',
        onPressed: _busy ? null : _save,
        busy: _busy,
        icon: LucideIcons.check,
      ),
      child: ListView(
        key: const PageStorageKey('settings-scroll'),
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          0,
          AppSpace.lg,
          AppSpace.lg,
        ),
        children: [
          AppCard(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.colorsOf(context).background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.colorsOf(context).border,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      widget.user.name.isNotEmpty
                          ? widget.user.name[0].toUpperCase()
                          : 'U',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.user.name,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpace.xxs),
                      Text(
                        accountType,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 56),
          Text(
            'Security Credentials',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpace.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppInput(
                  controller: _nameController,
                  hintText: '이름',
                  label: 'Display name',
                  icon: LucideIcons.user,
                ),
                const SizedBox(height: AppSpace.md),
                AppInput(
                  controller: _passwordController,
                  hintText: '새 비밀번호',
                  label: 'Master password',
                  icon: LucideIcons.lock,
                  obscureText: true,
                ),
                const SizedBox(height: AppSpace.md),
                AppInput(
                  controller: _confirmController,
                  hintText: '비밀번호 확인',
                  label: 'Confirm password',
                  icon: LucideIcons.shieldCheck,
                  obscureText: true,
                ),
                if (_message != null) ...[
                  const SizedBox(height: AppSpace.md),
                  AppInlineMessage(message: _message!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 56),
          Text(
            'Workspace Provisioning',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpace.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delete account',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  '삭제 후 복구할 수 없습니다.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpace.lg),
                AppButton(
                  label: 'Delete',
                  onPressed: _requestDelete,
                  primary: false,
                  icon: LucideIcons.trash2,
                  width: double.infinity,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
