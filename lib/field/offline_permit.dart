import 'dart:convert';
import 'package:cryptography/cryptography.dart';

class OfflinePermit {
  final DateTime expiresAt;
  final DateTime issuedAt;
  const OfflinePermit(this.issuedAt, this.expiresAt);

  static Future<OfflinePermit> verify({
    required String token,
    required String publicKey,
    required String accountId,
    required String installationId,
    required DateTime now,
    DateTime? lastSeen,
  }) async {
    final parts = token.split('.');
    if (parts.length != 3) throw const FormatException('Permiso inválido');
    final header =
        jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[0]))))
            as Map;
    if (header['alg'] != 'EdDSA' || header['typ'] != 'JWT') {
      throw const FormatException('Firma inválida');
    }
    final key = SimplePublicKey(
      base64Decode(publicKey),
      type: KeyPairType.ed25519,
    );
    final valid = await Ed25519().verify(
      utf8.encode('${parts[0]}.${parts[1]}'),
      signature: Signature(
        base64Url.decode(base64Url.normalize(parts[2])),
        publicKey: key,
      ),
    );
    if (!valid) throw const FormatException('Firma inválida');
    final body =
        jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
            as Map;
    if (body['sub'] != accountId ||
        body['installationId'] != installationId ||
        body['aud'] != 'watsolution-offline' ||
        body['iss'] != 'watsolution-api') {
      throw const FormatException('Permiso de otra cuenta o dispositivo');
    }
    final issued = DateTime.fromMillisecondsSinceEpoch(
      (body['iat'] as int) * 1000,
      isUtc: true,
    );
    final expires = DateTime.fromMillisecondsSinceEpoch(
      (body['exp'] as int) * 1000,
      isUtc: true,
    );
    if (!expires.isAfter(now) ||
        issued.isAfter(now.add(const Duration(minutes: 2))) ||
        expires.difference(issued) > const Duration(hours: 12) ||
        !expires.isAfter(issued) ||
        (lastSeen != null &&
            now.isBefore(lastSeen.subtract(const Duration(minutes: 2))))) {
      throw const FormatException(
        'Conéctate para renovar el permiso sin conexión',
      );
    }
    return OfflinePermit(issued, expires);
  }
}
