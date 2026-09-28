import 'dart:async';
import 'dart:collection';

/// Minimal leveled logger with an in-memory ring buffer (feeds the UI log panel).
enum LogLevel { debug, info, warn, error }

class LogRecord {
  LogRecord(
    this.level,
    this.tag,
    this.message, {
    this.error,
    this.stack,
    DateTime? at,
  }) : at = at ?? _now();

  static DateTime _now() => DateTime.now();

  final LogLevel level;
  final String tag;
  final String message;
  final Object? error;
  final StackTrace? stack;
  final DateTime at;

  String format() {
    final ts = at.toIso8601String().substring(11, 23);
    final lvl = level.name.toUpperCase().padRight(5);
    final buf = StringBuffer('$ts $lvl [$tag] $message');
    if (error != null) buf.write('\n      -> $error');
    if (stack != null) {
      for (final l in stack.toString().trim().split('\n').take(6)) {
        buf.write('\n      $l');
      }
    }
    return buf.toString();
  }
}

/// Namespaced logger. Records are buffered globally so the UI can show them.
class Logger {
  Logger(this.tag);

  final String tag;

  static final Queue<LogRecord> _records = Queue<LogRecord>();
  static final StreamController<LogRecord> _controller =
      StreamController<LogRecord>.broadcast();
  static const int maxBuffered = 2000;

  /// When false, [d] output is dropped (turn off in release builds).
  static bool debugEnabled = true;

  static Stream<LogRecord> get stream => _controller.stream;
  static List<LogRecord> get buffered => List.unmodifiable(_records);

  void d(String m) => _write(LogLevel.debug, tag, m);
  void i(String m) => _write(LogLevel.info, tag, m);
  void w(String m, [Object? error, StackTrace? stack]) =>
      _write(LogLevel.warn, tag, m, error, stack);
  void e(String m, [Object? error, StackTrace? stack]) =>
      _write(LogLevel.error, tag, m, error, stack);

  static void _write(
    LogLevel level,
    String tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) {
    if (level == LogLevel.debug && !debugEnabled) return;
    final rec = LogRecord(level, tag, message, error: error, stack: stack);
    _records.addLast(rec);
    while (_records.length > maxBuffered) {
      _records.removeFirst();
    }
    if (!_controller.isClosed) _controller.add(rec);
  }
}

/// Build a namespaced logger: `final log = 'cdp'.log;`
extension LoggerExt on String {
  Logger get log => Logger(this);
}

/// Process-wide default, so call sites can just use `log.i(...)`.
class _GlobalLog {
  _GlobalLog() : _default = Logger('agora');

  final Logger _default;
  void d(String m) => _default.d(m);
  void i(String m) => _default.i(m);
  void w(String m, [Object? error, StackTrace? stack]) =>
      _default.w(m, error, stack);
  void e(String m, [Object? error, StackTrace? stack]) =>
      _default.e(m, error, stack);
}

final log = _GlobalLog();
