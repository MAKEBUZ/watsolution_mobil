import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watsolution_mobil/field/offline_permit.dart';

void main() {
  final now = DateTime.utc(2026, 10, 5, 8);
  late SimpleKeyPair key;
  late String publicKey;
  late String token;
  setUp(() async {
    key = await Ed25519().newKeyPair();
    publicKey = base64Encode((await key.extractPublicKey()).bytes);
    String encode(Object value) =>
        base64UrlEncode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final content =
        '${encode({'alg': 'EdDSA', 'typ': 'JWT'})}.${encode({'iss': 'watsolution-api', 'aud': 'watsolution-offline', 'sub': '7', 'installationId': 'device-a', 'iat': now.millisecondsSinceEpoch ~/ 1000, 'exp': now.add(const Duration(hours: 12)).millisecondsSinceEpoch ~/ 1000})}';
    final signature = await Ed25519().sign(utf8.encode(content), keyPair: key);
    token = '$content.${base64UrlEncode(signature.bytes).replaceAll('=', '')}';
  });
  Future<OfflinePermit> verify({
    String? account,
    String? device,
    DateTime? time,
    DateTime? lastSeen,
    String? grant,
  }) => OfflinePermit.verify(
    token: grant ?? token,
    publicKey: publicKey,
    accountId: account ?? '7',
    installationId: device ?? 'device-a',
    now: time ?? now,
    lastSeen: lastSeen,
  );
  test(
    'accepts the server-signed grant for its account and installation',
    () async {
      expect((await verify()).expiresAt, now.add(const Duration(hours: 12)));
    },
  );
  test('rejects another account', () async {
    await expectLater(verify(account: '8'), throwsFormatException);
  });
  test('rejects another installation', () async {
    await expectLater(verify(device: 'device-b'), throwsFormatException);
  });
  test('rejects an expired grant', () async {
    await expectLater(
      verify(time: now.add(const Duration(hours: 12))),
      throwsFormatException,
    );
  });
  test('rejects clock rollback', () async {
    await expectLater(
      verify(lastSeen: now.add(const Duration(hours: 1))),
      throwsFormatException,
    );
  });
  test('rejects an altered signature', () async {
    final parts = token.split('.');
    parts[2] = base64UrlEncode(List.filled(64, 0));
    await expectLater(verify(grant: parts.join('.')), throwsFormatException);
  });
}
