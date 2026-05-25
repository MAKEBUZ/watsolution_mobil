import 'dart:convert';

class LocalPerson {
  final int? id;
  final int? serverId;
  final String fullName;
  final String documentNumber;
  final String? phone;
  final String? email;
  final String status;
  final int? addressId;
  final String syncStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  // Campos del backend NestJS
  final String? subscriberNumber;
  final int? stratum;
  final String? userId;
  final int? greenPoints;
  final int? daysSinceLastDebt;
  final double? savingsPercent;

  LocalPerson({
    this.id,
    this.serverId,
    required this.fullName,
    required this.documentNumber,
    this.phone,
    this.email,
    this.status = 'active',
    this.addressId,
    this.syncStatus = 'pending',
    this.createdAt,
    this.updatedAt,
    this.subscriberNumber,
    this.stratum,
    this.userId,
    this.greenPoints,
    this.daysSinceLastDebt,
    this.savingsPercent,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'server_id': serverId,
      'full_name': fullName,
      'document_number': documentNumber,
      'phone': phone,
      'email': email,
      'status': status,
      'address_id': addressId,
      'sync_status': syncStatus,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'subscriber_number': subscriberNumber,
      'stratum': stratum,
      'user_id': userId,
      'green_points': greenPoints,
      'days_since_last_debt': daysSinceLastDebt,
      'savings_percent': savingsPercent,
    };
  }

  factory LocalPerson.fromMap(Map<String, dynamic> map) {
    return LocalPerson(
      id: map['id']?.toInt(),
      serverId: map['server_id']?.toInt(),
      fullName: map['full_name'] ?? '',
      documentNumber: map['document_number'] ?? '',
      phone: map['phone'],
      email: map['email'],
      status: map['status'] ?? 'active',
      addressId: map['address_id']?.toInt(),
      syncStatus: map['sync_status'] ?? 'pending',
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      subscriberNumber: map['subscriber_number'],
      stratum: map['stratum']?.toInt(),
      userId: map['user_id'],
      greenPoints: map['green_points']?.toInt(),
      daysSinceLastDebt: map['days_since_last_debt']?.toInt(),
      savingsPercent: map['savings_percent']?.toDouble(),
    );
  }

  String toJson() => json.encode(toMap());

  factory LocalPerson.fromJson(String source) => LocalPerson.fromMap(json.decode(source));

  LocalPerson copyWith({
    int? id,
    int? serverId,
    String? fullName,
    String? documentNumber,
    String? phone,
    String? email,
    String? status,
    int? addressId,
    String? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? subscriberNumber,
    int? stratum,
    String? userId,
    int? greenPoints,
    int? daysSinceLastDebt,
    double? savingsPercent,
  }) {
    return LocalPerson(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      fullName: fullName ?? this.fullName,
      documentNumber: documentNumber ?? this.documentNumber,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      status: status ?? this.status,
      addressId: addressId ?? this.addressId,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      subscriberNumber: subscriberNumber ?? this.subscriberNumber,
      stratum: stratum ?? this.stratum,
      userId: userId ?? this.userId,
      greenPoints: greenPoints ?? this.greenPoints,
      daysSinceLastDebt: daysSinceLastDebt ?? this.daysSinceLastDebt,
      savingsPercent: savingsPercent ?? this.savingsPercent,
    );
  }
}

class LocalAddress {
  final int? id;
  final int? serverId;
  final String neighborhood;
  final String? street;
  final String? houseNumber;
  final String city;
  final double? latitude;
  final double? longitude;
  final String syncStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  LocalAddress({
    this.id,
    this.serverId,
    required this.neighborhood,
    this.street,
    this.houseNumber,
    required this.city,
    this.latitude,
    this.longitude,
    this.syncStatus = 'pending',
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'server_id': serverId,
      'neighborhood': neighborhood,
      'street': street,
      'house_number': houseNumber,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      'sync_status': syncStatus,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory LocalAddress.fromMap(Map<String, dynamic> map) {
    return LocalAddress(
      id: map['id']?.toInt(),
      serverId: map['server_id']?.toInt(),
      neighborhood: map['neighborhood'] ?? '',
      street: map['street'],
      houseNumber: map['house_number'],
      city: map['city'] ?? '',
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      syncStatus: map['sync_status'] ?? 'pending',
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory LocalAddress.fromJson(String source) => LocalAddress.fromMap(json.decode(source));
}

class LocalMeter {
  final int? id;
  final int? serverId;
  final int peopleId;
  final double waterMeasure;
  final DateTime readingDate;
  final String? observation;
  final String? invoicePath;
  final String syncStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  LocalMeter({
    this.id,
    this.serverId,
    required this.peopleId,
    required this.waterMeasure,
    required this.readingDate,
    this.observation,
    this.invoicePath,
    this.syncStatus = 'pending',
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'server_id': serverId,
      'people_id': peopleId,
      'water_measure': waterMeasure,
      'reading_date': readingDate.toIso8601String(),
      'observation': observation,
      'invoice_path': invoicePath,
      'sync_status': syncStatus,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory LocalMeter.fromMap(Map<String, dynamic> map) {
    return LocalMeter(
      id: map['id']?.toInt(),
      serverId: map['server_id']?.toInt(),
      peopleId: map['people_id']?.toInt() ?? 0,
      waterMeasure: map['water_measure']?.toDouble() ?? 0.0,
      readingDate: DateTime.parse(map['reading_date']),
      observation: map['observation'],
      invoicePath: map['invoice_path'],
      syncStatus: map['sync_status'] ?? 'pending',
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory LocalMeter.fromJson(String source) => LocalMeter.fromMap(json.decode(source));

  LocalMeter copyWith({
    int? id,
    int? serverId,
    int? peopleId,
    double? waterMeasure,
    DateTime? readingDate,
    String? observation,
    String? invoicePath,
    String? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LocalMeter(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      peopleId: peopleId ?? this.peopleId,
      waterMeasure: waterMeasure ?? this.waterMeasure,
      readingDate: readingDate ?? this.readingDate,
      observation: observation ?? this.observation,
      invoicePath: invoicePath ?? this.invoicePath,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class SyncQueueItem {
  final int? id;
  final String tableName;
  final int localId;
  final String operation;
  final String data;
  final DateTime? createdAt;

  SyncQueueItem({
    this.id,
    required this.tableName,
    required this.localId,
    required this.operation,
    required this.data,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'table_name': tableName,
      'local_id': localId,
      'operation': operation,
      'data': data,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory SyncQueueItem.fromMap(Map<String, dynamic> map) {
    return SyncQueueItem(
      id: map['id']?.toInt(),
      tableName: map['table_name'] ?? '',
      localId: map['local_id']?.toInt() ?? 0,
      operation: map['operation'] ?? '',
      data: map['data'] ?? '',
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory SyncQueueItem.fromJson(String source) => SyncQueueItem.fromMap(json.decode(source));
}
