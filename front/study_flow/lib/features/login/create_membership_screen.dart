import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
    extends ConsumerState<CreateMembershipScreen>
    with SingleTickerProviderStateMixin {
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pw2Ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  late AnimationController _bgCtrl;
  late Animation<double> _bgAnim;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);
    _bgAnim = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    _pw2Ctrl.dispose();
    _bgCtrl.dispose();
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
      setState(() => _loading = false);

      if (err == null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        );
      } else {
        setState(
          () => _error = '이미 사용 중인 아이디이거나 서버 오류가 발생했습니다.',
        );
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
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgAnim,
            builder: (_, __) => CustomPaint(
              painter: _SignupBgPainter(_bgAnim.value),
              size: MediaQuery.of(context).size,
            ),
          ),

          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _BackBtn(onTap: () => Navigator.pop(context)),
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SFLogo(size: 28),
                    const SizedBox(height: 44),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppTheme.bgSecondary.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppTheme.borderDefault.withValues(alpha: 0.7),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 40,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.accentDim,
                                      AppTheme.bgTertiary,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppTheme.accent.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.person_add_outlined,
                                  size: 15,
                                  color: AppTheme.accent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '계정 만들기',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  Text('30초면 충분해요.', style: AppTheme.bodySmall),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          SFTextField(
                            label: '아이디',
                            hint: '사용할 아이디 (3자 이상)',
                            controller: _idCtrl,
                            prefixIcon: Icons.person_outline_rounded,
                          ),
                          const SizedBox(height: 14),
                          SFTextField(
                            label: '비밀번호',
                            hint: '비밀번호 (4자 이상)',
                            controller: _pwCtrl,
                            obscure: true,
                            prefixIcon: Icons.lock_outline_rounded,
                          ),
                          const SizedBox(height: 14),
                          SFTextField(
                            label: '비밀번호 확인',
                            hint: '비밀번호를 다시 입력하세요',
                            controller: _pw2Ctrl,
                            obscure: true,
                            prefixIcon: Icons.lock_outline_rounded,
                            onSubmitted: (_) => _signup(),
                          ),

                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.red.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppTheme.red.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    size: 15,
                                    color: AppTheme.red,
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: GoogleFonts.inter(
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
                          _SignupSubmitBtn(
                            isLoading: _loading,
                            onPressed: _loading ? null : _signup,
                          ),

                          const SizedBox(height: 16),
                          // 혜택 안내
                          Row(
                            children: [
                              _Benefit(icon: Icons.cloud_outlined, label: '클라우드 동기화'),
                              const SizedBox(width: 16),
                              _Benefit(icon: Icons.auto_awesome_rounded, label: 'AI 요약 무제한'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Benefit({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: AppTheme.green),
      const SizedBox(width: 5),
      Text(label, style: AppTheme.caption.copyWith(color: AppTheme.textTertiary)),
    ],
  );
}

class _SignupSubmitBtn extends StatefulWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  const _SignupSubmitBtn({required this.isLoading, required this.onPressed});
  @override
  State<_SignupSubmitBtn> createState() => _SignupSubmitBtnState();
}

class _SignupSubmitBtnState extends State<_SignupSubmitBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: GestureDetector(
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: widget.isLoading
              ? null
              : LinearGradient(
                  colors: _hover
                      ? [const Color(0xFFDDFF88), AppTheme.accent]
                      : [AppTheme.accent, AppTheme.accentMuted],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: widget.isLoading ? AppTheme.bgTertiary : null,
          borderRadius: BorderRadius.circular(10),
          boxShadow: !widget.isLoading
              ? [
                  BoxShadow(
                    color: AppTheme.accent.withValues(
                      alpha: _hover ? 0.28 : 0.14,
                    ),
                    blurRadius: _hover ? 20 : 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: widget.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: AppTheme.textSecondary,
                    strokeWidth: 1.5,
                  ),
                )
              : Text(
                  '계정 만들기',
                  style: GoogleFonts.inter(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
        ),
      ),
    ),
  );
}

class _BackBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _BackBtn({required this.onTap});
  @override
  State<_BackBtn> createState() => _BackBtnState();
}

class _BackBtnState extends State<_BackBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _hover
              ? AppTheme.bgSecondary.withValues(alpha: 0.8)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: _hover ? Border.all(color: AppTheme.borderSubtle) : null,
        ),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 15,
          color: _hover ? AppTheme.textPrimary : AppTheme.textSecondary,
        ),
      ),
    ),
  );
}

class _SignupBgPainter extends CustomPainter {
  final double t;
  const _SignupBgPainter(this.t);

  @override
  void paint(Canvas c, Size s) {
    void blob(double cx, double cy, double r, Color col, double a) {
      c.drawCircle(
        Offset(cx * s.width, cy * s.height),
        r,
        Paint()
          ..color = col.withValues(alpha: a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 140),
      );
    }

    blob(0.9 - t * 0.06, 0.15, 240, AppTheme.accent, 0.06);
    blob(0.1, 0.8 + t * 0.04, 220, AppTheme.blue, 0.06);
    blob(0.5 + math.sin(t * math.pi) * 0.05, 1.0, 260, AppTheme.purple, 0.05);
  }

  @override
  bool shouldRepaint(_SignupBgPainter o) => (o.t - t).abs() > 0.004;
}
