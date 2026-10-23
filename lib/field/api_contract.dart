/// Validation at the network boundary. Never retain arbitrary account fields
/// (the published schema includes fields that must not enter local storage).
class FieldAccount {
  final String id;
  final String login;
  final List<String> roles;
  const FieldAccount(this.id, this.login, this.roles);

  factory FieldAccount.parse(dynamic value) {
    if (value is! Map ||
        value['login'] is! String ||
        (value['login'] as String).trim().isEmpty ||
        value['authorities'] is! List ||
        (value['authorities'] as List).any((role) => role is! String)) {
      throw const FormatException('La API devolvió una cuenta inválida.');
    }
    final roles = List<String>.from(value['authorities']);
    if (!roles.any((r) => r == 'ROLE_ADMIN' || r == 'ROLE_OPERATOR')) {
      throw StateError(
        'Esta app es exclusiva para operadores y administradores.',
      );
    }
    return FieldAccount(
      '${value['id'] ?? value['login']}',
      value['login'],
      roles,
    );
  }
}

String accessToken(dynamic value) {
  if (value is! Map ||
      value['id_token'] is! String ||
      (value['id_token'] as String).isEmpty) {
    throw const FormatException('La API no devolvió una sesión válida.');
  }
  return value['id_token'];
}

Map<String, dynamic> publicPerson(dynamic value) {
  if (value is! Map ||
      value['id'] is! int ||
      value['id'] < 1 ||
      value['fullName'] is! String) {
    throw const FormatException('La API devolvió una persona inválida.');
  }
  return {
    'id': value['id'],
    'fullName': value['fullName'],
    'subscriberNumber': value['subscriberNumber']?.toString(),
  };
}

Map<String, dynamic> readingAcknowledgement(dynamic value, Map command) {
  if (value is! Map ||
      value['operationId'] != command['operationId'] ||
      value['personId'] != command['personId'] ||
      value['meterId'] is! int ||
      value['meterId'] < 1 ||
      value['waterMeasure'] != command['waterMeasure'] ||
      value['readingDate'] != command['readingDate']) {
    throw const FormatException('Confirmación inválida del servidor.');
  }
  return Map<String, dynamic>.from(value);
}

Map<String, dynamic> preparedPerson(dynamic value) {
  final person = publicPerson(value);
  final meter = value['previousMeterId'];
  final reading = value['previousReading'];
  final date = value['previousDate'];
  if (meter != null &&
      (meter is! int ||
          meter < 1 ||
          reading is! num ||
          !reading.isFinite ||
          reading < 0 ||
          date is! String ||
          DateTime.tryParse(date) == null)) {
    throw const FormatException('Referencia de lectura inválida.');
  }
  if (meter == null && (reading != null || date != null)) {
    throw const FormatException('Referencia de lectura incompleta.');
  }
  return {
    ...person,
    'previousMeterId': meter,
    'previousReading': reading,
    'previousDate': date,
  };
}

int retryDelaySeconds(int attempts, String? retryAfter) {
  final requested = int.tryParse(retryAfter ?? '');
  if (requested != null) return requested.clamp(5, 3600);
  return (5 * (1 << attempts.clamp(0, 9))).clamp(5, 3600);
}
