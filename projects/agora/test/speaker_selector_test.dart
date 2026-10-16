import 'package:flutter_test/flutter_test.dart';

import 'package:agora/core/orchestration/council_protocol.dart';
import 'package:agora/core/orchestration/speaker_selector.dart';

/// The §18.1 table, exercised row by row.
///
/// Every case here is a rule that PLAN.md §18.1 states in prose. If one of
/// these goes red, the ratified dispatch contract has been broken.
void main() {
  const leader = 'gpt';
  const gem = 'gemini';
  const deep = 'deepseek';
  const participants = [leader, gem, deep];

  CouncilBlock block(CouncilAction action, {String? agent, String? task}) =>
      CouncilBlock(action: action, agent: agent, task: task);

  SpeakerDecision select(
    CouncilAction action, {
    String sender = leader,
    String? agent,
    List<String> members = participants,
  }) => SpeakerSelector.select(
    block: block(action, agent: agent),
    senderKind: sender,
    leaderKind: leader,
    participants: members,
  );

  group('invite — public, leader only', () {
    test('the leader reaches exactly the named participant', () {
      final d = select(CouncilAction.invite, agent: gem);
      expect(d.isRejected, isFalse);
      expect(d.targets, [gem]);
      expect(d.visibility, ChannelKind.publicChannel);
      expect(d.channelKey, isNull);
      expect(d.dispatches, isTrue);
    });

    test('a delegate may not invite', () {
      final d = select(CouncilAction.invite, sender: gem, agent: deep);
      expect(d.isRejected, isTrue);
      expect(d.error, contains('only the leader'));
      expect(d.targets, isEmpty);
    });

    test('a non-participant target is refused', () {
      final d = select(CouncilAction.invite, agent: 'claude');
      expect(d.isRejected, isTrue);
      expect(d.error, contains('not a participant'));
    });

    test('inviting yourself is refused', () {
      final d = select(CouncilAction.invite, agent: leader);
      expect(d.isRejected, isTrue);
      expect(d.error, contains('cannot target the sender'));
    });

    test('a missing target is refused', () {
      final d = select(CouncilAction.invite);
      expect(d.isRejected, isTrue);
      expect(d.error, contains('requires "agent"'));
    });
  });

  group('broadcast — public, leader only', () {
    test('the leader reaches every other participant, in roster order', () {
      final d = select(CouncilAction.broadcast);
      expect(d.isRejected, isFalse);
      expect(d.targets, [gem, deep]);
      expect(d.visibility, ChannelKind.publicChannel);
      expect(d.channelKey, isNull);
      expect(d.dispatches, isTrue);
    });

    test(
      'a delegate may not broadcast — it is not the old free-text round robin',
      () {
        final d = select(CouncilAction.broadcast, sender: gem);
        expect(d.isRejected, isTrue);
        expect(d.error, contains('only the leader'));
      },
    );

    test('a solo session has nobody to broadcast to', () {
      final d = select(CouncilAction.broadcast, members: const [leader]);
      expect(d.isRejected, isTrue);
      expect(d.error, contains('no other participant'));
    });
  });

  group('dm — private, any participant', () {
    test('the leader can dm one participant', () {
      final d = select(CouncilAction.dm, agent: gem);
      expect(d.isRejected, isFalse);
      expect(d.targets, [gem]);
      expect(d.visibility, ChannelKind.privateChannel);
      expect(d.visibility.isPrivate, isTrue);
      expect(d.channelKey, SpeakerSelector.dmChannelKey(leader, gem));
    });

    test('a delegate can dm the leader — the R1 power', () {
      final d = select(CouncilAction.dm, sender: gem, agent: leader);
      expect(d.isRejected, isFalse);
      expect(d.targets, [leader]);
      expect(d.visibility, ChannelKind.privateChannel);
    });

    test('a delegate can dm another delegate', () {
      final d = select(CouncilAction.dm, sender: gem, agent: deep);
      expect(d.isRejected, isFalse);
      expect(d.targets, [deep]);
      expect(d.visibility, ChannelKind.privateChannel);
    });

    test('the channel key is symmetric, so both sides share one thread', () {
      expect(
        SpeakerSelector.dmChannelKey(gem, deep),
        SpeakerSelector.dmChannelKey(deep, gem),
      );
      expect(
        SpeakerSelector.dmChannelKey(gem, deep),
        isNot(SpeakerSelector.dmChannelKey(gem, leader)),
      );
      expect(SpeakerSelector.dmChannelKey(gem, deep), 'dm:deepseek|gemini');
    });

    test('dming a non-participant is refused', () {
      final d = select(CouncilAction.dm, sender: gem, agent: 'claude');
      expect(d.isRejected, isTrue);
      expect(d.error, contains('not a participant'));
    });

    test('dming yourself is refused', () {
      final d = select(CouncilAction.dm, sender: gem, agent: gem);
      expect(d.isRejected, isTrue);
      expect(d.error, contains('cannot target the sender'));
    });

    test('dm without a target is refused', () {
      final d = select(CouncilAction.dm);
      expect(d.isRejected, isTrue);
      expect(d.error, contains('requires "agent"'));
    });
  });

  group('decide / comment / need_input — public, leader only, no dispatch', () {
    for (final action in const [
      CouncilAction.decide,
      CouncilAction.comment,
      CouncilAction.needInput,
    ]) {
      test('the leader may ${action.wire} without addressing anyone', () {
        final d = select(action);
        expect(d.isRejected, isFalse);
        expect(d.targets, isEmpty);
        expect(d.dispatches, isFalse);
        expect(d.visibility, ChannelKind.publicChannel);
        expect(d.channelKey, isNull);
      });

      test('a delegate may not ${action.wire}', () {
        final d = select(action, sender: gem);
        expect(d.isRejected, isTrue);
        expect(d.error, contains('only the leader'));
      });
    }
  });

  group('sender must be a participant', () {
    test('an unknown sender is refused before any other rule', () {
      final d = select(CouncilAction.dm, sender: 'claude', agent: gem);
      expect(d.isRejected, isTrue);
      expect(d.error, contains('not a participant in this session'));
    });
  });

  group('free text never dispatches', () {
    test('a block only exists if CouncilProtocol.parse found a fence', () {
      final parse = CouncilProtocol.parse('we should probably invite gemini');
      expect(parse.hasBlock, isFalse);

      final real = CouncilProtocol.parse('''
Fine, let us ask.

```council
{"action":"invite","agent":"gemini","task":"Review the plan"}
```
''');
      expect(real.hasBlock, isTrue);
      final d = SpeakerSelector.select(
        block: real.block!,
        senderKind: leader,
        leaderKind: leader,
        participants: participants,
      );
      expect(d.targets, [gem]);
    });
  });

  test('toString names the decision', () {
    expect(
      select(CouncilAction.invite, agent: gem).toString(),
      contains('public'),
    );
    expect(
      select(CouncilAction.invite, sender: gem, agent: deep).toString(),
      contains('rejected'),
    );
  });

  group('dmChannelMembers — the inverse of dmChannelKey', () {
    test('splits a well-formed key back into its sorted pair', () {
      expect(
        SpeakerSelector.dmChannelMembers(
          SpeakerSelector.dmChannelKey('gemini', 'deepseek'),
        ),
        <String>['deepseek', 'gemini'],
      );
    });

    test('rejects anything that is not a well-formed dm key', () {
      expect(SpeakerSelector.dmChannelMembers(''), isEmpty);
      expect(SpeakerSelector.dmChannelMembers('public'), isEmpty);
      expect(SpeakerSelector.dmChannelMembers('dm:'), isEmpty);
      expect(SpeakerSelector.dmChannelMembers('dm:solo'), isEmpty);
      expect(SpeakerSelector.dmChannelMembers('dm:a|b|c'), isEmpty);
      expect(SpeakerSelector.dmChannelMembers('dm:a|'), isEmpty);
      expect(SpeakerSelector.dmChannelMembers('dm:|b'), isEmpty);
    });
  });
}
