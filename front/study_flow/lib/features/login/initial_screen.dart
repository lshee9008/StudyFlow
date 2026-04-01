import 'package:flutter/material.dart';
import '../login/login_or_create_membership_screen.dart';
import '../../core/theme.dart';

class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});
  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 700;

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      body: Stack(
        children: [
          // 배경 그라디언트 오브
          Positioned(
            top: -200,
            right: -200,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accent.withOpacity(0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppTheme.blue.withOpacity(0.05), Colors.transparent],
                ),
              ),
            ),
          ),

          // 메인 콘텐츠
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 28 : 80,
                    vertical: 32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 상단 로고
                      const SFLogo(size: 28),
                      const Spacer(),

                      // 메인 헤드라인
                      _buildBadge(),
                      const SizedBox(height: 24),
                      Text(
                        isMobile
                            ? '학습의 흐름을\n끊지 않는\nAI 노트'
                            : '학습의 흐름을 끊지 않는\nAI 인지 보조 에이전트',
                        style: AppTheme.displayLarge.copyWith(
                          fontSize: isMobile ? 44 : 56,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '강의를 들으며 동시에 요약하고, 이해하고, 기억하세요.\n실시간 AI가 여러분의 학습 흐름을 함께 만들어갑니다.',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.7,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // CTA 버튼들
                      isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SFButton(
                                  label: '시작하기',
                                  icon: Icons.arrow_forward_rounded,
                                  width: double.infinity,
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const LoginOrCreateMembershipScreen(),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildFeatureRow(),
                              ],
                            )
                          : Row(
                              children: [
                                SFButton(
                                  label: '무료로 시작하기',
                                  icon: Icons.arrow_forward_rounded,
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const LoginOrCreateMembershipScreen(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                _buildFeatureRow(),
                              ],
                            ),

                      const Spacer(),

                      // 하단 기능 소개 카드
                      _buildFeatureCards(isMobile),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.accentDim,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppTheme.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '졸업작품 프로젝트 · 3조',
            style: TextStyle(
              color: AppTheme.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.green),
        const SizedBox(width: 6),
        Text(
          '무료 · 가입 30초',
          style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildFeatureCards(bool isMobile) {
    final features = [
      (Icons.auto_awesome_rounded, '실시간 요약', '타이핑하는 순간 AI가 구조화된 노트 생성'),
      (Icons.hub_rounded, '지식 그래프', '개념 간 연결관계를 시각적으로 파악'),
      (Icons.quiz_rounded, 'AI 퀴즈', '학습한 내용으로 즉시 복습 퀴즈 생성'),
    ];

    if (isMobile) {
      return Column(
        children: features
            .map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _featureCard(f.$1, f.$2, f.$3),
              ),
            )
            .toList(),
      );
    }

    return Row(
      children: features
          .asMap()
          .entries
          .map(
            (e) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: e.key < features.length - 1 ? 12 : 0,
                ),
                child: _featureCard(e.value.$1, e.value.$2, e.value.$3),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _featureCard(IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accentDim,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppTheme.accent),
          ),
          const SizedBox(height: 14),
          Text(title, style: AppTheme.headingSmall),
          const SizedBox(height: 6),
          Text(desc, style: AppTheme.bodySmall.copyWith(height: 1.5)),
        ],
      ),
    );
  }
}
