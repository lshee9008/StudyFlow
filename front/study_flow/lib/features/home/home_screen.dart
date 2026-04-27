// Auth guard — routes to AppShell (logged in) or InitialScreen (logged out).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/user_provider.dart';
import '../login/initial_screen.dart';
import '../shell/app_shell.dart';
import 'home_content.dart';

export 'home_content.dart' show HomeContent, HomeTopBar, HomeSkeleton, ProjectCreateSheet;

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    if (user == null) return const InitialScreen();
    if (user.id == '') return const HomeSkeleton();
    return const AppShell();
  }
}
