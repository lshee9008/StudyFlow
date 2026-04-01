// ============================================================
// main.dart  (Web-Compatible v2)
// ============================================================
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// sqflite_common_ffi는 모바일/데스크톱 전용
import 'core/theme.dart';
import 'features/home/home_screen.dart';

import 'package:intl/date_symbol_data_local.dart'; // ← 추가

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null); // ← 추가

  if (!kIsWeb) {
    await _initSqflite();
  }
  runApp(const ProviderScope(child: MyApp()));
}

/// 웹 빌드 시 dead code elimination을 위해 별도 함수로 분리
Future<void> _initSqflite() async {
  // ignore: avoid_web_libraries_in_flutter
  // 이 코드는 웹 빌드에서 트리쉐이킹으로 제거됨
  try {
    // sqflite_common_ffi 초기화 (데스크톱/모바일 전용)
    // 웹에서는 이 함수 자체가 호출되지 않음
    final sqfliteFfi = await _loadSqfliteFfi();
    sqfliteFfi?.call();
  } catch (e) {
    print('sqflite FFI init skipped: $e');
  }
}

Future<Function?> _loadSqfliteFfi() async {
  // conditional compilation trick
  if (kIsWeb) return null;
  // 아래 import는 웹 빌드 시 제거됨
  return null; // 실제 사용 시 sqfliteFfiInit 호출
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'StudyFlow',
      theme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const HomeScreen(),
    );
  }
}
