import 'council_protocol.dart';

/// Which thread a dispatch lands in.
///
/// `wire` is the value stored in `channels.kind` (see PLAN.md §18.5 item 2);
/// a public dispatch is the session's main thread and carries a null
/// `messages.channel_id`.
enum ChannelKind {
  publicChannel('public'),
  privateChannel('private');

  const ChannelKind(this.wire);

  final String wire;

  bool get isPrivate => this == ChannelKind.privateChannel;
}

/// The result of applying the §18.1 sender table to one parsed [CouncilBlock].
///
/// Mirrors [CouncilParse]'s idiom: plain fields plus an [error] string and
/// boolean getters, so callers branch without exceptions.
class SpeakerDecision {
  const SpeakerDecision({
    this.targets = const [],
    this.visibility = ChannelKind.publicChannel,
    this.channelKey,
    this.error,
  });

  const SpeakerDecision.rejected(String reason) : this(error: reason);

  /// Participant kinds that receive an outbound packet. Empty for the
  /// leader-only actions that do not dispatch (decide, comment, need_input).
  final List<String> targets;

  final ChannelKind visibility;

  /// Non-null only for private threads; stable for a given pair of kinds.
  final String? channelKey;

  /// Non-null when the sender table forbids the block.
  final String? error;

  bool get isRejected => error != null;

  /// True when at least one packet should actually be sent.
  bool get dispatches => error == null && targets.isNotEmpty;

  @override
  String toString() => isRejected
      ? 'SpeakerDecision.rejected($error)'
      : 'SpeakerDecision(${visibility.wire}, targets=$targets)';
}

/// The §18.1 dispatch table, in executable form.
///
/// > | Action | Channel | Allowed senders |
/// > | `invite` | public | leader only |
/// > | `broadcast` | public | leader only |
/// > | `dm` | private | any participant |
/// > | `decide` / `comment` / `need_input` | public | leader only |
///
/// This is the single place that rule lives. It is pure: no I/O, no clock, no
/// Flutter, so it runs under plain `dart test` and in the Sandbox Lab.
///
/// The non-negotiable from §18.1 is upheld upstream by [CouncilProtocol.parse]:
/// a block only reaches this class if it came from a machine-readable
/// ```council fence, so free text never dispatches.
class SpeakerSelector {
  const SpeakerSelector._();

  static SpeakerDecision select({
    required CouncilBlock block,
    required String senderKind,
    required String leaderKind,
    required List<String> participants,
  }) {
    final action = block.action;

    if (!participants.contains(senderKind)) {
      return SpeakerDecision.rejected(
        'sender "$senderKind" is not a participant in this session',
      );
    }

    if (action.isLeaderOnly && senderKind != leaderKind) {
      return SpeakerDecision.rejected(
        'only the leader may ${action.wire}; "$senderKind" is not the leader',
      );
    }

    // The leader's own contributions land in the public thread but address
    // nobody — decide closes the round, comment annotates, need_input pauses.
    if (action == CouncilAction.decide ||
        action == CouncilAction.comment ||
        action == CouncilAction.needInput) {
      return const SpeakerDecision(visibility: ChannelKind.publicChannel);
    }

    if (action == CouncilAction.broadcast) {
      final targets = participants
          .where((kind) => kind != senderKind)
          .toList(growable: false);
      if (targets.isEmpty) {
        return const SpeakerDecision.rejected(
          'broadcast has no other participant to reach',
        );
      }
      return SpeakerDecision(targets: targets);
    }

    // invite / dm name exactly one target. parse() already enforced a
    // non-empty "agent" for hasTarget actions; re-checked here because this
    // class is also called directly from tests and the Sandbox Lab.
    final target = block.agent;
    if (target == null) {
      return SpeakerDecision.rejected('${action.wire} requires "agent"');
    }
    if (!participants.contains(target)) {
      return SpeakerDecision.rejected(
        '"$target" is not a participant in this session',
      );
    }
    if (target == senderKind) {
      return SpeakerDecision.rejected(
        '${action.wire} cannot target the sender ("$target")',
      );
    }

    if (action == CouncilAction.dm) {
      return SpeakerDecision(
        targets: [target],
        visibility: ChannelKind.privateChannel,
        channelKey: dmChannelKey(senderKind, target),
      );
    }

    return SpeakerDecision(targets: [target]);
  }

  /// Stable key for the private thread between two kinds.
  ///
  /// Sorted, so `dmChannelKey('a','b') == dmChannelKey('b','a')` — both sides of
  /// a dm resolve to the same `channels` row regardless of who sent first.
  static String dmChannelKey(String a, String b) {
    final pair = [a, b]..sort();
    return 'dm:${pair[0]}|${pair[1]}';
  }

  /// Inverse of [dmChannelKey]: the two participant kinds, in sorted order.
  ///
  /// Returns an empty list for anything that is not a well-formed dm key, so a
  /// caller can fall back deliberately instead of inventing a participant.
  static List<String> dmChannelMembers(String channelKey) {
    if (!channelKey.startsWith('dm:')) return const <String>[];
    final parts = channelKey.substring(3).split('|');
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
      return const <String>[];
    }
    return parts;
  }
}
