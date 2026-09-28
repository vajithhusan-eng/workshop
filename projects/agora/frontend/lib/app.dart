import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'utils/theme.dart';
import 'screens/home_screen.dart';
import 'widgets/app_drawer.dart';

class StoryApp extends ConsumerWidget {
  const StoryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Story App - Multi-AI Agent Orchestrator',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
      drawer: const AppDrawer(),
    );
  }
}
