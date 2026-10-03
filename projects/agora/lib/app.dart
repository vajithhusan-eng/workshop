import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/database.dart';
import 'data/session_repository.dart';
import 'state/agora_controller.dart';
import 'ui/home_shell.dart';
import 'ui/theme.dart';

/// One database, one repository, one controller for the whole app.
final agoraDbProvider = Provider<AgoraDb>((_) {
  final db = AgoraDb();
  return db;
});

final repositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(ref.watch(agoraDbProvider));
});

final controllerProvider = ChangeNotifierProvider<AgoraController>((ref) {
  final c = AgoraController(ref.watch(repositoryProvider))..start();
  ref.onDispose(c.dispose);
  return c;
});

class AgoraApp extends ConsumerWidget {
  const AgoraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(controllerProvider);
    return MaterialApp(
      title: 'Agora',
      debugShowCheckedModeBanner: false,
      theme: AgoraTheme.build(),
      home: HomeShellGate(c: c),
    );
  }
}
