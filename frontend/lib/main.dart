import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const api = 'http://127.0.0.1:8123/api';

void main() => runApp(const OmniApp());

class OmniApp extends StatelessWidget {
  const OmniApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OMNIVEST',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int i = 0;
  final pages = const [
    BriefPage(),
    LearnPage(),
    JournalPage(),
    AutopsyPage(),
    SebiPage()
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OMNIVEST · free · knowledge-only')),
      body: pages[i],
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: (v) => setState(() => i = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.wb_sunny), label: 'Brief'),
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'Learn'),
          NavigationDestination(icon: Icon(Icons.book), label: 'Journal'),
          NavigationDestination(icon: Icon(Icons.science), label: 'Autopsy'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: '87.7%'),
        ],
      ),
    );
  }
}

Future<Map> getJ(String p) async {
  final r = await http.get(Uri.parse('$api$p'));
  return jsonDecode(r.body) as Map;
}

// ---------- BRIEF ----------
class BriefPage extends StatefulWidget {
  const BriefPage({super.key});
  @override
  State<BriefPage> createState() => _BriefState();
}

class _BriefState extends State<BriefPage> {
  String out =
      'Tap to generate your Morning Brief (deterministic watch-loop, \$0).';
  Future<void> gen() async {
    setState(() => out = '…');
    final r = await http.post(Uri.parse('$api/brief/daily'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': 'Investor',
          'events': [
            {
              'symbol': 'RELIANCE',
              'move_pct': -4.2,
              'sector_move_pct': -0.4,
              'holding': true
            }
          ]
        }));
    setState(() => out = (jsonDecode(r.body) as Map)['brief'].toString());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ElevatedButton(
            onPressed: gen, child: const Text('Generate Morning Brief')),
        const SizedBox(height: 12),
        Expanded(child: SingleChildScrollView(child: SelectableText(out))),
      ]),
    );
  }
}

// ---------- LEARN ----------
class LearnPage extends StatefulWidget {
  const LearnPage({super.key});
  @override
  State<LearnPage> createState() => _LearnState();
}

class _LearnState extends State<LearnPage> {
  Map? consensus, debates;
  @override
  void initState() {
    super.initState();
    getJ('/canon/consensus').then((v) => setState(() => consensus = v));
    getJ('/canon/debates').then((v) => setState(() => debates = v));
  }

  @override
  Widget build(BuildContext context) {
    final c = (consensus?['items'] as List?) ?? [];
    final d = (debates?['items'] as List?) ?? [];
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('8 things everyone agrees on',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      for (final x in c)
        ListTile(title: Text('${x['rule']}'), subtitle: Text('${x['line']}')),
      const Divider(),
      const Text('Where they fight (pick a side — graded in 12 months)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      for (final x in d)
        Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${x['question']}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Buffett: ${x['buffett']}'),
                      Text('Dalio: ${x['dalio']}'),
                      Text('Evidence: ${x['evidence']}',
                          style: const TextStyle(fontStyle: FontStyle.italic)),
                    ]))),
    ]);
  }
}

// ---------- JOURNAL ----------
class JournalPage extends StatefulWidget {
  const JournalPage({super.key});
  @override
  State<JournalPage> createState() => _JState();
}

class _JState extends State<JournalPage> {
  final sym = TextEditingController(text: 'RELIANCE');
  final why = TextEditingController(text: 'value setup, low debt');
  String tag = 'value';
  Map? stats;
  Future<void> log() async {
    await http.post(Uri.parse('$api/journal/entries'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'symbol': sym.text,
          'tag': tag,
          'why': why.text,
          'side': 'buy',
          'price': 1384
        }));
    final v = await getJ('/journal/stats');
    setState(() => stats = v);
  }

  @override
  void initState() {
    super.initState();
    getJ('/journal/stats').then((v) => setState(() => stats = v));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        TextField(
            controller: sym,
            decoration: const InputDecoration(labelText: 'Symbol')),
        TextField(
            controller: why,
            decoration: const InputDecoration(
                labelText: 'Why (required — frozen, graded later)')),
        DropdownButton<String>(
            value: tag,
            items: const ['value', 'FOMO', 'breakout', 'revenge-trade', 'swing']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => tag = v!)),
        ElevatedButton(onPressed: log, child: const Text('Log trade')),
        const SizedBox(height: 12),
        Expanded(child: SingleChildScrollView(child: Text(jsonEncode(stats)))),
      ]),
    );
  }
}

// ---------- AUTOPSY ----------
class AutopsyPage extends StatefulWidget {
  const AutopsyPage({super.key});
  @override
  State<AutopsyPage> createState() => _AState();
}

class _AState extends State<AutopsyPage> {
  String out = 'Run forensics on any technique: PBO-lite + DSR-lite + MinBTL.';
  Future<void> run() async {
    setState(() => out = '…');
    final r = await http.post(Uri.parse('$api/forensics/autopsy'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': 'Momentum 12-1',
          'sharpe': 0.68,
          'trials': 47,
          'backtest_excess_bps': 309,
          'live_excess_bps': -150
        }));
    setState(() =>
        out = const JsonEncoder.withIndent('  ').convert(jsonDecode(r.body)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ElevatedButton(
            onPressed: run,
            child: const Text('How Dead Is This? — Momentum 12-1')),
        const SizedBox(height: 12),
        Expanded(child: SingleChildScrollView(child: SelectableText(out))),
      ]),
    );
  }
}

// ---------- SEBI ----------
class SebiPage extends StatefulWidget {
  const SebiPage({super.key});
  @override
  State<SebiPage> createState() => _SState();
}

class _SState extends State<SebiPage> {
  Map? s;
  @override
  void initState() {
    super.initState();
    getJ('/sebi/summary').then((v) => setState(() => s = v));
  }

  @override
  Widget build(BuildContext context) {
    if (s == null) return const Center(child: CircularProgressIndicator());
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('You Are In The 87.7%',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      Text('Source: ${s!['source']}'),
      ListTile(
          title: const Text('Lost money FY26'),
          trailing: Text('${s!['loss_rate']}%')),
      ListTile(
          title: const Text('Aggregate net loss'),
          trailing: Text('Rs.${s!['aggregate_net_loss_crore']} cr')),
      ListTile(
          title: const Text('Avg loss / trader'),
          trailing: Text('Rs.${s!['avg_loss_per_trader']}')),
      ListTile(
          title: const Text('Losses from OPTIONS'),
          trailing: Text('${s!['options_share_of_losses']}%')),
      ListTile(
          title: const Text('Algo share of pro profits'),
          trailing: Text('${s!['algo_share_of_pro_profits']}%')),
      const Divider(),
      const Text(
          'Virtually all individual losses trace to aggressive orders. — Barber et al. (2009)',
          style: TextStyle(fontStyle: FontStyle.italic)),
    ]);
  }
}
