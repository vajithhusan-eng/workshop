import 'dart:convert';

import 'package:crypto/crypto.dart';

/// sha256 of [text], truncated to 32 hex chars.
///
/// This is the Verbatim Vault integrity stamp (upgrade C3). Stored alongside
/// every agent message so that if Agora ever altered someone's output, the
/// mismatch would be provable rather than a matter of trust.
///
/// 32 hex chars = 128 bits. Far beyond enough to detect accidental mutation
/// or tampering, and short enough to keep the database readable.
String contentHash(String text) =>
    sha256.convert(utf8.encode(text)).toString().substring(0, 32);

/// Bytes as a truncated lowercase hex digest, for binary payloads
/// (screenshots, packet bodies).
String hashBytes(List<int> bytes) =>
    sha256.convert(bytes).toString().substring(0, 32);
