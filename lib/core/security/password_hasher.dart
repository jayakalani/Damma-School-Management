import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class PasswordHasher {
  const PasswordHasher({this.iterations = 210000, this.saltLength = 16});

  static const _algorithm = 'pbkdf2_sha256';
  final int iterations;
  final int saltLength;

  String hash(String password) {
    final salt = List<int>.generate(
      saltLength,
      (_) => Random.secure().nextInt(256),
    );
    final derivedKey = _deriveKey(utf8.encode(password), salt, iterations);
    return [
      _algorithm,
      iterations.toString(),
      base64Url.encode(salt),
      base64Url.encode(derivedKey),
    ].join(r'$');
  }

  bool verify(String password, String encodedHash) {
    final parts = encodedHash.split(r'$');
    if (parts.length != 4 || parts[0] != _algorithm) {
      return false;
    }

    final storedIterations = int.tryParse(parts[1]);
    if (storedIterations == null || storedIterations <= 0) {
      return false;
    }

    try {
      final salt = base64Url.decode(parts[2]);
      final expected = base64Url.decode(parts[3]);
      final actual = _deriveKey(utf8.encode(password), salt, storedIterations);
      return _constantTimeEquals(actual, expected);
    } on FormatException {
      return false;
    }
  }

  List<int> _deriveKey(List<int> password, List<int> salt, int rounds) {
    final hmac = Hmac(sha256, password);
    final firstBlock = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final result = Uint8List.fromList(firstBlock);
    var previous = firstBlock;

    for (var round = 1; round < rounds; round++) {
      previous = hmac.convert(previous).bytes;
      for (var index = 0; index < result.length; index++) {
        result[index] ^= previous[index];
      }
    }
    return result;
  }

  bool _constantTimeEquals(List<int> first, List<int> second) {
    if (first.length != second.length) {
      return false;
    }
    var difference = 0;
    for (var index = 0; index < first.length; index++) {
      difference |= first[index] ^ second[index];
    }
    return difference == 0;
  }
}