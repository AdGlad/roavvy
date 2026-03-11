// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'roavvy_database.dart';

// ignore_for_file: type=lint
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
  @override
  List<GeneratedColumn> get $columns => [
    countryCode,
    inferredAt,
    photoCount,
    firstSeen,
    lastSeen,
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
  const InferredVisitRow({
    required this.countryCode,
    required this.inferredAt,
    required this.photoCount,
    this.firstSeen,
    this.lastSeen,
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
    };
  }

  InferredVisitRow copyWith({
    String? countryCode,
    DateTime? inferredAt,
    int? photoCount,
    Value<DateTime?> firstSeen = const Value.absent(),
    Value<DateTime?> lastSeen = const Value.absent(),
  }) => InferredVisitRow(
    countryCode: countryCode ?? this.countryCode,
    inferredAt: inferredAt ?? this.inferredAt,
    photoCount: photoCount ?? this.photoCount,
    firstSeen: firstSeen.present ? firstSeen.value : this.firstSeen,
    lastSeen: lastSeen.present ? lastSeen.value : this.lastSeen,
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
    );
  }

  @override
  String toString() {
    return (StringBuffer('InferredVisitRow(')
          ..write('countryCode: $countryCode, ')
          ..write('inferredAt: $inferredAt, ')
          ..write('photoCount: $photoCount, ')
          ..write('firstSeen: $firstSeen, ')
          ..write('lastSeen: $lastSeen')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(countryCode, inferredAt, photoCount, firstSeen, lastSeen);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InferredVisitRow &&
          other.countryCode == this.countryCode &&
          other.inferredAt == this.inferredAt &&
          other.photoCount == this.photoCount &&
          other.firstSeen == this.firstSeen &&
          other.lastSeen == this.lastSeen);
}

class InferredCountryVisitsCompanion extends UpdateCompanion<InferredVisitRow> {
  final Value<String> countryCode;
  final Value<DateTime> inferredAt;
  final Value<int> photoCount;
  final Value<DateTime?> firstSeen;
  final Value<DateTime?> lastSeen;
  final Value<int> rowid;
  const InferredCountryVisitsCompanion({
    this.countryCode = const Value.absent(),
    this.inferredAt = const Value.absent(),
    this.photoCount = const Value.absent(),
    this.firstSeen = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InferredCountryVisitsCompanion.insert({
    required String countryCode,
    required DateTime inferredAt,
    required int photoCount,
    this.firstSeen = const Value.absent(),
    this.lastSeen = const Value.absent(),
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
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (countryCode != null) 'country_code': countryCode,
      if (inferredAt != null) 'inferred_at': inferredAt,
      if (photoCount != null) 'photo_count': photoCount,
      if (firstSeen != null) 'first_seen': firstSeen,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InferredCountryVisitsCompanion copyWith({
    Value<String>? countryCode,
    Value<DateTime>? inferredAt,
    Value<int>? photoCount,
    Value<DateTime?>? firstSeen,
    Value<DateTime?>? lastSeen,
    Value<int>? rowid,
  }) {
    return InferredCountryVisitsCompanion(
      countryCode: countryCode ?? this.countryCode,
      inferredAt: inferredAt ?? this.inferredAt,
      photoCount: photoCount ?? this.photoCount,
      firstSeen: firstSeen ?? this.firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
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
  @override
  List<GeneratedColumn> get $columns => [countryCode, addedAt];
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
  const AddedCountryRow({required this.countryCode, required this.addedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['country_code'] = Variable<String>(countryCode);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  UserAddedCountriesCompanion toCompanion(bool nullToAbsent) {
    return UserAddedCountriesCompanion(
      countryCode: Value(countryCode),
      addedAt: Value(addedAt),
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
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'countryCode': serializer.toJson<String>(countryCode),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  AddedCountryRow copyWith({String? countryCode, DateTime? addedAt}) =>
      AddedCountryRow(
        countryCode: countryCode ?? this.countryCode,
        addedAt: addedAt ?? this.addedAt,
      );
  AddedCountryRow copyWithCompanion(UserAddedCountriesCompanion data) {
    return AddedCountryRow(
      countryCode:
          data.countryCode.present ? data.countryCode.value : this.countryCode,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AddedCountryRow(')
          ..write('countryCode: $countryCode, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(countryCode, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AddedCountryRow &&
          other.countryCode == this.countryCode &&
          other.addedAt == this.addedAt);
}

class UserAddedCountriesCompanion extends UpdateCompanion<AddedCountryRow> {
  final Value<String> countryCode;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const UserAddedCountriesCompanion({
    this.countryCode = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserAddedCountriesCompanion.insert({
    required String countryCode,
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  }) : countryCode = Value(countryCode),
       addedAt = Value(addedAt);
  static Insertable<AddedCountryRow> custom({
    Expression<String>? countryCode,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (countryCode != null) 'country_code': countryCode,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserAddedCountriesCompanion copyWith({
    Value<String>? countryCode,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return UserAddedCountriesCompanion(
      countryCode: countryCode ?? this.countryCode,
      addedAt: addedAt ?? this.addedAt,
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
  @override
  List<GeneratedColumn> get $columns => [countryCode, removedAt];
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
  const RemovedCountryRow({required this.countryCode, required this.removedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['country_code'] = Variable<String>(countryCode);
    map['removed_at'] = Variable<DateTime>(removedAt);
    return map;
  }

  UserRemovedCountriesCompanion toCompanion(bool nullToAbsent) {
    return UserRemovedCountriesCompanion(
      countryCode: Value(countryCode),
      removedAt: Value(removedAt),
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
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'countryCode': serializer.toJson<String>(countryCode),
      'removedAt': serializer.toJson<DateTime>(removedAt),
    };
  }

  RemovedCountryRow copyWith({String? countryCode, DateTime? removedAt}) =>
      RemovedCountryRow(
        countryCode: countryCode ?? this.countryCode,
        removedAt: removedAt ?? this.removedAt,
      );
  RemovedCountryRow copyWithCompanion(UserRemovedCountriesCompanion data) {
    return RemovedCountryRow(
      countryCode:
          data.countryCode.present ? data.countryCode.value : this.countryCode,
      removedAt: data.removedAt.present ? data.removedAt.value : this.removedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RemovedCountryRow(')
          ..write('countryCode: $countryCode, ')
          ..write('removedAt: $removedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(countryCode, removedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RemovedCountryRow &&
          other.countryCode == this.countryCode &&
          other.removedAt == this.removedAt);
}

class UserRemovedCountriesCompanion extends UpdateCompanion<RemovedCountryRow> {
  final Value<String> countryCode;
  final Value<DateTime> removedAt;
  final Value<int> rowid;
  const UserRemovedCountriesCompanion({
    this.countryCode = const Value.absent(),
    this.removedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserRemovedCountriesCompanion.insert({
    required String countryCode,
    required DateTime removedAt,
    this.rowid = const Value.absent(),
  }) : countryCode = Value(countryCode),
       removedAt = Value(removedAt);
  static Insertable<RemovedCountryRow> custom({
    Expression<String>? countryCode,
    Expression<DateTime>? removedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (countryCode != null) 'country_code': countryCode,
      if (removedAt != null) 'removed_at': removedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserRemovedCountriesCompanion copyWith({
    Value<String>? countryCode,
    Value<DateTime>? removedAt,
    Value<int>? rowid,
  }) {
    return UserRemovedCountriesCompanion(
      countryCode: countryCode ?? this.countryCode,
      removedAt: removedAt ?? this.removedAt,
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
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$RoavvyDatabase extends GeneratedDatabase {
  _$RoavvyDatabase(QueryExecutor e) : super(e);
  $RoavvyDatabaseManager get managers => $RoavvyDatabaseManager(this);
  late final $InferredCountryVisitsTable inferredCountryVisits =
      $InferredCountryVisitsTable(this);
  late final $UserAddedCountriesTable userAddedCountries =
      $UserAddedCountriesTable(this);
  late final $UserRemovedCountriesTable userRemovedCountries =
      $UserRemovedCountriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    inferredCountryVisits,
    userAddedCountries,
    userRemovedCountries,
  ];
}

typedef $$InferredCountryVisitsTableCreateCompanionBuilder =
    InferredCountryVisitsCompanion Function({
      required String countryCode,
      required DateTime inferredAt,
      required int photoCount,
      Value<DateTime?> firstSeen,
      Value<DateTime?> lastSeen,
      Value<int> rowid,
    });
typedef $$InferredCountryVisitsTableUpdateCompanionBuilder =
    InferredCountryVisitsCompanion Function({
      Value<String> countryCode,
      Value<DateTime> inferredAt,
      Value<int> photoCount,
      Value<DateTime?> firstSeen,
      Value<DateTime?> lastSeen,
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
                Value<int> rowid = const Value.absent(),
              }) => InferredCountryVisitsCompanion(
                countryCode: countryCode,
                inferredAt: inferredAt,
                photoCount: photoCount,
                firstSeen: firstSeen,
                lastSeen: lastSeen,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String countryCode,
                required DateTime inferredAt,
                required int photoCount,
                Value<DateTime?> firstSeen = const Value.absent(),
                Value<DateTime?> lastSeen = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InferredCountryVisitsCompanion.insert(
                countryCode: countryCode,
                inferredAt: inferredAt,
                photoCount: photoCount,
                firstSeen: firstSeen,
                lastSeen: lastSeen,
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
      Value<int> rowid,
    });
typedef $$UserAddedCountriesTableUpdateCompanionBuilder =
    UserAddedCountriesCompanion Function({
      Value<String> countryCode,
      Value<DateTime> addedAt,
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
                Value<int> rowid = const Value.absent(),
              }) => UserAddedCountriesCompanion(
                countryCode: countryCode,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String countryCode,
                required DateTime addedAt,
                Value<int> rowid = const Value.absent(),
              }) => UserAddedCountriesCompanion.insert(
                countryCode: countryCode,
                addedAt: addedAt,
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
      Value<int> rowid,
    });
typedef $$UserRemovedCountriesTableUpdateCompanionBuilder =
    UserRemovedCountriesCompanion Function({
      Value<String> countryCode,
      Value<DateTime> removedAt,
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
                Value<int> rowid = const Value.absent(),
              }) => UserRemovedCountriesCompanion(
                countryCode: countryCode,
                removedAt: removedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String countryCode,
                required DateTime removedAt,
                Value<int> rowid = const Value.absent(),
              }) => UserRemovedCountriesCompanion.insert(
                countryCode: countryCode,
                removedAt: removedAt,
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

class $RoavvyDatabaseManager {
  final _$RoavvyDatabase _db;
  $RoavvyDatabaseManager(this._db);
  $$InferredCountryVisitsTableTableManager get inferredCountryVisits =>
      $$InferredCountryVisitsTableTableManager(_db, _db.inferredCountryVisits);
  $$UserAddedCountriesTableTableManager get userAddedCountries =>
      $$UserAddedCountriesTableTableManager(_db, _db.userAddedCountries);
  $$UserRemovedCountriesTableTableManager get userRemovedCountries =>
      $$UserRemovedCountriesTableTableManager(_db, _db.userRemovedCountries);
}
