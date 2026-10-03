/// Shared presentation primitives.
///
/// The visual grammar here is not decoration. This app's entire argument is
/// that a verdict should be harder to ignore than a number, so severity is
/// carried by colour **and** by an explicit word, never by colour alone —
/// roughly one in twelve men cannot reliably separate the red and green used
/// here, and "green = good" is exactly the traffic-light assumption this
/// product exists to interrogate.
library;

import 'package:flutter/material.dart';

import 'api.dart';

/// Severity buckets used across the whole app. Keeping them in one place is
/// what stops the forensics page showing "high" in red while the orders page
/// shows the same word in grey.
enum Sev { pass, warn, alert, bad, unknown, info }

Sev sevFrom(Object? raw) {
  final s = (raw ?? '').toString().toUpperCase();
  if (s.startsWith('REJECT') ||
      s == 'HIGH' ||
      s == 'SEVERE' ||
      s == 'IMPATIENT') {
    return Sev.bad;
  }
  if (s == 'ALERT' || s.contains('RISK')) return Sev.alert;
  if (s == 'MEDIUM' || s == 'ELEVATED' || s == 'WARN') return Sev.warn;
  if (s == 'LOW' || s.startsWith('PASS') || s == 'PATIENT') return Sev.pass;
  if (s == 'INFO' || s == 'NORMAL') return Sev.info;
  return Sev.unknown;
}

Color sevColor(Sev s, ColorScheme cs) => switch (s) {
  Sev.pass => const Color(0xFF1B7F4B),
  Sev.warn => const Color(0xFFB26A00),
  Sev.alert => const Color(0xFFC2410C),
  Sev.bad => cs.error,
  Sev.info => cs.primary,
  Sev.unknown => cs.outline,
};

IconData sevIcon(Sev s) => switch (s) {
  Sev.pass => Icons.verified_outlined,
  Sev.warn => Icons.error_outline,
  Sev.alert => Icons.report_problem_outlined,
  Sev.bad => Icons.dangerous_outlined,
  Sev.info => Icons.info_outline,
  Sev.unknown => Icons.help_outline,
};

/// Formats a number without pretending to more precision than we have.
/// `null` renders as an em dash rather than "null", because a blank cell is
/// honest and the string "null" is a bug report.
String fmt(Object? v, {int places = 2, String suffix = ''}) {
  if (v == null) return '—';
  if (v is num) {
    final s = v.toStringAsFixed(places);
    return '$s$suffix';
  }
  return '$v$suffix';
}

String rupees(num? v) {
  if (v == null) return '—';
  if (v.abs() >= 1e7) return '₹${(v / 1e7).toStringAsFixed(2)} Cr';
  if (v.abs() >= 1e5) return '₹${(v / 1e5).toStringAsFixed(2)} L';
  return '₹${v.toStringAsFixed(0)}';
}

/// The single most important widget in the app: a verdict that says what it
/// is, how bad it is, and why, all above the fold.
class VerdictBanner extends StatelessWidget {
  const VerdictBanner({
    super.key,
    required this.severity,
    required this.headline,
    this.detail,
    this.source,
  });

  final Object severity;
  final String headline;
  final String? detail;
  final String? source;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sev = sevFrom(severity);
    final color = sevColor(sev, cs);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(sevIcon(sev), color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  headline,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          if (detail != null && detail!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(detail!, style: const TextStyle(height: 1.35)),
          ],
          if (source != null && source!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Source(source!),
          ],
        ],
      ),
    );
  }
}

/// Every figure in this app carries its provenance. A number with no source
/// is how people end up trading on a blog post.
class Source extends StatelessWidget {
  const Source(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 11.5,
      fontStyle: FontStyle.italic,
      color: Theme.of(context).colorScheme.outline,
      height: 1.3,
    ),
  );
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.severity,
    this.source,
  });

  final String label;
  final String value;
  final Object? severity;
  final String? source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = severity == null
        ? theme.colorScheme.onSurface
        : sevColor(sevFrom(severity), theme.colorScheme);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(label, style: theme.textTheme.bodySmall),
          if (source != null) Source(source!),
        ],
      ),
    );
  }
}

/// Key on the left, value on the right. Used for the small factual rows where
/// a StatTile's vertical layout would waste the width.
class Kv extends StatelessWidget {
  const Kv(this.k, this.v, {super.key, this.severity, this.bold = false});
  final String k;
  final String v;
  final Object? severity;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = severity == null
        ? theme.colorScheme.onSurface
        : sevColor(sevFrom(severity), theme.colorScheme);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 5, child: Text(k, style: theme.textTheme.bodyMedium)),
          Expanded(
            flex: 4,
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoadingBox extends StatelessWidget {
  const LoadingBox([this.label = 'Loading']);
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(fontSize: 12.5)),
      ],
    ),
  );
}

/// A backend failure is shown with its remedy. Silently retrying, or showing
/// "something went wrong", wastes the one moment where the user can be told
/// exactly what to do.
class ErrorBox extends StatelessWidget {
  const ErrorBox(this.message, {super.key, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.4),
        border: Border.all(color: cs.error.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_off, color: cs.error, size: 18),
              const SizedBox(width: 8),
              Text(
                'Could not load',
                style: TextStyle(fontWeight: FontWeight.w700, color: cs.error),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(message, style: const TextStyle(fontSize: 12.5)),
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}

class EmptyBox extends StatelessWidget {
  const EmptyBox(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Theme.of(context).colorScheme.outline,
        fontStyle: FontStyle.italic,
        fontSize: 12.5,
        height: 1.4,
      ),
    ),
  );
}

/// A run button that reports its own in-flight state, so a slow call cannot be
/// double-submitted and the user is never left wondering whether it worked.
class RunButton extends StatelessWidget {
  const RunButton({
    super.key,
    required this.onPressed,
    required this.busy,
    required this.label,
    this.icon,
    this.busyLabel = 'Working…',
  });

  final VoidCallback onPressed;
  final bool busy;
  final String label;
  final String busyLabel;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: busy ? null : onPressed,
    icon: busy
        ? const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon ?? Icons.play_arrow, size: 18),
    label: Text(busy ? busyLabel : label),
  );
}

/// A section that loads itself once and can be reloaded on demand.
class AsyncSection<T> extends StatefulWidget {
  const AsyncSection({
    super.key,
    required this.future,
    required this.builder,
    this.loadingLabel = 'Loading',
  });

  final Future<Result<T>> Function() future;
  final Widget Function(BuildContext, T) builder;
  final String loadingLabel;

  @override
  State<AsyncSection<T>> createState() => _AsyncSectionState<T>();
}

class _AsyncSectionState<T> extends State<AsyncSection<T>> {
  late Future<Result<T>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.future();
  }

  void _reload() => setState(() => _future = widget.future());

  @override
  Widget build(BuildContext context) => FutureBuilder<Result<T>>(
    future: _future,
    builder: (context, snap) {
      if (!snap.hasData) return LoadingBox(widget.loadingLabel);
      final r = snap.data!;
      if (!r.ok) return ErrorBox(r.error!, onRetry: _reload);
      return widget.builder(context, r.value as T);
    },
  );
}

/// Labelled numeric input. Parses defensively and falls back to [fallback]
/// rather than throwing — a half-typed number should not crash the tab, but
/// it must not silently become a flattering default either, so the fallback is
/// always the endpoint's own default, never a better-looking number.
class NumField extends StatelessWidget {
  const NumField({
    super.key,
    required this.label,
    required this.controller,
    this.fallback = 0,
    this.decimals = 2,
    this.hint,
    this.helper,
  });

  final String label;
  final TextEditingController controller;
  final double fallback;
  final int decimals;
  final String? hint;
  final String? helper;

  double read() => double.tryParse(controller.text.trim()) ?? fallback;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      helperMaxLines: 2,
      border: const OutlineInputBorder(),
      isDense: true,
    ),
    onChanged: (_) => setState(() {}),
  );
}

/// Rebuilds when a NumField's contents change, so dependent readouts stay live.
class NumFieldStateful extends StatelessWidget {
  const NumFieldStateful({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      StatefulBuilder(builder: (context, setState) => child);
}
