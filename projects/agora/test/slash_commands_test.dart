import 'package:agora/ui/composer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('slashQueryAt', () {
    test('no slash at all is not a command', () {
      expect(slashQueryAt('hello', 5), isNull);
      expect(slashQueryAt('', 0), isNull);
      expect(slashQueryAt('@gemini hi', 10), isNull);
    });

    test('a caret outside the text is not a command', () {
      expect(slashQueryAt('/stop', -1), isNull);
      expect(slashQueryAt('/stop', 99), isNull);
    });

    test('an empty token opens the menu', () {
      expect(slashQueryAt('/', 1), '');
      expect(slashQueryAt('hi /', 4), '');
    });

    test('a partial token is returned without the slash', () {
      expect(slashQueryAt('/st', 3), 'st');
      expect(slashQueryAt('/stop', 5), 'stop');
      expect(slashQueryAt('hi /sn', 6), 'sn');
    });

    test('the token is read from the caret, not the end', () {
      expect(slashQueryAt('/stop now', 5), 'stop');
    });

    test('a URL is never mistaken for a command', () {
      expect(slashQueryAt('https://x', 9), isNull);
      expect(slashQueryAt('see http://a/b', 14), isNull);
    });

    test('a space closes the menu', () {
      expect(slashQueryAt('/stop now', 9), isNull);
    });

    test('a non-letter in the token closes the menu', () {
      expect(slashQueryAt('/st0', 4), isNull);
      expect(slashQueryAt('/s-t', 4), isNull);
    });
  });

  group('slashMatches', () {
    test('an empty query lists every real command', () {
      expect(slashMatches('').length, kSlashCommands.length);
      expect(
        slashMatches('').map((c) => c.name).toList(),
        kSlashCommands.map((c) => c.name).toList(),
      );
    });

    test('matching is a case-insensitive prefix', () {
      expect(slashMatches('s').map((c) => c.name).toList(), [
        'stop',
        'snapshot',
      ]);
      expect(slashMatches('ST').map((c) => c.name).toList(), ['stop']);
      expect(slashMatches('ex').map((c) => c.name).toList(), ['export']);
    });

    test('an unknown prefix matches nothing', () {
      expect(slashMatches('zzz'), isEmpty);
    });
  });

  group('commandFor', () {
    test('a bare command resolves', () {
      expect(commandFor('/stop')?.name, 'stop');
      expect(commandFor('/help')?.name, 'help');
    });

    test('trailing arguments are ignored', () {
      expect(commandFor('/stop now')?.name, 'stop');
      expect(commandFor('/export today')?.name, 'export');
    });

    test('text that is not a bare command is an ordinary message', () {
      expect(commandFor('hello'), isNull);
      expect(commandFor(' /stop'), isNull);
      expect(commandFor('/'), isNull);
      expect(commandFor('/stopnow'), isNull);
      expect(commandFor('/nope'), isNull);
    });
  });

  group('the command surface is real', () {
    test('exactly the wired commands exist', () {
      expect(kSlashCommands.map((c) => c.name).toList(), [
        'stop',
        'snapshot',
        'export',
        'archived',
        'help',
      ]);
    });

    test('every command has help text and a unique name', () {
      for (final c in kSlashCommands) {
        expect(c.help.trim(), isNotEmpty, reason: '/${c.name} needs help text');
      }
      final names = kSlashCommands.map((c) => c.name).toSet();
      expect(names.length, kSlashCommands.length);
    });

    test('§18.3 commands with no engine behind them are absent', () {
      for (final name in const [
        'adversarial',
        'fork',
        'template',
        'roles',
        'inject',
      ]) {
        expect(
          commandFor('/$name'),
          isNull,
          reason: '/$name must not appear until its engine exists',
        );
      }
    });
  });
}
