import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/chrome/chrome_launcher.dart';
import '../state/agora_controller.dart';
import 'theme.dart';

/// Settings. The three PLAN.md §17 open questions are answered here, with the
/// suggested defaults, and written to disk — so the plan stops carrying
/// questions the app has already answered.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});
  final AgoraController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _kCap = 'agora.dailyCapPerAgent';
  static const _kVisible = 'agora.chromeVisible';
  static const _kRaw = 'agora.relayRaw';

  int _cap = 60;
  bool _visible = true;
  bool _raw = true;
  List<Map<String, Object?>> _usage = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final rows = await widget.controller.repo.usage();
    setState(() {
      _cap = p.getInt(_kCap) ?? 60;
      _visible = p.getBool(_kVisible) ?? true;
      _raw = p.getBool(_kRaw) ?? true;
      _usage = [
        for (final r in rows)
          <String, Object?>{
            'agent': r.agentKind,
            'day': r.day,
            'messages': r.messageCount,
            'bytes': r.byteCount,
          },
      ];
      _loaded = true;
    });
  }

  Future<void> _set(String key, Object value) async {
    final p = await SharedPreferences.getInstance();
    switch (value) {
      case int v:
        await p.setInt(key, v);
      case bool v:
        await p.setBool(key, v);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _section('Council limits', [
            _intRow(
              label: 'Messages per agent per day',
              help:
                  'Hard stop once an agent reaches this. The default of 60 keeps '
                  'a runaway council from burning a paid quota overnight.',
              value: _cap,
              onChanged: (v) => setState(() => _cap = v),
            ),
          ]),
          _section('Browser', [
            _boolRow(
              label: 'Show the Chrome window while a council runs',
              help:
                  'You can watch every agent work. Agora uses its own Chrome '
                  'profile at ~/.config/agora/chrome-profile — Chrome 136+ '
                  'refuses remote debugging on the default one.',
              value: _visible,
              onChanged: (v) {
                setState(() => _visible = v);
                _set(_kVisible, v);
              },
            ),
          ]),
          _section('Relaying', [
            _boolRow(
              label: 'Relay raw replies between agents',
              help:
                  'Off means the leader summarises before anyone else sees an '
                  'answer. Raw keeps the evidence chain intact; the leader can '
                  'still add its own framing.',
              value: _raw,
              onChanged: (v) {
                setState(() => _raw = v);
                _set(_kRaw, v);
              },
            ),
          ]),
          _section('Usage today', [
            if (_usage.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Nothing counted yet.', style: AgoraTheme.caption),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      for (final u in _usage)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 100,
                                child: Text(
                                  '${u['agent']}',
                                  style: AgoraTheme.mono,
                                ),
                              ),
                              SizedBox(
                                width: 110,
                                child: Text(
                                  '${u['day']}',
                                  style: AgoraTheme.caption,
                                ),
                              ),
                              Text(
                                '${u['messages']} msgs',
                                style: AgoraTheme.mono,
                              ),
                              const Spacer(),
                              Text(
                                '${((u['bytes'] as int?) ?? 0) ~/ 1024} KiB',
                                style: AgoraTheme.caption,
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 90,
                                child: LinearProgressIndicator(
                                  value:
                                      ((u['messages'] as int?) ?? 0) /
                                      (_cap == 0 ? 1 : _cap),
                                  minHeight: 4,
                                  backgroundColor: AgoraTheme.surface2,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ]),
          _section('On disk', [
            _path('Config root', AgoraPaths.root),
            _path('Chrome profile', AgoraPaths.chromeProfile),
            _path('Verbatim vault', AgoraPaths.vaultDir),
            _path('Logs', AgoraPaths.logsDir),
            const SizedBox(height: 6),
            const Text(
              'Everything Agora knows lives in these four directories. Delete '
              'them and the app is clean; nothing else is written anywhere.',
              style: AgoraTheme.caption,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> kids) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: AgoraTheme.caption.copyWith(
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ...kids,
      ],
    ),
  );

  Widget _intRow({
    required String label,
    required String help,
    required int value,
    required ValueChanged<int> onChanged,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(child: _copy(label, help)),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: TextField(
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: '$value')
                ..selection = TextSelection.collapsed(offset: '$value'.length),
              onSubmitted: (t) {
                final v = int.tryParse(t.trim());
                if (v != null && v > 0) {
                  onChanged(v);
                  _set(_kCap, v);
                }
              },
              decoration: const InputDecoration(suffixText: '/day'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _boolRow({
    required String label,
    required String help,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(child: _copy(label, help)),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    ),
  );

  Widget _copy(String label, String help) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 3),
      Text(help, style: AgoraTheme.caption.copyWith(height: 1.45)),
    ],
  );

  Widget _path(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 120, child: Text(label, style: AgoraTheme.caption)),
        Expanded(child: SelectableText(value, style: AgoraTheme.mono)),
      ],
    ),
  );
}
