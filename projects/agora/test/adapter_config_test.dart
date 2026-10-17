import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:agora/core/adapters/adapter_config.dart';

/// Only `kind` and `homeUrl` are required by [AdapterConfig.fromJson]; every
/// other field has a default, so an adapter can be built from two keys.
AdapterConfig _adapterWith(String homeUrl) =>
    AdapterConfig.fromJson({'kind': 'sandbox', 'homeUrl': homeUrl});

/// The fixture that ships in the repository.
const _fixtureRelUrl = 'file://./tool/sandbox/mock_ai_site.html';

void main() {
  group('AdapterConfig.homeUrl', () {
    test('http and about: URLs pass through untouched', () {
      expect(
        _adapterWith('https://chat.example.com/').homeUrl,
        'https://chat.example.com/',
      );
      expect(_adapterWith('about:blank').homeUrl, 'about:blank');
    });

    test('an already-absolute file:// URL is left alone', () {
      const absolute = 'file:///tmp/agora-mock-site.html';
      expect(_adapterWith(absolute).homeUrl, absolute);
    });

    test('a relative file:// URL resolves against the working directory', () {
      final url = _adapterWith(_fixtureRelUrl).homeUrl;
      // No machine's directory layout is baked into the config any more.
      expect(url, startsWith('file:///'));
      expect(
        Uri.parse(url).toFilePath(),
        p.join(Directory.current.path, 'tool', 'sandbox', 'mock_ai_site.html'),
      );
    });

    test('the shipped fixture URL points at a file that exists', () {
      // This is the assertion the repository actually needs: the Sandbox Lab
      // fixture must resolve to a real file from the package root.
      final file = Uri.parse(_adapterWith(_fixtureRelUrl).homeUrl).toFilePath();
      expect(File(file).existsSync(), isTrue, reason: '$file is missing');
    });

    test('a parent-relative file:// URL is normalised, not left as ".."', () {
      final url = _adapterWith('file://../sibling.html').homeUrl;
      expect(url, isNot(contains('/../')));
      expect(
        p.normalize(Uri.parse(url).toFilePath()),
        p.join(p.dirname(Directory.current.path), 'sibling.html'),
      );
    });

    test('the shipped fixture adapter parses and validates', () {
      // The fixture is a complete adapter, so it must survive validate() — and
      // its homeUrl must resolve to a real file, from the package root.
      final file = File(p.join('tool', 'sandbox', 'adapter_sandbox.json'));
      final adapter = AdapterConfig.parse(
        file.readAsStringSync(),
        origin: 'sandbox fixture',
      );
      expect(adapter.homeUrl, startsWith('file:///'));
      expect(
        Uri.parse(adapter.homeUrl).toFilePath(),
        p.join(Directory.current.path, 'tool', 'sandbox', 'mock_ai_site.html'),
      );
      expect(adapter.isValid, isTrue, reason: adapter.validate().join('; '));
    });
  });
}
