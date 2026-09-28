import 'package:agora/core/orchestration/council_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fence detection', () {
    test('finds a well-formed invite block', () {
      const reply = '''
Here is my analysis of the spec.

```council
{"action":"invite","agent":"gemini","task":"Critique the cathode spec"}
```
''';
      final r = CouncilProtocol.parse(
        reply,
        participants: ['gemini', 'deepseek'],
      );
      expect(r.isUsable, isTrue);
      expect(r.block!.action, CouncilAction.invite);
      expect(r.block!.agent, 'gemini');
      expect(r.block!.task, 'Critique the cathode spec');
    });

    test('ignores other fenced code blocks', () {
      const reply = '''
```python
print("hello")
```
```json
{"action": "invite"}
```
''';
      // A bare ```json fence is not a council block; the later ```council wins.
      final r = CouncilProtocol.parse(reply);
      expect(r.hasBlock, isFalse);
      expect(r.error, isNull);
    });

    test('is case-insensitive on the fence tag', () {
      const reply = '```COUNCIL\n{"action":"comment"}\n```';
      final r = CouncilProtocol.parse(reply);
      expect(r.isUsable, isTrue);
      expect(r.block!.action, CouncilAction.comment);
    });

    test('uses the last council block when several are present', () {
      const reply = '''
```council
{"action":"invite","agent":"gemini"}
```
Actually wait, let me reconsider.
```council
{"action":"decide","status":"solved","answer":"done"}
```
''';
      final r = CouncilProtocol.parse(reply);
      expect(r.block!.action, CouncilAction.decide);
      expect(r.block!.isSolved, isTrue);
    });
  });

  group('free text never dispatches', () {
    test('plain prose with no block yields no block', () {
      const reply =
          'I think I should ask Gemini to look at this. What do you think?';
      final r = CouncilProtocol.parse(reply);
      expect(r.hasBlock, isFalse);
      expect(r.block, isNull);
      expect(r.error, isNull, reason: 'absence of a block is not an error');
    });

    test('a council-ish mention in prose is not parsed', () {
      const reply =
          'Use the ```council block``` format when you want to invite me.';
      final r = CouncilProtocol.parse(reply);
      expect(r.hasBlock, isFalse);
    });

    test('malformed JSON is surfaced as an error, not guessed at', () {
      const reply = '```council\n{"action": "invite", agent: gemini}\n```';
      final r = CouncilProtocol.parse(reply);
      expect(r.hasBlock, isFalse);
      expect(r.hasError, isTrue);
      expect(r.error, contains('invalid JSON'));
    });

    test('non-object JSON is rejected', () {
      const reply = '```council\n["invite","gemini"]\n```';
      final r = CouncilProtocol.parse(reply);
      expect(r.hasError, isTrue);
      expect(r.error, contains('must be a JSON object'));
    });

    test('missing action is rejected', () {
      const reply = '```council\n{"agent":"gemini"}\n```';
      final r = CouncilProtocol.parse(reply);
      expect(r.hasError, isTrue);
      expect(r.error, contains('missing "action"'));
    });

    test('unknown action is rejected', () {
      const reply = '```council\n{"action":"launch_missiles"}\n```';
      final r = CouncilProtocol.parse(reply);
      expect(r.hasError, isTrue);
      expect(r.error, contains('unknown action'));
    });
  });

  group('invite validation', () {
    test('rejects an invite with no target', () {
      const reply = '```council\n{"action":"invite","task":"do it"}\n```';
      final r = CouncilProtocol.parse(reply, participants: ['gemini']);
      expect(r.hasError, isTrue);
      expect(r.error, contains('requires "agent"'));
    });

    test('rejects an invite to a non-participant', () {
      const reply = '```council\n{"action":"invite","agent":"claude"}\n```';
      final r = CouncilProtocol.parse(
        reply,
        participants: ['gemini', 'deepseek'],
      );
      expect(r.hasBlock, isFalse);
      expect(r.error, contains('not a participant'));
    });

    test('accepts an invite to a participant', () {
      const reply = '```council\n{"action":"invite","agent":"gemini"}\n```';
      final r = CouncilProtocol.parse(reply, participants: ['gemini']);
      expect(r.isUsable, isTrue);
    });

    test('when no participants are supplied, any target is allowed', () {
      const reply = '```council\n{"action":"invite","agent":"anyone"}\n```';
      final r = CouncilProtocol.parse(reply);
      expect(r.isUsable, isTrue);
    });
  });

  group('decide parsing', () {
    test('parses a solved decision with confidence and dissent', () {
      const reply = '''
```council
{"action":"decide","status":"solved","answer":"Use LFP for the cathode.",
 "confidence":0.82,"dissent":["gemini prefers NMC"]}
```
''';
      final r = CouncilProtocol.parse(reply);
      expect(r.block!.isSolved, isTrue);
      expect(r.block!.answer, 'Use LFP for the cathode.');
      expect(r.block!.confidence, closeTo(0.82, 1e-9));
      expect(r.block!.dissent, ['gemini prefers NMC']);
    });

    test('parses a blocked decision', () {
      const reply = '```council\n{"action":"decide","status":"blocked"}\n```';
      final r = CouncilProtocol.parse(reply);
      expect(r.block!.isBlocked, isTrue);
      expect(r.block!.isSolved, isFalse);
    });

    test('clamps out-of-range confidence', () {
      final high = CouncilProtocol.parse(
        '```council\n{"action":"decide","status":"solved","confidence":5}\n```',
      );
      expect(high.block!.confidence, 1.0);

      final low = CouncilProtocol.parse(
        '```council\n{"action":"decide","status":"solved","confidence":-2}\n```',
      );
      expect(low.block!.confidence, 0.0);
    });

    test('accepts confidence given as a string', () {
      final r = CouncilProtocol.parse(
        '```council\n{"action":"decide","status":"solved","confidence":"0.5"}\n```',
      );
      expect(r.block!.confidence, closeTo(0.5, 1e-9));
    });

    test('tolerates dissent as a bare string', () {
      final r = CouncilProtocol.parse(
        '```council\n{"action":"decide","status":"solved","dissent":"gemini disagreed"}\n```',
      );
      expect(r.block!.dissent, ['gemini disagreed']);
    });
  });

  group('need_input', () {
    test('parses need_input with underscore wire name', () {
      const reply = '```council\n{"action":"need_input"}\n```';
      final r = CouncilProtocol.parse(reply);
      expect(r.isUsable, isTrue);
      expect(r.block!.action, CouncilAction.needInput);
      expect(r.block!.action.wire, 'need_input');
    });
  });

  group('proseOf', () {
    test('separates human prose from the machine block', () {
      const reply = '''
My analysis says the electrolyte is fine.

```council
{"action":"decide","status":"solved","answer":"x"}
```
''';
      final prose = CouncilProtocol.proseOf(reply);
      expect(prose, contains('My analysis says'));
      expect(prose, isNot(contains('council')));
      expect(prose, isNot(contains('electrolyte is fine.\n{')));
    });

    test('returns the reply untouched when there is no block', () {
      const reply = 'Just prose.';
      expect(CouncilProtocol.proseOf(reply), 'Just prose.');
    });
  });

  group('leaderInstructions', () {
    test('lists participants and states the round cap', () {
      final s = CouncilProtocol.leaderInstructions(
        displayName: 'ChatGPT',
        participants: const [
          AgentBrief(
            kind: 'gemini',
            displayName: 'Gemini',
            roleCard: 'Battery electrochemist',
          ),
          AgentBrief(kind: 'deepseek', displayName: 'DeepSeek'),
        ],
        maxRounds: 12,
        requireDissent: true,
      );
      expect(s, contains('ChatGPT'));
      expect(s, contains('gemini'));
      expect(s, contains('deepseek'));
      expect(s, contains('Battery electrochemist'));
      expect(s, contains('12 rounds'));
      expect(s, contains('at least one other agent'));
    });

    test('the last fence in the preamble wins', () {
      final s = CouncilProtocol.leaderInstructions(
        displayName: 'ChatGPT',
        participants: const [AgentBrief(kind: 'gemini', displayName: 'Gemini')],
        maxRounds: 12,
        requireDissent: false,
      );
      // The preamble shows two example blocks (invite then decide). Parsing must
      // resolve to the LAST one, so an echoed preamble can never be mistaken for
      // a stale earlier instruction.
      final r = CouncilProtocol.parse(s);
      expect(r.isUsable, isTrue);
      expect(r.block!.action, CouncilAction.decide);
    });
  });
}
