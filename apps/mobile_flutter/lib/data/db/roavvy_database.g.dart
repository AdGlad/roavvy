// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'roavvy_database.dart';

// ignore_for_file: type=lint
class $ScanMetadataTable extends ScanMetadata
    with TableInfo<$ScanMetadataTable, ScanMetadataRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScanMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastScanAtMeta = const VerificationMeta(
    'lastScanAt',
  );
  @override
  late final GeneratedColumn<String> lastScanAt = GeneratedColumn<String>(
    'last_scan_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bootstrapCompletedAtMeta =
      const VerificationMeta('bootstrapCompletedAt');
  @override
  late final GeneratedColumn<String> bootstrapCompletedAt =
      GeneratedColumn<String>(
        'bootstrap_completed_at',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [id, lastScanAt, bootstrapCompletedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scan_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScanMetadataRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('last_scan_at')) {
      context.handle(
        _lastScanAtMeta,
        lastScanAt.isAcceptableOrUnknown(
          data['last_scan_at']!,
          _lastScanAtMeta,
        ),
      );
    }
    if (data.containsKey('bootstrap_completed_at')) {
      context.handle(
        _bootstrapCompletedAtMeta,
        bootstrapCompletedAt.isAcceptableOrUnknown(
          data['bootstrap_completed_at']!,
          _bootstrapCompletedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScanMetadataRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScanMetadataRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      lastScanAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_scan_at'],
      ),
      bootstrapCompletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bootstrap_completed_at'],
      ),
    );
  }

  @override
  $ScanMetadataTable createAlias(String alias) {
    return $ScanMetadataTable(attachedDatabase, alias);
  }
}

class ScanMetadataRow extends DataClass implements Insertable<ScanMetadataRow> {
  final int id;
  final String? lastScanAt;
  final String? bootstrapCompletedAt;
  const ScanMetadataRow({
    required this.id,
    this.lastScanAt,
    this.bootstrapCompletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || lastScanAt != null) {
      map['last_scan_at'] = Variable<String>(lastScanAt);
    }
    if (!nullToAbsent || bootstrapCompletedAt != null) {
      map['bootstrap_completed_at'] = Variable<String>(bootstrapCompletedAt);
    }
    return map;
  }

  ScanMetadataCompanion toCompanion(bool nullToAbsent) {
    return ScanMetadataCompanion(
      id: Value(id),
      lastScanAt:
          lastScanAt == null && nullToAbsent
              ? const Value.absent()
              : Value(lastScanAt),
      bootstrapCompletedAt:
          bootstrapCompletedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(bootstrapCompletedAt),
    );
  }

  factory ScanMetadataRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScanMetadataRow(
      id: serializer.fromJson<int>(json['id']),
      lastScanAt: serializer.fromJson<String?>(json['lastScanAt']),
      bootstrapCompletedAt: serializer.fromJson<String?>(
        json['bootstrapCompletedAt'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'lastScanAt': serializer.toJson<String?>(lastScanAt),
      'bootstrapCompletedAt': serializer.toJson<String?>(bootstrapCompletedAt),
    };
  }

  ScanMetadataRow copyWith({
    int? id,
    Value<String?> lastScanAt = const Value.absent(),
    Value<String?> bootstrapCompletedAt = const Value.absent(),
  }) => ScanMetadataRow(
    id: id ?? this.id,
    lastScanAt: lastScanAt.present ? lastScanAt.value : this.lastScanAt,
    bootstrapCompletedAt:
        bootstrapCompletedAt.present
            ? bootstrapCompletedAt.value
            : this.bootstrapCompletedAt,
  );
  ScanMetadataRow copyWithCompanion(ScanMetadataCompanion data) {
    return ScanMetadataRow(
      id: data.id.present ? data.id.value : this.id,
      lastScanAt:
          data.lastScanAt.present ? data.lastScanAt.value : this.lastScanAt,
      bootstrapCompletedAt:
          data.bootstrapCompletedAt.present
              ? data.bootstrapCompletedAt.value
              : this.bootstrapCompletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScanMetadataRow(')
          ..write('id: $id, ')
          ..write('lastScanAt: $lastScanAt, ')
          ..write('bootstrapCompletedAt: $bootstrapCompletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, lastScanAt, bootstrapCompletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScanMetadataRow &&
          other.id == this.id &&
          other.lastScanAt == this.lastScanAt &&
          other.bootstrapCompletedAt == this.bootstrapCompletedAt);
}

class ScanMetadataCompanion extends UpdateCompanion<ScanMetadataRow> {
  final Value<int> id;
  final Value<String?> lastScanAt;
  final Value<String?> bootstrapCompletedAt;
  const ScanMetadataCompanion({
    this.id = const Value.absent(),
    this.lastScanAt = const Value.absent(),
    this.bootstrapCompletedAt = const Value.absent(),
  });
  ScanMetadataCompanion.insert({
    this.id = const Value.absent(),
    this.lastScanAt = const Value.absent(),
    this.bootstrapCompletedAt = const Value.absent(),
  });
  static Insertable<ScanMetadataRow> custom({
    Expression<int>? id,
    Expression<String>? lastScanAt,
    Expression<String>? bootstrapCompletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lastScanAt != null) 'last_scan_at': lastScanAt,
      if (bootstrapCompletedAt != null)
        'bootstrap_completed_at': bootstrapCompletedAt,
    });
  }

  ScanMetadataCompanion copyWith({
    Value<int>? id,
    Value<String?>? lastScanAt,
    Value<String?>? bootstrapCompletedAt,
  }) {
    return ScanMetadataCompanion(
      id: id ?? this.id,
      lastScanAt: lastScanAt ?? this.lastScanAt,
      bootstrapCompletedAt: bootstrapCompletedAt ?? this.bootstrapCompletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (lastScanAt.present) {
      map['last_scan_at'] = Variable<String>(lastScanAt.value);
    }
    if (bootstrapCompletedAt.present) {
      map['bootstrap_completed_at'] = Variable<String>(
        bootstrapCompletedAt.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScanMetadataCompanion(')
          ..write('id: $id, ')
          ..write('lastScanAt: $lastScanAt, ')
          ..write('bootstrapCompletedAt: $bootstrapCompletedAt')
          ..write(')'))
        .toString();
  }
}

class $InferredCountryVisitsTable extends InferredCountryVisits
    with TableInfo<$InferredCountryVisitsTable, InferredVisitRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InferredCountryVisitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _countryCodeMeta = const VerificationMeta(
    'countryCode',
  );
  @override
  late final GeneratedColumn<String> countryCode = GeneratedColumn<String>(
    'country_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inferredAtMeta = const VerificationMeta(
    'inferredAt',
  );
  @override
  late final GeneratedColumn<DateTime> inferredAt = GeneratedColumn<DateTime>(
    'inferred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _photoCountMeta = const VerificationMeta(
    'photoCount',
  );
  @override
  late final GeneratedColumn<int> photoCount = GeneratedColumn<int>(
    'photo_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firstSeenMeta = const VerificationMeta(
    'firstSeen',
  );
  @override
  late final GeneratedColumn<DateTime> firstSeen = GeneratedColumn<DateTime>(
    'first_seen',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSeenMeta = const VerificationMeta(
    'lastSeen',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeen = GeneratedColumn<DateTime>(
    'last_seen',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDirtyMeta = const VerificationMeta(
    'isDirty',
  );
  @override
  late final GeneratedColumn<int> isDirty = GeneratedColumn<int>(
    'is_dirty',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<String> syncedAt = GeneratedColumn<String>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    countryCode,
    inferredAt,
    photoCount,
    firstSeen,
    lastSeen,
    isDirty,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inferred_country_visits';
  @override
  VerificationContext validateIntegrity(
    Insertable<InferredVisitRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('country_code')) {
      context.handle(
        _countryCodeMeta,
        countryCode.isAcceptableOrUnknown(
          data['country_code']!,
          _countryCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_countryCodeMeta);
    }
    if (data.containsKey('inferred_at')) {
      context.handle(
        _inferredAtMeta,
        inferredAt.isAcceptableOrUnknown(data['inferred_at']!, _inferredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_inferredAtMeta);
    }
    if (data.containsKey('photo_count')) {
      context.handle(
        _photoCountMeta,
        photoCount.isAcceptableOrUnknown(data['photo_count']!, _photoCountMeta),
      );
    } else if (isInserting) {
      context.missing(_photoCountMeta);
    }
    if (data.containsKey('first_seen')) {
      context.handle(
        _firstSeenMeta,
        firstSeen.isAcceptableOrUnknown(data['first_seen']!, _firstSeenMeta),
      );
    }
    if (data.containsKey('last_seen')) {
      context.handle(
        _lastSeenMeta,
        lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta),
      );
    }
    if (data.containsKey('is_dirty')) {
      context.handle(
        _isDirtyMeta,
        isDirty.isAcceptableOrUnknown(data['is_dirty']!, _isDirtyMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {countryCode};
  @override
  InferredVisitRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InferredVisitRow(
      countryCode:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}country_code'],
          )!,
      inferredAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}inferred_at'],
          )!,
      photoCount:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}photo_count'],
          )!,
      firstSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}first_seen'],
      ),
      lastSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen'],
      ),
      isDirty:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}is_dirty'],
          )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $InferredCountryVisitsTable createAlias(String alias) {
    return $InferredCountryVisitsTable(attachedDatabase, alias);
  }
}

class InferredVisitRow extends DataClass
    implements Insertable<InferredVisitRow> {
  final String countryCode;
  final DateTime inferredAt;
  final int photoCount;
  final DateTime? firstSeen;
  final DateTime? lastSeen;
  final int isDirty;
  final String? syncedAt;
  const InferredVisitRow({
    required this.countryCode,
    required this.inferredAt,
    required this.photoCount,
    this.firstSeen,
    this.lastSeen,
    required this.isDirty,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['country_code'] = Variable<String>(countryCode);
    map['inferred_at'] = Variable<DateTime>(inferredAt);
    map['photo_count'] = Variable<int>(photoCount);
    if (!nullToAbsent || firstSeen != null) {
      map['first_seen'] = Variable<DateTime>(firstSeen);
    }
    if (!nullToAbsent || lastSeen != null) {
      map['last_seen'] = Variable<DateTime>(lastSeen);
    }
    map['is_dirty'] = Variable<int>(isDirty);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<String>(syncedAt);
    }
    return map;
  }

  InferredCountryVisitsCompanion toCompanion(bool nullToAbsent) {
    return InferredCountryVisitsCompanion(
      countryCode: Value(countryCode),
      inferredAt: Value(inferredAt),
      photoCount: Value(photoCount),
      firstSeen:
          firstSeen == null && nullToAbsent
              ? const Value.absent()
              : Value(firstSeen),
      lastSeen:
          lastSeen == null && nullToAbsent
              ? const Value.absent()
              : Value(lastSeen),
      isDirty: Value(isDirty),
      syncedAt:
          syncedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(syncedAt),
    );
  }

  factory InferredVisitRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InferredVisitRow(
      countryCode: serializer.fromJson<String>(json['countryCode']),
      inferredAt: serializer.fromJson<DateTime>(json['inferredAt']),
      photoCount: serializer.fromJson<int>(json['photoCount']),
      firstSeen: serializer.fromJson<DateTime?>(json['firstSeen']),
      lastSeen: serializer.fromJson<DateTime?>(json['lastSeen']),
      isDirty: serializer.fromJson<int>(json['isDirty']),
      syncedAt: serializer.fromJson<String?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'countryCode': serializer.toJson<String>(countryCode),
      'inferredAt': serializer.toJson<DateTime>(inferredAt),
      'photoCount': serializer.toJson<int>(photoCount),
      'firstSeen': serializer.toJson<DateTime?>(firstSeen),
      'lastSeen': serializer.toJson<DateTime?>(lastSeen),
      'isDirty': serializer.toJson<int>(isDirty),
      'syncedAt': serializer.toJson<String?>(syncedAt),
    };
  }

  InferredVisitRow copyWith({
    String? countryCode,
    DateTime? inferredAt,
    int? photoCount,
    Value<DateTime?> firstSeen = const Value.absent(),
    Value<DateTime?> lastSeen = const Value.absent(),
    int? isDirty,
    Value<String?> syncedAt = const Value.absent(),
  }) => InferredVisitRow(
    countryCode: countryCode ?? this.countryCode,
    inferredAt: inferredAt ?? this.inferredAt,
    photoCount: photoCount ?? this.photoCount,
    firstSeen: firstSeen.present ? firstSeen.value : this.firstSeen,
    lastSeen: lastSeen.present ? lastSeen.value : this.lastSeen,
    isDirty: isDirty ?? this.isDirty,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  InferredVisitRow copyWithCompanion(InferredCountryVisitsCompanion data) {
    return InferredVisitRow(
      countryCode:
          data.countryCode.present ? data.countryCode.value : this.countryCode,
      inferredAt:
          data.inferredAt.present ? data.inferredAt.value : this.inferredAt,
      photoCount:
          data.photoCount.present ? data.photoCount.value : this.photoCount,
      firstSeen: data.firstSeen.present ? data.firstSeen.value : this.firstSeen,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
      isDirty: data.isDirty.present ? data.isDirty.value : this.isDirty,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InferredVisitRow(')
          ..write('countryCode: $countryCode, ')
          ..write('inferredAt: $inferredAt, ')
          ..write('photoCount: $photoCount, ')
          ..write('firstSeen: $firstSeen, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('isDirty: $isDirty, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    countryCode,
    inferredAt,
    photoCount,
    firstSeen,
    lastSeen,
    isDirty,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InferredVisitRow &&
          other.countryCode == this.countryCode &&
          other.inferredAt == this.inferredAt &&
          other.photoCount == this.photoCount &&
          other.firstSeen == this.firstSeen &&
          other.lastSeen == this.lastSeen &&
          other.isDirty == this.isDirty &&
          other.syncedAt == this.syncedAt);
}

class InferredCountryVisitsCompanion extends UpdateCompanion<InferredVisitRow> {
  final Value<String> countryCode;
  final Value<DateTime> inferredAt;
  final Value<int> photoCount;
  final Value<DateTime?> firstSeen;
  final Value<DateTime?> lastSeen;
  final Value<int> isDirty;
  final Value<String?> syncedAt;
  final Value<int> rowid;
  const InferredCountryVisitsCompanion({
    this.countryCode = const Value.absent(),
    this.inferredAt = const Value.absent(),
    this.photoCount = const Value.absent(),
    this.firstSeen = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.isDirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InferredCountryVisitsCompanion.insert({
    required String countryCode,
    required DateTime inferredAt,
    required int photoCount,
    this.firstSeen = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.isDirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : countryCode = Value(countryCode),
       inferredAt = Value(inferredAt),
       photoCount = Value(photoCount);
  static Insertable<InferredVisitRow> custom({
    Expression<String>? countryCode,
    Expression<DateTime>? inferredAt,
    Expression<int>? photoCount,
    Expression<DateTime>? firstSeen,
    Expression<DateTime>? lastSeen,
    Expression<int>? isDirty,
    Expression<String>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (countryCode != null) 'country_code': countryCode,
      if (inferredAt != null) 'inferred_at': inferredAt,
      if (photoCount != null) 'photo_count': photoCount,
      if (firstSeen != null) 'first_seen': firstSeen,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (isDirty != null) 'is_dirty': isDirty,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InferredCountryVisitsCompanion copyWith({
    Value<String>? countryCode,
    Value<DateTime>? inferredAt,
    Value<int>? photoCount,
    Value<DateTime?>? firstSeen,
    Value<DateTime?>? lastSeen,
    Value<int>? isDirty,
    Value<String?>? syncedAt,
    Value<int>? rowid,
  }) {
    return InferredCountryVisitsCompanion(
      countryCode: countryCode ?? this.countryCode,
      inferredAt: inferredAt ?? this.inferredAt,
      photoCount: photoCount ?? this.photoCount,
      firstSeen: firstSeen ?? this.firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
      isDirty: isDirty ?? this.isDirty,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (countryCode.present) {
      map['country_code'] = Variable<String>(countryCode.value);
    }
    if (inferredAt.present) {
      map['inferred_at'] = Variable<DateTime>(inferredAt.value);
    }
    if (photoCount.present) {
      map['photo_count'] = Variable<int>(photoCount.value);
    }
    if (firstSeen.present) {
      map['first_seen'] = Variable<DateTime>(firstSeen.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<DateTime>(lastSeen.value);
    }
    if (isDirty.present) {
      map['is_dirty'] = Variable<int>(isDirty.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<String>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InferredCountryVisitsCompanion(')
          ..write('countryCode: $countryCode, ')
          ..write('inferredAt: $inferredAt, ')
          ..write('photoCount: $photoCount, ')
          ..write('firstSeen: $firstSeen, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('isDirty: $isDirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserAddedCountriesTable extends UserAddedCountries
    with TableInfo<$UserAddedCountriesTable, AddedCountryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserAddedCountriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _countryCodeMeta = const VerificationMeta(
    'countryCode',
  );
  @override
  late final GeneratedColumn<String> countryCode = GeneratedColumn<String>(
    'country_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDirtyMeta = const VerificationMeta(
    'isDirty',
  );
  @override
  late final GeneratedColumn<int> isDirty = GeneratedColumn<int>(
    'is_dirty',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<String> syncedAt = GeneratedColumn<String>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    countryCode,
    addedAt,
    isDirty,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_added_countries';
  @override
  VerificationContext validateIntegrity(
    Insertable<AddedCountryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('country_code')) {
      context.handle(
        _countryCodeMeta,
        countryCode.isAcceptableOrUnknown(
          data['country_code']!,
          _countryCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_countryCodeMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('is_dirty')) {
      context.handle(
        _isDirtyMeta,
        isDirty.isAcceptableOrUnknown(data['is_dirty']!, _isDirtyMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {countryCode};
  @override
  AddedCountryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AddedCountryRow(
      countryCode:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}country_code'],
          )!,
      addedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}added_at'],
          )!,
      isDirty:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}is_dirty'],
          )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $UserAddedCountriesTable createAlias(String alias) {
    return $UserAddedCountriesTable(attachedDatabase, alias);
  }
}

class AddedCountryRow extends DataClass implements Insertable<AddedCountryRow> {
  final String countryCode;
  final DateTime addedAt;
  final int isDirty;
  final String? syncedAt;
  const AddedCountryRow({
    required this.countryCode,
    required this.addedAt,
    required this.isDirty,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['country_code'] = Variable<String>(countryCode);
    map['added_at'] = Variable<DateTime>(addedAt);
    map['is_dirty'] = Variable<int>(isDirty);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<String>(syncedAt);
    }
    return map;
  }

  UserAddedCountriesCompanion toCompanion(bool nullToAbsent) {
    return UserAddedCountriesCompanion(
      countryCode: Value(countryCode),
      addedAt: Value(addedAt),
      isDirty: Value(isDirty),
      syncedAt:
          syncedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(syncedAt),
    );
  }

  factory AddedCountryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AddedCountryRow(
      countryCode: serializer.fromJson<String>(json['countryCode']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      isDirty: serializer.fromJson<int>(json['isDirty']),
      syncedAt: serializer.fromJson<String?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'countryCode': serializer.toJson<String>(countryCode),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'isDirty': serializer.toJson<int>(isDirty),
      'syncedAt': serializer.toJson<String?>(syncedAt),
    };
  }

  AddedCountryRow copyWith({
    String? countryCode,
    DateTime? addedAt,
    int? isDirty,
    Value<String?> syncedAt = const Value.absent(),
  }) => AddedCountryRow(
    countryCode: countryCode ?? this.countryCode,
    addedAt: addedAt ?? this.addedAt,
    isDirty: isDirty ?? this.isDirty,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  AddedCountryRow copyWithCompanion(UserAddedCountriesCompanion data) {
    return AddedCountryRow(
      countryCode:
          data.countryCode.present ? data.countryCode.value : this.countryCode,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      isDirty: data.isDirty.present ? data.isDirty.value : this.isDirty,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AddedCountryRow(')
          ..write('countryCode: $countryCode, ')
          ..write('addedAt: $addedAt, ')
          ..write('isDirty: $isDirty, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(countryCode, addedAt, isDirty, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AddedCountryRow &&
          other.countryCode == this.countryCode &&
          other.addedAt == this.addedAt &&
          other.isDirty == this.isDirty &&
          other.syncedAt == this.syncedAt);
}

class UserAddedCountriesCompanion extends UpdateCompanion<AddedCountryRow> {
  final Value<String> countryCode;
  final Value<DateTime> addedAt;
  final Value<int> isDirty;
  final Value<String?> syncedAt;
  final Value<int> rowid;
  const UserAddedCountriesCompanion({
    this.countryCode = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.isDirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserAddedCountriesCompanion.insert({
    required String countryCode,
    required DateTime addedAt,
    this.isDirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : countryCode = Value(countryCode),
       addedAt = Value(addedAt);
  static Insertable<AddedCountryRow> custom({
    Expression<String>? countryCode,
    Expression<DateTime>? addedAt,
    Expression<int>? isDirty,
    Expression<String>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (countryCode != null) 'country_code': countryCode,
      if (addedAt != null) 'added_at': addedAt,
      if (isDirty != null) 'is_dirty': isDirty,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserAddedCountriesCompanion copyWith({
    Value<String>? countryCode,
    Value<DateTime>? addedAt,
    Value<int>? isDirty,
    Value<String?>? syncedAt,
    Value<int>? rowid,
  }) {
    return UserAddedCountriesCompanion(
      countryCode: countryCode ?? this.countryCode,
      addedAt: addedAt ?? this.addedAt,
      isDirty: isDirty ?? this.isDirty,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (countryCode.present) {
      map['country_code'] = Variable<String>(countryCode.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (isDirty.present) {
      map['is_dirty'] = Variable<int>(isDirty.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<String>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserAddedCountriesCompanion(')
          ..write('countryCode: $countryCode, ')
          ..write('addedAt: $addedAt, ')
          ..write('isDirty: $isDirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserRemovedCountriesTable extends UserRemovedCountries
    with TableInfo<$UserRemovedCountriesTable, RemovedCountryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserRemovedCountriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _countryCodeMeta = const VerificationMeta(
    'countryCode',
  );
  @override
  late final GeneratedColumn<String> countryCode = GeneratedColumn<String>(
    'country_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _removedAtMeta = const VerificationMeta(
    'removedAt',
  );
  @override
  late final GeneratedColumn<DateTime> removedAt = GeneratedColumn<DateTime>(
    'removed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDirtyMeta = const VerificationMeta(
    'isDirty',
  );
  @override
  late final GeneratedColumn<int> isDirty = GeneratedColumn<int>(
    'is_dirty',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<String> syncedAt = GeneratedColumn<String>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    countryCode,
    removedAt,
    isDirty,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_removed_countries';
  @override
  VerificationContext validateIntegrity(
    Insertable<RemovedCountryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('country_code')) {
      context.handle(
        _countryCodeMeta,
        countryCode.isAcceptableOrUnknown(
          data['country_code']!,
          _countryCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_countryCodeMeta);
    }
    if (data.containsKey('removed_at')) {
      context.handle(
        _removedAtMeta,
        removedAt.isAcceptableOrUnknown(data['removed_at']!, _removedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_removedAtMeta);
    }
    if (data.containsKey('is_dirty')) {
      context.handle(
        _isDirtyMeta,
        isDirty.isAcceptableOrUnknown(data['is_dirty']!, _isDirtyMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {countryCode};
  @override
  RemovedCountryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RemovedCountryRow(
      countryCode:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}country_code'],
          )!,
      removedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}removed_at'],
          )!,
      isDirty:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}is_dirty'],
          )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $UserRemovedCountriesTable createAlias(String alias) {
    return $UserRemovedCountriesTable(attachedDatabase, alias);
  }
}

class RemovedCountryRow extends DataClass
    implements Insertable<RemovedCountryRow> {
  final String countryCode;
  final DateTime removedAt;
  final int isDirty;
  final String? syncedAt;
  const RemovedCountryRow({
    required this.countryCode,
    required this.removedAt,
    required this.isDirty,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['country_code'] = Variable<String>(countryCode);
    map['removed_at'] = Variable<DateTime>(removedAt);
    map['is_dirty'] = Variable<int>(isDirty);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<String>(syncedAt);
    }
    return map;
  }

  UserRemovedCountriesCompanion toCompanion(bool nullToAbsent) {
    return UserRemovedCountriesCompanion(
      countryCode: Value(countryCode),
      removedAt: Value(removedAt),
      isDirty: Value(isDirty),
      syncedAt:
          syncedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(syncedAt),
    );
  }

  factory RemovedCountryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RemovedCountryRow(
      countryCode: serializer.fromJson<String>(json['countryCode']),
      removedAt: serializer.fromJson<DateTime>(json['removedAt']),
      isDirty: serializer.fromJson<int>(json['isDirty']),
      syncedAt: serializer.fromJson<String?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'countryCode': serializer.toJson<String>(countryCode),
      'removedAt': serializer.toJson<DateTime>(removedAt),
      'isDirty': serializer.toJson<int>(isDirty),
      'syncedAt': serializer.toJson<String?>(syncedAt),
    };
  }

  RemovedCountryRow copyWith({
    String? countryCode,
    DateTime? removedAt,
    int? isDirty,
    Value<String?> syncedAt = const Value.absent(),
  }) => RemovedCountryRow(
    countryCode: countryCode ?? this.countryCode,
    removedAt: removedAt ?? this.removedAt,
    isDirty: isDirty ?? this.isDirty,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  RemovedCountryRow copyWithCompanion(UserRemovedCountriesCompanion data) {
    return RemovedCountryRow(
      countryCode:
          data.countryCode.present ? data.countryCode.value : this.countryCode,
      removedAt: data.removedAt.present ? data.removedAt.value : this.removedAt,
      isDirty: data.isDirty.present ? data.isDirty.value : this.isDirty,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RemovedCountryRow(')
          ..write('countryCode: $countryCode, ')
          ..write('removedAt: $removedAt, ')
          ..write('isDirty: $isDirty, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(countryCode, removedAt, isDirty, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RemovedCountryRow &&
          other.countryCode == this.countryCode &&
          other.removedAt == this.removedAt &&
          other.isDirty == this.isDirty &&
          other.syncedAt == this.syncedAt);
}

class UserRemovedCountriesCompanion extends UpdateCompanion<RemovedCountryRow> {
  final Value<String> countryCode;
  final Value<DateTime> removedAt;
  final Value<int> isDirty;
  final Value<String?> syncedAt;
  final Value<int> rowid;
  const UserRemovedCountriesCompanion({
    this.countryCode = const Value.absent(),
    this.removedAt = const Value.absent(),
    this.isDirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserRemovedCountriesCompanion.insert({
    required String countryCode,
    required DateTime removedAt,
    this.isDirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : countryCode = Value(countryCode),
       removedAt = Value(removedAt);
  static Insertable<RemovedCountryRow> custom({
    Expression<String>? countryCode,
    Expression<DateTime>? removedAt,
    Expression<int>? isDirty,
    Expression<String>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (countryCode != null) 'country_code': countryCode,
      if (removedAt != null) 'removed_at': removedAt,
      if (isDirty != null) 'is_dirty': isDirty,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserRemovedCountriesCompanion copyWith({
    Value<String>? countryCode,
    Value<DateTime>? removedAt,
    Value<int>? isDirty,
    Value<String?>? syncedAt,
    Value<int>? rowid,
  }) {
    return UserRemovedCountriesCompanion(
      countryCode: countryCode ?? this.countryCode,
      removedAt: removedAt ?? this.removedAt,
      isDirty: isDirty ?? this.isDirty,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (countryCode.present) {
      map['country_code'] = Variable<String>(countryCode.value);
    }
    if (removedAt.present) {
      map['removed_at'] = Variable<DateTime>(removedAt.value);
    }
    if (isDirty.present) {
      map['is_dirty'] = Variable<int>(isDirty.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<String>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserRemovedCountriesCompanion(')
          ..write('countryCode: $countryCode, ')
          ..write('removedAt: $removedAt, ')
          ..write('isDirty: $isDirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UnlockedAchievementsTable extends UnlockedAchievements
    with TableInfo<$UnlockedAchievementsTable, UnlockedAchievementRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UnlockedAchievementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _achievementIdMeta = const VerificationMeta(
    'achievementId',
  );
  @override
  late final GeneratedColumn<String> achievementId = GeneratedColumn<String>(
    'achievement_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unlockedAtMeta = const VerificationMeta(
    'unlockedAt',
  );
  @override
  late final GeneratedColumn<DateTime> unlockedAt = GeneratedColumn<DateTime>(
    'unlocked_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDirtyMeta = const VerificationMeta(
    'isDirty',
  );
  @override
  late final GeneratedColumn<int> isDirty = GeneratedColumn<int>(
    'is_dirty',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    achievementId,
    unlockedAt,
    isDirty,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'unlocked_achievements';
  @override
  VerificationContext validateIntegrity(
    Insertable<UnlockedAchievementRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('achievement_id')) {
      context.handle(
        _achievementIdMeta,
        achievementId.isAcceptableOrUnknown(
          data['achievement_id']!,
          _achievementIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_achievementIdMeta);
    }
    if (data.containsKey('unlocked_at')) {
      context.handle(
        _unlockedAtMeta,
        unlockedAt.isAcceptableOrUnknown(data['unlocked_at']!, _unlockedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_unlockedAtMeta);
    }
    if (data.containsKey('is_dirty')) {
      context.handle(
        _isDirtyMeta,
        isDirty.isAcceptableOrUnknown(data['is_dirty']!, _isDirtyMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {achievementId};
  @override
  UnlockedAchievementRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UnlockedAchievementRow(
      achievementId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}achievement_id'],
          )!,
      unlockedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}unlocked_at'],
          )!,
      isDirty:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}is_dirty'],
          )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $UnlockedAchievementsTable createAlias(String alias) {
    return $UnlockedAchievementsTable(attachedDatabase, alias);
  }
}

class UnlockedAchievementRow extends DataClass
    implements Insertable<UnlockedAchievementRow> {
  final String achievementId;
  final DateTime unlockedAt;
  final int isDirty;
  final DateTime? syncedAt;
  const UnlockedAchievementRow({
    required this.achievementId,
    required this.unlockedAt,
    required this.isDirty,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['achievement_id'] = Variable<String>(achievementId);
    map['unlocked_at'] = Variable<DateTime>(unlockedAt);
    map['is_dirty'] = Variable<int>(isDirty);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  UnlockedAchievementsCompanion toCompanion(bool nullToAbsent) {
    return UnlockedAchievementsCompanion(
      achievementId: Value(achievementId),
      unlockedAt: Value(unlockedAt),
      isDirty: Value(isDirty),
      syncedAt:
          syncedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(syncedAt),
    );
  }

  factory UnlockedAchievementRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UnlockedAchievementRow(
      achievementId: serializer.fromJson<String>(json['achievementId']),
      unlockedAt: serializer.fromJson<DateTime>(json['unlockedAt']),
      isDirty: serializer.fromJson<int>(json['isDirty']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'achievementId': serializer.toJson<String>(achievementId),
      'unlockedAt': serializer.toJson<DateTime>(unlockedAt),
      'isDirty': serializer.toJson<int>(isDirty),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  UnlockedAchievementRow copyWith({
    String? achievementId,
    DateTime? unlockedAt,
    int? isDirty,
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => UnlockedAchievementRow(
    achievementId: achievementId ?? this.achievementId,
    unlockedAt: unlockedAt ?? this.unlockedAt,
    isDirty: isDirty ?? this.isDirty,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  UnlockedAchievementRow copyWithCompanion(UnlockedAchievementsCompanion data) {
    return UnlockedAchievementRow(
      achievementId:
          data.achievementId.present
              ? data.achievementId.value
              : this.achievementId,
      unlockedAt:
          data.unlockedAt.present ? data.unlockedAt.value : this.unlockedAt,
      isDirty: data.isDirty.present ? data.isDirty.value : this.isDirty,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UnlockedAchievementRow(')
          ..write('achievementId: $achievementId, ')
          ..write('unlockedAt: $unlockedAt, ')
          ..write('isDirty: $isDirty, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(achievementId, unlockedAt, isDirty, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UnlockedAchievementRow &&
          other.achievementId == this.achievementId &&
          other.unlockedAt == this.unlockedAt &&
          other.isDirty == this.isDirty &&
          other.syncedAt == this.syncedAt);
}

class UnlockedAchievementsCompanion
    extends UpdateCompanion<UnlockedAchievementRow> {
  final Value<String> achievementId;
  final Value<DateTime> unlockedAt;
  final Value<int> isDirty;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const UnlockedAchievementsCompanion({
    this.achievementId = const Value.absent(),
    this.unlockedAt = const Value.absent(),
    this.isDirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UnlockedAchievementsCompanion.insert({
    required String achievementId,
    required DateTime unlockedAt,
    this.isDirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : achievementId = Value(achievementId),
       unlockedAt = Value(unlockedAt);
  static Insertable<UnlockedAchievementRow> custom({
    Expression<String>? achievementId,
    Expression<DateTime>? unlockedAt,
    Expression<int>? isDirty,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (achievementId != null) 'achievement_id': achievementId,
      if (unlockedAt != null) 'unlocked_at': unlockedAt,
      if (isDirty != null) 'is_dirty': isDirty,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UnlockedAchievementsCompanion copyWith({
    Value<String>? achievementId,
    Value<DateTime>? unlockedAt,
    Value<int>? isDirty,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return UnlockedAchievementsCompanion(
      achievementId: achievementId ?? this.achievementId,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      isDirty: isDirty ?? this.isDirty,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (achievementId.present) {
      map['achievement_id'] = Variable<String>(achievementId.value);
    }
    if (unlockedAt.present) {
      map['unlocked_at'] = Variable<DateTime>(unlockedAt.value);
    }
    if (isDirty.present) {
      map['is_dirty'] = Variable<int>(isDirty.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UnlockedAchievementsCompanion(')
          ..write('achievementId: $achievementId, ')
          ..write('unlockedAt: $unlockedAt, ')
          ..write('isDirty: $isDirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ShareTokensTable extends ShareTokens
    with TableInfo<$ShareTokensTable, ShareTokenRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShareTokensTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tokenMeta = const VerificationMeta('token');
  @override
  late final GeneratedColumn<String> token = GeneratedColumn<String>(
    'token',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, token];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'share_tokens';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShareTokenRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('token')) {
      context.handle(
        _tokenMeta,
        token.isAcceptableOrUnknown(data['token']!, _tokenMeta),
      );
    } else if (isInserting) {
      context.missing(_tokenMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShareTokenRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShareTokenRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      token:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}token'],
          )!,
    );
  }

  @override
  $ShareTokensTable createAlias(String alias) {
    return $ShareTokensTable(attachedDatabase, alias);
  }
}

class ShareTokenRow extends DataClass implements Insertable<ShareTokenRow> {
  final int id;
  final String token;
  const ShareTokenRow({required this.id, required this.token});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['token'] = Variable<String>(token);
    return map;
  }

  ShareTokensCompanion toCompanion(bool nullToAbsent) {
    return ShareTokensCompanion(id: Value(id), token: Value(token));
  }

  factory ShareTokenRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShareTokenRow(
      id: serializer.fromJson<int>(json['id']),
      token: serializer.fromJson<String>(json['token']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'token': serializer.toJson<String>(token),
    };
  }

  ShareTokenRow copyWith({int? id, String? token}) =>
      ShareTokenRow(id: id ?? this.id, token: token ?? this.token);
  ShareTokenRow copyWithCompanion(ShareTokensCompanion data) {
    return ShareTokenRow(
      id: data.id.present ? data.id.value : this.id,
      token: data.token.present ? data.token.value : this.token,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShareTokenRow(')
          ..write('id: $id, ')
          ..write('token: $token')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, token);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShareTokenRow &&
          other.id == this.id &&
          other.token == this.token);
}

class ShareTokensCompanion extends UpdateCompanion<ShareTokenRow> {
  final Value<int> id;
  final Value<String> token;
  const ShareTokensCompanion({
    this.id = const Value.absent(),
    this.token = const Value.absent(),
  });
  ShareTokensCompanion.insert({
    this.id = const Value.absent(),
    required String token,
  }) : token = Value(token);
  static Insertable<ShareTokenRow> custom({
    Expression<int>? id,
    Expression<String>? token,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (token != null) 'token': token,
    });
  }

  ShareTokensCompanion copyWith({Value<int>? id, Value<String>? token}) {
    return ShareTokensCompanion(id: id ?? this.id, token: token ?? this.token);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (token.present) {
      map['token'] = Variable<String>(token.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShareTokensCompanion(')
          ..write('id: $id, ')
          ..write('token: $token')
          ..write(')'))
        .toString();
  }
}

class $RegionVisitsTable extends RegionVisits
    with TableInfo<$RegionVisitsTable, RegionVisitRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RegionVisitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
    'trip_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _regionCodeMeta = const VerificationMeta(
    'regionCode',
  );
  @override
  late final GeneratedColumn<String> regionCode = GeneratedColumn<String>(
    'region_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countryCodeMeta = const VerificationMeta(
    'countryCode',
  );
  @override
  late final GeneratedColumn<String> countryCode = GeneratedColumn<String>(
    'country_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firstSeenMeta = const VerificationMeta(
    'firstSeen',
  );
  @override
  late final GeneratedColumn<DateTime> firstSeen = GeneratedColumn<DateTime>(
    'first_seen',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenMeta = const VerificationMeta(
    'lastSeen',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeen = GeneratedColumn<DateTime>(
    'last_seen',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _photoCountMeta = const VerificationMeta(
    'photoCount',
  );
  @override
  late final GeneratedColumn<int> photoCount = GeneratedColumn<int>(
    'photo_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isDirtyMeta = const VerificationMeta(
    'isDirty',
  );
  @override
  late final GeneratedColumn<int> isDirty = GeneratedColumn<int>(
    'is_dirty',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<String> syncedAt = GeneratedColumn<String>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    tripId,
    regionCode,
    countryCode,
    firstSeen,
    lastSeen,
    photoCount,
    isDirty,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'region_visits';
  @override
  VerificationContext validateIntegrity(
    Insertable<RegionVisitRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tripIdMeta);
    }
    if (data.containsKey('region_code')) {
      context.handle(
        _regionCodeMeta,
        regionCode.isAcceptableOrUnknown(data['region_code']!, _regionCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_regionCodeMeta);
    }
    if (data.containsKey('country_code')) {
      context.handle(
        _countryCodeMeta,
        countryCode.isAcceptableOrUnknown(
          data['country_code']!,
          _countryCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_countryCodeMeta);
    }
    if (data.containsKey('first_seen')) {
      context.handle(
        _firstSeenMeta,
        firstSeen.isAcceptableOrUnknown(data['first_seen']!, _firstSeenMeta),
      );
    } else if (isInserting) {
      context.missing(_firstSeenMeta);
    }
    if (data.containsKey('last_seen')) {
      context.handle(
        _lastSeenMeta,
        lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta),
      );
    } else if (isInserting) {
      context.missing(_lastSeenMeta);
    }
    if (data.containsKey('photo_count')) {
      context.handle(
        _photoCountMeta,
        photoCount.isAcceptableOrUnknown(data['photo_count']!, _photoCountMeta),
      );
    }
    if (data.containsKey('is_dirty')) {
      context.handle(
        _isDirtyMeta,
        isDirty.isAcceptableOrUnknown(data['is_dirty']!, _isDirtyMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tripId, regionCode};
  @override
  RegionVisitRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RegionVisitRow(
      tripId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}trip_id'],
          )!,
      regionCode:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}region_code'],
          )!,
      countryCode:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}country_code'],
          )!,
      firstSeen:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}first_seen'],
          )!,
      lastSeen:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}last_seen'],
          )!,
      photoCount:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}photo_count'],
          )!,
      isDirty:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}is_dirty'],
          )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $RegionVisitsTable createAlias(String alias) {
    return $RegionVisitsTable(attachedDatabase, alias);
  }
}

class RegionVisitRow extends DataClass implements Insertable<RegionVisitRow> {
  final String tripId;
  final String regionCode;
  final String countryCode;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final int photoCount;
  final int isDirty;
  final String? syncedAt;
  const RegionVisitRow({
    required this.tripId,
    required this.regionCode,
    required this.countryCode,
    required this.firstSeen,
    required this.lastSeen,
    required this.photoCount,
    required this.isDirty,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['trip_id'] = Variable<String>(tripId);
    map['region_code'] = Variable<String>(regionCode);
    map['country_code'] = Variable<String>(countryCode);
    map['first_seen'] = Variable<DateTime>(firstSeen);
    map['last_seen'] = Variable<DateTime>(lastSeen);
    map['photo_count'] = Variable<int>(photoCount);
    map['is_dirty'] = Variable<int>(isDirty);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<String>(syncedAt);
    }
    return map;
  }

  RegionVisitsCompanion toCompanion(bool nullToAbsent) {
    return RegionVisitsCompanion(
      tripId: Value(tripId),
      regionCode: Value(regionCode),
      countryCode: Value(countryCode),
      firstSeen: Value(firstSeen),
      lastSeen: Value(lastSeen),
      photoCount: Value(photoCount),
      isDirty: Value(isDirty),
      syncedAt:
          syncedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(syncedAt),
    );
  }

  factory RegionVisitRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RegionVisitRow(
      tripId: serializer.fromJson<String>(json['tripId']),
      regionCode: serializer.fromJson<String>(json['regionCode']),
      countryCode: serializer.fromJson<String>(json['countryCode']),
      firstSeen: serializer.fromJson<DateTime>(json['firstSeen']),
      lastSeen: serializer.fromJson<DateTime>(json['lastSeen']),
      photoCount: serializer.fromJson<int>(json['photoCount']),
      isDirty: serializer.fromJson<int>(json['isDirty']),
      syncedAt: serializer.fromJson<String?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tripId': serializer.toJson<String>(tripId),
      'regionCode': serializer.toJson<String>(regionCode),
      'countryCode': serializer.toJson<String>(countryCode),
      'firstSeen': serializer.toJson<DateTime>(firstSeen),
      'lastSeen': serializer.toJson<DateTime>(lastSeen),
      'photoCount': serializer.toJson<int>(photoCount),
      'isDirty': serializer.toJson<int>(isDirty),
      'syncedAt': serializer.toJson<String?>(syncedAt),
    };
  }

  RegionVisitRow copyWith({
    String? tripId,
    String? regionCode,
    String? countryCode,
    DateTime? firstSeen,
    DateTime? lastSeen,
    int? photoCount,
    int? isDirty,
    Value<String?> syncedAt = const Value.absent(),
  }) => RegionVisitRow(
    tripId: tripId ?? this.tripId,
    regionCode: regionCode ?? this.regionCode,
    countryCode: countryCode ?? this.countryCode,
    firstSeen: firstSeen ?? this.firstSeen,
    lastSeen: lastSeen ?? this.lastSeen,
    photoCount: photoCount ?? this.photoCount,
    isDirty: isDirty ?? this.isDirty,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  RegionVisitRow copyWithCompanion(RegionVisitsCompanion data) {
    return RegionVisitRow(
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      regionCode:
          data.regionCode.present ? data.regionCode.value : this.regionCode,
      countryCode:
          data.countryCode.present ? data.countryCode.value : this.countryCode,
      firstSeen: data.firstSeen.present ? data.firstSeen.value : this.firstSeen,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
      photoCount:
          data.photoCount.present ? data.photoCount.value : this.photoCount,
      isDirty: data.isDirty.present ? data.isDirty.value : this.isDirty,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RegionVisitRow(')
          ..write('tripId: $tripId, ')
          ..write('regionCode: $regionCode, ')
          ..write('countryCode: $countryCode, ')
          ..write('firstSeen: $firstSeen, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('photoCount: $photoCount, ')
          ..write('isDirty: $isDirty, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    tripId,
    regionCode,
    countryCode,
    firstSeen,
    lastSeen,
    photoCount,
    isDirty,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RegionVisitRow &&
          other.tripId == this.tripId &&
          other.regionCode == this.regionCode &&
          other.countryCode == this.countryCode &&
          other.firstSeen == this.firstSeen &&
          other.lastSeen == this.lastSeen &&
          other.photoCount == this.photoCount &&
          other.isDirty == this.isDirty &&
          other.syncedAt == this.syncedAt);
}

class RegionVisitsCompanion extends UpdateCompanion<RegionVisitRow> {
  final Value<String> tripId;
  final Value<String> regionCode;
  final Value<String> countryCode;
  final Value<DateTime> firstSeen;
  final Value<DateTime> lastSeen;
  final Value<int> photoCount;
  final Value<int> isDirty;
  final Value<String?> syncedAt;
  final Value<int> rowid;
  const RegionVisitsCompanion({
    this.tripId = const Value.absent(),
    this.regionCode = const Value.absent(),
    this.countryCode = const Value.absent(),
    this.firstSeen = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.photoCount = const Value.absent(),
    this.isDirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RegionVisitsCompanion.insert({
    required String tripId,
    required String regionCode,
    required String countryCode,
    required DateTime firstSeen,
    required DateTime lastSeen,
    this.photoCount = const Value.absent(),
    this.isDirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : tripId = Value(tripId),
       regionCode = Value(regionCode),
       countryCode = Value(countryCode),
       firstSeen = Value(firstSeen),
       lastSeen = Value(lastSeen);
  static Insertable<RegionVisitRow> custom({
    Expression<String>? tripId,
    Expression<String>? regionCode,
    Expression<String>? countryCode,
    Expression<DateTime>? firstSeen,
    Expression<DateTime>? lastSeen,
    Expression<int>? photoCount,
    Expression<int>? isDirty,
    Expression<String>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tripId != null) 'trip_id': tripId,
      if (regionCode != null) 'region_code': regionCode,
      if (countryCode != null) 'country_code': countryCode,
      if (firstSeen != null) 'first_seen': firstSeen,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (photoCount != null) 'photo_count': photoCount,
      if (isDirty != null) 'is_dirty': isDirty,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RegionVisitsCompanion copyWith({
    Value<String>? tripId,
    Value<String>? regionCode,
    Value<String>? countryCode,
    Value<DateTime>? firstSeen,
    Value<DateTime>? lastSeen,
    Value<int>? photoCount,
    Value<int>? isDirty,
    Value<String?>? syncedAt,
    Value<int>? rowid,
  }) {
    return RegionVisitsCompanion(
      tripId: tripId ?? this.tripId,
      regionCode: regionCode ?? this.regionCode,
      countryCode: countryCode ?? this.countryCode,
      firstSeen: firstSeen ?? this.firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
      photoCount: photoCount ?? this.photoCount,
      isDirty: isDirty ?? this.isDirty,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (regionCode.present) {
      map['region_code'] = Variable<String>(regionCode.value);
    }
    if (countryCode.present) {
      map['country_code'] = Variable<String>(countryCode.value);
    }
    if (firstSeen.present) {
      map['first_seen'] = Variable<DateTime>(firstSeen.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<DateTime>(lastSeen.value);
    }
    if (photoCount.present) {
      map['photo_count'] = Variable<int>(photoCount.value);
    }
    if (isDirty.present) {
      map['is_dirty'] = Variable<int>(isDirty.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<String>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RegionVisitsCompanion(')
          ..write('tripId: $tripId, ')
          ..write('regionCode: $regionCode, ')
          ..write('countryCode: $countryCode, ')
          ..write('firstSeen: $firstSeen, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('photoCount: $photoCount, ')
          ..write('isDirty: $isDirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PhotoDateRecordsTable extends PhotoDateRecords
    with TableInfo<$PhotoDateRecordsTable, PhotoDateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhotoDateRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _countryCodeMeta = const VerificationMeta(
    'countryCode',
  );
  @override
  late final GeneratedColumn<String> countryCode = GeneratedColumn<String>(
    'country_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capturedAtMeta = const VerificationMeta(
    'capturedAt',
  );
  @override
  late final GeneratedColumn<DateTime> capturedAt = GeneratedColumn<DateTime>(
    'captured_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _regionCodeMeta = const VerificationMeta(
    'regionCode',
  );
  @override
  late final GeneratedColumn<String> regionCode = GeneratedColumn<String>(
    'region_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [countryCode, capturedAt, regionCode];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'photo_date_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<PhotoDateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('country_code')) {
      context.handle(
        _countryCodeMeta,
        countryCode.isAcceptableOrUnknown(
          data['country_code']!,
          _countryCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_countryCodeMeta);
    }
    if (data.containsKey('captured_at')) {
      context.handle(
        _capturedAtMeta,
        capturedAt.isAcceptableOrUnknown(data['captured_at']!, _capturedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_capturedAtMeta);
    }
    if (data.containsKey('region_code')) {
      context.handle(
        _regionCodeMeta,
        regionCode.isAcceptableOrUnknown(data['region_code']!, _regionCodeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {countryCode, capturedAt};
  @override
  PhotoDateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PhotoDateRow(
      countryCode:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}country_code'],
          )!,
      capturedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}captured_at'],
          )!,
      regionCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}region_code'],
      ),
    );
  }

  @override
  $PhotoDateRecordsTable createAlias(String alias) {
    return $PhotoDateRecordsTable(attachedDatabase, alias);
  }
}

class PhotoDateRow extends DataClass implements Insertable<PhotoDateRow> {
  final String countryCode;
  final DateTime capturedAt;

  /// ISO 3166-2 region code resolved during scanning. Null when the coordinate
  /// falls in open water, a micro-state with no admin1 divisions, or for rows
  /// created before schema v7.
  final String? regionCode;
  const PhotoDateRow({
    required this.countryCode,
    required this.capturedAt,
    this.regionCode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['country_code'] = Variable<String>(countryCode);
    map['captured_at'] = Variable<DateTime>(capturedAt);
    if (!nullToAbsent || regionCode != null) {
      map['region_code'] = Variable<String>(regionCode);
    }
    return map;
  }

  PhotoDateRecordsCompanion toCompanion(bool nullToAbsent) {
    return PhotoDateRecordsCompanion(
      countryCode: Value(countryCode),
      capturedAt: Value(capturedAt),
      regionCode:
          regionCode == null && nullToAbsent
              ? const Value.absent()
              : Value(regionCode),
    );
  }

  factory PhotoDateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PhotoDateRow(
      countryCode: serializer.fromJson<String>(json['countryCode']),
      capturedAt: serializer.fromJson<DateTime>(json['capturedAt']),
      regionCode: serializer.fromJson<String?>(json['regionCode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'countryCode': serializer.toJson<String>(countryCode),
      'capturedAt': serializer.toJson<DateTime>(capturedAt),
      'regionCode': serializer.toJson<String?>(regionCode),
    };
  }

  PhotoDateRow copyWith({
    String? countryCode,
    DateTime? capturedAt,
    Value<String?> regionCode = const Value.absent(),
  }) => PhotoDateRow(
    countryCode: countryCode ?? this.countryCode,
    capturedAt: capturedAt ?? this.capturedAt,
    regionCode: regionCode.present ? regionCode.value : this.regionCode,
  );
  PhotoDateRow copyWithCompanion(PhotoDateRecordsCompanion data) {
    return PhotoDateRow(
      countryCode:
          data.countryCode.present ? data.countryCode.value : this.countryCode,
      capturedAt:
          data.capturedAt.present ? data.capturedAt.value : this.capturedAt,
      regionCode:
          data.regionCode.present ? data.regionCode.value : this.regionCode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhotoDateRow(')
          ..write('countryCode: $countryCode, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('regionCode: $regionCode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(countryCode, capturedAt, regionCode);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhotoDateRow &&
          other.countryCode == this.countryCode &&
          other.capturedAt == this.capturedAt &&
          other.regionCode == this.regionCode);
}

class PhotoDateRecordsCompanion extends UpdateCompanion<PhotoDateRow> {
  final Value<String> countryCode;
  final Value<DateTime> capturedAt;
  final Value<String?> regionCode;
  final Value<int> rowid;
  const PhotoDateRecordsCompanion({
    this.countryCode = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.regionCode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PhotoDateRecordsCompanion.insert({
    required String countryCode,
    required DateTime capturedAt,
    this.regionCode = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : countryCode = Value(countryCode),
       capturedAt = Value(capturedAt);
  static Insertable<PhotoDateRow> custom({
    Expression<String>? countryCode,
    Expression<DateTime>? capturedAt,
    Expression<String>? regionCode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (countryCode != null) 'country_code': countryCode,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (regionCode != null) 'region_code': regionCode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PhotoDateRecordsCompanion copyWith({
    Value<String>? countryCode,
    Value<DateTime>? capturedAt,
    Value<String?>? regionCode,
    Value<int>? rowid,
  }) {
    return PhotoDateRecordsCompanion(
      countryCode: countryCode ?? this.countryCode,
      capturedAt: capturedAt ?? this.capturedAt,
      regionCode: regionCode ?? this.regionCode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (countryCode.present) {
      map['country_code'] = Variable<String>(countryCode.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<DateTime>(capturedAt.value);
    }
    if (regionCode.present) {
      map['region_code'] = Variable<String>(regionCode.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhotoDateRecordsCompanion(')
          ..write('countryCode: $countryCode, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('regionCode: $regionCode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TripsTable extends Trips with TableInfo<$TripsTable, TripRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TripsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countryCodeMeta = const VerificationMeta(
    'countryCode',
  );
  @override
  late final GeneratedColumn<String> countryCode = GeneratedColumn<String>(
    'country_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedOnMeta = const VerificationMeta(
    'startedOn',
  );
  @override
  late final GeneratedColumn<DateTime> startedOn = GeneratedColumn<DateTime>(
    'started_on',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedOnMeta = const VerificationMeta(
    'endedOn',
  );
  @override
  late final GeneratedColumn<DateTime> endedOn = GeneratedColumn<DateTime>(
    'ended_on',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _photoCountMeta = const VerificationMeta(
    'photoCount',
  );
  @override
  late final GeneratedColumn<int> photoCount = GeneratedColumn<int>(
    'photo_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isManualMeta = const VerificationMeta(
    'isManual',
  );
  @override
  late final GeneratedColumn<int> isManual = GeneratedColumn<int>(
    'is_manual',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isDirtyMeta = const VerificationMeta(
    'isDirty',
  );
  @override
  late final GeneratedColumn<int> isDirty = GeneratedColumn<int>(
    'is_dirty',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<String> syncedAt = GeneratedColumn<String>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    countryCode,
    startedOn,
    endedOn,
    photoCount,
    isManual,
    isDirty,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trips';
  @override
  VerificationContext validateIntegrity(
    Insertable<TripRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('country_code')) {
      context.handle(
        _countryCodeMeta,
        countryCode.isAcceptableOrUnknown(
          data['country_code']!,
          _countryCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_countryCodeMeta);
    }
    if (data.containsKey('started_on')) {
      context.handle(
        _startedOnMeta,
        startedOn.isAcceptableOrUnknown(data['started_on']!, _startedOnMeta),
      );
    } else if (isInserting) {
      context.missing(_startedOnMeta);
    }
    if (data.containsKey('ended_on')) {
      context.handle(
        _endedOnMeta,
        endedOn.isAcceptableOrUnknown(data['ended_on']!, _endedOnMeta),
      );
    } else if (isInserting) {
      context.missing(_endedOnMeta);
    }
    if (data.containsKey('photo_count')) {
      context.handle(
        _photoCountMeta,
        photoCount.isAcceptableOrUnknown(data['photo_count']!, _photoCountMeta),
      );
    } else if (isInserting) {
      context.missing(_photoCountMeta);
    }
    if (data.containsKey('is_manual')) {
      context.handle(
        _isManualMeta,
        isManual.isAcceptableOrUnknown(data['is_manual']!, _isManualMeta),
      );
    }
    if (data.containsKey('is_dirty')) {
      context.handle(
        _isDirtyMeta,
        isDirty.isAcceptableOrUnknown(data['is_dirty']!, _isDirtyMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TripRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TripRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      countryCode:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}country_code'],
          )!,
      startedOn:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}started_on'],
          )!,
      endedOn:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}ended_on'],
          )!,
      photoCount:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}photo_count'],
          )!,
      isManual:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}is_manual'],
          )!,
      isDirty:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}is_dirty'],
          )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $TripsTable createAlias(String alias) {
    return $TripsTable(attachedDatabase, alias);
  }
}

class TripRow extends DataClass implements Insertable<TripRow> {
  final String id;
  final String countryCode;
  final DateTime startedOn;
  final DateTime endedOn;
  final int photoCount;

  /// 1 = manually created/edited; 0 = inferred from photos.
  final int isManual;
  final int isDirty;
  final String? syncedAt;
  const TripRow({
    required this.id,
    required this.countryCode,
    required this.startedOn,
    required this.endedOn,
    required this.photoCount,
    required this.isManual,
    required this.isDirty,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['country_code'] = Variable<String>(countryCode);
    map['started_on'] = Variable<DateTime>(startedOn);
    map['ended_on'] = Variable<DateTime>(endedOn);
    map['photo_count'] = Variable<int>(photoCount);
    map['is_manual'] = Variable<int>(isManual);
    map['is_dirty'] = Variable<int>(isDirty);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<String>(syncedAt);
    }
    return map;
  }

  TripsCompanion toCompanion(bool nullToAbsent) {
    return TripsCompanion(
      id: Value(id),
      countryCode: Value(countryCode),
      startedOn: Value(startedOn),
      endedOn: Value(endedOn),
      photoCount: Value(photoCount),
      isManual: Value(isManual),
      isDirty: Value(isDirty),
      syncedAt:
          syncedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(syncedAt),
    );
  }

  factory TripRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TripRow(
      id: serializer.fromJson<String>(json['id']),
      countryCode: serializer.fromJson<String>(json['countryCode']),
      startedOn: serializer.fromJson<DateTime>(json['startedOn']),
      endedOn: serializer.fromJson<DateTime>(json['endedOn']),
      photoCount: serializer.fromJson<int>(json['photoCount']),
      isManual: serializer.fromJson<int>(json['isManual']),
      isDirty: serializer.fromJson<int>(json['isDirty']),
      syncedAt: serializer.fromJson<String?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'countryCode': serializer.toJson<String>(countryCode),
      'startedOn': serializer.toJson<DateTime>(startedOn),
      'endedOn': serializer.toJson<DateTime>(endedOn),
      'photoCount': serializer.toJson<int>(photoCount),
      'isManual': serializer.toJson<int>(isManual),
      'isDirty': serializer.toJson<int>(isDirty),
      'syncedAt': serializer.toJson<String?>(syncedAt),
    };
  }

  TripRow copyWith({
    String? id,
    String? countryCode,
    DateTime? startedOn,
    DateTime? endedOn,
    int? photoCount,
    int? isManual,
    int? isDirty,
    Value<String?> syncedAt = const Value.absent(),
  }) => TripRow(
    id: id ?? this.id,
    countryCode: countryCode ?? this.countryCode,
    startedOn: startedOn ?? this.startedOn,
    endedOn: endedOn ?? this.endedOn,
    photoCount: photoCount ?? this.photoCount,
    isManual: isManual ?? this.isManual,
    isDirty: isDirty ?? this.isDirty,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  TripRow copyWithCompanion(TripsCompanion data) {
    return TripRow(
      id: data.id.present ? data.id.value : this.id,
      countryCode:
          data.countryCode.present ? data.countryCode.value : this.countryCode,
      startedOn: data.startedOn.present ? data.startedOn.value : this.startedOn,
      endedOn: data.endedOn.present ? data.endedOn.value : this.endedOn,
      photoCount:
          data.photoCount.present ? data.photoCount.value : this.photoCount,
      isManual: data.isManual.present ? data.isManual.value : this.isManual,
      isDirty: data.isDirty.present ? data.isDirty.value : this.isDirty,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TripRow(')
          ..write('id: $id, ')
          ..write('countryCode: $countryCode, ')
          ..write('startedOn: $startedOn, ')
          ..write('endedOn: $endedOn, ')
          ..write('photoCount: $photoCount, ')
          ..write('isManual: $isManual, ')
          ..write('isDirty: $isDirty, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    countryCode,
    startedOn,
    endedOn,
    photoCount,
    isManual,
    isDirty,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TripRow &&
          other.id == this.id &&
          other.countryCode == this.countryCode &&
          other.startedOn == this.startedOn &&
          other.endedOn == this.endedOn &&
          other.photoCount == this.photoCount &&
          other.isManual == this.isManual &&
          other.isDirty == this.isDirty &&
          other.syncedAt == this.syncedAt);
}

class TripsCompanion extends UpdateCompanion<TripRow> {
  final Value<String> id;
  final Value<String> countryCode;
  final Value<DateTime> startedOn;
  final Value<DateTime> endedOn;
  final Value<int> photoCount;
  final Value<int> isManual;
  final Value<int> isDirty;
  final Value<String?> syncedAt;
  final Value<int> rowid;
  const TripsCompanion({
    this.id = const Value.absent(),
    this.countryCode = const Value.absent(),
    this.startedOn = const Value.absent(),
    this.endedOn = const Value.absent(),
    this.photoCount = const Value.absent(),
    this.isManual = const Value.absent(),
    this.isDirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TripsCompanion.insert({
    required String id,
    required String countryCode,
    required DateTime startedOn,
    required DateTime endedOn,
    required int photoCount,
    this.isManual = const Value.absent(),
    this.isDirty = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       countryCode = Value(countryCode),
       startedOn = Value(startedOn),
       endedOn = Value(endedOn),
       photoCount = Value(photoCount);
  static Insertable<TripRow> custom({
    Expression<String>? id,
    Expression<String>? countryCode,
    Expression<DateTime>? startedOn,
    Expression<DateTime>? endedOn,
    Expression<int>? photoCount,
    Expression<int>? isManual,
    Expression<int>? isDirty,
    Expression<String>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (countryCode != null) 'country_code': countryCode,
      if (startedOn != null) 'started_on': startedOn,
      if (endedOn != null) 'ended_on': endedOn,
      if (photoCount != null) 'photo_count': photoCount,
      if (isManual != null) 'is_manual': isManual,
      if (isDirty != null) 'is_dirty': isDirty,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TripsCompanion copyWith({
    Value<String>? id,
    Value<String>? countryCode,
    Value<DateTime>? startedOn,
    Value<DateTime>? endedOn,
    Value<int>? photoCount,
    Value<int>? isManual,
    Value<int>? isDirty,
    Value<String?>? syncedAt,
    Value<int>? rowid,
  }) {
    return TripsCompanion(
      id: id ?? this.id,
      countryCode: countryCode ?? this.countryCode,
      startedOn: startedOn ?? this.startedOn,
      endedOn: endedOn ?? this.endedOn,
      photoCount: photoCount ?? this.photoCount,
      isManual: isManual ?? this.isManual,
      isDirty: isDirty ?? this.isDirty,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (countryCode.present) {
      map['country_code'] = Variable<String>(countryCode.value);
    }
    if (startedOn.present) {
      map['started_on'] = Variable<DateTime>(startedOn.value);
    }
    if (endedOn.present) {
      map['ended_on'] = Variable<DateTime>(endedOn.value);
    }
    if (photoCount.present) {
      map['photo_count'] = Variable<int>(photoCount.value);
    }
    if (isManual.present) {
      map['is_manual'] = Variable<int>(isManual.value);
    }
    if (isDirty.present) {
      map['is_dirty'] = Variable<int>(isDirty.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<String>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripsCompanion(')
          ..write('id: $id, ')
          ..write('countryCode: $countryCode, ')
          ..write('startedOn: $startedOn, ')
          ..write('endedOn: $endedOn, ')
          ..write('photoCount: $photoCount, ')
          ..write('isManual: $isManual, ')
          ..write('isDirty: $isDirty, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$RoavvyDatabase extends GeneratedDatabase {
  _$RoavvyDatabase(QueryExecutor e) : super(e);
  $RoavvyDatabaseManager get managers => $RoavvyDatabaseManager(this);
  late final $ScanMetadataTable scanMetadata = $ScanMetadataTable(this);
  late final $InferredCountryVisitsTable inferredCountryVisits =
      $InferredCountryVisitsTable(this);
  late final $UserAddedCountriesTable userAddedCountries =
      $UserAddedCountriesTable(this);
  late final $UserRemovedCountriesTable userRemovedCountries =
      $UserRemovedCountriesTable(this);
  late final $UnlockedAchievementsTable unlockedAchievements =
      $UnlockedAchievementsTable(this);
  late final $ShareTokensTable shareTokens = $ShareTokensTable(this);
  late final $RegionVisitsTable regionVisits = $RegionVisitsTable(this);
  late final $PhotoDateRecordsTable photoDateRecords = $PhotoDateRecordsTable(
    this,
  );
  late final $TripsTable trips = $TripsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    scanMetadata,
    inferredCountryVisits,
    userAddedCountries,
    userRemovedCountries,
    unlockedAchievements,
    shareTokens,
    regionVisits,
    photoDateRecords,
    trips,
  ];
}

typedef $$ScanMetadataTableCreateCompanionBuilder =
    ScanMetadataCompanion Function({
      Value<int> id,
      Value<String?> lastScanAt,
      Value<String?> bootstrapCompletedAt,
    });
typedef $$ScanMetadataTableUpdateCompanionBuilder =
    ScanMetadataCompanion Function({
      Value<int> id,
      Value<String?> lastScanAt,
      Value<String?> bootstrapCompletedAt,
    });

class $$ScanMetadataTableFilterComposer
    extends Composer<_$RoavvyDatabase, $ScanMetadataTable> {
  $$ScanMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastScanAt => $composableBuilder(
    column: $table.lastScanAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bootstrapCompletedAt => $composableBuilder(
    column: $table.bootstrapCompletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScanMetadataTableOrderingComposer
    extends Composer<_$RoavvyDatabase, $ScanMetadataTable> {
  $$ScanMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastScanAt => $composableBuilder(
    column: $table.lastScanAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bootstrapCompletedAt => $composableBuilder(
    column: $table.bootstrapCompletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScanMetadataTableAnnotationComposer
    extends Composer<_$RoavvyDatabase, $ScanMetadataTable> {
  $$ScanMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get lastScanAt => $composableBuilder(
    column: $table.lastScanAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bootstrapCompletedAt => $composableBuilder(
    column: $table.bootstrapCompletedAt,
    builder: (column) => column,
  );
}

class $$ScanMetadataTableTableManager
    extends
        RootTableManager<
          _$RoavvyDatabase,
          $ScanMetadataTable,
          ScanMetadataRow,
          $$ScanMetadataTableFilterComposer,
          $$ScanMetadataTableOrderingComposer,
          $$ScanMetadataTableAnnotationComposer,
          $$ScanMetadataTableCreateCompanionBuilder,
          $$ScanMetadataTableUpdateCompanionBuilder,
          (
            ScanMetadataRow,
            BaseReferences<
              _$RoavvyDatabase,
              $ScanMetadataTable,
              ScanMetadataRow
            >,
          ),
          ScanMetadataRow,
          PrefetchHooks Function()
        > {
  $$ScanMetadataTableTableManager(_$RoavvyDatabase db, $ScanMetadataTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ScanMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$ScanMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$ScanMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> lastScanAt = const Value.absent(),
                Value<String?> bootstrapCompletedAt = const Value.absent(),
              }) => ScanMetadataCompanion(
                id: id,
                lastScanAt: lastScanAt,
                bootstrapCompletedAt: bootstrapCompletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> lastScanAt = const Value.absent(),
                Value<String?> bootstrapCompletedAt = const Value.absent(),
              }) => ScanMetadataCompanion.insert(
                id: id,
                lastScanAt: lastScanAt,
                bootstrapCompletedAt: bootstrapCompletedAt,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScanMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$RoavvyDatabase,
      $ScanMetadataTable,
      ScanMetadataRow,
      $$ScanMetadataTableFilterComposer,
      $$ScanMetadataTableOrderingComposer,
      $$ScanMetadataTableAnnotationComposer,
      $$ScanMetadataTableCreateCompanionBuilder,
      $$ScanMetadataTableUpdateCompanionBuilder,
      (
        ScanMetadataRow,
        BaseReferences<_$RoavvyDatabase, $ScanMetadataTable, ScanMetadataRow>,
      ),
      ScanMetadataRow,
      PrefetchHooks Function()
    >;
typedef $$InferredCountryVisitsTableCreateCompanionBuilder =
    InferredCountryVisitsCompanion Function({
      required String countryCode,
      required DateTime inferredAt,
      required int photoCount,
      Value<DateTime?> firstSeen,
      Value<DateTime?> lastSeen,
      Value<int> isDirty,
      Value<String?> syncedAt,
      Value<int> rowid,
    });
typedef $$InferredCountryVisitsTableUpdateCompanionBuilder =
    InferredCountryVisitsCompanion Function({
      Value<String> countryCode,
      Value<DateTime> inferredAt,
      Value<int> photoCount,
      Value<DateTime?> firstSeen,
      Value<DateTime?> lastSeen,
      Value<int> isDirty,
      Value<String?> syncedAt,
      Value<int> rowid,
    });

class $$InferredCountryVisitsTableFilterComposer
    extends Composer<_$RoavvyDatabase, $InferredCountryVisitsTable> {
  $$InferredCountryVisitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get countryCode => $composableBuilder(
    column: $table.countryCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get inferredAt => $composableBuilder(
    column: $table.inferredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get photoCount => $composableBuilder(
    column: $table.photoCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get firstSeen => $composableBuilder(
    column: $table.firstSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isDirty => $composableBuilder(
    column: $table.isDirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InferredCountryVisitsTableOrderingComposer
    extends Composer<_$RoavvyDatabase, $InferredCountryVisitsTable> {
  $$InferredCountryVisitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get countryCode => $composableBuilder(
    column: $table.countryCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get inferredAt => $composableBuilder(
    column: $table.inferredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get photoCount => $composableBuilder(
    column: $table.photoCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get firstSeen => $composableBuilder(
    column: $table.firstSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isDirty => $composableBuilder(
    column: $table.isDirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InferredCountryVisitsTableAnnotationComposer
    extends Composer<_$RoavvyDatabase, $InferredCountryVisitsTable> {
  $$InferredCountryVisitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get countryCode => $composableBuilder(
    column: $table.countryCode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get inferredAt => $composableBuilder(
    column: $table.inferredAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get photoCount => $composableBuilder(
    column: $table.photoCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get firstSeen =>
      $composableBuilder(column: $table.firstSeen, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => column);

  GeneratedColumn<int> get isDirty =>
      $composableBuilder(column: $table.isDirty, builder: (column) => column);

  GeneratedColumn<String> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$InferredCountryVisitsTableTableManager
    extends
        RootTableManager<
          _$RoavvyDatabase,
          $InferredCountryVisitsTable,
          InferredVisitRow,
          $$InferredCountryVisitsTableFilterComposer,
          $$InferredCountryVisitsTableOrderingComposer,
          $$InferredCountryVisitsTableAnnotationComposer,
          $$InferredCountryVisitsTableCreateCompanionBuilder,
          $$InferredCountryVisitsTableUpdateCompanionBuilder,
          (
            InferredVisitRow,
            BaseReferences<
              _$RoavvyDatabase,
              $InferredCountryVisitsTable,
              InferredVisitRow
            >,
          ),
          InferredVisitRow,
          PrefetchHooks Function()
        > {
  $$InferredCountryVisitsTableTableManager(
    _$RoavvyDatabase db,
    $InferredCountryVisitsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$InferredCountryVisitsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$InferredCountryVisitsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$InferredCountryVisitsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> countryCode = const Value.absent(),
                Value<DateTime> inferredAt = const Value.absent(),
                Value<int> photoCount = const Value.absent(),
                Value<DateTime?> firstSeen = const Value.absent(),
                Value<DateTime?> lastSeen = const Value.absent(),
                Value<int> isDirty = const Value.absent(),
                Value<String?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InferredCountryVisitsCompanion(
                countryCode: countryCode,
                inferredAt: inferredAt,
                photoCount: photoCount,
                firstSeen: firstSeen,
                lastSeen: lastSeen,
                isDirty: isDirty,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String countryCode,
                required DateTime inferredAt,
                required int photoCount,
                Value<DateTime?> firstSeen = const Value.absent(),
                Value<DateTime?> lastSeen = const Value.absent(),
                Value<int> isDirty = const Value.absent(),
                Value<String?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InferredCountryVisitsCompanion.insert(
                countryCode: countryCode,
                inferredAt: inferredAt,
                photoCount: photoCount,
                firstSeen: firstSeen,
                lastSeen: lastSeen,
                isDirty: isDirty,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InferredCountryVisitsTableProcessedTableManager =
    ProcessedTableManager<
      _$RoavvyDatabase,
      $InferredCountryVisitsTable,
      InferredVisitRow,
      $$InferredCountryVisitsTableFilterComposer,
      $$InferredCountryVisitsTableOrderingComposer,
      $$InferredCountryVisitsTableAnnotationComposer,
      $$InferredCountryVisitsTableCreateCompanionBuilder,
      $$InferredCountryVisitsTableUpdateCompanionBuilder,
      (
        InferredVisitRow,
        BaseReferences<
          _$RoavvyDatabase,
          $InferredCountryVisitsTable,
          InferredVisitRow
        >,
      ),
      InferredVisitRow,
      PrefetchHooks Function()
    >;
typedef $$UserAddedCountriesTableCreateCompanionBuilder =
    UserAddedCountriesCompanion Function({
      required String countryCode,
      required DateTime addedAt,
      Value<int> isDirty,
      Value<String?> syncedAt,
      Value<int> rowid,
    });
typedef $$UserAddedCountriesTableUpdateCompanionBuilder =
    UserAddedCountriesCompanion Function({
      Value<String> countryCode,
      Value<DateTime> addedAt,
      Value<int> isDirty,
      Value<String?> syncedAt,
      Value<int> rowid,
    });

class $$UserAddedCountriesTableFilterComposer
    extends Composer<_$RoavvyDatabase, $UserAddedCountriesTable> {
  $$UserAddedCountriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get countryCode => $composableBuilder(
    column: $table.countryCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isDirty => $composableBuilder(
    column: $table.isDirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserAddedCountriesTableOrderingComposer
    extends Composer<_$RoavvyDatabase, $UserAddedCountriesTable> {
  $$UserAddedCountriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get countryCode => $composableBuilder(
    column: $table.countryCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isDirty => $composableBuilder(
    column: $table.isDirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserAddedCountriesTableAnnotationComposer
    extends Composer<_$RoavvyDatabase, $UserAddedCountriesTable> {
  $$UserAddedCountriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get countryCode => $composableBuilder(
    column: $table.countryCode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<int> get isDirty =>
      $composableBuilder(column: $table.isDirty, builder: (column) => column);

  GeneratedColumn<String> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$UserAddedCountriesTableTableManager
    extends
        RootTableManager<
          _$RoavvyDatabase,
          $UserAddedCountriesTable,
          AddedCountryRow,
          $$UserAddedCountriesTableFilterComposer,
          $$UserAddedCountriesTableOrderingComposer,
          $$UserAddedCountriesTableAnnotationComposer,
          $$UserAddedCountriesTableCreateCompanionBuilder,
          $$UserAddedCountriesTableUpdateCompanionBuilder,
          (
            AddedCountryRow,
            BaseReferences<
              _$RoavvyDatabase,
              $UserAddedCountriesTable,
              AddedCountryRow
            >,
          ),
          AddedCountryRow,
          PrefetchHooks Function()
        > {
  $$UserAddedCountriesTableTableManager(
    _$RoavvyDatabase db,
    $UserAddedCountriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$UserAddedCountriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$UserAddedCountriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$UserAddedCountriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> countryCode = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> isDirty = const Value.absent(),
                Value<String?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserAddedCountriesCompanion(
                countryCode: countryCode,
                addedAt: addedAt,
                isDirty: isDirty,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String countryCode,
                required DateTime addedAt,
                Value<int> isDirty = const Value.absent(),
                Value<String?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserAddedCountriesCompanion.insert(
                countryCode: countryCode,
                addedAt: addedAt,
                isDirty: isDirty,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserAddedCountriesTableProcessedTableManager =
    ProcessedTableManager<
      _$RoavvyDatabase,
      $UserAddedCountriesTable,
      AddedCountryRow,
      $$UserAddedCountriesTableFilterComposer,
      $$UserAddedCountriesTableOrderingComposer,
      $$UserAddedCountriesTableAnnotationComposer,
      $$UserAddedCountriesTableCreateCompanionBuilder,
      $$UserAddedCountriesTableUpdateCompanionBuilder,
      (
        AddedCountryRow,
        BaseReferences<
          _$RoavvyDatabase,
          $UserAddedCountriesTable,
          AddedCountryRow
        >,
      ),
      AddedCountryRow,
      PrefetchHooks Function()
    >;
typedef $$UserRemovedCountriesTableCreateCompanionBuilder =
    UserRemovedCountriesCompanion Function({
      required String countryCode,
      required DateTime removedAt,
      Value<int> isDirty,
      Value<String?> syncedAt,
      Value<int> rowid,
    });
typedef $$UserRemovedCountriesTableUpdateCompanionBuilder =
    UserRemovedCountriesCompanion Function({
      Value<String> countryCode,
      Value<DateTime> removedAt,
      Value<int> isDirty,
      Value<String?> syncedAt,
      Value<int> rowid,
    });

class $$UserRemovedCountriesTableFilterComposer
    extends Composer<_$RoavvyDatabase, $UserRemovedCountriesTable> {
  $$UserRemovedCountriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get countryCode => $composableBuilder(
    column: $table.countryCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get removedAt => $composableBuilder(
    column: $table.removedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isDirty => $composableBuilder(
    column: $table.isDirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserRemovedCountriesTableOrderingComposer
    extends Composer<_$RoavvyDatabase, $UserRemovedCountriesTable> {
  $$UserRemovedCountriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get countryCode => $composableBuilder(
    column: $table.countryCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get removedAt => $composableBuilder(
    column: $table.removedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isDirty => $composableBuilder(
    column: $table.isDirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserRemovedCountriesTableAnnotationComposer
    extends Composer<_$RoavvyDatabase, $UserRemovedCountriesTable> {
  $$UserRemovedCountriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get countryCode => $composableBuilder(
    column: $table.countryCode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get removedAt =>
      $composableBuilder(column: $table.removedAt, builder: (column) => column);

  GeneratedColumn<int> get isDirty =>
      $composableBuilder(column: $table.isDirty, builder: (column) => column);

  GeneratedColumn<String> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$UserRemovedCountriesTableTableManager
    extends
        RootTableManager<
          _$RoavvyDatabase,
          $UserRemovedCountriesTable,
          RemovedCountryRow,
          $$UserRemovedCountriesTableFilterComposer,
          $$UserRemovedCountriesTableOrderingComposer,
          $$UserRemovedCountriesTableAnnotationComposer,
          $$UserRemovedCountriesTableCreateCompanionBuilder,
          $$UserRemovedCountriesTableUpdateCompanionBuilder,
          (
            RemovedCountryRow,
            BaseReferences<
              _$RoavvyDatabase,
              $UserRemovedCountriesTable,
              RemovedCountryRow
            >,
          ),
          RemovedCountryRow,
          PrefetchHooks Function()
        > {
  $$UserRemovedCountriesTableTableManager(
    _$RoavvyDatabase db,
    $UserRemovedCountriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$UserRemovedCountriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$UserRemovedCountriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$UserRemovedCountriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> countryCode = const Value.absent(),
                Value<DateTime> removedAt = const Value.absent(),
                Value<int> isDirty = const Value.absent(),
                Value<String?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserRemovedCountriesCompanion(
                countryCode: countryCode,
                removedAt: removedAt,
                isDirty: isDirty,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String countryCode,
                required DateTime removedAt,
                Value<int> isDirty = const Value.absent(),
                Value<String?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserRemovedCountriesCompanion.insert(
                countryCode: countryCode,
                removedAt: removedAt,
                isDirty: isDirty,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserRemovedCountriesTableProcessedTableManager =
    ProcessedTableManager<
      _$RoavvyDatabase,
      $UserRemovedCountriesTable,
      RemovedCountryRow,
      $$UserRemovedCountriesTableFilterComposer,
      $$UserRemovedCountriesTableOrderingComposer,
      $$UserRemovedCountriesTableAnnotationComposer,
      $$UserRemovedCountriesTableCreateCompanionBuilder,
      $$UserRemovedCountriesTableUpdateCompanionBuilder,
      (
        RemovedCountryRow,
        BaseReferences<
          _$RoavvyDatabase,
          $UserRemovedCountriesTable,
          RemovedCountryRow
        >,
      ),
      RemovedCountryRow,
      PrefetchHooks Function()
    >;
typedef $$UnlockedAchievementsTableCreateCompanionBuilder =
    UnlockedAchievementsCompanion Function({
      required String achievementId,
      required DateTime unlockedAt,
      Value<int> isDirty,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });
typedef $$UnlockedAchievementsTableUpdateCompanionBuilder =
    UnlockedAchievementsCompanion Function({
      Value<String> achievementId,
      Value<DateTime> unlockedAt,
      Value<int> isDirty,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });

class $$UnlockedAchievementsTableFilterComposer
    extends Composer<_$RoavvyDatabase, $UnlockedAchievementsTable> {
  $$UnlockedAchievementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get achievementId => $composableBuilder(
    column: $table.achievementId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get unlockedAt => $composableBuilder(
    column: $table.unlockedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isDirty => $composableBuilder(
    column: $table.isDirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UnlockedAchievementsTableOrderingComposer
    extends Composer<_$RoavvyDatabase, $UnlockedAchievementsTable> {
  $$UnlockedAchievementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get achievementId => $composableBuilder(
    column: $table.achievementId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get unlockedAt => $composableBuilder(
    column: $table.unlockedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isDirty => $composableBuilder(
    column: $table.isDirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UnlockedAchievementsTableAnnotationComposer
    extends Composer<_$RoavvyDatabase, $UnlockedAchievementsTable> {
  $$UnlockedAchievementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get achievementId => $composableBuilder(
    column: $table.achievementId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get unlockedAt => $composableBuilder(
    column: $table.unlockedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get isDirty =>
      $composableBuilder(column: $table.isDirty, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$UnlockedAchievementsTableTableManager
    extends
        RootTableManager<
          _$RoavvyDatabase,
          $UnlockedAchievementsTable,
          UnlockedAchievementRow,
          $$UnlockedAchievementsTableFilterComposer,
          $$UnlockedAchievementsTableOrderingComposer,
          $$UnlockedAchievementsTableAnnotationComposer,
          $$UnlockedAchievementsTableCreateCompanionBuilder,
          $$UnlockedAchievementsTableUpdateCompanionBuilder,
          (
            UnlockedAchievementRow,
            BaseReferences<
              _$RoavvyDatabase,
              $UnlockedAchievementsTable,
              UnlockedAchievementRow
            >,
          ),
          UnlockedAchievementRow,
          PrefetchHooks Function()
        > {
  $$UnlockedAchievementsTableTableManager(
    _$RoavvyDatabase db,
    $UnlockedAchievementsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$UnlockedAchievementsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$UnlockedAchievementsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$UnlockedAchievementsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> achievementId = const Value.absent(),
                Value<DateTime> unlockedAt = const Value.absent(),
                Value<int> isDirty = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UnlockedAchievementsCompanion(
                achievementId: achievementId,
                unlockedAt: unlockedAt,
                isDirty: isDirty,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String achievementId,
                required DateTime unlockedAt,
                Value<int> isDirty = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UnlockedAchievementsCompanion.insert(
                achievementId: achievementId,
                unlockedAt: unlockedAt,
                isDirty: isDirty,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UnlockedAchievementsTableProcessedTableManager =
    ProcessedTableManager<
      _$RoavvyDatabase,
      $UnlockedAchievementsTable,
      UnlockedAchievementRow,
      $$UnlockedAchievementsTableFilterComposer,
      $$UnlockedAchievementsTableOrderingComposer,
      $$UnlockedAchievementsTableAnnotationComposer,
      $$UnlockedAchievementsTableCreateCompanionBuilder,
      $$UnlockedAchievementsTableUpdateCompanionBuilder,
      (
        UnlockedAchievementRow,
        BaseReferences<
          _$RoavvyDatabase,
          $UnlockedAchievementsTable,
          UnlockedAchievementRow
        >,
      ),
      UnlockedAchievementRow,
      PrefetchHooks Function()
    >;
typedef $$ShareTokensTableCreateCompanionBuilder =
    ShareTokensCompanion Function({Value<int> id, required String token});
typedef $$ShareTokensTableUpdateCompanionBuilder =
    ShareTokensCompanion Function({Value<int> id, Value<String> token});

class $$ShareTokensTableFilterComposer
    extends Composer<_$RoavvyDatabase, $ShareTokensTable> {
  $$ShareTokensTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get token => $composableBuilder(
    column: $table.token,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ShareTokensTableOrderingComposer
    extends Composer<_$RoavvyDatabase, $ShareTokensTable> {
  $$ShareTokensTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get token => $composableBuilder(
    column: $table.token,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ShareTokensTableAnnotationComposer
    extends Composer<_$RoavvyDatabase, $ShareTokensTable> {
  $$ShareTokensTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get token =>
      $composableBuilder(column: $table.token, builder: (column) => column);
}

class $$ShareTokensTableTableManager
    extends
        RootTableManager<
          _$RoavvyDatabase,
          $ShareTokensTable,
          ShareTokenRow,
          $$ShareTokensTableFilterComposer,
          $$ShareTokensTableOrderingComposer,
          $$ShareTokensTableAnnotationComposer,
          $$ShareTokensTableCreateCompanionBuilder,
          $$ShareTokensTableUpdateCompanionBuilder,
          (
            ShareTokenRow,
            BaseReferences<_$RoavvyDatabase, $ShareTokensTable, ShareTokenRow>,
          ),
          ShareTokenRow,
          PrefetchHooks Function()
        > {
  $$ShareTokensTableTableManager(_$RoavvyDatabase db, $ShareTokensTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ShareTokensTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$ShareTokensTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$ShareTokensTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> token = const Value.absent(),
              }) => ShareTokensCompanion(id: id, token: token),
          createCompanionCallback:
              ({Value<int> id = const Value.absent(), required String token}) =>
                  ShareTokensCompanion.insert(id: id, token: token),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ShareTokensTableProcessedTableManager =
    ProcessedTableManager<
      _$RoavvyDatabase,
      $ShareTokensTable,
      ShareTokenRow,
      $$ShareTokensTableFilterComposer,
      $$ShareTokensTableOrderingComposer,
      $$ShareTokensTableAnnotationComposer,
      $$ShareTokensTableCreateCompanionBuilder,
      $$ShareTokensTableUpdateCompanionBuilder,
      (
        ShareTokenRow,
        BaseReferences<_$RoavvyDatabase, $ShareTokensTable, ShareTokenRow>,
      ),
      ShareTokenRow,
      PrefetchHooks Function()
    >;
typedef $$RegionVisitsTableCreateCompanionBuilder =
    RegionVisitsCompanion Function({
      required String tripId,
      required String regionCode,
      required String countryCode,
      required DateTime firstSeen,
      required DateTime lastSeen,
      Value<int> photoCount,
      Value<int> isDirty,
      Value<String?> syncedAt,
      Value<int> rowid,
    });
typedef $$RegionVisitsTableUpdateCompanionBuilder =
    RegionVisitsCompanion Function({
      Value<String> tripId,
      Value<String> regionCode,
      Value<String> countryCode,
      Value<DateTime> firstSeen,
      Value<DateTime> lastSeen,
      Value<int> photoCount,
      Value<int> isDirty,
      Value<String?> syncedAt,
      Value<int> rowid,
    });

class $$RegionVisitsTableFilterComposer
    extends Composer<_$RoavvyDatabase, $RegionVisitsTable> {
  $$RegionVisitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get regionCode => $composableBuilder(
    column: $table.regionCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get countryCode => $composableBuilder(
    column: $table.countryCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get firstSeen => $composableBuilder(
    column: $table.firstSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get photoCount => $composableBuilder(
    column: $table.photoCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isDirty => $composableBuilder(
    column: $table.isDirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RegionVisitsTableOrderingComposer
    extends Composer<_$RoavvyDatabase, $RegionVisitsTable> {
  $$RegionVisitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get regionCode => $composableBuilder(
    column: $table.regionCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get countryCode => $composableBuilder(
    column: $table.countryCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get firstSeen => $composableBuilder(
    column: $table.firstSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get photoCount => $composableBuilder(
    column: $table.photoCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isDirty => $composableBuilder(
    column: $table.isDirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RegionVisitsTableAnnotationComposer
    extends Composer<_$RoavvyDatabase, $RegionVisitsTable> {
  $$RegionVisitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tripId =>
      $composableBuilder(column: $table.tripId, builder: (column) => column);

  GeneratedColumn<String> get regionCode => $composableBuilder(
    column: $table.regionCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get countryCode => $composableBuilder(
    column: $table.countryCode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get firstSeen =>
      $composableBuilder(column: $table.firstSeen, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => column);

  GeneratedColumn<int> get photoCount => $composableBuilder(
    column: $table.photoCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get isDirty =>
      $composableBuilder(column: $table.isDirty, builder: (column) => column);

  GeneratedColumn<String> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$RegionVisitsTableTableManager
    extends
        RootTableManager<
          _$RoavvyDatabase,
          $RegionVisitsTable,
          RegionVisitRow,
          $$RegionVisitsTableFilterComposer,
          $$RegionVisitsTableOrderingComposer,
          $$RegionVisitsTableAnnotationComposer,
          $$RegionVisitsTableCreateCompanionBuilder,
          $$RegionVisitsTableUpdateCompanionBuilder,
          (
            RegionVisitRow,
            BaseReferences<
              _$RoavvyDatabase,
              $RegionVisitsTable,
              RegionVisitRow
            >,
          ),
          RegionVisitRow,
          PrefetchHooks Function()
        > {
  $$RegionVisitsTableTableManager(_$RoavvyDatabase db, $RegionVisitsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$RegionVisitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$RegionVisitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$RegionVisitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> tripId = const Value.absent(),
                Value<String> regionCode = const Value.absent(),
                Value<String> countryCode = const Value.absent(),
                Value<DateTime> firstSeen = const Value.absent(),
                Value<DateTime> lastSeen = const Value.absent(),
                Value<int> photoCount = const Value.absent(),
                Value<int> isDirty = const Value.absent(),
                Value<String?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RegionVisitsCompanion(
                tripId: tripId,
                regionCode: regionCode,
                countryCode: countryCode,
                firstSeen: firstSeen,
                lastSeen: lastSeen,
                photoCount: photoCount,
                isDirty: isDirty,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String tripId,
                required String regionCode,
                required String countryCode,
                required DateTime firstSeen,
                required DateTime lastSeen,
                Value<int> photoCount = const Value.absent(),
                Value<int> isDirty = const Value.absent(),
                Value<String?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RegionVisitsCompanion.insert(
                tripId: tripId,
                regionCode: regionCode,
                countryCode: countryCode,
                firstSeen: firstSeen,
                lastSeen: lastSeen,
                photoCount: photoCount,
                isDirty: isDirty,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RegionVisitsTableProcessedTableManager =
    ProcessedTableManager<
      _$RoavvyDatabase,
      $RegionVisitsTable,
      RegionVisitRow,
      $$RegionVisitsTableFilterComposer,
      $$RegionVisitsTableOrderingComposer,
      $$RegionVisitsTableAnnotationComposer,
      $$RegionVisitsTableCreateCompanionBuilder,
      $$RegionVisitsTableUpdateCompanionBuilder,
      (
        RegionVisitRow,
        BaseReferences<_$RoavvyDatabase, $RegionVisitsTable, RegionVisitRow>,
      ),
      RegionVisitRow,
      PrefetchHooks Function()
    >;
typedef $$PhotoDateRecordsTableCreateCompanionBuilder =
    PhotoDateRecordsCompanion Function({
      required String countryCode,
      required DateTime capturedAt,
      Value<String?> regionCode,
      Value<int> rowid,
    });
typedef $$PhotoDateRecordsTableUpdateCompanionBuilder =
    PhotoDateRecordsCompanion Function({
      Value<String> countryCode,
      Value<DateTime> capturedAt,
      Value<String?> regionCode,
      Value<int> rowid,
    });

class $$PhotoDateRecordsTableFilterComposer
    extends Composer<_$RoavvyDatabase, $PhotoDateRecordsTable> {
  $$PhotoDateRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get countryCode => $composableBuilder(
    column: $table.countryCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get regionCode => $composableBuilder(
    column: $table.regionCode,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PhotoDateRecordsTableOrderingComposer
    extends Composer<_$RoavvyDatabase, $PhotoDateRecordsTable> {
  $$PhotoDateRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get countryCode => $composableBuilder(
    column: $table.countryCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get regionCode => $composableBuilder(
    column: $table.regionCode,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PhotoDateRecordsTableAnnotationComposer
    extends Composer<_$RoavvyDatabase, $PhotoDateRecordsTable> {
  $$PhotoDateRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get countryCode => $composableBuilder(
    column: $table.countryCode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get regionCode => $composableBuilder(
    column: $table.regionCode,
    builder: (column) => column,
  );
}

class $$PhotoDateRecordsTableTableManager
    extends
        RootTableManager<
          _$RoavvyDatabase,
          $PhotoDateRecordsTable,
          PhotoDateRow,
          $$PhotoDateRecordsTableFilterComposer,
          $$PhotoDateRecordsTableOrderingComposer,
          $$PhotoDateRecordsTableAnnotationComposer,
          $$PhotoDateRecordsTableCreateCompanionBuilder,
          $$PhotoDateRecordsTableUpdateCompanionBuilder,
          (
            PhotoDateRow,
            BaseReferences<
              _$RoavvyDatabase,
              $PhotoDateRecordsTable,
              PhotoDateRow
            >,
          ),
          PhotoDateRow,
          PrefetchHooks Function()
        > {
  $$PhotoDateRecordsTableTableManager(
    _$RoavvyDatabase db,
    $PhotoDateRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () =>
                  $$PhotoDateRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$PhotoDateRecordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$PhotoDateRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> countryCode = const Value.absent(),
                Value<DateTime> capturedAt = const Value.absent(),
                Value<String?> regionCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhotoDateRecordsCompanion(
                countryCode: countryCode,
                capturedAt: capturedAt,
                regionCode: regionCode,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String countryCode,
                required DateTime capturedAt,
                Value<String?> regionCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhotoDateRecordsCompanion.insert(
                countryCode: countryCode,
                capturedAt: capturedAt,
                regionCode: regionCode,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PhotoDateRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$RoavvyDatabase,
      $PhotoDateRecordsTable,
      PhotoDateRow,
      $$PhotoDateRecordsTableFilterComposer,
      $$PhotoDateRecordsTableOrderingComposer,
      $$PhotoDateRecordsTableAnnotationComposer,
      $$PhotoDateRecordsTableCreateCompanionBuilder,
      $$PhotoDateRecordsTableUpdateCompanionBuilder,
      (
        PhotoDateRow,
        BaseReferences<_$RoavvyDatabase, $PhotoDateRecordsTable, PhotoDateRow>,
      ),
      PhotoDateRow,
      PrefetchHooks Function()
    >;
typedef $$TripsTableCreateCompanionBuilder =
    TripsCompanion Function({
      required String id,
      required String countryCode,
      required DateTime startedOn,
      required DateTime endedOn,
      required int photoCount,
      Value<int> isManual,
      Value<int> isDirty,
      Value<String?> syncedAt,
      Value<int> rowid,
    });
typedef $$TripsTableUpdateCompanionBuilder =
    TripsCompanion Function({
      Value<String> id,
      Value<String> countryCode,
      Value<DateTime> startedOn,
      Value<DateTime> endedOn,
      Value<int> photoCount,
      Value<int> isManual,
      Value<int> isDirty,
      Value<String?> syncedAt,
      Value<int> rowid,
    });

class $$TripsTableFilterComposer
    extends Composer<_$RoavvyDatabase, $TripsTable> {
  $$TripsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get countryCode => $composableBuilder(
    column: $table.countryCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedOn => $composableBuilder(
    column: $table.startedOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedOn => $composableBuilder(
    column: $table.endedOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get photoCount => $composableBuilder(
    column: $table.photoCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isManual => $composableBuilder(
    column: $table.isManual,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isDirty => $composableBuilder(
    column: $table.isDirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TripsTableOrderingComposer
    extends Composer<_$RoavvyDatabase, $TripsTable> {
  $$TripsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get countryCode => $composableBuilder(
    column: $table.countryCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedOn => $composableBuilder(
    column: $table.startedOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedOn => $composableBuilder(
    column: $table.endedOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get photoCount => $composableBuilder(
    column: $table.photoCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isManual => $composableBuilder(
    column: $table.isManual,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isDirty => $composableBuilder(
    column: $table.isDirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TripsTableAnnotationComposer
    extends Composer<_$RoavvyDatabase, $TripsTable> {
  $$TripsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get countryCode => $composableBuilder(
    column: $table.countryCode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedOn =>
      $composableBuilder(column: $table.startedOn, builder: (column) => column);

  GeneratedColumn<DateTime> get endedOn =>
      $composableBuilder(column: $table.endedOn, builder: (column) => column);

  GeneratedColumn<int> get photoCount => $composableBuilder(
    column: $table.photoCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get isManual =>
      $composableBuilder(column: $table.isManual, builder: (column) => column);

  GeneratedColumn<int> get isDirty =>
      $composableBuilder(column: $table.isDirty, builder: (column) => column);

  GeneratedColumn<String> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$TripsTableTableManager
    extends
        RootTableManager<
          _$RoavvyDatabase,
          $TripsTable,
          TripRow,
          $$TripsTableFilterComposer,
          $$TripsTableOrderingComposer,
          $$TripsTableAnnotationComposer,
          $$TripsTableCreateCompanionBuilder,
          $$TripsTableUpdateCompanionBuilder,
          (TripRow, BaseReferences<_$RoavvyDatabase, $TripsTable, TripRow>),
          TripRow,
          PrefetchHooks Function()
        > {
  $$TripsTableTableManager(_$RoavvyDatabase db, $TripsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$TripsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$TripsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$TripsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> countryCode = const Value.absent(),
                Value<DateTime> startedOn = const Value.absent(),
                Value<DateTime> endedOn = const Value.absent(),
                Value<int> photoCount = const Value.absent(),
                Value<int> isManual = const Value.absent(),
                Value<int> isDirty = const Value.absent(),
                Value<String?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TripsCompanion(
                id: id,
                countryCode: countryCode,
                startedOn: startedOn,
                endedOn: endedOn,
                photoCount: photoCount,
                isManual: isManual,
                isDirty: isDirty,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String countryCode,
                required DateTime startedOn,
                required DateTime endedOn,
                required int photoCount,
                Value<int> isManual = const Value.absent(),
                Value<int> isDirty = const Value.absent(),
                Value<String?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TripsCompanion.insert(
                id: id,
                countryCode: countryCode,
                startedOn: startedOn,
                endedOn: endedOn,
                photoCount: photoCount,
                isManual: isManual,
                isDirty: isDirty,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TripsTableProcessedTableManager =
    ProcessedTableManager<
      _$RoavvyDatabase,
      $TripsTable,
      TripRow,
      $$TripsTableFilterComposer,
      $$TripsTableOrderingComposer,
      $$TripsTableAnnotationComposer,
      $$TripsTableCreateCompanionBuilder,
      $$TripsTableUpdateCompanionBuilder,
      (TripRow, BaseReferences<_$RoavvyDatabase, $TripsTable, TripRow>),
      TripRow,
      PrefetchHooks Function()
    >;

class $RoavvyDatabaseManager {
  final _$RoavvyDatabase _db;
  $RoavvyDatabaseManager(this._db);
  $$ScanMetadataTableTableManager get scanMetadata =>
      $$ScanMetadataTableTableManager(_db, _db.scanMetadata);
  $$InferredCountryVisitsTableTableManager get inferredCountryVisits =>
      $$InferredCountryVisitsTableTableManager(_db, _db.inferredCountryVisits);
  $$UserAddedCountriesTableTableManager get userAddedCountries =>
      $$UserAddedCountriesTableTableManager(_db, _db.userAddedCountries);
  $$UserRemovedCountriesTableTableManager get userRemovedCountries =>
      $$UserRemovedCountriesTableTableManager(_db, _db.userRemovedCountries);
  $$UnlockedAchievementsTableTableManager get unlockedAchievements =>
      $$UnlockedAchievementsTableTableManager(_db, _db.unlockedAchievements);
  $$ShareTokensTableTableManager get shareTokens =>
      $$ShareTokensTableTableManager(_db, _db.shareTokens);
  $$RegionVisitsTableTableManager get regionVisits =>
      $$RegionVisitsTableTableManager(_db, _db.regionVisits);
  $$PhotoDateRecordsTableTableManager get photoDateRecords =>
      $$PhotoDateRecordsTableTableManager(_db, _db.photoDateRecords);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db, _db.trips);
}
