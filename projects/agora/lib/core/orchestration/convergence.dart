import 'dart:math' as math;

import '../logging.dart';

/// One agent's self-assessment of the council's current candidate answer.
/// This is how Agora measures convergence (A3/A4) without guessing.
class AgentVerdict {
  AgentVerdict({
    required this.agentKind,
    required this.score,
    required this.confidence,
    required this.reason,
    required this.text,
  });

  final String agentKind;

  /// 0..10 — how good the agent thinks the current answer is.
  final double score;

  /// 0..1 — how sure it is.
  final double confidence;

  final String reason;

  /// Verbatim agent reply. Never rewritten.
  final String text;

  bool get satisfied => score >= 7.5 && confidence >= 0.6;
}

/// A single point on the Convergence Graph.
class ConvergencePoint {
  ConvergencePoint({
    required this.round,
    required this.similarity,
    required this.meanScore,
    required this.meanConfidence,
    required this.agreement,
    required this.answered,
    required this.satisfiedFraction,
  });

  final int round;

  /// 0..1 — how close this round's answers are to the previous round's.
  final double similarity;

  final double meanScore;
  final double meanConfidence;

  /// 0..1 — pairwise text agreement between the agents that answered this round.
  final double agreement;

  final int answered;
  final double satisfiedFraction;

  @override
  String toString() =>
      'r$round sim=${similarity.toStringAsFixed(2)} '
      'score=${meanScore.toStringAsFixed(1)} agree=${agreement.toStringAsFixed(2)}';
}

/// Verdict of the whole council for a round.
enum ConvergenceState { gathering, converged, stagnant, unknown }

class ConvergenceReport {
  ConvergenceReport({
    required this.state,
    required this.reason,
    required this.points,
    required this.latest,
    required this.verdicts,
    required this.stagnantRounds,
  });

  final ConvergenceState state;
  final String reason;
  final List<ConvergencePoint> points;
  final ConvergencePoint? latest;
  final List<AgentVerdict> verdicts;

  /// How many consecutive rounds have shown no meaningful movement.
  final int stagnantRounds;

  bool get shouldStop =>
      state == ConvergenceState.converged || state == ConvergenceState.stagnant;

  /// Data for the Convergence Graph widget.
  List<double> get scoreSeries => points.map((p) => p.meanScore).toList();
  List<double> get similaritySeries => points.map((p) => p.similarity).toList();
}

/// Decides when the council has actually stopped making progress.
///
/// This is upgrade A4 (Convergence Graph) and B3 (Stagnation detector): the
/// mechanism that makes "talk until it's solved" terminate instead of burning
/// your quota and your afternoon.
///
/// Three independent signals, because any one alone is gameable:
///   1. Self-reported scores  — agents rate the candidate answer (A3).
///   2. Text convergence     — are the answers getting measurably more alike?
///   3. Stagnation           — have several rounds produced the same answer?
///
/// Design note: this NEVER edits or summarises anyone's words. It only reads
/// numbers off them. The verbatim guarantee is absolute.
class ConvergenceScorer {
  ConvergenceScorer({
    this.convergeThreshold = 0.82,
    this.stagnationThreshold = 0.97,
    this.stagnationRoundsToStop = 2,
    this.satisfiedFractionNeeded = 0.6,
    this.minRoundsBeforeConverge = 2,
  });

  /// Pairwise similarity above this counts as "they agree".
  final double convergeThreshold;

  /// Similarity at or above this for N rounds means nobody is changing their mind.
  final double stagnationThreshold;

  final int stagnationRoundsToStop;

  /// Fraction of voting agents that must be satisfied to call it converged.
  final double satisfiedFractionNeeded;

  /// Refuse to declare victory before this many rounds have happened.
  final int minRoundsBeforeConverge;

  final List<ConvergencePoint> _points = <ConvergencePoint>[];

  List<ConvergencePoint> get points =>
      List<ConvergencePoint>.unmodifiable(_points);

  int get length => _points.length;

  void reset() => _points.clear();

  /// Record a completed round.
  ///
  /// [round] 1-based round number.
  /// [answers] agentKind -> that agent's verbatim reply for this round.
  /// [verdicts] self-reported scores, parsed from the same replies.
  ConvergenceReport record({
    required int round,
    required Map<String, String> answers,
    List<AgentVerdict> verdicts = const <AgentVerdict>[],
  }) {
    if (answers.isEmpty) {
      return ConvergenceReport(
        state: ConvergenceState.gathering,
        reason: 'no answers recorded for round $round',
        points: _points,
        latest: _points.isEmpty ? null : _points.last,
        verdicts: verdicts,
        stagnantRounds: 0,
      );
    }

    final agreement = _meanPairwiseSimilarity(answers);
    final previous = _points.isEmpty ? null : _points.last;

    // Similarity is computed against the PREVIOUS round's answers when we have
    // them; otherwise against the round's own internal agreement, so the graph
    // still starts at a meaningful value.
    final similarity = previous == null
        ? agreement
        : _crossRoundSimilarity(previous, answers);

    final scores = verdicts.map((v) => v.score).toList();
    final confs = verdicts.map((v) => v.confidence).toList();
    final satisfied =
        verdicts.where((v) => v.satisfied).length /
        math.max(1, verdicts.length);

    final point = ConvergencePoint(
      round: round,
      similarity: similarity,
      meanScore: scores.isEmpty
          ? 0
          : scores.reduce((a, b) => a + b) / scores.length,
      meanConfidence: confs.isEmpty
          ? 0
          : confs.reduce((a, b) => a + b) / confs.length,
      agreement: agreement,
      answered: answers.length,
      satisfiedFraction: satisfied,
    );
    _points.add(point);

    return _judge(round: round, verdicts: verdicts, satisfied: satisfied);
  }

  ConvergenceReport _judge({
    required int round,
    required List<AgentVerdict> verdicts,
    required double satisfied,
  }) {
    // Count consecutive stagnant rounds at the tail of the series.
    var stagnant = 0;
    for (var i = _points.length - 1; i >= 0; i--) {
      if (_points[i].similarity >= stagnationThreshold) {
        stagnant++;
      } else {
        break;
      }
    }

    if (stagnant >= stagnationRoundsToStop) {
      return ConvergenceReport(
        state: ConvergenceState.stagnant,
        reason:
            'answers have not changed for $stagnant consecutive rounds '
            '(similarity >= $stagnationThreshold) — more rounds will not help',
        points: _points,
        latest: _points.last,
        verdicts: verdicts,
        stagnantRounds: stagnant,
      );
    }

    if (round < minRoundsBeforeConverge) {
      return ConvergenceReport(
        state: ConvergenceState.gathering,
        reason:
            'round $round of at least $minRoundsBeforeConverge before '
            'convergence can be declared',
        points: _points,
        latest: _points.last,
        verdicts: verdicts,
        stagnantRounds: stagnant,
      );
    }

    final enoughVotes =
        verdicts.isNotEmpty &&
        satisfied >= satisfiedFractionNeeded &&
        verdicts.every((v) => v.confidence >= 0.5);
    final textsAgree = _points.last.agreement >= convergeThreshold;

    if (enoughVotes && textsAgree) {
      return ConvergenceReport(
        state: ConvergenceState.converged,
        reason:
            '${(satisfied * 100).round()}% of the council is satisfied and '
            'their answers agree (${_points.last.agreement.toStringAsFixed(2)} '
            '>= $convergeThreshold)',
        points: _points,
        latest: _points.last,
        verdicts: verdicts,
        stagnantRounds: stagnant,
      );
    }

    final why = <String>[
      if (verdicts.isEmpty) 'no self-assessments yet',
      if (verdicts.isNotEmpty && satisfied < satisfiedFractionNeeded)
        'only ${(satisfied * 100).round()}% satisfied',
      if (!textsAgree)
        'answers still disagree (${_points.last.agreement.toStringAsFixed(2)} '
            '< $convergeThreshold)',
    ];
    log.d('round $round not converged: ${why.join(', ')}');

    return ConvergenceReport(
      state: ConvergenceState.gathering,
      reason: why.join('; '),
      points: _points,
      latest: _points.last,
      verdicts: verdicts,
      stagnantRounds: stagnant,
    );
  }

  // ------------------------------------------------------------- similarity

  static final RegExp _wordSplit = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

  static List<String> _tokens(String text) => _wordSplit
      .allMatches(text.toLowerCase())
      .map((m) => m.group(0)!)
      .where((t) => t.isNotEmpty)
      .toList();

  /// Jaccard similarity over word sets, with a guard for tiny answers.
  static double similarity(String a, String b) {
    final ta = _tokens(a).toSet();
    final tb = _tokens(b).toSet();
    if (ta.isEmpty && tb.isEmpty) return 1;
    if (ta.isEmpty || tb.isEmpty) return 0;
    var inter = 0;
    // Iterate the smaller set.
    final small = ta.length <= tb.length ? ta : tb;
    final large = ta.length <= tb.length ? tb : ta;
    for (final t in small) {
      if (large.contains(t)) inter++;
    }
    final union = ta.length + tb.length - inter;
    return union == 0 ? 1 : inter / union;
  }

  static double _meanPairwiseSimilarity(Map<String, String> answers) {
    final entries = answers.entries.toList();
    if (entries.length < 2) return 1;
    var total = 0.0;
    var pairs = 0;
    for (var i = 0; i < entries.length; i++) {
      for (var j = i + 1; j < entries.length; j++) {
        total += similarity(entries[i].value, entries[j].value);
        pairs++;
      }
    }
    return pairs == 0 ? 1 : total / pairs;
  }

  /// Cross-round movement: 1.0 means "identical to last round".
  ///
  /// We compare the round's aggregate fingerprint against the previous point's.
  /// Since we only persist numbers, we store the previous round's joined text
  /// transiently on the point via [ConvergencePoint.similarity]'s sibling.
  double _crossRoundSimilarity(
    ConvergencePoint previous,
    Map<String, String> answers,
  ) {
    final joined = answers.values.join('\n');
    final prevJoined = _previousText ?? joined;
    _previousText = joined;
    return similarity(prevJoined, joined);
  }

  String? _previousText;

  // ------------------------------------------------------------ verdicts

  /// Pull self-assessments out of the council protocol of a scoring agent.
  ///
  /// The leader can force scoring by asking for this fenced block:
  ///   ```council_score {"score":8,"confidence":0.9,"reason":"..."}```
  /// Parsing is optional — a missing block just means "no vote", never an error.
  static AgentVerdict? parseVerdict(String agentKind, String reply) {
    const fence = 'council_score';
    final idx = reply.lastIndexOf('```$fence');
    if (idx < 0) return null;
    final start = reply.indexOf('\n', idx);
    final end = reply.indexOf('```', idx + 3);
    if (start < 0 || end < 0 || end <= start) return null;

    var score = 0.0;
    var confidence = 0.0;
    final reason = StringBuffer();
    // Deliberately tolerant: models emit wildly different shapes here.
    final scoreRe = RegExp(r'"?score"?\s*[:=]\s*([0-9]+(?:\.[0-9]+)?)');
    final confRe = RegExp(r'"?confidence"?\s*[:=]\s*([0-9]+(?:\.[0-9]+)?)');
    final reasonRe = RegExp(r'"?reason"?\s*[:=]\s*"([^"]*)"');
    final body = reply.substring(start, end);

    final s = scoreRe.firstMatch(body);
    if (s == null) return null;
    score = double.tryParse(s.group(1)!) ?? 0;
    if (score > 10) score = 10;
    if (score < 0) score = 0;

    final c = confRe.firstMatch(body);
    if (c != null) {
      confidence = double.tryParse(c.group(1)!) ?? 0;
      // Models frequently answer "0.8" or "8" for confidence; normalise both.
      if (confidence > 1 && confidence <= 10) confidence /= 10;
    }
    final r = reasonRe.firstMatch(body);
    if (r != null) reason.write(r.group(1));

    return AgentVerdict(
      agentKind: agentKind,
      score: score,
      confidence: confidence.clamp(0.0, 1.0),
      reason: reason.toString(),
      text: reply,
    );
  }

  /// Build the instruction that asks each agent for a score.
  static String scoringInstruction({required String roundLabel}) {
    return '''
[AGORA SCORING $roundLabel]
Before your answer, judge the council's CURRENT best answer so far, then end
your reply with exactly this block:

\`\`\`council_score
{"score": <0-10 integer>, "confidence": <0-1 decimal>, "reason": "<one short sentence>"}
\`\`\`

- score: how good the current best answer is (10 = ready to ship).
- confidence: how sure you are (0.0 - 1.0).
- reason: one sentence, plain text, no quotes inside.
Be honest. A council that stops early because everyone hedged is worthless.
''';
  }
}
