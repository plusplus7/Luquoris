// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MeetingsTable extends Meetings with TableInfo<$MeetingsTable, Meeting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MeetingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (created_at >= 0)',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (updated_at >= created_at)',
  );
  static const VerificationMeta _rowRevisionMeta = const VerificationMeta(
    'rowRevision',
  );
  @override
  late final GeneratedColumn<int> rowRevision = GeneratedColumn<int>(
    'row_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (row_revision >= 0)',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT 0 CHECK ((is_deleted = 0 AND deleted_at IS NULL) OR (is_deleted = 1 AND deleted_at IS NOT NULL))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NULL CHECK (deleted_at IS NULL OR deleted_at >= 0)',
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaDurationUsMeta = const VerificationMeta(
    'mediaDurationUs',
  );
  @override
  late final GeneratedColumn<int> mediaDurationUs = GeneratedColumn<int>(
    'media_duration_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant<int>(0),
  );
  static const VerificationMeta _lifecycleMeta = const VerificationMeta(
    'lifecycle',
  );
  @override
  late final GeneratedColumn<String> lifecycle = GeneratedColumn<String>(
    'lifecycle',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _languageModeMeta = const VerificationMeta(
    'languageMode',
  );
  @override
  late final GeneratedColumn<String> languageMode = GeneratedColumn<String>(
    'language_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trashedAtUtcMsMeta = const VerificationMeta(
    'trashedAtUtcMs',
  );
  @override
  late final GeneratedColumn<int> trashedAtUtcMs = GeneratedColumn<int>(
    'trashed_at_utc_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lifecycleBeforeTrashMeta =
      const VerificationMeta('lifecycleBeforeTrash');
  @override
  late final GeneratedColumn<String> lifecycleBeforeTrash =
      GeneratedColumn<String>(
        'lifecycle_before_trash',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    title,
    mediaDurationUs,
    lifecycle,
    languageMode,
    trashedAtUtcMs,
    lifecycleBeforeTrash,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meetings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Meeting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('row_revision')) {
      context.handle(
        _rowRevisionMeta,
        rowRevision.isAcceptableOrUnknown(
          data['row_revision']!,
          _rowRevisionMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('media_duration_us')) {
      context.handle(
        _mediaDurationUsMeta,
        mediaDurationUs.isAcceptableOrUnknown(
          data['media_duration_us']!,
          _mediaDurationUsMeta,
        ),
      );
    }
    if (data.containsKey('lifecycle')) {
      context.handle(
        _lifecycleMeta,
        lifecycle.isAcceptableOrUnknown(data['lifecycle']!, _lifecycleMeta),
      );
    } else if (isInserting) {
      context.missing(_lifecycleMeta);
    }
    if (data.containsKey('language_mode')) {
      context.handle(
        _languageModeMeta,
        languageMode.isAcceptableOrUnknown(
          data['language_mode']!,
          _languageModeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_languageModeMeta);
    }
    if (data.containsKey('trashed_at_utc_ms')) {
      context.handle(
        _trashedAtUtcMsMeta,
        trashedAtUtcMs.isAcceptableOrUnknown(
          data['trashed_at_utc_ms']!,
          _trashedAtUtcMsMeta,
        ),
      );
    }
    if (data.containsKey('lifecycle_before_trash')) {
      context.handle(
        _lifecycleBeforeTrashMeta,
        lifecycleBeforeTrash.isAcceptableOrUnknown(
          data['lifecycle_before_trash']!,
          _lifecycleBeforeTrashMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Meeting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Meeting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      rowRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_revision'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      mediaDurationUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}media_duration_us'],
      )!,
      lifecycle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lifecycle'],
      )!,
      languageMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language_mode'],
      )!,
      trashedAtUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trashed_at_utc_ms'],
      ),
      lifecycleBeforeTrash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lifecycle_before_trash'],
      ),
    );
  }

  @override
  $MeetingsTable createAlias(String alias) {
    return $MeetingsTable(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
}

class Meeting extends DataClass implements Insertable<Meeting> {
  /// Stable UUID-style identifier.
  final String id;

  /// UTC creation instant in epoch milliseconds.
  final int createdAt;

  /// UTC last-update instant in epoch milliseconds.
  final int updatedAt;

  /// Monotonic row revision used by restore conflict handling.
  final int rowRevision;

  /// Whether this row is hidden by a soft delete.
  final bool isDeleted;

  /// UTC soft-delete instant in epoch milliseconds.
  final int? deletedAt;

  /// User-visible title.
  final String title;

  /// Pause-free media duration in microseconds.
  final int mediaDurationUs;

  /// Persisted recording lifecycle.
  final String lifecycle;

  /// User-selected recognition language hint.
  final String languageMode;

  /// UTC trash instant used for the seven-day retention period.
  final int? trashedAtUtcMs;

  /// Durable lifecycle restored when the meeting leaves trash.
  final String? lifecycleBeforeTrash;
  const Meeting({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.rowRevision,
    required this.isDeleted,
    this.deletedAt,
    required this.title,
    required this.mediaDurationUs,
    required this.lifecycle,
    required this.languageMode,
    this.trashedAtUtcMs,
    this.lifecycleBeforeTrash,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['row_revision'] = Variable<int>(rowRevision);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['title'] = Variable<String>(title);
    map['media_duration_us'] = Variable<int>(mediaDurationUs);
    map['lifecycle'] = Variable<String>(lifecycle);
    map['language_mode'] = Variable<String>(languageMode);
    if (!nullToAbsent || trashedAtUtcMs != null) {
      map['trashed_at_utc_ms'] = Variable<int>(trashedAtUtcMs);
    }
    if (!nullToAbsent || lifecycleBeforeTrash != null) {
      map['lifecycle_before_trash'] = Variable<String>(lifecycleBeforeTrash);
    }
    return map;
  }

  MeetingsCompanion toCompanion(bool nullToAbsent) {
    return MeetingsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      rowRevision: Value(rowRevision),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      title: Value(title),
      mediaDurationUs: Value(mediaDurationUs),
      lifecycle: Value(lifecycle),
      languageMode: Value(languageMode),
      trashedAtUtcMs: trashedAtUtcMs == null && nullToAbsent
          ? const Value.absent()
          : Value(trashedAtUtcMs),
      lifecycleBeforeTrash: lifecycleBeforeTrash == null && nullToAbsent
          ? const Value.absent()
          : Value(lifecycleBeforeTrash),
    );
  }

  factory Meeting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Meeting(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      rowRevision: serializer.fromJson<int>(json['rowRevision']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      title: serializer.fromJson<String>(json['title']),
      mediaDurationUs: serializer.fromJson<int>(json['mediaDurationUs']),
      lifecycle: serializer.fromJson<String>(json['lifecycle']),
      languageMode: serializer.fromJson<String>(json['languageMode']),
      trashedAtUtcMs: serializer.fromJson<int?>(json['trashedAtUtcMs']),
      lifecycleBeforeTrash: serializer.fromJson<String?>(
        json['lifecycleBeforeTrash'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'rowRevision': serializer.toJson<int>(rowRevision),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'title': serializer.toJson<String>(title),
      'mediaDurationUs': serializer.toJson<int>(mediaDurationUs),
      'lifecycle': serializer.toJson<String>(lifecycle),
      'languageMode': serializer.toJson<String>(languageMode),
      'trashedAtUtcMs': serializer.toJson<int?>(trashedAtUtcMs),
      'lifecycleBeforeTrash': serializer.toJson<String?>(lifecycleBeforeTrash),
    };
  }

  Meeting copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    int? rowRevision,
    bool? isDeleted,
    Value<int?> deletedAt = const Value.absent(),
    String? title,
    int? mediaDurationUs,
    String? lifecycle,
    String? languageMode,
    Value<int?> trashedAtUtcMs = const Value.absent(),
    Value<String?> lifecycleBeforeTrash = const Value.absent(),
  }) => Meeting(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    rowRevision: rowRevision ?? this.rowRevision,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    title: title ?? this.title,
    mediaDurationUs: mediaDurationUs ?? this.mediaDurationUs,
    lifecycle: lifecycle ?? this.lifecycle,
    languageMode: languageMode ?? this.languageMode,
    trashedAtUtcMs: trashedAtUtcMs.present
        ? trashedAtUtcMs.value
        : this.trashedAtUtcMs,
    lifecycleBeforeTrash: lifecycleBeforeTrash.present
        ? lifecycleBeforeTrash.value
        : this.lifecycleBeforeTrash,
  );
  Meeting copyWithCompanion(MeetingsCompanion data) {
    return Meeting(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      rowRevision: data.rowRevision.present
          ? data.rowRevision.value
          : this.rowRevision,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      title: data.title.present ? data.title.value : this.title,
      mediaDurationUs: data.mediaDurationUs.present
          ? data.mediaDurationUs.value
          : this.mediaDurationUs,
      lifecycle: data.lifecycle.present ? data.lifecycle.value : this.lifecycle,
      languageMode: data.languageMode.present
          ? data.languageMode.value
          : this.languageMode,
      trashedAtUtcMs: data.trashedAtUtcMs.present
          ? data.trashedAtUtcMs.value
          : this.trashedAtUtcMs,
      lifecycleBeforeTrash: data.lifecycleBeforeTrash.present
          ? data.lifecycleBeforeTrash.value
          : this.lifecycleBeforeTrash,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Meeting(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('title: $title, ')
          ..write('mediaDurationUs: $mediaDurationUs, ')
          ..write('lifecycle: $lifecycle, ')
          ..write('languageMode: $languageMode, ')
          ..write('trashedAtUtcMs: $trashedAtUtcMs, ')
          ..write('lifecycleBeforeTrash: $lifecycleBeforeTrash')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    title,
    mediaDurationUs,
    lifecycle,
    languageMode,
    trashedAtUtcMs,
    lifecycleBeforeTrash,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Meeting &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.rowRevision == this.rowRevision &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt &&
          other.title == this.title &&
          other.mediaDurationUs == this.mediaDurationUs &&
          other.lifecycle == this.lifecycle &&
          other.languageMode == this.languageMode &&
          other.trashedAtUtcMs == this.trashedAtUtcMs &&
          other.lifecycleBeforeTrash == this.lifecycleBeforeTrash);
}

class MeetingsCompanion extends UpdateCompanion<Meeting> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowRevision;
  final Value<bool> isDeleted;
  final Value<int?> deletedAt;
  final Value<String> title;
  final Value<int> mediaDurationUs;
  final Value<String> lifecycle;
  final Value<String> languageMode;
  final Value<int?> trashedAtUtcMs;
  final Value<String?> lifecycleBeforeTrash;
  final Value<int> rowid;
  const MeetingsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.title = const Value.absent(),
    this.mediaDurationUs = const Value.absent(),
    this.lifecycle = const Value.absent(),
    this.languageMode = const Value.absent(),
    this.trashedAtUtcMs = const Value.absent(),
    this.lifecycleBeforeTrash = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MeetingsCompanion.insert({
    required String id,
    required int createdAt,
    required int updatedAt,
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String title,
    this.mediaDurationUs = const Value.absent(),
    required String lifecycle,
    required String languageMode,
    this.trashedAtUtcMs = const Value.absent(),
    this.lifecycleBeforeTrash = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       title = Value(title),
       lifecycle = Value(lifecycle),
       languageMode = Value(languageMode);
  static Insertable<Meeting> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowRevision,
    Expression<bool>? isDeleted,
    Expression<int>? deletedAt,
    Expression<String>? title,
    Expression<int>? mediaDurationUs,
    Expression<String>? lifecycle,
    Expression<String>? languageMode,
    Expression<int>? trashedAtUtcMs,
    Expression<String>? lifecycleBeforeTrash,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowRevision != null) 'row_revision': rowRevision,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (title != null) 'title': title,
      if (mediaDurationUs != null) 'media_duration_us': mediaDurationUs,
      if (lifecycle != null) 'lifecycle': lifecycle,
      if (languageMode != null) 'language_mode': languageMode,
      if (trashedAtUtcMs != null) 'trashed_at_utc_ms': trashedAtUtcMs,
      if (lifecycleBeforeTrash != null)
        'lifecycle_before_trash': lifecycleBeforeTrash,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MeetingsCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowRevision,
    Value<bool>? isDeleted,
    Value<int?>? deletedAt,
    Value<String>? title,
    Value<int>? mediaDurationUs,
    Value<String>? lifecycle,
    Value<String>? languageMode,
    Value<int?>? trashedAtUtcMs,
    Value<String?>? lifecycleBeforeTrash,
    Value<int>? rowid,
  }) {
    return MeetingsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowRevision: rowRevision ?? this.rowRevision,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      title: title ?? this.title,
      mediaDurationUs: mediaDurationUs ?? this.mediaDurationUs,
      lifecycle: lifecycle ?? this.lifecycle,
      languageMode: languageMode ?? this.languageMode,
      trashedAtUtcMs: trashedAtUtcMs ?? this.trashedAtUtcMs,
      lifecycleBeforeTrash: lifecycleBeforeTrash ?? this.lifecycleBeforeTrash,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowRevision.present) {
      map['row_revision'] = Variable<int>(rowRevision.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (mediaDurationUs.present) {
      map['media_duration_us'] = Variable<int>(mediaDurationUs.value);
    }
    if (lifecycle.present) {
      map['lifecycle'] = Variable<String>(lifecycle.value);
    }
    if (languageMode.present) {
      map['language_mode'] = Variable<String>(languageMode.value);
    }
    if (trashedAtUtcMs.present) {
      map['trashed_at_utc_ms'] = Variable<int>(trashedAtUtcMs.value);
    }
    if (lifecycleBeforeTrash.present) {
      map['lifecycle_before_trash'] = Variable<String>(
        lifecycleBeforeTrash.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MeetingsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('title: $title, ')
          ..write('mediaDurationUs: $mediaDurationUs, ')
          ..write('lifecycle: $lifecycle, ')
          ..write('languageMode: $languageMode, ')
          ..write('trashedAtUtcMs: $trashedAtUtcMs, ')
          ..write('lifecycleBeforeTrash: $lifecycleBeforeTrash, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AudioSegmentsTable extends AudioSegments
    with TableInfo<$AudioSegmentsTable, AudioSegment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AudioSegmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (created_at >= 0)',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (updated_at >= created_at)',
  );
  static const VerificationMeta _rowRevisionMeta = const VerificationMeta(
    'rowRevision',
  );
  @override
  late final GeneratedColumn<int> rowRevision = GeneratedColumn<int>(
    'row_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (row_revision >= 0)',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT 0 CHECK ((is_deleted = 0 AND deleted_at IS NULL) OR (is_deleted = 1 AND deleted_at IS NOT NULL))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NULL CHECK (deleted_at IS NULL OR deleted_at >= 0)',
  );
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<String> meetingId = GeneratedColumn<String>(
    'meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meetings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaStartUsMeta = const VerificationMeta(
    'mediaStartUs',
  );
  @override
  late final GeneratedColumn<int> mediaStartUs = GeneratedColumn<int>(
    'media_start_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaDurationUsMeta = const VerificationMeta(
    'mediaDurationUs',
  );
  @override
  late final GeneratedColumn<int> mediaDurationUs = GeneratedColumn<int>(
    'media_duration_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _committedBytesMeta = const VerificationMeta(
    'committedBytes',
  );
  @override
  late final GeneratedColumn<int> committedBytes = GeneratedColumn<int>(
    'committed_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    meetingId,
    sequence,
    relativePath,
    mediaStartUs,
    mediaDurationUs,
    committedBytes,
    state,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audio_segments';
  @override
  VerificationContext validateIntegrity(
    Insertable<AudioSegment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('row_revision')) {
      context.handle(
        _rowRevisionMeta,
        rowRevision.isAcceptableOrUnknown(
          data['row_revision']!,
          _rowRevisionMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    } else if (isInserting) {
      context.missing(_sequenceMeta);
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('media_start_us')) {
      context.handle(
        _mediaStartUsMeta,
        mediaStartUs.isAcceptableOrUnknown(
          data['media_start_us']!,
          _mediaStartUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_mediaStartUsMeta);
    }
    if (data.containsKey('media_duration_us')) {
      context.handle(
        _mediaDurationUsMeta,
        mediaDurationUs.isAcceptableOrUnknown(
          data['media_duration_us']!,
          _mediaDurationUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_mediaDurationUsMeta);
    }
    if (data.containsKey('committed_bytes')) {
      context.handle(
        _committedBytesMeta,
        committedBytes.isAcceptableOrUnknown(
          data['committed_bytes']!,
          _committedBytesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_committedBytesMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AudioSegment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AudioSegment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      rowRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_revision'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      )!,
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      )!,
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      mediaStartUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}media_start_us'],
      )!,
      mediaDurationUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}media_duration_us'],
      )!,
      committedBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}committed_bytes'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
    );
  }

  @override
  $AudioSegmentsTable createAlias(String alias) {
    return $AudioSegmentsTable(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
}

class AudioSegment extends DataClass implements Insertable<AudioSegment> {
  /// Stable UUID-style identifier.
  final String id;

  /// UTC creation instant in epoch milliseconds.
  final int createdAt;

  /// UTC last-update instant in epoch milliseconds.
  final int updatedAt;

  /// Monotonic row revision used by restore conflict handling.
  final int rowRevision;

  /// Whether this row is hidden by a soft delete.
  final bool isDeleted;

  /// UTC soft-delete instant in epoch milliseconds.
  final int? deletedAt;

  /// Owning meeting.
  final String meetingId;

  /// Monotonic segment order within the meeting.
  final int sequence;

  /// Validated path relative to the private media directory.
  final String relativePath;

  /// Pause-free media start in microseconds.
  final int mediaStartUs;

  /// Committed media duration in microseconds.
  final int mediaDurationUs;

  /// Bytes known to be durably committed.
  final int committedBytes;

  /// Segment integrity and commit state.
  final String state;
  const AudioSegment({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.rowRevision,
    required this.isDeleted,
    this.deletedAt,
    required this.meetingId,
    required this.sequence,
    required this.relativePath,
    required this.mediaStartUs,
    required this.mediaDurationUs,
    required this.committedBytes,
    required this.state,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['row_revision'] = Variable<int>(rowRevision);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['meeting_id'] = Variable<String>(meetingId);
    map['sequence'] = Variable<int>(sequence);
    map['relative_path'] = Variable<String>(relativePath);
    map['media_start_us'] = Variable<int>(mediaStartUs);
    map['media_duration_us'] = Variable<int>(mediaDurationUs);
    map['committed_bytes'] = Variable<int>(committedBytes);
    map['state'] = Variable<String>(state);
    return map;
  }

  AudioSegmentsCompanion toCompanion(bool nullToAbsent) {
    return AudioSegmentsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      rowRevision: Value(rowRevision),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      meetingId: Value(meetingId),
      sequence: Value(sequence),
      relativePath: Value(relativePath),
      mediaStartUs: Value(mediaStartUs),
      mediaDurationUs: Value(mediaDurationUs),
      committedBytes: Value(committedBytes),
      state: Value(state),
    );
  }

  factory AudioSegment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AudioSegment(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      rowRevision: serializer.fromJson<int>(json['rowRevision']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      meetingId: serializer.fromJson<String>(json['meetingId']),
      sequence: serializer.fromJson<int>(json['sequence']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      mediaStartUs: serializer.fromJson<int>(json['mediaStartUs']),
      mediaDurationUs: serializer.fromJson<int>(json['mediaDurationUs']),
      committedBytes: serializer.fromJson<int>(json['committedBytes']),
      state: serializer.fromJson<String>(json['state']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'rowRevision': serializer.toJson<int>(rowRevision),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'meetingId': serializer.toJson<String>(meetingId),
      'sequence': serializer.toJson<int>(sequence),
      'relativePath': serializer.toJson<String>(relativePath),
      'mediaStartUs': serializer.toJson<int>(mediaStartUs),
      'mediaDurationUs': serializer.toJson<int>(mediaDurationUs),
      'committedBytes': serializer.toJson<int>(committedBytes),
      'state': serializer.toJson<String>(state),
    };
  }

  AudioSegment copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    int? rowRevision,
    bool? isDeleted,
    Value<int?> deletedAt = const Value.absent(),
    String? meetingId,
    int? sequence,
    String? relativePath,
    int? mediaStartUs,
    int? mediaDurationUs,
    int? committedBytes,
    String? state,
  }) => AudioSegment(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    rowRevision: rowRevision ?? this.rowRevision,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    meetingId: meetingId ?? this.meetingId,
    sequence: sequence ?? this.sequence,
    relativePath: relativePath ?? this.relativePath,
    mediaStartUs: mediaStartUs ?? this.mediaStartUs,
    mediaDurationUs: mediaDurationUs ?? this.mediaDurationUs,
    committedBytes: committedBytes ?? this.committedBytes,
    state: state ?? this.state,
  );
  AudioSegment copyWithCompanion(AudioSegmentsCompanion data) {
    return AudioSegment(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      rowRevision: data.rowRevision.present
          ? data.rowRevision.value
          : this.rowRevision,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      mediaStartUs: data.mediaStartUs.present
          ? data.mediaStartUs.value
          : this.mediaStartUs,
      mediaDurationUs: data.mediaDurationUs.present
          ? data.mediaDurationUs.value
          : this.mediaDurationUs,
      committedBytes: data.committedBytes.present
          ? data.committedBytes.value
          : this.committedBytes,
      state: data.state.present ? data.state.value : this.state,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AudioSegment(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('meetingId: $meetingId, ')
          ..write('sequence: $sequence, ')
          ..write('relativePath: $relativePath, ')
          ..write('mediaStartUs: $mediaStartUs, ')
          ..write('mediaDurationUs: $mediaDurationUs, ')
          ..write('committedBytes: $committedBytes, ')
          ..write('state: $state')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    meetingId,
    sequence,
    relativePath,
    mediaStartUs,
    mediaDurationUs,
    committedBytes,
    state,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AudioSegment &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.rowRevision == this.rowRevision &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt &&
          other.meetingId == this.meetingId &&
          other.sequence == this.sequence &&
          other.relativePath == this.relativePath &&
          other.mediaStartUs == this.mediaStartUs &&
          other.mediaDurationUs == this.mediaDurationUs &&
          other.committedBytes == this.committedBytes &&
          other.state == this.state);
}

class AudioSegmentsCompanion extends UpdateCompanion<AudioSegment> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowRevision;
  final Value<bool> isDeleted;
  final Value<int?> deletedAt;
  final Value<String> meetingId;
  final Value<int> sequence;
  final Value<String> relativePath;
  final Value<int> mediaStartUs;
  final Value<int> mediaDurationUs;
  final Value<int> committedBytes;
  final Value<String> state;
  final Value<int> rowid;
  const AudioSegmentsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.sequence = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.mediaStartUs = const Value.absent(),
    this.mediaDurationUs = const Value.absent(),
    this.committedBytes = const Value.absent(),
    this.state = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AudioSegmentsCompanion.insert({
    required String id,
    required int createdAt,
    required int updatedAt,
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String meetingId,
    required int sequence,
    required String relativePath,
    required int mediaStartUs,
    required int mediaDurationUs,
    required int committedBytes,
    required String state,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       meetingId = Value(meetingId),
       sequence = Value(sequence),
       relativePath = Value(relativePath),
       mediaStartUs = Value(mediaStartUs),
       mediaDurationUs = Value(mediaDurationUs),
       committedBytes = Value(committedBytes),
       state = Value(state);
  static Insertable<AudioSegment> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowRevision,
    Expression<bool>? isDeleted,
    Expression<int>? deletedAt,
    Expression<String>? meetingId,
    Expression<int>? sequence,
    Expression<String>? relativePath,
    Expression<int>? mediaStartUs,
    Expression<int>? mediaDurationUs,
    Expression<int>? committedBytes,
    Expression<String>? state,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowRevision != null) 'row_revision': rowRevision,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (meetingId != null) 'meeting_id': meetingId,
      if (sequence != null) 'sequence': sequence,
      if (relativePath != null) 'relative_path': relativePath,
      if (mediaStartUs != null) 'media_start_us': mediaStartUs,
      if (mediaDurationUs != null) 'media_duration_us': mediaDurationUs,
      if (committedBytes != null) 'committed_bytes': committedBytes,
      if (state != null) 'state': state,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AudioSegmentsCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowRevision,
    Value<bool>? isDeleted,
    Value<int?>? deletedAt,
    Value<String>? meetingId,
    Value<int>? sequence,
    Value<String>? relativePath,
    Value<int>? mediaStartUs,
    Value<int>? mediaDurationUs,
    Value<int>? committedBytes,
    Value<String>? state,
    Value<int>? rowid,
  }) {
    return AudioSegmentsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowRevision: rowRevision ?? this.rowRevision,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      meetingId: meetingId ?? this.meetingId,
      sequence: sequence ?? this.sequence,
      relativePath: relativePath ?? this.relativePath,
      mediaStartUs: mediaStartUs ?? this.mediaStartUs,
      mediaDurationUs: mediaDurationUs ?? this.mediaDurationUs,
      committedBytes: committedBytes ?? this.committedBytes,
      state: state ?? this.state,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowRevision.present) {
      map['row_revision'] = Variable<int>(rowRevision.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (meetingId.present) {
      map['meeting_id'] = Variable<String>(meetingId.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (mediaStartUs.present) {
      map['media_start_us'] = Variable<int>(mediaStartUs.value);
    }
    if (mediaDurationUs.present) {
      map['media_duration_us'] = Variable<int>(mediaDurationUs.value);
    }
    if (committedBytes.present) {
      map['committed_bytes'] = Variable<int>(committedBytes.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AudioSegmentsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('meetingId: $meetingId, ')
          ..write('sequence: $sequence, ')
          ..write('relativePath: $relativePath, ')
          ..write('mediaStartUs: $mediaStartUs, ')
          ..write('mediaDurationUs: $mediaDurationUs, ')
          ..write('committedBytes: $committedBytes, ')
          ..write('state: $state, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionEventsTable extends SessionEvents
    with TableInfo<$SessionEventsTable, SessionEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (created_at >= 0)',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (updated_at >= created_at)',
  );
  static const VerificationMeta _rowRevisionMeta = const VerificationMeta(
    'rowRevision',
  );
  @override
  late final GeneratedColumn<int> rowRevision = GeneratedColumn<int>(
    'row_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (row_revision >= 0)',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT 0 CHECK ((is_deleted = 0 AND deleted_at IS NULL) OR (is_deleted = 1 AND deleted_at IS NOT NULL))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NULL CHECK (deleted_at IS NULL OR deleted_at >= 0)',
  );
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<String> meetingId = GeneratedColumn<String>(
    'meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meetings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wallClockUtcMsMeta = const VerificationMeta(
    'wallClockUtcMs',
  );
  @override
  late final GeneratedColumn<int> wallClockUtcMs = GeneratedColumn<int>(
    'wall_clock_utc_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monotonicElapsedUsMeta =
      const VerificationMeta('monotonicElapsedUs');
  @override
  late final GeneratedColumn<int> monotonicElapsedUs = GeneratedColumn<int>(
    'monotonic_elapsed_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaOffsetUsMeta = const VerificationMeta(
    'mediaOffsetUs',
  );
  @override
  late final GeneratedColumn<int> mediaOffsetUs = GeneratedColumn<int>(
    'media_offset_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    meetingId,
    sequence,
    type,
    wallClockUtcMs,
    monotonicElapsedUs,
    mediaOffsetUs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('row_revision')) {
      context.handle(
        _rowRevisionMeta,
        rowRevision.isAcceptableOrUnknown(
          data['row_revision']!,
          _rowRevisionMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    } else if (isInserting) {
      context.missing(_sequenceMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('wall_clock_utc_ms')) {
      context.handle(
        _wallClockUtcMsMeta,
        wallClockUtcMs.isAcceptableOrUnknown(
          data['wall_clock_utc_ms']!,
          _wallClockUtcMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_wallClockUtcMsMeta);
    }
    if (data.containsKey('monotonic_elapsed_us')) {
      context.handle(
        _monotonicElapsedUsMeta,
        monotonicElapsedUs.isAcceptableOrUnknown(
          data['monotonic_elapsed_us']!,
          _monotonicElapsedUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_monotonicElapsedUsMeta);
    }
    if (data.containsKey('media_offset_us')) {
      context.handle(
        _mediaOffsetUsMeta,
        mediaOffsetUs.isAcceptableOrUnknown(
          data['media_offset_us']!,
          _mediaOffsetUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_mediaOffsetUsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      rowRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_revision'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      )!,
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      wallClockUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wall_clock_utc_ms'],
      )!,
      monotonicElapsedUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}monotonic_elapsed_us'],
      )!,
      mediaOffsetUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}media_offset_us'],
      )!,
    );
  }

  @override
  $SessionEventsTable createAlias(String alias) {
    return $SessionEventsTable(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
}

class SessionEvent extends DataClass implements Insertable<SessionEvent> {
  /// Stable UUID-style identifier.
  final String id;

  /// UTC creation instant in epoch milliseconds.
  final int createdAt;

  /// UTC last-update instant in epoch milliseconds.
  final int updatedAt;

  /// Monotonic row revision used by restore conflict handling.
  final int rowRevision;

  /// Whether this row is hidden by a soft delete.
  final bool isDeleted;

  /// UTC soft-delete instant in epoch milliseconds.
  final int? deletedAt;

  /// Owning meeting.
  final String meetingId;

  /// Monotonic event order within the meeting.
  final int sequence;

  /// Event classification.
  final String type;

  /// Real UTC wall-clock time in epoch milliseconds.
  final int wallClockUtcMs;

  /// Monotonic elapsed time in microseconds.
  final int monotonicElapsedUs;

  /// Pause-free media position in microseconds.
  final int mediaOffsetUs;
  const SessionEvent({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.rowRevision,
    required this.isDeleted,
    this.deletedAt,
    required this.meetingId,
    required this.sequence,
    required this.type,
    required this.wallClockUtcMs,
    required this.monotonicElapsedUs,
    required this.mediaOffsetUs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['row_revision'] = Variable<int>(rowRevision);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['meeting_id'] = Variable<String>(meetingId);
    map['sequence'] = Variable<int>(sequence);
    map['type'] = Variable<String>(type);
    map['wall_clock_utc_ms'] = Variable<int>(wallClockUtcMs);
    map['monotonic_elapsed_us'] = Variable<int>(monotonicElapsedUs);
    map['media_offset_us'] = Variable<int>(mediaOffsetUs);
    return map;
  }

  SessionEventsCompanion toCompanion(bool nullToAbsent) {
    return SessionEventsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      rowRevision: Value(rowRevision),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      meetingId: Value(meetingId),
      sequence: Value(sequence),
      type: Value(type),
      wallClockUtcMs: Value(wallClockUtcMs),
      monotonicElapsedUs: Value(monotonicElapsedUs),
      mediaOffsetUs: Value(mediaOffsetUs),
    );
  }

  factory SessionEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionEvent(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      rowRevision: serializer.fromJson<int>(json['rowRevision']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      meetingId: serializer.fromJson<String>(json['meetingId']),
      sequence: serializer.fromJson<int>(json['sequence']),
      type: serializer.fromJson<String>(json['type']),
      wallClockUtcMs: serializer.fromJson<int>(json['wallClockUtcMs']),
      monotonicElapsedUs: serializer.fromJson<int>(json['monotonicElapsedUs']),
      mediaOffsetUs: serializer.fromJson<int>(json['mediaOffsetUs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'rowRevision': serializer.toJson<int>(rowRevision),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'meetingId': serializer.toJson<String>(meetingId),
      'sequence': serializer.toJson<int>(sequence),
      'type': serializer.toJson<String>(type),
      'wallClockUtcMs': serializer.toJson<int>(wallClockUtcMs),
      'monotonicElapsedUs': serializer.toJson<int>(monotonicElapsedUs),
      'mediaOffsetUs': serializer.toJson<int>(mediaOffsetUs),
    };
  }

  SessionEvent copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    int? rowRevision,
    bool? isDeleted,
    Value<int?> deletedAt = const Value.absent(),
    String? meetingId,
    int? sequence,
    String? type,
    int? wallClockUtcMs,
    int? monotonicElapsedUs,
    int? mediaOffsetUs,
  }) => SessionEvent(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    rowRevision: rowRevision ?? this.rowRevision,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    meetingId: meetingId ?? this.meetingId,
    sequence: sequence ?? this.sequence,
    type: type ?? this.type,
    wallClockUtcMs: wallClockUtcMs ?? this.wallClockUtcMs,
    monotonicElapsedUs: monotonicElapsedUs ?? this.monotonicElapsedUs,
    mediaOffsetUs: mediaOffsetUs ?? this.mediaOffsetUs,
  );
  SessionEvent copyWithCompanion(SessionEventsCompanion data) {
    return SessionEvent(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      rowRevision: data.rowRevision.present
          ? data.rowRevision.value
          : this.rowRevision,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      type: data.type.present ? data.type.value : this.type,
      wallClockUtcMs: data.wallClockUtcMs.present
          ? data.wallClockUtcMs.value
          : this.wallClockUtcMs,
      monotonicElapsedUs: data.monotonicElapsedUs.present
          ? data.monotonicElapsedUs.value
          : this.monotonicElapsedUs,
      mediaOffsetUs: data.mediaOffsetUs.present
          ? data.mediaOffsetUs.value
          : this.mediaOffsetUs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionEvent(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('meetingId: $meetingId, ')
          ..write('sequence: $sequence, ')
          ..write('type: $type, ')
          ..write('wallClockUtcMs: $wallClockUtcMs, ')
          ..write('monotonicElapsedUs: $monotonicElapsedUs, ')
          ..write('mediaOffsetUs: $mediaOffsetUs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    meetingId,
    sequence,
    type,
    wallClockUtcMs,
    monotonicElapsedUs,
    mediaOffsetUs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionEvent &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.rowRevision == this.rowRevision &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt &&
          other.meetingId == this.meetingId &&
          other.sequence == this.sequence &&
          other.type == this.type &&
          other.wallClockUtcMs == this.wallClockUtcMs &&
          other.monotonicElapsedUs == this.monotonicElapsedUs &&
          other.mediaOffsetUs == this.mediaOffsetUs);
}

class SessionEventsCompanion extends UpdateCompanion<SessionEvent> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowRevision;
  final Value<bool> isDeleted;
  final Value<int?> deletedAt;
  final Value<String> meetingId;
  final Value<int> sequence;
  final Value<String> type;
  final Value<int> wallClockUtcMs;
  final Value<int> monotonicElapsedUs;
  final Value<int> mediaOffsetUs;
  final Value<int> rowid;
  const SessionEventsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.sequence = const Value.absent(),
    this.type = const Value.absent(),
    this.wallClockUtcMs = const Value.absent(),
    this.monotonicElapsedUs = const Value.absent(),
    this.mediaOffsetUs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionEventsCompanion.insert({
    required String id,
    required int createdAt,
    required int updatedAt,
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String meetingId,
    required int sequence,
    required String type,
    required int wallClockUtcMs,
    required int monotonicElapsedUs,
    required int mediaOffsetUs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       meetingId = Value(meetingId),
       sequence = Value(sequence),
       type = Value(type),
       wallClockUtcMs = Value(wallClockUtcMs),
       monotonicElapsedUs = Value(monotonicElapsedUs),
       mediaOffsetUs = Value(mediaOffsetUs);
  static Insertable<SessionEvent> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowRevision,
    Expression<bool>? isDeleted,
    Expression<int>? deletedAt,
    Expression<String>? meetingId,
    Expression<int>? sequence,
    Expression<String>? type,
    Expression<int>? wallClockUtcMs,
    Expression<int>? monotonicElapsedUs,
    Expression<int>? mediaOffsetUs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowRevision != null) 'row_revision': rowRevision,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (meetingId != null) 'meeting_id': meetingId,
      if (sequence != null) 'sequence': sequence,
      if (type != null) 'type': type,
      if (wallClockUtcMs != null) 'wall_clock_utc_ms': wallClockUtcMs,
      if (monotonicElapsedUs != null)
        'monotonic_elapsed_us': monotonicElapsedUs,
      if (mediaOffsetUs != null) 'media_offset_us': mediaOffsetUs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionEventsCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowRevision,
    Value<bool>? isDeleted,
    Value<int?>? deletedAt,
    Value<String>? meetingId,
    Value<int>? sequence,
    Value<String>? type,
    Value<int>? wallClockUtcMs,
    Value<int>? monotonicElapsedUs,
    Value<int>? mediaOffsetUs,
    Value<int>? rowid,
  }) {
    return SessionEventsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowRevision: rowRevision ?? this.rowRevision,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      meetingId: meetingId ?? this.meetingId,
      sequence: sequence ?? this.sequence,
      type: type ?? this.type,
      wallClockUtcMs: wallClockUtcMs ?? this.wallClockUtcMs,
      monotonicElapsedUs: monotonicElapsedUs ?? this.monotonicElapsedUs,
      mediaOffsetUs: mediaOffsetUs ?? this.mediaOffsetUs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowRevision.present) {
      map['row_revision'] = Variable<int>(rowRevision.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (meetingId.present) {
      map['meeting_id'] = Variable<String>(meetingId.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (wallClockUtcMs.present) {
      map['wall_clock_utc_ms'] = Variable<int>(wallClockUtcMs.value);
    }
    if (monotonicElapsedUs.present) {
      map['monotonic_elapsed_us'] = Variable<int>(monotonicElapsedUs.value);
    }
    if (mediaOffsetUs.present) {
      map['media_offset_us'] = Variable<int>(mediaOffsetUs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionEventsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('meetingId: $meetingId, ')
          ..write('sequence: $sequence, ')
          ..write('type: $type, ')
          ..write('wallClockUtcMs: $wallClockUtcMs, ')
          ..write('monotonicElapsedUs: $monotonicElapsedUs, ')
          ..write('mediaOffsetUs: $mediaOffsetUs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookmarksTable extends Bookmarks
    with TableInfo<$BookmarksTable, Bookmark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (created_at >= 0)',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (updated_at >= created_at)',
  );
  static const VerificationMeta _rowRevisionMeta = const VerificationMeta(
    'rowRevision',
  );
  @override
  late final GeneratedColumn<int> rowRevision = GeneratedColumn<int>(
    'row_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (row_revision >= 0)',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT 0 CHECK ((is_deleted = 0 AND deleted_at IS NULL) OR (is_deleted = 1 AND deleted_at IS NOT NULL))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NULL CHECK (deleted_at IS NULL OR deleted_at >= 0)',
  );
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<String> meetingId = GeneratedColumn<String>(
    'meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meetings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _mediaOffsetUsMeta = const VerificationMeta(
    'mediaOffsetUs',
  );
  @override
  late final GeneratedColumn<int> mediaOffsetUs = GeneratedColumn<int>(
    'media_offset_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    meetingId,
    mediaOffsetUs,
    kind,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Bookmark> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('row_revision')) {
      context.handle(
        _rowRevisionMeta,
        rowRevision.isAcceptableOrUnknown(
          data['row_revision']!,
          _rowRevisionMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('media_offset_us')) {
      context.handle(
        _mediaOffsetUsMeta,
        mediaOffsetUs.isAcceptableOrUnknown(
          data['media_offset_us']!,
          _mediaOffsetUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_mediaOffsetUsMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Bookmark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Bookmark(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      rowRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_revision'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      )!,
      mediaOffsetUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}media_offset_us'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
    );
  }

  @override
  $BookmarksTable createAlias(String alias) {
    return $BookmarksTable(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
}

class Bookmark extends DataClass implements Insertable<Bookmark> {
  /// Stable UUID-style identifier.
  final String id;

  /// UTC creation instant in epoch milliseconds.
  final int createdAt;

  /// UTC last-update instant in epoch milliseconds.
  final int updatedAt;

  /// Monotonic row revision used by restore conflict handling.
  final int rowRevision;

  /// Whether this row is hidden by a soft delete.
  final bool isDeleted;

  /// UTC soft-delete instant in epoch milliseconds.
  final int? deletedAt;

  /// Owning meeting.
  final String meetingId;

  /// Pause-free media position in microseconds.
  final int mediaOffsetUs;

  /// Bookmark or highlight classification.
  final String kind;
  const Bookmark({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.rowRevision,
    required this.isDeleted,
    this.deletedAt,
    required this.meetingId,
    required this.mediaOffsetUs,
    required this.kind,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['row_revision'] = Variable<int>(rowRevision);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['meeting_id'] = Variable<String>(meetingId);
    map['media_offset_us'] = Variable<int>(mediaOffsetUs);
    map['kind'] = Variable<String>(kind);
    return map;
  }

  BookmarksCompanion toCompanion(bool nullToAbsent) {
    return BookmarksCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      rowRevision: Value(rowRevision),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      meetingId: Value(meetingId),
      mediaOffsetUs: Value(mediaOffsetUs),
      kind: Value(kind),
    );
  }

  factory Bookmark.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Bookmark(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      rowRevision: serializer.fromJson<int>(json['rowRevision']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      meetingId: serializer.fromJson<String>(json['meetingId']),
      mediaOffsetUs: serializer.fromJson<int>(json['mediaOffsetUs']),
      kind: serializer.fromJson<String>(json['kind']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'rowRevision': serializer.toJson<int>(rowRevision),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'meetingId': serializer.toJson<String>(meetingId),
      'mediaOffsetUs': serializer.toJson<int>(mediaOffsetUs),
      'kind': serializer.toJson<String>(kind),
    };
  }

  Bookmark copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    int? rowRevision,
    bool? isDeleted,
    Value<int?> deletedAt = const Value.absent(),
    String? meetingId,
    int? mediaOffsetUs,
    String? kind,
  }) => Bookmark(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    rowRevision: rowRevision ?? this.rowRevision,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    meetingId: meetingId ?? this.meetingId,
    mediaOffsetUs: mediaOffsetUs ?? this.mediaOffsetUs,
    kind: kind ?? this.kind,
  );
  Bookmark copyWithCompanion(BookmarksCompanion data) {
    return Bookmark(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      rowRevision: data.rowRevision.present
          ? data.rowRevision.value
          : this.rowRevision,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      mediaOffsetUs: data.mediaOffsetUs.present
          ? data.mediaOffsetUs.value
          : this.mediaOffsetUs,
      kind: data.kind.present ? data.kind.value : this.kind,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Bookmark(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('meetingId: $meetingId, ')
          ..write('mediaOffsetUs: $mediaOffsetUs, ')
          ..write('kind: $kind')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    meetingId,
    mediaOffsetUs,
    kind,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bookmark &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.rowRevision == this.rowRevision &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt &&
          other.meetingId == this.meetingId &&
          other.mediaOffsetUs == this.mediaOffsetUs &&
          other.kind == this.kind);
}

class BookmarksCompanion extends UpdateCompanion<Bookmark> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowRevision;
  final Value<bool> isDeleted;
  final Value<int?> deletedAt;
  final Value<String> meetingId;
  final Value<int> mediaOffsetUs;
  final Value<String> kind;
  final Value<int> rowid;
  const BookmarksCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.mediaOffsetUs = const Value.absent(),
    this.kind = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookmarksCompanion.insert({
    required String id,
    required int createdAt,
    required int updatedAt,
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String meetingId,
    required int mediaOffsetUs,
    required String kind,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       meetingId = Value(meetingId),
       mediaOffsetUs = Value(mediaOffsetUs),
       kind = Value(kind);
  static Insertable<Bookmark> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowRevision,
    Expression<bool>? isDeleted,
    Expression<int>? deletedAt,
    Expression<String>? meetingId,
    Expression<int>? mediaOffsetUs,
    Expression<String>? kind,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowRevision != null) 'row_revision': rowRevision,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (meetingId != null) 'meeting_id': meetingId,
      if (mediaOffsetUs != null) 'media_offset_us': mediaOffsetUs,
      if (kind != null) 'kind': kind,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookmarksCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowRevision,
    Value<bool>? isDeleted,
    Value<int?>? deletedAt,
    Value<String>? meetingId,
    Value<int>? mediaOffsetUs,
    Value<String>? kind,
    Value<int>? rowid,
  }) {
    return BookmarksCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowRevision: rowRevision ?? this.rowRevision,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      meetingId: meetingId ?? this.meetingId,
      mediaOffsetUs: mediaOffsetUs ?? this.mediaOffsetUs,
      kind: kind ?? this.kind,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowRevision.present) {
      map['row_revision'] = Variable<int>(rowRevision.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (meetingId.present) {
      map['meeting_id'] = Variable<String>(meetingId.value);
    }
    if (mediaOffsetUs.present) {
      map['media_offset_us'] = Variable<int>(mediaOffsetUs.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookmarksCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('meetingId: $meetingId, ')
          ..write('mediaOffsetUs: $mediaOffsetUs, ')
          ..write('kind: $kind, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ModelManifestsTable extends ModelManifests
    with TableInfo<$ModelManifestsTable, ModelManifest> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ModelManifestsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (created_at >= 0)',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (updated_at >= created_at)',
  );
  static const VerificationMeta _rowRevisionMeta = const VerificationMeta(
    'rowRevision',
  );
  @override
  late final GeneratedColumn<int> rowRevision = GeneratedColumn<int>(
    'row_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (row_revision >= 0)',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT 0 CHECK ((is_deleted = 0 AND deleted_at IS NULL) OR (is_deleted = 1 AND deleted_at IS NOT NULL))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NULL CHECK (deleted_at IS NULL OR deleted_at >= 0)',
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expectedEngineIdMeta = const VerificationMeta(
    'expectedEngineId',
  );
  @override
  late final GeneratedColumn<String> expectedEngineId = GeneratedColumn<String>(
    'expected_engine_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _licenseIdMeta = const VerificationMeta(
    'licenseId',
  );
  @override
  late final GeneratedColumn<String> licenseId = GeneratedColumn<String>(
    'license_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _licenseSnapshotPathMeta =
      const VerificationMeta('licenseSnapshotPath');
  @override
  late final GeneratedColumn<String> licenseSnapshotPath =
      GeneratedColumn<String>(
        'license_snapshot_path',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    version,
    source,
    sha256,
    bytes,
    expectedEngineId,
    licenseId,
    licenseSnapshotPath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'model_manifests';
  @override
  VerificationContext validateIntegrity(
    Insertable<ModelManifest> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('row_revision')) {
      context.handle(
        _rowRevisionMeta,
        rowRevision.isAcceptableOrUnknown(
          data['row_revision']!,
          _rowRevisionMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    } else if (isInserting) {
      context.missing(_sha256Meta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    if (data.containsKey('expected_engine_id')) {
      context.handle(
        _expectedEngineIdMeta,
        expectedEngineId.isAcceptableOrUnknown(
          data['expected_engine_id']!,
          _expectedEngineIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_expectedEngineIdMeta);
    }
    if (data.containsKey('license_id')) {
      context.handle(
        _licenseIdMeta,
        licenseId.isAcceptableOrUnknown(data['license_id']!, _licenseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_licenseIdMeta);
    }
    if (data.containsKey('license_snapshot_path')) {
      context.handle(
        _licenseSnapshotPathMeta,
        licenseSnapshotPath.isAcceptableOrUnknown(
          data['license_snapshot_path']!,
          _licenseSnapshotPathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_licenseSnapshotPathMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ModelManifest map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ModelManifest(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      rowRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_revision'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes'],
      )!,
      expectedEngineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expected_engine_id'],
      )!,
      licenseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}license_id'],
      )!,
      licenseSnapshotPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}license_snapshot_path'],
      )!,
    );
  }

  @override
  $ModelManifestsTable createAlias(String alias) {
    return $ModelManifestsTable(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
}

class ModelManifest extends DataClass implements Insertable<ModelManifest> {
  /// Stable UUID-style identifier.
  final String id;

  /// UTC creation instant in epoch milliseconds.
  final int createdAt;

  /// UTC last-update instant in epoch milliseconds.
  final int updatedAt;

  /// Monotonic row revision used by restore conflict handling.
  final int rowRevision;

  /// Whether this row is hidden by a soft delete.
  final bool isDeleted;

  /// UTC soft-delete instant in epoch milliseconds.
  final int? deletedAt;

  /// Exact model release version.
  final String version;

  /// Reviewed upstream source reference.
  final String source;

  /// Expected SHA-256 digest.
  final String sha256;

  /// Bundled byte length.
  final int bytes;

  /// Compatible inference-engine identifier.
  final String expectedEngineId;

  /// SPDX identifier or reviewed fixed license key.
  final String licenseId;

  /// App-relative bundled license snapshot.
  final String licenseSnapshotPath;
  const ModelManifest({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.rowRevision,
    required this.isDeleted,
    this.deletedAt,
    required this.version,
    required this.source,
    required this.sha256,
    required this.bytes,
    required this.expectedEngineId,
    required this.licenseId,
    required this.licenseSnapshotPath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['row_revision'] = Variable<int>(rowRevision);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['version'] = Variable<String>(version);
    map['source'] = Variable<String>(source);
    map['sha256'] = Variable<String>(sha256);
    map['bytes'] = Variable<int>(bytes);
    map['expected_engine_id'] = Variable<String>(expectedEngineId);
    map['license_id'] = Variable<String>(licenseId);
    map['license_snapshot_path'] = Variable<String>(licenseSnapshotPath);
    return map;
  }

  ModelManifestsCompanion toCompanion(bool nullToAbsent) {
    return ModelManifestsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      rowRevision: Value(rowRevision),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      version: Value(version),
      source: Value(source),
      sha256: Value(sha256),
      bytes: Value(bytes),
      expectedEngineId: Value(expectedEngineId),
      licenseId: Value(licenseId),
      licenseSnapshotPath: Value(licenseSnapshotPath),
    );
  }

  factory ModelManifest.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ModelManifest(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      rowRevision: serializer.fromJson<int>(json['rowRevision']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      version: serializer.fromJson<String>(json['version']),
      source: serializer.fromJson<String>(json['source']),
      sha256: serializer.fromJson<String>(json['sha256']),
      bytes: serializer.fromJson<int>(json['bytes']),
      expectedEngineId: serializer.fromJson<String>(json['expectedEngineId']),
      licenseId: serializer.fromJson<String>(json['licenseId']),
      licenseSnapshotPath: serializer.fromJson<String>(
        json['licenseSnapshotPath'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'rowRevision': serializer.toJson<int>(rowRevision),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'version': serializer.toJson<String>(version),
      'source': serializer.toJson<String>(source),
      'sha256': serializer.toJson<String>(sha256),
      'bytes': serializer.toJson<int>(bytes),
      'expectedEngineId': serializer.toJson<String>(expectedEngineId),
      'licenseId': serializer.toJson<String>(licenseId),
      'licenseSnapshotPath': serializer.toJson<String>(licenseSnapshotPath),
    };
  }

  ModelManifest copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    int? rowRevision,
    bool? isDeleted,
    Value<int?> deletedAt = const Value.absent(),
    String? version,
    String? source,
    String? sha256,
    int? bytes,
    String? expectedEngineId,
    String? licenseId,
    String? licenseSnapshotPath,
  }) => ModelManifest(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    rowRevision: rowRevision ?? this.rowRevision,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    version: version ?? this.version,
    source: source ?? this.source,
    sha256: sha256 ?? this.sha256,
    bytes: bytes ?? this.bytes,
    expectedEngineId: expectedEngineId ?? this.expectedEngineId,
    licenseId: licenseId ?? this.licenseId,
    licenseSnapshotPath: licenseSnapshotPath ?? this.licenseSnapshotPath,
  );
  ModelManifest copyWithCompanion(ModelManifestsCompanion data) {
    return ModelManifest(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      rowRevision: data.rowRevision.present
          ? data.rowRevision.value
          : this.rowRevision,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      version: data.version.present ? data.version.value : this.version,
      source: data.source.present ? data.source.value : this.source,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      expectedEngineId: data.expectedEngineId.present
          ? data.expectedEngineId.value
          : this.expectedEngineId,
      licenseId: data.licenseId.present ? data.licenseId.value : this.licenseId,
      licenseSnapshotPath: data.licenseSnapshotPath.present
          ? data.licenseSnapshotPath.value
          : this.licenseSnapshotPath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ModelManifest(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('version: $version, ')
          ..write('source: $source, ')
          ..write('sha256: $sha256, ')
          ..write('bytes: $bytes, ')
          ..write('expectedEngineId: $expectedEngineId, ')
          ..write('licenseId: $licenseId, ')
          ..write('licenseSnapshotPath: $licenseSnapshotPath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    version,
    source,
    sha256,
    bytes,
    expectedEngineId,
    licenseId,
    licenseSnapshotPath,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelManifest &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.rowRevision == this.rowRevision &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt &&
          other.version == this.version &&
          other.source == this.source &&
          other.sha256 == this.sha256 &&
          other.bytes == this.bytes &&
          other.expectedEngineId == this.expectedEngineId &&
          other.licenseId == this.licenseId &&
          other.licenseSnapshotPath == this.licenseSnapshotPath);
}

class ModelManifestsCompanion extends UpdateCompanion<ModelManifest> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowRevision;
  final Value<bool> isDeleted;
  final Value<int?> deletedAt;
  final Value<String> version;
  final Value<String> source;
  final Value<String> sha256;
  final Value<int> bytes;
  final Value<String> expectedEngineId;
  final Value<String> licenseId;
  final Value<String> licenseSnapshotPath;
  final Value<int> rowid;
  const ModelManifestsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.source = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.bytes = const Value.absent(),
    this.expectedEngineId = const Value.absent(),
    this.licenseId = const Value.absent(),
    this.licenseSnapshotPath = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ModelManifestsCompanion.insert({
    required String id,
    required int createdAt,
    required int updatedAt,
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String version,
    required String source,
    required String sha256,
    required int bytes,
    required String expectedEngineId,
    required String licenseId,
    required String licenseSnapshotPath,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       version = Value(version),
       source = Value(source),
       sha256 = Value(sha256),
       bytes = Value(bytes),
       expectedEngineId = Value(expectedEngineId),
       licenseId = Value(licenseId),
       licenseSnapshotPath = Value(licenseSnapshotPath);
  static Insertable<ModelManifest> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowRevision,
    Expression<bool>? isDeleted,
    Expression<int>? deletedAt,
    Expression<String>? version,
    Expression<String>? source,
    Expression<String>? sha256,
    Expression<int>? bytes,
    Expression<String>? expectedEngineId,
    Expression<String>? licenseId,
    Expression<String>? licenseSnapshotPath,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowRevision != null) 'row_revision': rowRevision,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (version != null) 'version': version,
      if (source != null) 'source': source,
      if (sha256 != null) 'sha256': sha256,
      if (bytes != null) 'bytes': bytes,
      if (expectedEngineId != null) 'expected_engine_id': expectedEngineId,
      if (licenseId != null) 'license_id': licenseId,
      if (licenseSnapshotPath != null)
        'license_snapshot_path': licenseSnapshotPath,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ModelManifestsCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowRevision,
    Value<bool>? isDeleted,
    Value<int?>? deletedAt,
    Value<String>? version,
    Value<String>? source,
    Value<String>? sha256,
    Value<int>? bytes,
    Value<String>? expectedEngineId,
    Value<String>? licenseId,
    Value<String>? licenseSnapshotPath,
    Value<int>? rowid,
  }) {
    return ModelManifestsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowRevision: rowRevision ?? this.rowRevision,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      version: version ?? this.version,
      source: source ?? this.source,
      sha256: sha256 ?? this.sha256,
      bytes: bytes ?? this.bytes,
      expectedEngineId: expectedEngineId ?? this.expectedEngineId,
      licenseId: licenseId ?? this.licenseId,
      licenseSnapshotPath: licenseSnapshotPath ?? this.licenseSnapshotPath,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowRevision.present) {
      map['row_revision'] = Variable<int>(rowRevision.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (expectedEngineId.present) {
      map['expected_engine_id'] = Variable<String>(expectedEngineId.value);
    }
    if (licenseId.present) {
      map['license_id'] = Variable<String>(licenseId.value);
    }
    if (licenseSnapshotPath.present) {
      map['license_snapshot_path'] = Variable<String>(
        licenseSnapshotPath.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ModelManifestsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('version: $version, ')
          ..write('source: $source, ')
          ..write('sha256: $sha256, ')
          ..write('bytes: $bytes, ')
          ..write('expectedEngineId: $expectedEngineId, ')
          ..write('licenseId: $licenseId, ')
          ..write('licenseSnapshotPath: $licenseSnapshotPath, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TranscriptRunsTable extends TranscriptRuns
    with TableInfo<$TranscriptRunsTable, TranscriptRun> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TranscriptRunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (created_at >= 0)',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (updated_at >= created_at)',
  );
  static const VerificationMeta _rowRevisionMeta = const VerificationMeta(
    'rowRevision',
  );
  @override
  late final GeneratedColumn<int> rowRevision = GeneratedColumn<int>(
    'row_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (row_revision >= 0)',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT 0 CHECK ((is_deleted = 0 AND deleted_at IS NULL) OR (is_deleted = 1 AND deleted_at IS NOT NULL))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NULL CHECK (deleted_at IS NULL OR deleted_at >= 0)',
  );
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<String> meetingId = GeneratedColumn<String>(
    'meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meetings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _engineIdMeta = const VerificationMeta(
    'engineId',
  );
  @override
  late final GeneratedColumn<String> engineId = GeneratedColumn<String>(
    'engine_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _engineVersionMeta = const VerificationMeta(
    'engineVersion',
  );
  @override
  late final GeneratedColumn<String> engineVersion = GeneratedColumn<String>(
    'engine_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES model_manifests (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _modelVersionMeta = const VerificationMeta(
    'modelVersion',
  );
  @override
  late final GeneratedColumn<String> modelVersion = GeneratedColumn<String>(
    'model_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelSha256Meta = const VerificationMeta(
    'modelSha256',
  );
  @override
  late final GeneratedColumn<String> modelSha256 = GeneratedColumn<String>(
    'model_sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parametersJsonMeta = const VerificationMeta(
    'parametersJson',
  );
  @override
  late final GeneratedColumn<String> parametersJson = GeneratedColumn<String>(
    'parameters_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runStateMeta = const VerificationMeta(
    'runState',
  );
  @override
  late final GeneratedColumn<String> runState = GeneratedColumn<String>(
    'run_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtUtcMsMeta = const VerificationMeta(
    'startedAtUtcMs',
  );
  @override
  late final GeneratedColumn<int> startedAtUtcMs = GeneratedColumn<int>(
    'started_at_utc_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endedAtUtcMsMeta = const VerificationMeta(
    'endedAtUtcMs',
  );
  @override
  late final GeneratedColumn<int> endedAtUtcMs = GeneratedColumn<int>(
    'ended_at_utc_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant<double>(0),
  );
  static const VerificationMeta _failureCodeMeta = const VerificationMeta(
    'failureCode',
  );
  @override
  late final GeneratedColumn<String> failureCode = GeneratedColumn<String>(
    'failure_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    meetingId,
    engineId,
    engineVersion,
    modelId,
    modelVersion,
    modelSha256,
    parametersJson,
    runState,
    startedAtUtcMs,
    endedAtUtcMs,
    progress,
    failureCode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transcript_runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<TranscriptRun> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('row_revision')) {
      context.handle(
        _rowRevisionMeta,
        rowRevision.isAcceptableOrUnknown(
          data['row_revision']!,
          _rowRevisionMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('engine_id')) {
      context.handle(
        _engineIdMeta,
        engineId.isAcceptableOrUnknown(data['engine_id']!, _engineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_engineIdMeta);
    }
    if (data.containsKey('engine_version')) {
      context.handle(
        _engineVersionMeta,
        engineVersion.isAcceptableOrUnknown(
          data['engine_version']!,
          _engineVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_engineVersionMeta);
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_modelIdMeta);
    }
    if (data.containsKey('model_version')) {
      context.handle(
        _modelVersionMeta,
        modelVersion.isAcceptableOrUnknown(
          data['model_version']!,
          _modelVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_modelVersionMeta);
    }
    if (data.containsKey('model_sha256')) {
      context.handle(
        _modelSha256Meta,
        modelSha256.isAcceptableOrUnknown(
          data['model_sha256']!,
          _modelSha256Meta,
        ),
      );
    } else if (isInserting) {
      context.missing(_modelSha256Meta);
    }
    if (data.containsKey('parameters_json')) {
      context.handle(
        _parametersJsonMeta,
        parametersJson.isAcceptableOrUnknown(
          data['parameters_json']!,
          _parametersJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_parametersJsonMeta);
    }
    if (data.containsKey('run_state')) {
      context.handle(
        _runStateMeta,
        runState.isAcceptableOrUnknown(data['run_state']!, _runStateMeta),
      );
    } else if (isInserting) {
      context.missing(_runStateMeta);
    }
    if (data.containsKey('started_at_utc_ms')) {
      context.handle(
        _startedAtUtcMsMeta,
        startedAtUtcMs.isAcceptableOrUnknown(
          data['started_at_utc_ms']!,
          _startedAtUtcMsMeta,
        ),
      );
    }
    if (data.containsKey('ended_at_utc_ms')) {
      context.handle(
        _endedAtUtcMsMeta,
        endedAtUtcMs.isAcceptableOrUnknown(
          data['ended_at_utc_ms']!,
          _endedAtUtcMsMeta,
        ),
      );
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('failure_code')) {
      context.handle(
        _failureCodeMeta,
        failureCode.isAcceptableOrUnknown(
          data['failure_code']!,
          _failureCodeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TranscriptRun map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TranscriptRun(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      rowRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_revision'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      )!,
      engineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}engine_id'],
      )!,
      engineVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}engine_version'],
      )!,
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      )!,
      modelVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_version'],
      )!,
      modelSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_sha256'],
      )!,
      parametersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parameters_json'],
      )!,
      runState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_state'],
      )!,
      startedAtUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at_utc_ms'],
      ),
      endedAtUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ended_at_utc_ms'],
      ),
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress'],
      )!,
      failureCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failure_code'],
      ),
    );
  }

  @override
  $TranscriptRunsTable createAlias(String alias) {
    return $TranscriptRunsTable(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
}

class TranscriptRun extends DataClass implements Insertable<TranscriptRun> {
  /// Stable UUID-style identifier.
  final String id;

  /// UTC creation instant in epoch milliseconds.
  final int createdAt;

  /// UTC last-update instant in epoch milliseconds.
  final int updatedAt;

  /// Monotonic row revision used by restore conflict handling.
  final int rowRevision;

  /// Whether this row is hidden by a soft delete.
  final bool isDeleted;

  /// UTC soft-delete instant in epoch milliseconds.
  final int? deletedAt;

  /// Owning meeting.
  final String meetingId;

  /// Stable inference-engine identifier.
  final String engineId;

  /// Exact inference-engine version.
  final String engineVersion;

  /// Bundled model manifest used by the run.
  final String modelId;

  /// Exact model version copied into immutable run provenance.
  final String modelVersion;

  /// Model digest copied into immutable run provenance.
  final String modelSha256;

  /// Canonical JSON of the actual inference parameters.
  final String parametersJson;

  /// Queued, running, completed, or failed.
  final String runState;

  /// UTC start instant when work has begun.
  final int? startedAtUtcMs;

  /// UTC terminal instant for completed or failed work.
  final int? endedAtUtcMs;

  /// Normalized completion fraction.
  final double progress;

  /// Structured privacy-safe terminal failure code.
  final String? failureCode;
  const TranscriptRun({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.rowRevision,
    required this.isDeleted,
    this.deletedAt,
    required this.meetingId,
    required this.engineId,
    required this.engineVersion,
    required this.modelId,
    required this.modelVersion,
    required this.modelSha256,
    required this.parametersJson,
    required this.runState,
    this.startedAtUtcMs,
    this.endedAtUtcMs,
    required this.progress,
    this.failureCode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['row_revision'] = Variable<int>(rowRevision);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['meeting_id'] = Variable<String>(meetingId);
    map['engine_id'] = Variable<String>(engineId);
    map['engine_version'] = Variable<String>(engineVersion);
    map['model_id'] = Variable<String>(modelId);
    map['model_version'] = Variable<String>(modelVersion);
    map['model_sha256'] = Variable<String>(modelSha256);
    map['parameters_json'] = Variable<String>(parametersJson);
    map['run_state'] = Variable<String>(runState);
    if (!nullToAbsent || startedAtUtcMs != null) {
      map['started_at_utc_ms'] = Variable<int>(startedAtUtcMs);
    }
    if (!nullToAbsent || endedAtUtcMs != null) {
      map['ended_at_utc_ms'] = Variable<int>(endedAtUtcMs);
    }
    map['progress'] = Variable<double>(progress);
    if (!nullToAbsent || failureCode != null) {
      map['failure_code'] = Variable<String>(failureCode);
    }
    return map;
  }

  TranscriptRunsCompanion toCompanion(bool nullToAbsent) {
    return TranscriptRunsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      rowRevision: Value(rowRevision),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      meetingId: Value(meetingId),
      engineId: Value(engineId),
      engineVersion: Value(engineVersion),
      modelId: Value(modelId),
      modelVersion: Value(modelVersion),
      modelSha256: Value(modelSha256),
      parametersJson: Value(parametersJson),
      runState: Value(runState),
      startedAtUtcMs: startedAtUtcMs == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAtUtcMs),
      endedAtUtcMs: endedAtUtcMs == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAtUtcMs),
      progress: Value(progress),
      failureCode: failureCode == null && nullToAbsent
          ? const Value.absent()
          : Value(failureCode),
    );
  }

  factory TranscriptRun.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TranscriptRun(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      rowRevision: serializer.fromJson<int>(json['rowRevision']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      meetingId: serializer.fromJson<String>(json['meetingId']),
      engineId: serializer.fromJson<String>(json['engineId']),
      engineVersion: serializer.fromJson<String>(json['engineVersion']),
      modelId: serializer.fromJson<String>(json['modelId']),
      modelVersion: serializer.fromJson<String>(json['modelVersion']),
      modelSha256: serializer.fromJson<String>(json['modelSha256']),
      parametersJson: serializer.fromJson<String>(json['parametersJson']),
      runState: serializer.fromJson<String>(json['runState']),
      startedAtUtcMs: serializer.fromJson<int?>(json['startedAtUtcMs']),
      endedAtUtcMs: serializer.fromJson<int?>(json['endedAtUtcMs']),
      progress: serializer.fromJson<double>(json['progress']),
      failureCode: serializer.fromJson<String?>(json['failureCode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'rowRevision': serializer.toJson<int>(rowRevision),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'meetingId': serializer.toJson<String>(meetingId),
      'engineId': serializer.toJson<String>(engineId),
      'engineVersion': serializer.toJson<String>(engineVersion),
      'modelId': serializer.toJson<String>(modelId),
      'modelVersion': serializer.toJson<String>(modelVersion),
      'modelSha256': serializer.toJson<String>(modelSha256),
      'parametersJson': serializer.toJson<String>(parametersJson),
      'runState': serializer.toJson<String>(runState),
      'startedAtUtcMs': serializer.toJson<int?>(startedAtUtcMs),
      'endedAtUtcMs': serializer.toJson<int?>(endedAtUtcMs),
      'progress': serializer.toJson<double>(progress),
      'failureCode': serializer.toJson<String?>(failureCode),
    };
  }

  TranscriptRun copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    int? rowRevision,
    bool? isDeleted,
    Value<int?> deletedAt = const Value.absent(),
    String? meetingId,
    String? engineId,
    String? engineVersion,
    String? modelId,
    String? modelVersion,
    String? modelSha256,
    String? parametersJson,
    String? runState,
    Value<int?> startedAtUtcMs = const Value.absent(),
    Value<int?> endedAtUtcMs = const Value.absent(),
    double? progress,
    Value<String?> failureCode = const Value.absent(),
  }) => TranscriptRun(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    rowRevision: rowRevision ?? this.rowRevision,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    meetingId: meetingId ?? this.meetingId,
    engineId: engineId ?? this.engineId,
    engineVersion: engineVersion ?? this.engineVersion,
    modelId: modelId ?? this.modelId,
    modelVersion: modelVersion ?? this.modelVersion,
    modelSha256: modelSha256 ?? this.modelSha256,
    parametersJson: parametersJson ?? this.parametersJson,
    runState: runState ?? this.runState,
    startedAtUtcMs: startedAtUtcMs.present
        ? startedAtUtcMs.value
        : this.startedAtUtcMs,
    endedAtUtcMs: endedAtUtcMs.present ? endedAtUtcMs.value : this.endedAtUtcMs,
    progress: progress ?? this.progress,
    failureCode: failureCode.present ? failureCode.value : this.failureCode,
  );
  TranscriptRun copyWithCompanion(TranscriptRunsCompanion data) {
    return TranscriptRun(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      rowRevision: data.rowRevision.present
          ? data.rowRevision.value
          : this.rowRevision,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      engineId: data.engineId.present ? data.engineId.value : this.engineId,
      engineVersion: data.engineVersion.present
          ? data.engineVersion.value
          : this.engineVersion,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      modelVersion: data.modelVersion.present
          ? data.modelVersion.value
          : this.modelVersion,
      modelSha256: data.modelSha256.present
          ? data.modelSha256.value
          : this.modelSha256,
      parametersJson: data.parametersJson.present
          ? data.parametersJson.value
          : this.parametersJson,
      runState: data.runState.present ? data.runState.value : this.runState,
      startedAtUtcMs: data.startedAtUtcMs.present
          ? data.startedAtUtcMs.value
          : this.startedAtUtcMs,
      endedAtUtcMs: data.endedAtUtcMs.present
          ? data.endedAtUtcMs.value
          : this.endedAtUtcMs,
      progress: data.progress.present ? data.progress.value : this.progress,
      failureCode: data.failureCode.present
          ? data.failureCode.value
          : this.failureCode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptRun(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('meetingId: $meetingId, ')
          ..write('engineId: $engineId, ')
          ..write('engineVersion: $engineVersion, ')
          ..write('modelId: $modelId, ')
          ..write('modelVersion: $modelVersion, ')
          ..write('modelSha256: $modelSha256, ')
          ..write('parametersJson: $parametersJson, ')
          ..write('runState: $runState, ')
          ..write('startedAtUtcMs: $startedAtUtcMs, ')
          ..write('endedAtUtcMs: $endedAtUtcMs, ')
          ..write('progress: $progress, ')
          ..write('failureCode: $failureCode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    meetingId,
    engineId,
    engineVersion,
    modelId,
    modelVersion,
    modelSha256,
    parametersJson,
    runState,
    startedAtUtcMs,
    endedAtUtcMs,
    progress,
    failureCode,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TranscriptRun &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.rowRevision == this.rowRevision &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt &&
          other.meetingId == this.meetingId &&
          other.engineId == this.engineId &&
          other.engineVersion == this.engineVersion &&
          other.modelId == this.modelId &&
          other.modelVersion == this.modelVersion &&
          other.modelSha256 == this.modelSha256 &&
          other.parametersJson == this.parametersJson &&
          other.runState == this.runState &&
          other.startedAtUtcMs == this.startedAtUtcMs &&
          other.endedAtUtcMs == this.endedAtUtcMs &&
          other.progress == this.progress &&
          other.failureCode == this.failureCode);
}

class TranscriptRunsCompanion extends UpdateCompanion<TranscriptRun> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowRevision;
  final Value<bool> isDeleted;
  final Value<int?> deletedAt;
  final Value<String> meetingId;
  final Value<String> engineId;
  final Value<String> engineVersion;
  final Value<String> modelId;
  final Value<String> modelVersion;
  final Value<String> modelSha256;
  final Value<String> parametersJson;
  final Value<String> runState;
  final Value<int?> startedAtUtcMs;
  final Value<int?> endedAtUtcMs;
  final Value<double> progress;
  final Value<String?> failureCode;
  final Value<int> rowid;
  const TranscriptRunsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.engineId = const Value.absent(),
    this.engineVersion = const Value.absent(),
    this.modelId = const Value.absent(),
    this.modelVersion = const Value.absent(),
    this.modelSha256 = const Value.absent(),
    this.parametersJson = const Value.absent(),
    this.runState = const Value.absent(),
    this.startedAtUtcMs = const Value.absent(),
    this.endedAtUtcMs = const Value.absent(),
    this.progress = const Value.absent(),
    this.failureCode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TranscriptRunsCompanion.insert({
    required String id,
    required int createdAt,
    required int updatedAt,
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String meetingId,
    required String engineId,
    required String engineVersion,
    required String modelId,
    required String modelVersion,
    required String modelSha256,
    required String parametersJson,
    required String runState,
    this.startedAtUtcMs = const Value.absent(),
    this.endedAtUtcMs = const Value.absent(),
    this.progress = const Value.absent(),
    this.failureCode = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       meetingId = Value(meetingId),
       engineId = Value(engineId),
       engineVersion = Value(engineVersion),
       modelId = Value(modelId),
       modelVersion = Value(modelVersion),
       modelSha256 = Value(modelSha256),
       parametersJson = Value(parametersJson),
       runState = Value(runState);
  static Insertable<TranscriptRun> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowRevision,
    Expression<bool>? isDeleted,
    Expression<int>? deletedAt,
    Expression<String>? meetingId,
    Expression<String>? engineId,
    Expression<String>? engineVersion,
    Expression<String>? modelId,
    Expression<String>? modelVersion,
    Expression<String>? modelSha256,
    Expression<String>? parametersJson,
    Expression<String>? runState,
    Expression<int>? startedAtUtcMs,
    Expression<int>? endedAtUtcMs,
    Expression<double>? progress,
    Expression<String>? failureCode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowRevision != null) 'row_revision': rowRevision,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (meetingId != null) 'meeting_id': meetingId,
      if (engineId != null) 'engine_id': engineId,
      if (engineVersion != null) 'engine_version': engineVersion,
      if (modelId != null) 'model_id': modelId,
      if (modelVersion != null) 'model_version': modelVersion,
      if (modelSha256 != null) 'model_sha256': modelSha256,
      if (parametersJson != null) 'parameters_json': parametersJson,
      if (runState != null) 'run_state': runState,
      if (startedAtUtcMs != null) 'started_at_utc_ms': startedAtUtcMs,
      if (endedAtUtcMs != null) 'ended_at_utc_ms': endedAtUtcMs,
      if (progress != null) 'progress': progress,
      if (failureCode != null) 'failure_code': failureCode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TranscriptRunsCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowRevision,
    Value<bool>? isDeleted,
    Value<int?>? deletedAt,
    Value<String>? meetingId,
    Value<String>? engineId,
    Value<String>? engineVersion,
    Value<String>? modelId,
    Value<String>? modelVersion,
    Value<String>? modelSha256,
    Value<String>? parametersJson,
    Value<String>? runState,
    Value<int?>? startedAtUtcMs,
    Value<int?>? endedAtUtcMs,
    Value<double>? progress,
    Value<String?>? failureCode,
    Value<int>? rowid,
  }) {
    return TranscriptRunsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowRevision: rowRevision ?? this.rowRevision,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      meetingId: meetingId ?? this.meetingId,
      engineId: engineId ?? this.engineId,
      engineVersion: engineVersion ?? this.engineVersion,
      modelId: modelId ?? this.modelId,
      modelVersion: modelVersion ?? this.modelVersion,
      modelSha256: modelSha256 ?? this.modelSha256,
      parametersJson: parametersJson ?? this.parametersJson,
      runState: runState ?? this.runState,
      startedAtUtcMs: startedAtUtcMs ?? this.startedAtUtcMs,
      endedAtUtcMs: endedAtUtcMs ?? this.endedAtUtcMs,
      progress: progress ?? this.progress,
      failureCode: failureCode ?? this.failureCode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowRevision.present) {
      map['row_revision'] = Variable<int>(rowRevision.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (meetingId.present) {
      map['meeting_id'] = Variable<String>(meetingId.value);
    }
    if (engineId.present) {
      map['engine_id'] = Variable<String>(engineId.value);
    }
    if (engineVersion.present) {
      map['engine_version'] = Variable<String>(engineVersion.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (modelVersion.present) {
      map['model_version'] = Variable<String>(modelVersion.value);
    }
    if (modelSha256.present) {
      map['model_sha256'] = Variable<String>(modelSha256.value);
    }
    if (parametersJson.present) {
      map['parameters_json'] = Variable<String>(parametersJson.value);
    }
    if (runState.present) {
      map['run_state'] = Variable<String>(runState.value);
    }
    if (startedAtUtcMs.present) {
      map['started_at_utc_ms'] = Variable<int>(startedAtUtcMs.value);
    }
    if (endedAtUtcMs.present) {
      map['ended_at_utc_ms'] = Variable<int>(endedAtUtcMs.value);
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (failureCode.present) {
      map['failure_code'] = Variable<String>(failureCode.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptRunsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('meetingId: $meetingId, ')
          ..write('engineId: $engineId, ')
          ..write('engineVersion: $engineVersion, ')
          ..write('modelId: $modelId, ')
          ..write('modelVersion: $modelVersion, ')
          ..write('modelSha256: $modelSha256, ')
          ..write('parametersJson: $parametersJson, ')
          ..write('runState: $runState, ')
          ..write('startedAtUtcMs: $startedAtUtcMs, ')
          ..write('endedAtUtcMs: $endedAtUtcMs, ')
          ..write('progress: $progress, ')
          ..write('failureCode: $failureCode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MeetingTranscriptSelectionsTable extends MeetingTranscriptSelections
    with
        TableInfo<
          $MeetingTranscriptSelectionsTable,
          MeetingTranscriptSelection
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MeetingTranscriptSelectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (created_at >= 0)',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (updated_at >= created_at)',
  );
  static const VerificationMeta _rowRevisionMeta = const VerificationMeta(
    'rowRevision',
  );
  @override
  late final GeneratedColumn<int> rowRevision = GeneratedColumn<int>(
    'row_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (row_revision >= 0)',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT 0 CHECK ((is_deleted = 0 AND deleted_at IS NULL) OR (is_deleted = 1 AND deleted_at IS NOT NULL))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NULL CHECK (deleted_at IS NULL OR deleted_at >= 0)',
  );
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<String> meetingId = GeneratedColumn<String>(
    'meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meetings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _transcriptRunIdMeta = const VerificationMeta(
    'transcriptRunId',
  );
  @override
  late final GeneratedColumn<String> transcriptRunId = GeneratedColumn<String>(
    'transcript_run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES transcript_runs (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    meetingId,
    transcriptRunId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meeting_transcript_selections';
  @override
  VerificationContext validateIntegrity(
    Insertable<MeetingTranscriptSelection> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('row_revision')) {
      context.handle(
        _rowRevisionMeta,
        rowRevision.isAcceptableOrUnknown(
          data['row_revision']!,
          _rowRevisionMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('transcript_run_id')) {
      context.handle(
        _transcriptRunIdMeta,
        transcriptRunId.isAcceptableOrUnknown(
          data['transcript_run_id']!,
          _transcriptRunIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transcriptRunIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MeetingTranscriptSelection map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MeetingTranscriptSelection(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      rowRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_revision'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      )!,
      transcriptRunId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript_run_id'],
      )!,
    );
  }

  @override
  $MeetingTranscriptSelectionsTable createAlias(String alias) {
    return $MeetingTranscriptSelectionsTable(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
}

class MeetingTranscriptSelection extends DataClass
    implements Insertable<MeetingTranscriptSelection> {
  /// Stable UUID-style identifier.
  final String id;

  /// UTC creation instant in epoch milliseconds.
  final int createdAt;

  /// UTC last-update instant in epoch milliseconds.
  final int updatedAt;

  /// Monotonic row revision used by restore conflict handling.
  final int rowRevision;

  /// Whether this row is hidden by a soft delete.
  final bool isDeleted;

  /// UTC soft-delete instant in epoch milliseconds.
  final int? deletedAt;

  /// Meeting whose current transcript is selected.
  final String meetingId;

  /// Explicitly selected transcript run.
  final String transcriptRunId;
  const MeetingTranscriptSelection({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.rowRevision,
    required this.isDeleted,
    this.deletedAt,
    required this.meetingId,
    required this.transcriptRunId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['row_revision'] = Variable<int>(rowRevision);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['meeting_id'] = Variable<String>(meetingId);
    map['transcript_run_id'] = Variable<String>(transcriptRunId);
    return map;
  }

  MeetingTranscriptSelectionsCompanion toCompanion(bool nullToAbsent) {
    return MeetingTranscriptSelectionsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      rowRevision: Value(rowRevision),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      meetingId: Value(meetingId),
      transcriptRunId: Value(transcriptRunId),
    );
  }

  factory MeetingTranscriptSelection.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MeetingTranscriptSelection(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      rowRevision: serializer.fromJson<int>(json['rowRevision']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      meetingId: serializer.fromJson<String>(json['meetingId']),
      transcriptRunId: serializer.fromJson<String>(json['transcriptRunId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'rowRevision': serializer.toJson<int>(rowRevision),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'meetingId': serializer.toJson<String>(meetingId),
      'transcriptRunId': serializer.toJson<String>(transcriptRunId),
    };
  }

  MeetingTranscriptSelection copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    int? rowRevision,
    bool? isDeleted,
    Value<int?> deletedAt = const Value.absent(),
    String? meetingId,
    String? transcriptRunId,
  }) => MeetingTranscriptSelection(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    rowRevision: rowRevision ?? this.rowRevision,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    meetingId: meetingId ?? this.meetingId,
    transcriptRunId: transcriptRunId ?? this.transcriptRunId,
  );
  MeetingTranscriptSelection copyWithCompanion(
    MeetingTranscriptSelectionsCompanion data,
  ) {
    return MeetingTranscriptSelection(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      rowRevision: data.rowRevision.present
          ? data.rowRevision.value
          : this.rowRevision,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      transcriptRunId: data.transcriptRunId.present
          ? data.transcriptRunId.value
          : this.transcriptRunId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MeetingTranscriptSelection(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('meetingId: $meetingId, ')
          ..write('transcriptRunId: $transcriptRunId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    meetingId,
    transcriptRunId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MeetingTranscriptSelection &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.rowRevision == this.rowRevision &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt &&
          other.meetingId == this.meetingId &&
          other.transcriptRunId == this.transcriptRunId);
}

class MeetingTranscriptSelectionsCompanion
    extends UpdateCompanion<MeetingTranscriptSelection> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowRevision;
  final Value<bool> isDeleted;
  final Value<int?> deletedAt;
  final Value<String> meetingId;
  final Value<String> transcriptRunId;
  final Value<int> rowid;
  const MeetingTranscriptSelectionsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.transcriptRunId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MeetingTranscriptSelectionsCompanion.insert({
    required String id,
    required int createdAt,
    required int updatedAt,
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String meetingId,
    required String transcriptRunId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       meetingId = Value(meetingId),
       transcriptRunId = Value(transcriptRunId);
  static Insertable<MeetingTranscriptSelection> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowRevision,
    Expression<bool>? isDeleted,
    Expression<int>? deletedAt,
    Expression<String>? meetingId,
    Expression<String>? transcriptRunId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowRevision != null) 'row_revision': rowRevision,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (meetingId != null) 'meeting_id': meetingId,
      if (transcriptRunId != null) 'transcript_run_id': transcriptRunId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MeetingTranscriptSelectionsCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowRevision,
    Value<bool>? isDeleted,
    Value<int?>? deletedAt,
    Value<String>? meetingId,
    Value<String>? transcriptRunId,
    Value<int>? rowid,
  }) {
    return MeetingTranscriptSelectionsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowRevision: rowRevision ?? this.rowRevision,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      meetingId: meetingId ?? this.meetingId,
      transcriptRunId: transcriptRunId ?? this.transcriptRunId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowRevision.present) {
      map['row_revision'] = Variable<int>(rowRevision.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (meetingId.present) {
      map['meeting_id'] = Variable<String>(meetingId.value);
    }
    if (transcriptRunId.present) {
      map['transcript_run_id'] = Variable<String>(transcriptRunId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MeetingTranscriptSelectionsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('meetingId: $meetingId, ')
          ..write('transcriptRunId: $transcriptRunId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DiarizationRunsTable extends DiarizationRuns
    with TableInfo<$DiarizationRunsTable, DiarizationRun> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiarizationRunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (created_at >= 0)',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (updated_at >= created_at)',
  );
  static const VerificationMeta _rowRevisionMeta = const VerificationMeta(
    'rowRevision',
  );
  @override
  late final GeneratedColumn<int> rowRevision = GeneratedColumn<int>(
    'row_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (row_revision >= 0)',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT 0 CHECK ((is_deleted = 0 AND deleted_at IS NULL) OR (is_deleted = 1 AND deleted_at IS NOT NULL))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NULL CHECK (deleted_at IS NULL OR deleted_at >= 0)',
  );
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<String> meetingId = GeneratedColumn<String>(
    'meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meetings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _engineIdMeta = const VerificationMeta(
    'engineId',
  );
  @override
  late final GeneratedColumn<String> engineId = GeneratedColumn<String>(
    'engine_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _engineVersionMeta = const VerificationMeta(
    'engineVersion',
  );
  @override
  late final GeneratedColumn<String> engineVersion = GeneratedColumn<String>(
    'engine_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES model_manifests (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _modelVersionMeta = const VerificationMeta(
    'modelVersion',
  );
  @override
  late final GeneratedColumn<String> modelVersion = GeneratedColumn<String>(
    'model_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelSha256Meta = const VerificationMeta(
    'modelSha256',
  );
  @override
  late final GeneratedColumn<String> modelSha256 = GeneratedColumn<String>(
    'model_sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parametersJsonMeta = const VerificationMeta(
    'parametersJson',
  );
  @override
  late final GeneratedColumn<String> parametersJson = GeneratedColumn<String>(
    'parameters_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runStateMeta = const VerificationMeta(
    'runState',
  );
  @override
  late final GeneratedColumn<String> runState = GeneratedColumn<String>(
    'run_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtUtcMsMeta = const VerificationMeta(
    'startedAtUtcMs',
  );
  @override
  late final GeneratedColumn<int> startedAtUtcMs = GeneratedColumn<int>(
    'started_at_utc_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endedAtUtcMsMeta = const VerificationMeta(
    'endedAtUtcMs',
  );
  @override
  late final GeneratedColumn<int> endedAtUtcMs = GeneratedColumn<int>(
    'ended_at_utc_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant<double>(0),
  );
  static const VerificationMeta _failureCodeMeta = const VerificationMeta(
    'failureCode',
  );
  @override
  late final GeneratedColumn<String> failureCode = GeneratedColumn<String>(
    'failure_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    meetingId,
    engineId,
    engineVersion,
    modelId,
    modelVersion,
    modelSha256,
    parametersJson,
    runState,
    startedAtUtcMs,
    endedAtUtcMs,
    progress,
    failureCode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'diarization_runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiarizationRun> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('row_revision')) {
      context.handle(
        _rowRevisionMeta,
        rowRevision.isAcceptableOrUnknown(
          data['row_revision']!,
          _rowRevisionMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('engine_id')) {
      context.handle(
        _engineIdMeta,
        engineId.isAcceptableOrUnknown(data['engine_id']!, _engineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_engineIdMeta);
    }
    if (data.containsKey('engine_version')) {
      context.handle(
        _engineVersionMeta,
        engineVersion.isAcceptableOrUnknown(
          data['engine_version']!,
          _engineVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_engineVersionMeta);
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_modelIdMeta);
    }
    if (data.containsKey('model_version')) {
      context.handle(
        _modelVersionMeta,
        modelVersion.isAcceptableOrUnknown(
          data['model_version']!,
          _modelVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_modelVersionMeta);
    }
    if (data.containsKey('model_sha256')) {
      context.handle(
        _modelSha256Meta,
        modelSha256.isAcceptableOrUnknown(
          data['model_sha256']!,
          _modelSha256Meta,
        ),
      );
    } else if (isInserting) {
      context.missing(_modelSha256Meta);
    }
    if (data.containsKey('parameters_json')) {
      context.handle(
        _parametersJsonMeta,
        parametersJson.isAcceptableOrUnknown(
          data['parameters_json']!,
          _parametersJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_parametersJsonMeta);
    }
    if (data.containsKey('run_state')) {
      context.handle(
        _runStateMeta,
        runState.isAcceptableOrUnknown(data['run_state']!, _runStateMeta),
      );
    } else if (isInserting) {
      context.missing(_runStateMeta);
    }
    if (data.containsKey('started_at_utc_ms')) {
      context.handle(
        _startedAtUtcMsMeta,
        startedAtUtcMs.isAcceptableOrUnknown(
          data['started_at_utc_ms']!,
          _startedAtUtcMsMeta,
        ),
      );
    }
    if (data.containsKey('ended_at_utc_ms')) {
      context.handle(
        _endedAtUtcMsMeta,
        endedAtUtcMs.isAcceptableOrUnknown(
          data['ended_at_utc_ms']!,
          _endedAtUtcMsMeta,
        ),
      );
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('failure_code')) {
      context.handle(
        _failureCodeMeta,
        failureCode.isAcceptableOrUnknown(
          data['failure_code']!,
          _failureCodeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DiarizationRun map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiarizationRun(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      rowRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_revision'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      )!,
      engineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}engine_id'],
      )!,
      engineVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}engine_version'],
      )!,
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      )!,
      modelVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_version'],
      )!,
      modelSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_sha256'],
      )!,
      parametersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parameters_json'],
      )!,
      runState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_state'],
      )!,
      startedAtUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at_utc_ms'],
      ),
      endedAtUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ended_at_utc_ms'],
      ),
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress'],
      )!,
      failureCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failure_code'],
      ),
    );
  }

  @override
  $DiarizationRunsTable createAlias(String alias) {
    return $DiarizationRunsTable(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
}

class DiarizationRun extends DataClass implements Insertable<DiarizationRun> {
  /// Stable UUID-style identifier.
  final String id;

  /// UTC creation instant in epoch milliseconds.
  final int createdAt;

  /// UTC last-update instant in epoch milliseconds.
  final int updatedAt;

  /// Monotonic row revision used by restore conflict handling.
  final int rowRevision;

  /// Whether this row is hidden by a soft delete.
  final bool isDeleted;

  /// UTC soft-delete instant in epoch milliseconds.
  final int? deletedAt;

  /// Owning meeting.
  final String meetingId;

  /// Stable inference-engine identifier.
  final String engineId;

  /// Exact inference-engine version.
  final String engineVersion;

  /// Bundled model manifest used by the run.
  final String modelId;

  /// Exact model version copied into immutable run provenance.
  final String modelVersion;

  /// Model digest copied into immutable run provenance.
  final String modelSha256;

  /// Canonical JSON of the actual inference parameters.
  final String parametersJson;

  /// Queued, running, completed, or failed.
  final String runState;

  /// UTC start instant when work has begun.
  final int? startedAtUtcMs;

  /// UTC terminal instant for completed or failed work.
  final int? endedAtUtcMs;

  /// Normalized completion fraction.
  final double progress;

  /// Structured privacy-safe terminal failure code.
  final String? failureCode;
  const DiarizationRun({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.rowRevision,
    required this.isDeleted,
    this.deletedAt,
    required this.meetingId,
    required this.engineId,
    required this.engineVersion,
    required this.modelId,
    required this.modelVersion,
    required this.modelSha256,
    required this.parametersJson,
    required this.runState,
    this.startedAtUtcMs,
    this.endedAtUtcMs,
    required this.progress,
    this.failureCode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['row_revision'] = Variable<int>(rowRevision);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['meeting_id'] = Variable<String>(meetingId);
    map['engine_id'] = Variable<String>(engineId);
    map['engine_version'] = Variable<String>(engineVersion);
    map['model_id'] = Variable<String>(modelId);
    map['model_version'] = Variable<String>(modelVersion);
    map['model_sha256'] = Variable<String>(modelSha256);
    map['parameters_json'] = Variable<String>(parametersJson);
    map['run_state'] = Variable<String>(runState);
    if (!nullToAbsent || startedAtUtcMs != null) {
      map['started_at_utc_ms'] = Variable<int>(startedAtUtcMs);
    }
    if (!nullToAbsent || endedAtUtcMs != null) {
      map['ended_at_utc_ms'] = Variable<int>(endedAtUtcMs);
    }
    map['progress'] = Variable<double>(progress);
    if (!nullToAbsent || failureCode != null) {
      map['failure_code'] = Variable<String>(failureCode);
    }
    return map;
  }

  DiarizationRunsCompanion toCompanion(bool nullToAbsent) {
    return DiarizationRunsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      rowRevision: Value(rowRevision),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      meetingId: Value(meetingId),
      engineId: Value(engineId),
      engineVersion: Value(engineVersion),
      modelId: Value(modelId),
      modelVersion: Value(modelVersion),
      modelSha256: Value(modelSha256),
      parametersJson: Value(parametersJson),
      runState: Value(runState),
      startedAtUtcMs: startedAtUtcMs == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAtUtcMs),
      endedAtUtcMs: endedAtUtcMs == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAtUtcMs),
      progress: Value(progress),
      failureCode: failureCode == null && nullToAbsent
          ? const Value.absent()
          : Value(failureCode),
    );
  }

  factory DiarizationRun.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiarizationRun(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      rowRevision: serializer.fromJson<int>(json['rowRevision']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      meetingId: serializer.fromJson<String>(json['meetingId']),
      engineId: serializer.fromJson<String>(json['engineId']),
      engineVersion: serializer.fromJson<String>(json['engineVersion']),
      modelId: serializer.fromJson<String>(json['modelId']),
      modelVersion: serializer.fromJson<String>(json['modelVersion']),
      modelSha256: serializer.fromJson<String>(json['modelSha256']),
      parametersJson: serializer.fromJson<String>(json['parametersJson']),
      runState: serializer.fromJson<String>(json['runState']),
      startedAtUtcMs: serializer.fromJson<int?>(json['startedAtUtcMs']),
      endedAtUtcMs: serializer.fromJson<int?>(json['endedAtUtcMs']),
      progress: serializer.fromJson<double>(json['progress']),
      failureCode: serializer.fromJson<String?>(json['failureCode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'rowRevision': serializer.toJson<int>(rowRevision),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'meetingId': serializer.toJson<String>(meetingId),
      'engineId': serializer.toJson<String>(engineId),
      'engineVersion': serializer.toJson<String>(engineVersion),
      'modelId': serializer.toJson<String>(modelId),
      'modelVersion': serializer.toJson<String>(modelVersion),
      'modelSha256': serializer.toJson<String>(modelSha256),
      'parametersJson': serializer.toJson<String>(parametersJson),
      'runState': serializer.toJson<String>(runState),
      'startedAtUtcMs': serializer.toJson<int?>(startedAtUtcMs),
      'endedAtUtcMs': serializer.toJson<int?>(endedAtUtcMs),
      'progress': serializer.toJson<double>(progress),
      'failureCode': serializer.toJson<String?>(failureCode),
    };
  }

  DiarizationRun copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    int? rowRevision,
    bool? isDeleted,
    Value<int?> deletedAt = const Value.absent(),
    String? meetingId,
    String? engineId,
    String? engineVersion,
    String? modelId,
    String? modelVersion,
    String? modelSha256,
    String? parametersJson,
    String? runState,
    Value<int?> startedAtUtcMs = const Value.absent(),
    Value<int?> endedAtUtcMs = const Value.absent(),
    double? progress,
    Value<String?> failureCode = const Value.absent(),
  }) => DiarizationRun(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    rowRevision: rowRevision ?? this.rowRevision,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    meetingId: meetingId ?? this.meetingId,
    engineId: engineId ?? this.engineId,
    engineVersion: engineVersion ?? this.engineVersion,
    modelId: modelId ?? this.modelId,
    modelVersion: modelVersion ?? this.modelVersion,
    modelSha256: modelSha256 ?? this.modelSha256,
    parametersJson: parametersJson ?? this.parametersJson,
    runState: runState ?? this.runState,
    startedAtUtcMs: startedAtUtcMs.present
        ? startedAtUtcMs.value
        : this.startedAtUtcMs,
    endedAtUtcMs: endedAtUtcMs.present ? endedAtUtcMs.value : this.endedAtUtcMs,
    progress: progress ?? this.progress,
    failureCode: failureCode.present ? failureCode.value : this.failureCode,
  );
  DiarizationRun copyWithCompanion(DiarizationRunsCompanion data) {
    return DiarizationRun(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      rowRevision: data.rowRevision.present
          ? data.rowRevision.value
          : this.rowRevision,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      engineId: data.engineId.present ? data.engineId.value : this.engineId,
      engineVersion: data.engineVersion.present
          ? data.engineVersion.value
          : this.engineVersion,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      modelVersion: data.modelVersion.present
          ? data.modelVersion.value
          : this.modelVersion,
      modelSha256: data.modelSha256.present
          ? data.modelSha256.value
          : this.modelSha256,
      parametersJson: data.parametersJson.present
          ? data.parametersJson.value
          : this.parametersJson,
      runState: data.runState.present ? data.runState.value : this.runState,
      startedAtUtcMs: data.startedAtUtcMs.present
          ? data.startedAtUtcMs.value
          : this.startedAtUtcMs,
      endedAtUtcMs: data.endedAtUtcMs.present
          ? data.endedAtUtcMs.value
          : this.endedAtUtcMs,
      progress: data.progress.present ? data.progress.value : this.progress,
      failureCode: data.failureCode.present
          ? data.failureCode.value
          : this.failureCode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiarizationRun(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('meetingId: $meetingId, ')
          ..write('engineId: $engineId, ')
          ..write('engineVersion: $engineVersion, ')
          ..write('modelId: $modelId, ')
          ..write('modelVersion: $modelVersion, ')
          ..write('modelSha256: $modelSha256, ')
          ..write('parametersJson: $parametersJson, ')
          ..write('runState: $runState, ')
          ..write('startedAtUtcMs: $startedAtUtcMs, ')
          ..write('endedAtUtcMs: $endedAtUtcMs, ')
          ..write('progress: $progress, ')
          ..write('failureCode: $failureCode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    meetingId,
    engineId,
    engineVersion,
    modelId,
    modelVersion,
    modelSha256,
    parametersJson,
    runState,
    startedAtUtcMs,
    endedAtUtcMs,
    progress,
    failureCode,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiarizationRun &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.rowRevision == this.rowRevision &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt &&
          other.meetingId == this.meetingId &&
          other.engineId == this.engineId &&
          other.engineVersion == this.engineVersion &&
          other.modelId == this.modelId &&
          other.modelVersion == this.modelVersion &&
          other.modelSha256 == this.modelSha256 &&
          other.parametersJson == this.parametersJson &&
          other.runState == this.runState &&
          other.startedAtUtcMs == this.startedAtUtcMs &&
          other.endedAtUtcMs == this.endedAtUtcMs &&
          other.progress == this.progress &&
          other.failureCode == this.failureCode);
}

class DiarizationRunsCompanion extends UpdateCompanion<DiarizationRun> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowRevision;
  final Value<bool> isDeleted;
  final Value<int?> deletedAt;
  final Value<String> meetingId;
  final Value<String> engineId;
  final Value<String> engineVersion;
  final Value<String> modelId;
  final Value<String> modelVersion;
  final Value<String> modelSha256;
  final Value<String> parametersJson;
  final Value<String> runState;
  final Value<int?> startedAtUtcMs;
  final Value<int?> endedAtUtcMs;
  final Value<double> progress;
  final Value<String?> failureCode;
  final Value<int> rowid;
  const DiarizationRunsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.engineId = const Value.absent(),
    this.engineVersion = const Value.absent(),
    this.modelId = const Value.absent(),
    this.modelVersion = const Value.absent(),
    this.modelSha256 = const Value.absent(),
    this.parametersJson = const Value.absent(),
    this.runState = const Value.absent(),
    this.startedAtUtcMs = const Value.absent(),
    this.endedAtUtcMs = const Value.absent(),
    this.progress = const Value.absent(),
    this.failureCode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DiarizationRunsCompanion.insert({
    required String id,
    required int createdAt,
    required int updatedAt,
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String meetingId,
    required String engineId,
    required String engineVersion,
    required String modelId,
    required String modelVersion,
    required String modelSha256,
    required String parametersJson,
    required String runState,
    this.startedAtUtcMs = const Value.absent(),
    this.endedAtUtcMs = const Value.absent(),
    this.progress = const Value.absent(),
    this.failureCode = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       meetingId = Value(meetingId),
       engineId = Value(engineId),
       engineVersion = Value(engineVersion),
       modelId = Value(modelId),
       modelVersion = Value(modelVersion),
       modelSha256 = Value(modelSha256),
       parametersJson = Value(parametersJson),
       runState = Value(runState);
  static Insertable<DiarizationRun> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowRevision,
    Expression<bool>? isDeleted,
    Expression<int>? deletedAt,
    Expression<String>? meetingId,
    Expression<String>? engineId,
    Expression<String>? engineVersion,
    Expression<String>? modelId,
    Expression<String>? modelVersion,
    Expression<String>? modelSha256,
    Expression<String>? parametersJson,
    Expression<String>? runState,
    Expression<int>? startedAtUtcMs,
    Expression<int>? endedAtUtcMs,
    Expression<double>? progress,
    Expression<String>? failureCode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowRevision != null) 'row_revision': rowRevision,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (meetingId != null) 'meeting_id': meetingId,
      if (engineId != null) 'engine_id': engineId,
      if (engineVersion != null) 'engine_version': engineVersion,
      if (modelId != null) 'model_id': modelId,
      if (modelVersion != null) 'model_version': modelVersion,
      if (modelSha256 != null) 'model_sha256': modelSha256,
      if (parametersJson != null) 'parameters_json': parametersJson,
      if (runState != null) 'run_state': runState,
      if (startedAtUtcMs != null) 'started_at_utc_ms': startedAtUtcMs,
      if (endedAtUtcMs != null) 'ended_at_utc_ms': endedAtUtcMs,
      if (progress != null) 'progress': progress,
      if (failureCode != null) 'failure_code': failureCode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DiarizationRunsCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowRevision,
    Value<bool>? isDeleted,
    Value<int?>? deletedAt,
    Value<String>? meetingId,
    Value<String>? engineId,
    Value<String>? engineVersion,
    Value<String>? modelId,
    Value<String>? modelVersion,
    Value<String>? modelSha256,
    Value<String>? parametersJson,
    Value<String>? runState,
    Value<int?>? startedAtUtcMs,
    Value<int?>? endedAtUtcMs,
    Value<double>? progress,
    Value<String?>? failureCode,
    Value<int>? rowid,
  }) {
    return DiarizationRunsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowRevision: rowRevision ?? this.rowRevision,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      meetingId: meetingId ?? this.meetingId,
      engineId: engineId ?? this.engineId,
      engineVersion: engineVersion ?? this.engineVersion,
      modelId: modelId ?? this.modelId,
      modelVersion: modelVersion ?? this.modelVersion,
      modelSha256: modelSha256 ?? this.modelSha256,
      parametersJson: parametersJson ?? this.parametersJson,
      runState: runState ?? this.runState,
      startedAtUtcMs: startedAtUtcMs ?? this.startedAtUtcMs,
      endedAtUtcMs: endedAtUtcMs ?? this.endedAtUtcMs,
      progress: progress ?? this.progress,
      failureCode: failureCode ?? this.failureCode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowRevision.present) {
      map['row_revision'] = Variable<int>(rowRevision.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (meetingId.present) {
      map['meeting_id'] = Variable<String>(meetingId.value);
    }
    if (engineId.present) {
      map['engine_id'] = Variable<String>(engineId.value);
    }
    if (engineVersion.present) {
      map['engine_version'] = Variable<String>(engineVersion.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (modelVersion.present) {
      map['model_version'] = Variable<String>(modelVersion.value);
    }
    if (modelSha256.present) {
      map['model_sha256'] = Variable<String>(modelSha256.value);
    }
    if (parametersJson.present) {
      map['parameters_json'] = Variable<String>(parametersJson.value);
    }
    if (runState.present) {
      map['run_state'] = Variable<String>(runState.value);
    }
    if (startedAtUtcMs.present) {
      map['started_at_utc_ms'] = Variable<int>(startedAtUtcMs.value);
    }
    if (endedAtUtcMs.present) {
      map['ended_at_utc_ms'] = Variable<int>(endedAtUtcMs.value);
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (failureCode.present) {
      map['failure_code'] = Variable<String>(failureCode.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiarizationRunsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('meetingId: $meetingId, ')
          ..write('engineId: $engineId, ')
          ..write('engineVersion: $engineVersion, ')
          ..write('modelId: $modelId, ')
          ..write('modelVersion: $modelVersion, ')
          ..write('modelSha256: $modelSha256, ')
          ..write('parametersJson: $parametersJson, ')
          ..write('runState: $runState, ')
          ..write('startedAtUtcMs: $startedAtUtcMs, ')
          ..write('endedAtUtcMs: $endedAtUtcMs, ')
          ..write('progress: $progress, ')
          ..write('failureCode: $failureCode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SpeakersTable extends Speakers with TableInfo<$SpeakersTable, Speaker> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpeakersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (created_at >= 0)',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (updated_at >= created_at)',
  );
  static const VerificationMeta _rowRevisionMeta = const VerificationMeta(
    'rowRevision',
  );
  @override
  late final GeneratedColumn<int> rowRevision = GeneratedColumn<int>(
    'row_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (row_revision >= 0)',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT 0 CHECK ((is_deleted = 0 AND deleted_at IS NULL) OR (is_deleted = 1 AND deleted_at IS NOT NULL))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NULL CHECK (deleted_at IS NULL OR deleted_at >= 0)',
  );
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<String> meetingId = GeneratedColumn<String>(
    'meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meetings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _analysisRunIdMeta = const VerificationMeta(
    'analysisRunId',
  );
  @override
  late final GeneratedColumn<String> analysisRunId = GeneratedColumn<String>(
    'analysis_run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES diarization_runs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    meetingId,
    analysisRunId,
    label,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'speakers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Speaker> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('row_revision')) {
      context.handle(
        _rowRevisionMeta,
        rowRevision.isAcceptableOrUnknown(
          data['row_revision']!,
          _rowRevisionMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('analysis_run_id')) {
      context.handle(
        _analysisRunIdMeta,
        analysisRunId.isAcceptableOrUnknown(
          data['analysis_run_id']!,
          _analysisRunIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_analysisRunIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Speaker map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Speaker(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      rowRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_revision'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      )!,
      analysisRunId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}analysis_run_id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
    );
  }

  @override
  $SpeakersTable createAlias(String alias) {
    return $SpeakersTable(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
}

class Speaker extends DataClass implements Insertable<Speaker> {
  /// Stable UUID-style identifier.
  final String id;

  /// UTC creation instant in epoch milliseconds.
  final int createdAt;

  /// UTC last-update instant in epoch milliseconds.
  final int updatedAt;

  /// Monotonic row revision used by restore conflict handling.
  final int rowRevision;

  /// Whether this row is hidden by a soft delete.
  final bool isDeleted;

  /// UTC soft-delete instant in epoch milliseconds.
  final int? deletedAt;

  /// Owning meeting.
  final String meetingId;

  /// Owning diarization run.
  final String analysisRunId;

  /// User-visible meeting-local label.
  final String label;
  const Speaker({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.rowRevision,
    required this.isDeleted,
    this.deletedAt,
    required this.meetingId,
    required this.analysisRunId,
    required this.label,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['row_revision'] = Variable<int>(rowRevision);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['meeting_id'] = Variable<String>(meetingId);
    map['analysis_run_id'] = Variable<String>(analysisRunId);
    map['label'] = Variable<String>(label);
    return map;
  }

  SpeakersCompanion toCompanion(bool nullToAbsent) {
    return SpeakersCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      rowRevision: Value(rowRevision),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      meetingId: Value(meetingId),
      analysisRunId: Value(analysisRunId),
      label: Value(label),
    );
  }

  factory Speaker.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Speaker(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      rowRevision: serializer.fromJson<int>(json['rowRevision']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      meetingId: serializer.fromJson<String>(json['meetingId']),
      analysisRunId: serializer.fromJson<String>(json['analysisRunId']),
      label: serializer.fromJson<String>(json['label']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'rowRevision': serializer.toJson<int>(rowRevision),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'meetingId': serializer.toJson<String>(meetingId),
      'analysisRunId': serializer.toJson<String>(analysisRunId),
      'label': serializer.toJson<String>(label),
    };
  }

  Speaker copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    int? rowRevision,
    bool? isDeleted,
    Value<int?> deletedAt = const Value.absent(),
    String? meetingId,
    String? analysisRunId,
    String? label,
  }) => Speaker(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    rowRevision: rowRevision ?? this.rowRevision,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    meetingId: meetingId ?? this.meetingId,
    analysisRunId: analysisRunId ?? this.analysisRunId,
    label: label ?? this.label,
  );
  Speaker copyWithCompanion(SpeakersCompanion data) {
    return Speaker(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      rowRevision: data.rowRevision.present
          ? data.rowRevision.value
          : this.rowRevision,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      analysisRunId: data.analysisRunId.present
          ? data.analysisRunId.value
          : this.analysisRunId,
      label: data.label.present ? data.label.value : this.label,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Speaker(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('meetingId: $meetingId, ')
          ..write('analysisRunId: $analysisRunId, ')
          ..write('label: $label')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    meetingId,
    analysisRunId,
    label,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Speaker &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.rowRevision == this.rowRevision &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt &&
          other.meetingId == this.meetingId &&
          other.analysisRunId == this.analysisRunId &&
          other.label == this.label);
}

class SpeakersCompanion extends UpdateCompanion<Speaker> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowRevision;
  final Value<bool> isDeleted;
  final Value<int?> deletedAt;
  final Value<String> meetingId;
  final Value<String> analysisRunId;
  final Value<String> label;
  final Value<int> rowid;
  const SpeakersCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.analysisRunId = const Value.absent(),
    this.label = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SpeakersCompanion.insert({
    required String id,
    required int createdAt,
    required int updatedAt,
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String meetingId,
    required String analysisRunId,
    required String label,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       meetingId = Value(meetingId),
       analysisRunId = Value(analysisRunId),
       label = Value(label);
  static Insertable<Speaker> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowRevision,
    Expression<bool>? isDeleted,
    Expression<int>? deletedAt,
    Expression<String>? meetingId,
    Expression<String>? analysisRunId,
    Expression<String>? label,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowRevision != null) 'row_revision': rowRevision,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (meetingId != null) 'meeting_id': meetingId,
      if (analysisRunId != null) 'analysis_run_id': analysisRunId,
      if (label != null) 'label': label,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SpeakersCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowRevision,
    Value<bool>? isDeleted,
    Value<int?>? deletedAt,
    Value<String>? meetingId,
    Value<String>? analysisRunId,
    Value<String>? label,
    Value<int>? rowid,
  }) {
    return SpeakersCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowRevision: rowRevision ?? this.rowRevision,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      meetingId: meetingId ?? this.meetingId,
      analysisRunId: analysisRunId ?? this.analysisRunId,
      label: label ?? this.label,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowRevision.present) {
      map['row_revision'] = Variable<int>(rowRevision.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (meetingId.present) {
      map['meeting_id'] = Variable<String>(meetingId.value);
    }
    if (analysisRunId.present) {
      map['analysis_run_id'] = Variable<String>(analysisRunId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpeakersCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('meetingId: $meetingId, ')
          ..write('analysisRunId: $analysisRunId, ')
          ..write('label: $label, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TranscriptSegmentsTable extends TranscriptSegments
    with TableInfo<$TranscriptSegmentsTable, TranscriptSegment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TranscriptSegmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (created_at >= 0)',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (updated_at >= created_at)',
  );
  static const VerificationMeta _rowRevisionMeta = const VerificationMeta(
    'rowRevision',
  );
  @override
  late final GeneratedColumn<int> rowRevision = GeneratedColumn<int>(
    'row_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (row_revision >= 0)',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT 0 CHECK ((is_deleted = 0 AND deleted_at IS NULL) OR (is_deleted = 1 AND deleted_at IS NOT NULL))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NULL CHECK (deleted_at IS NULL OR deleted_at >= 0)',
  );
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<String> meetingId = GeneratedColumn<String>(
    'meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meetings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _transcriptRunIdMeta = const VerificationMeta(
    'transcriptRunId',
  );
  @override
  late final GeneratedColumn<String> transcriptRunId = GeneratedColumn<String>(
    'transcript_run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES transcript_runs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _startUsMeta = const VerificationMeta(
    'startUs',
  );
  @override
  late final GeneratedColumn<int> startUs = GeneratedColumn<int>(
    'start_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endUsMeta = const VerificationMeta('endUs');
  @override
  late final GeneratedColumn<int> endUs = GeneratedColumn<int>(
    'end_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawModelTextMeta = const VerificationMeta(
    'rawModelText',
  );
  @override
  late final GeneratedColumn<String> rawModelText = GeneratedColumn<String>(
    'raw_model_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayedTextMeta = const VerificationMeta(
    'displayedText',
  );
  @override
  late final GeneratedColumn<String> displayedText = GeneratedColumn<String>(
    'displayed_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionStateMeta = const VerificationMeta(
    'revisionState',
  );
  @override
  late final GeneratedColumn<String> revisionState = GeneratedColumn<String>(
    'revision_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _speakerIdMeta = const VerificationMeta(
    'speakerId',
  );
  @override
  late final GeneratedColumn<String> speakerId = GeneratedColumn<String>(
    'speaker_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _speakerMeetingIdMeta = const VerificationMeta(
    'speakerMeetingId',
  );
  @override
  late final GeneratedColumn<String> speakerMeetingId = GeneratedColumn<String>(
    'speaker_meeting_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    meetingId,
    transcriptRunId,
    startUs,
    endUs,
    rawModelText,
    displayedText,
    revisionState,
    speakerId,
    speakerMeetingId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transcript_segments';
  @override
  VerificationContext validateIntegrity(
    Insertable<TranscriptSegment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('row_revision')) {
      context.handle(
        _rowRevisionMeta,
        rowRevision.isAcceptableOrUnknown(
          data['row_revision']!,
          _rowRevisionMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('transcript_run_id')) {
      context.handle(
        _transcriptRunIdMeta,
        transcriptRunId.isAcceptableOrUnknown(
          data['transcript_run_id']!,
          _transcriptRunIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transcriptRunIdMeta);
    }
    if (data.containsKey('start_us')) {
      context.handle(
        _startUsMeta,
        startUs.isAcceptableOrUnknown(data['start_us']!, _startUsMeta),
      );
    } else if (isInserting) {
      context.missing(_startUsMeta);
    }
    if (data.containsKey('end_us')) {
      context.handle(
        _endUsMeta,
        endUs.isAcceptableOrUnknown(data['end_us']!, _endUsMeta),
      );
    } else if (isInserting) {
      context.missing(_endUsMeta);
    }
    if (data.containsKey('raw_model_text')) {
      context.handle(
        _rawModelTextMeta,
        rawModelText.isAcceptableOrUnknown(
          data['raw_model_text']!,
          _rawModelTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rawModelTextMeta);
    }
    if (data.containsKey('displayed_text')) {
      context.handle(
        _displayedTextMeta,
        displayedText.isAcceptableOrUnknown(
          data['displayed_text']!,
          _displayedTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayedTextMeta);
    }
    if (data.containsKey('revision_state')) {
      context.handle(
        _revisionStateMeta,
        revisionState.isAcceptableOrUnknown(
          data['revision_state']!,
          _revisionStateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_revisionStateMeta);
    }
    if (data.containsKey('speaker_id')) {
      context.handle(
        _speakerIdMeta,
        speakerId.isAcceptableOrUnknown(data['speaker_id']!, _speakerIdMeta),
      );
    }
    if (data.containsKey('speaker_meeting_id')) {
      context.handle(
        _speakerMeetingIdMeta,
        speakerMeetingId.isAcceptableOrUnknown(
          data['speaker_meeting_id']!,
          _speakerMeetingIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TranscriptSegment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TranscriptSegment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      rowRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_revision'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      )!,
      transcriptRunId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript_run_id'],
      )!,
      startUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_us'],
      )!,
      endUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_us'],
      )!,
      rawModelText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_model_text'],
      )!,
      displayedText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}displayed_text'],
      )!,
      revisionState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}revision_state'],
      )!,
      speakerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}speaker_id'],
      ),
      speakerMeetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}speaker_meeting_id'],
      ),
    );
  }

  @override
  $TranscriptSegmentsTable createAlias(String alias) {
    return $TranscriptSegmentsTable(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
}

class TranscriptSegment extends DataClass
    implements Insertable<TranscriptSegment> {
  /// Stable UUID-style identifier.
  final String id;

  /// UTC creation instant in epoch milliseconds.
  final int createdAt;

  /// UTC last-update instant in epoch milliseconds.
  final int updatedAt;

  /// Monotonic row revision used by restore conflict handling.
  final int rowRevision;

  /// Whether this row is hidden by a soft delete.
  final bool isDeleted;

  /// UTC soft-delete instant in epoch milliseconds.
  final int? deletedAt;

  /// Denormalized owner used to enforce meeting-local references.
  final String meetingId;

  /// Owning transcript run.
  final String transcriptRunId;

  /// Inclusive pause-free start in microseconds.
  final int startUs;

  /// Exclusive pause-free end in microseconds.
  final int endUs;

  /// Untouched local engine output.
  final String rawModelText;

  /// Current user-visible text.
  final String displayedText;

  /// Whether displayed text includes a human correction.
  final String revisionState;

  /// Current meeting-local speaker selected for display/export.
  final String? speakerId;

  /// Owner paired with [speakerId] for the composite foreign key.
  final String? speakerMeetingId;
  const TranscriptSegment({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.rowRevision,
    required this.isDeleted,
    this.deletedAt,
    required this.meetingId,
    required this.transcriptRunId,
    required this.startUs,
    required this.endUs,
    required this.rawModelText,
    required this.displayedText,
    required this.revisionState,
    this.speakerId,
    this.speakerMeetingId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['row_revision'] = Variable<int>(rowRevision);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['meeting_id'] = Variable<String>(meetingId);
    map['transcript_run_id'] = Variable<String>(transcriptRunId);
    map['start_us'] = Variable<int>(startUs);
    map['end_us'] = Variable<int>(endUs);
    map['raw_model_text'] = Variable<String>(rawModelText);
    map['displayed_text'] = Variable<String>(displayedText);
    map['revision_state'] = Variable<String>(revisionState);
    if (!nullToAbsent || speakerId != null) {
      map['speaker_id'] = Variable<String>(speakerId);
    }
    if (!nullToAbsent || speakerMeetingId != null) {
      map['speaker_meeting_id'] = Variable<String>(speakerMeetingId);
    }
    return map;
  }

  TranscriptSegmentsCompanion toCompanion(bool nullToAbsent) {
    return TranscriptSegmentsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      rowRevision: Value(rowRevision),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      meetingId: Value(meetingId),
      transcriptRunId: Value(transcriptRunId),
      startUs: Value(startUs),
      endUs: Value(endUs),
      rawModelText: Value(rawModelText),
      displayedText: Value(displayedText),
      revisionState: Value(revisionState),
      speakerId: speakerId == null && nullToAbsent
          ? const Value.absent()
          : Value(speakerId),
      speakerMeetingId: speakerMeetingId == null && nullToAbsent
          ? const Value.absent()
          : Value(speakerMeetingId),
    );
  }

  factory TranscriptSegment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TranscriptSegment(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      rowRevision: serializer.fromJson<int>(json['rowRevision']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      meetingId: serializer.fromJson<String>(json['meetingId']),
      transcriptRunId: serializer.fromJson<String>(json['transcriptRunId']),
      startUs: serializer.fromJson<int>(json['startUs']),
      endUs: serializer.fromJson<int>(json['endUs']),
      rawModelText: serializer.fromJson<String>(json['rawModelText']),
      displayedText: serializer.fromJson<String>(json['displayedText']),
      revisionState: serializer.fromJson<String>(json['revisionState']),
      speakerId: serializer.fromJson<String?>(json['speakerId']),
      speakerMeetingId: serializer.fromJson<String?>(json['speakerMeetingId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'rowRevision': serializer.toJson<int>(rowRevision),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'meetingId': serializer.toJson<String>(meetingId),
      'transcriptRunId': serializer.toJson<String>(transcriptRunId),
      'startUs': serializer.toJson<int>(startUs),
      'endUs': serializer.toJson<int>(endUs),
      'rawModelText': serializer.toJson<String>(rawModelText),
      'displayedText': serializer.toJson<String>(displayedText),
      'revisionState': serializer.toJson<String>(revisionState),
      'speakerId': serializer.toJson<String?>(speakerId),
      'speakerMeetingId': serializer.toJson<String?>(speakerMeetingId),
    };
  }

  TranscriptSegment copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    int? rowRevision,
    bool? isDeleted,
    Value<int?> deletedAt = const Value.absent(),
    String? meetingId,
    String? transcriptRunId,
    int? startUs,
    int? endUs,
    String? rawModelText,
    String? displayedText,
    String? revisionState,
    Value<String?> speakerId = const Value.absent(),
    Value<String?> speakerMeetingId = const Value.absent(),
  }) => TranscriptSegment(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    rowRevision: rowRevision ?? this.rowRevision,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    meetingId: meetingId ?? this.meetingId,
    transcriptRunId: transcriptRunId ?? this.transcriptRunId,
    startUs: startUs ?? this.startUs,
    endUs: endUs ?? this.endUs,
    rawModelText: rawModelText ?? this.rawModelText,
    displayedText: displayedText ?? this.displayedText,
    revisionState: revisionState ?? this.revisionState,
    speakerId: speakerId.present ? speakerId.value : this.speakerId,
    speakerMeetingId: speakerMeetingId.present
        ? speakerMeetingId.value
        : this.speakerMeetingId,
  );
  TranscriptSegment copyWithCompanion(TranscriptSegmentsCompanion data) {
    return TranscriptSegment(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      rowRevision: data.rowRevision.present
          ? data.rowRevision.value
          : this.rowRevision,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      transcriptRunId: data.transcriptRunId.present
          ? data.transcriptRunId.value
          : this.transcriptRunId,
      startUs: data.startUs.present ? data.startUs.value : this.startUs,
      endUs: data.endUs.present ? data.endUs.value : this.endUs,
      rawModelText: data.rawModelText.present
          ? data.rawModelText.value
          : this.rawModelText,
      displayedText: data.displayedText.present
          ? data.displayedText.value
          : this.displayedText,
      revisionState: data.revisionState.present
          ? data.revisionState.value
          : this.revisionState,
      speakerId: data.speakerId.present ? data.speakerId.value : this.speakerId,
      speakerMeetingId: data.speakerMeetingId.present
          ? data.speakerMeetingId.value
          : this.speakerMeetingId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptSegment(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('meetingId: $meetingId, ')
          ..write('transcriptRunId: $transcriptRunId, ')
          ..write('startUs: $startUs, ')
          ..write('endUs: $endUs, ')
          ..write('rawModelText: $rawModelText, ')
          ..write('displayedText: $displayedText, ')
          ..write('revisionState: $revisionState, ')
          ..write('speakerId: $speakerId, ')
          ..write('speakerMeetingId: $speakerMeetingId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    meetingId,
    transcriptRunId,
    startUs,
    endUs,
    rawModelText,
    displayedText,
    revisionState,
    speakerId,
    speakerMeetingId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TranscriptSegment &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.rowRevision == this.rowRevision &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt &&
          other.meetingId == this.meetingId &&
          other.transcriptRunId == this.transcriptRunId &&
          other.startUs == this.startUs &&
          other.endUs == this.endUs &&
          other.rawModelText == this.rawModelText &&
          other.displayedText == this.displayedText &&
          other.revisionState == this.revisionState &&
          other.speakerId == this.speakerId &&
          other.speakerMeetingId == this.speakerMeetingId);
}

class TranscriptSegmentsCompanion extends UpdateCompanion<TranscriptSegment> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowRevision;
  final Value<bool> isDeleted;
  final Value<int?> deletedAt;
  final Value<String> meetingId;
  final Value<String> transcriptRunId;
  final Value<int> startUs;
  final Value<int> endUs;
  final Value<String> rawModelText;
  final Value<String> displayedText;
  final Value<String> revisionState;
  final Value<String?> speakerId;
  final Value<String?> speakerMeetingId;
  final Value<int> rowid;
  const TranscriptSegmentsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.transcriptRunId = const Value.absent(),
    this.startUs = const Value.absent(),
    this.endUs = const Value.absent(),
    this.rawModelText = const Value.absent(),
    this.displayedText = const Value.absent(),
    this.revisionState = const Value.absent(),
    this.speakerId = const Value.absent(),
    this.speakerMeetingId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TranscriptSegmentsCompanion.insert({
    required String id,
    required int createdAt,
    required int updatedAt,
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String meetingId,
    required String transcriptRunId,
    required int startUs,
    required int endUs,
    required String rawModelText,
    required String displayedText,
    required String revisionState,
    this.speakerId = const Value.absent(),
    this.speakerMeetingId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       meetingId = Value(meetingId),
       transcriptRunId = Value(transcriptRunId),
       startUs = Value(startUs),
       endUs = Value(endUs),
       rawModelText = Value(rawModelText),
       displayedText = Value(displayedText),
       revisionState = Value(revisionState);
  static Insertable<TranscriptSegment> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowRevision,
    Expression<bool>? isDeleted,
    Expression<int>? deletedAt,
    Expression<String>? meetingId,
    Expression<String>? transcriptRunId,
    Expression<int>? startUs,
    Expression<int>? endUs,
    Expression<String>? rawModelText,
    Expression<String>? displayedText,
    Expression<String>? revisionState,
    Expression<String>? speakerId,
    Expression<String>? speakerMeetingId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowRevision != null) 'row_revision': rowRevision,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (meetingId != null) 'meeting_id': meetingId,
      if (transcriptRunId != null) 'transcript_run_id': transcriptRunId,
      if (startUs != null) 'start_us': startUs,
      if (endUs != null) 'end_us': endUs,
      if (rawModelText != null) 'raw_model_text': rawModelText,
      if (displayedText != null) 'displayed_text': displayedText,
      if (revisionState != null) 'revision_state': revisionState,
      if (speakerId != null) 'speaker_id': speakerId,
      if (speakerMeetingId != null) 'speaker_meeting_id': speakerMeetingId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TranscriptSegmentsCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowRevision,
    Value<bool>? isDeleted,
    Value<int?>? deletedAt,
    Value<String>? meetingId,
    Value<String>? transcriptRunId,
    Value<int>? startUs,
    Value<int>? endUs,
    Value<String>? rawModelText,
    Value<String>? displayedText,
    Value<String>? revisionState,
    Value<String?>? speakerId,
    Value<String?>? speakerMeetingId,
    Value<int>? rowid,
  }) {
    return TranscriptSegmentsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowRevision: rowRevision ?? this.rowRevision,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      meetingId: meetingId ?? this.meetingId,
      transcriptRunId: transcriptRunId ?? this.transcriptRunId,
      startUs: startUs ?? this.startUs,
      endUs: endUs ?? this.endUs,
      rawModelText: rawModelText ?? this.rawModelText,
      displayedText: displayedText ?? this.displayedText,
      revisionState: revisionState ?? this.revisionState,
      speakerId: speakerId ?? this.speakerId,
      speakerMeetingId: speakerMeetingId ?? this.speakerMeetingId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowRevision.present) {
      map['row_revision'] = Variable<int>(rowRevision.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (meetingId.present) {
      map['meeting_id'] = Variable<String>(meetingId.value);
    }
    if (transcriptRunId.present) {
      map['transcript_run_id'] = Variable<String>(transcriptRunId.value);
    }
    if (startUs.present) {
      map['start_us'] = Variable<int>(startUs.value);
    }
    if (endUs.present) {
      map['end_us'] = Variable<int>(endUs.value);
    }
    if (rawModelText.present) {
      map['raw_model_text'] = Variable<String>(rawModelText.value);
    }
    if (displayedText.present) {
      map['displayed_text'] = Variable<String>(displayedText.value);
    }
    if (revisionState.present) {
      map['revision_state'] = Variable<String>(revisionState.value);
    }
    if (speakerId.present) {
      map['speaker_id'] = Variable<String>(speakerId.value);
    }
    if (speakerMeetingId.present) {
      map['speaker_meeting_id'] = Variable<String>(speakerMeetingId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptSegmentsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('meetingId: $meetingId, ')
          ..write('transcriptRunId: $transcriptRunId, ')
          ..write('startUs: $startUs, ')
          ..write('endUs: $endUs, ')
          ..write('rawModelText: $rawModelText, ')
          ..write('displayedText: $displayedText, ')
          ..write('revisionState: $revisionState, ')
          ..write('speakerId: $speakerId, ')
          ..write('speakerMeetingId: $speakerMeetingId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LanguageDecisionsTable extends LanguageDecisions
    with TableInfo<$LanguageDecisionsTable, LanguageDecision> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LanguageDecisionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (created_at >= 0)',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (updated_at >= created_at)',
  );
  static const VerificationMeta _rowRevisionMeta = const VerificationMeta(
    'rowRevision',
  );
  @override
  late final GeneratedColumn<int> rowRevision = GeneratedColumn<int>(
    'row_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (row_revision >= 0)',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT 0 CHECK ((is_deleted = 0 AND deleted_at IS NULL) OR (is_deleted = 1 AND deleted_at IS NOT NULL))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NULL CHECK (deleted_at IS NULL OR deleted_at >= 0)',
  );
  static const VerificationMeta _transcriptSegmentIdMeta =
      const VerificationMeta('transcriptSegmentId');
  @override
  late final GeneratedColumn<String> transcriptSegmentId =
      GeneratedColumn<String>(
        'transcript_segment_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES transcript_segments (id) ON DELETE CASCADE',
        ),
      );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    transcriptSegmentId,
    tag,
    source,
    confidence,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'language_decisions';
  @override
  VerificationContext validateIntegrity(
    Insertable<LanguageDecision> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('row_revision')) {
      context.handle(
        _rowRevisionMeta,
        rowRevision.isAcceptableOrUnknown(
          data['row_revision']!,
          _rowRevisionMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('transcript_segment_id')) {
      context.handle(
        _transcriptSegmentIdMeta,
        transcriptSegmentId.isAcceptableOrUnknown(
          data['transcript_segment_id']!,
          _transcriptSegmentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transcriptSegmentIdMeta);
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LanguageDecision map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LanguageDecision(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      rowRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_revision'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      transcriptSegmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript_segment_id'],
      )!,
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      ),
    );
  }

  @override
  $LanguageDecisionsTable createAlias(String alias) {
    return $LanguageDecisionsTable(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
}

class LanguageDecision extends DataClass
    implements Insertable<LanguageDecision> {
  /// Stable UUID-style identifier.
  final String id;

  /// UTC creation instant in epoch milliseconds.
  final int createdAt;

  /// UTC last-update instant in epoch milliseconds.
  final int updatedAt;

  /// Monotonic row revision used by restore conflict handling.
  final int rowRevision;

  /// Whether this row is hidden by a soft delete.
  final bool isDeleted;

  /// UTC soft-delete instant in epoch milliseconds.
  final int? deletedAt;

  /// Target stable transcript segment.
  final String transcriptSegmentId;

  /// Chinese, English, mixed, or uncertain.
  final String tag;

  /// Automatic or manual provenance.
  final String source;

  /// Calibrated confidence when available.
  final double? confidence;
  const LanguageDecision({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.rowRevision,
    required this.isDeleted,
    this.deletedAt,
    required this.transcriptSegmentId,
    required this.tag,
    required this.source,
    this.confidence,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['row_revision'] = Variable<int>(rowRevision);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['transcript_segment_id'] = Variable<String>(transcriptSegmentId);
    map['tag'] = Variable<String>(tag);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || confidence != null) {
      map['confidence'] = Variable<double>(confidence);
    }
    return map;
  }

  LanguageDecisionsCompanion toCompanion(bool nullToAbsent) {
    return LanguageDecisionsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      rowRevision: Value(rowRevision),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      transcriptSegmentId: Value(transcriptSegmentId),
      tag: Value(tag),
      source: Value(source),
      confidence: confidence == null && nullToAbsent
          ? const Value.absent()
          : Value(confidence),
    );
  }

  factory LanguageDecision.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LanguageDecision(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      rowRevision: serializer.fromJson<int>(json['rowRevision']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      transcriptSegmentId: serializer.fromJson<String>(
        json['transcriptSegmentId'],
      ),
      tag: serializer.fromJson<String>(json['tag']),
      source: serializer.fromJson<String>(json['source']),
      confidence: serializer.fromJson<double?>(json['confidence']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'rowRevision': serializer.toJson<int>(rowRevision),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'transcriptSegmentId': serializer.toJson<String>(transcriptSegmentId),
      'tag': serializer.toJson<String>(tag),
      'source': serializer.toJson<String>(source),
      'confidence': serializer.toJson<double?>(confidence),
    };
  }

  LanguageDecision copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    int? rowRevision,
    bool? isDeleted,
    Value<int?> deletedAt = const Value.absent(),
    String? transcriptSegmentId,
    String? tag,
    String? source,
    Value<double?> confidence = const Value.absent(),
  }) => LanguageDecision(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    rowRevision: rowRevision ?? this.rowRevision,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    transcriptSegmentId: transcriptSegmentId ?? this.transcriptSegmentId,
    tag: tag ?? this.tag,
    source: source ?? this.source,
    confidence: confidence.present ? confidence.value : this.confidence,
  );
  LanguageDecision copyWithCompanion(LanguageDecisionsCompanion data) {
    return LanguageDecision(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      rowRevision: data.rowRevision.present
          ? data.rowRevision.value
          : this.rowRevision,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      transcriptSegmentId: data.transcriptSegmentId.present
          ? data.transcriptSegmentId.value
          : this.transcriptSegmentId,
      tag: data.tag.present ? data.tag.value : this.tag,
      source: data.source.present ? data.source.value : this.source,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LanguageDecision(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('transcriptSegmentId: $transcriptSegmentId, ')
          ..write('tag: $tag, ')
          ..write('source: $source, ')
          ..write('confidence: $confidence')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    transcriptSegmentId,
    tag,
    source,
    confidence,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LanguageDecision &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.rowRevision == this.rowRevision &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt &&
          other.transcriptSegmentId == this.transcriptSegmentId &&
          other.tag == this.tag &&
          other.source == this.source &&
          other.confidence == this.confidence);
}

class LanguageDecisionsCompanion extends UpdateCompanion<LanguageDecision> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowRevision;
  final Value<bool> isDeleted;
  final Value<int?> deletedAt;
  final Value<String> transcriptSegmentId;
  final Value<String> tag;
  final Value<String> source;
  final Value<double?> confidence;
  final Value<int> rowid;
  const LanguageDecisionsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.transcriptSegmentId = const Value.absent(),
    this.tag = const Value.absent(),
    this.source = const Value.absent(),
    this.confidence = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LanguageDecisionsCompanion.insert({
    required String id,
    required int createdAt,
    required int updatedAt,
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String transcriptSegmentId,
    required String tag,
    required String source,
    this.confidence = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       transcriptSegmentId = Value(transcriptSegmentId),
       tag = Value(tag),
       source = Value(source);
  static Insertable<LanguageDecision> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowRevision,
    Expression<bool>? isDeleted,
    Expression<int>? deletedAt,
    Expression<String>? transcriptSegmentId,
    Expression<String>? tag,
    Expression<String>? source,
    Expression<double>? confidence,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowRevision != null) 'row_revision': rowRevision,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (transcriptSegmentId != null)
        'transcript_segment_id': transcriptSegmentId,
      if (tag != null) 'tag': tag,
      if (source != null) 'source': source,
      if (confidence != null) 'confidence': confidence,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LanguageDecisionsCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowRevision,
    Value<bool>? isDeleted,
    Value<int?>? deletedAt,
    Value<String>? transcriptSegmentId,
    Value<String>? tag,
    Value<String>? source,
    Value<double?>? confidence,
    Value<int>? rowid,
  }) {
    return LanguageDecisionsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowRevision: rowRevision ?? this.rowRevision,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      transcriptSegmentId: transcriptSegmentId ?? this.transcriptSegmentId,
      tag: tag ?? this.tag,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowRevision.present) {
      map['row_revision'] = Variable<int>(rowRevision.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (transcriptSegmentId.present) {
      map['transcript_segment_id'] = Variable<String>(
        transcriptSegmentId.value,
      );
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LanguageDecisionsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('transcriptSegmentId: $transcriptSegmentId, ')
          ..write('tag: $tag, ')
          ..write('source: $source, ')
          ..write('confidence: $confidence, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TranscriptLanguageSelectionsTable extends TranscriptLanguageSelections
    with
        TableInfo<
          $TranscriptLanguageSelectionsTable,
          TranscriptLanguageSelection
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TranscriptLanguageSelectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (created_at >= 0)',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (updated_at >= created_at)',
  );
  static const VerificationMeta _rowRevisionMeta = const VerificationMeta(
    'rowRevision',
  );
  @override
  late final GeneratedColumn<int> rowRevision = GeneratedColumn<int>(
    'row_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (row_revision >= 0)',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT 0 CHECK ((is_deleted = 0 AND deleted_at IS NULL) OR (is_deleted = 1 AND deleted_at IS NOT NULL))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NULL CHECK (deleted_at IS NULL OR deleted_at >= 0)',
  );
  static const VerificationMeta _transcriptSegmentIdMeta =
      const VerificationMeta('transcriptSegmentId');
  @override
  late final GeneratedColumn<String> transcriptSegmentId =
      GeneratedColumn<String>(
        'transcript_segment_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES transcript_segments (id) ON DELETE CASCADE',
        ),
      );
  static const VerificationMeta _languageDecisionIdMeta =
      const VerificationMeta('languageDecisionId');
  @override
  late final GeneratedColumn<String> languageDecisionId =
      GeneratedColumn<String>(
        'language_decision_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES language_decisions (id) ON DELETE CASCADE',
        ),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    transcriptSegmentId,
    languageDecisionId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transcript_language_selections';
  @override
  VerificationContext validateIntegrity(
    Insertable<TranscriptLanguageSelection> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('row_revision')) {
      context.handle(
        _rowRevisionMeta,
        rowRevision.isAcceptableOrUnknown(
          data['row_revision']!,
          _rowRevisionMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('transcript_segment_id')) {
      context.handle(
        _transcriptSegmentIdMeta,
        transcriptSegmentId.isAcceptableOrUnknown(
          data['transcript_segment_id']!,
          _transcriptSegmentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transcriptSegmentIdMeta);
    }
    if (data.containsKey('language_decision_id')) {
      context.handle(
        _languageDecisionIdMeta,
        languageDecisionId.isAcceptableOrUnknown(
          data['language_decision_id']!,
          _languageDecisionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_languageDecisionIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TranscriptLanguageSelection map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TranscriptLanguageSelection(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      rowRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_revision'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      transcriptSegmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript_segment_id'],
      )!,
      languageDecisionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language_decision_id'],
      )!,
    );
  }

  @override
  $TranscriptLanguageSelectionsTable createAlias(String alias) {
    return $TranscriptLanguageSelectionsTable(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
}

class TranscriptLanguageSelection extends DataClass
    implements Insertable<TranscriptLanguageSelection> {
  /// Stable UUID-style identifier.
  final String id;

  /// UTC creation instant in epoch milliseconds.
  final int createdAt;

  /// UTC last-update instant in epoch milliseconds.
  final int updatedAt;

  /// Monotonic row revision used by restore conflict handling.
  final int rowRevision;

  /// Whether this row is hidden by a soft delete.
  final bool isDeleted;

  /// UTC soft-delete instant in epoch milliseconds.
  final int? deletedAt;

  /// Stable transcript segment whose language is selected.
  final String transcriptSegmentId;

  /// Explicitly selected automatic or human language decision.
  final String languageDecisionId;
  const TranscriptLanguageSelection({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.rowRevision,
    required this.isDeleted,
    this.deletedAt,
    required this.transcriptSegmentId,
    required this.languageDecisionId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['row_revision'] = Variable<int>(rowRevision);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['transcript_segment_id'] = Variable<String>(transcriptSegmentId);
    map['language_decision_id'] = Variable<String>(languageDecisionId);
    return map;
  }

  TranscriptLanguageSelectionsCompanion toCompanion(bool nullToAbsent) {
    return TranscriptLanguageSelectionsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      rowRevision: Value(rowRevision),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      transcriptSegmentId: Value(transcriptSegmentId),
      languageDecisionId: Value(languageDecisionId),
    );
  }

  factory TranscriptLanguageSelection.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TranscriptLanguageSelection(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      rowRevision: serializer.fromJson<int>(json['rowRevision']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      transcriptSegmentId: serializer.fromJson<String>(
        json['transcriptSegmentId'],
      ),
      languageDecisionId: serializer.fromJson<String>(
        json['languageDecisionId'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'rowRevision': serializer.toJson<int>(rowRevision),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'transcriptSegmentId': serializer.toJson<String>(transcriptSegmentId),
      'languageDecisionId': serializer.toJson<String>(languageDecisionId),
    };
  }

  TranscriptLanguageSelection copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    int? rowRevision,
    bool? isDeleted,
    Value<int?> deletedAt = const Value.absent(),
    String? transcriptSegmentId,
    String? languageDecisionId,
  }) => TranscriptLanguageSelection(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    rowRevision: rowRevision ?? this.rowRevision,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    transcriptSegmentId: transcriptSegmentId ?? this.transcriptSegmentId,
    languageDecisionId: languageDecisionId ?? this.languageDecisionId,
  );
  TranscriptLanguageSelection copyWithCompanion(
    TranscriptLanguageSelectionsCompanion data,
  ) {
    return TranscriptLanguageSelection(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      rowRevision: data.rowRevision.present
          ? data.rowRevision.value
          : this.rowRevision,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      transcriptSegmentId: data.transcriptSegmentId.present
          ? data.transcriptSegmentId.value
          : this.transcriptSegmentId,
      languageDecisionId: data.languageDecisionId.present
          ? data.languageDecisionId.value
          : this.languageDecisionId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptLanguageSelection(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('transcriptSegmentId: $transcriptSegmentId, ')
          ..write('languageDecisionId: $languageDecisionId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    transcriptSegmentId,
    languageDecisionId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TranscriptLanguageSelection &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.rowRevision == this.rowRevision &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt &&
          other.transcriptSegmentId == this.transcriptSegmentId &&
          other.languageDecisionId == this.languageDecisionId);
}

class TranscriptLanguageSelectionsCompanion
    extends UpdateCompanion<TranscriptLanguageSelection> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowRevision;
  final Value<bool> isDeleted;
  final Value<int?> deletedAt;
  final Value<String> transcriptSegmentId;
  final Value<String> languageDecisionId;
  final Value<int> rowid;
  const TranscriptLanguageSelectionsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.transcriptSegmentId = const Value.absent(),
    this.languageDecisionId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TranscriptLanguageSelectionsCompanion.insert({
    required String id,
    required int createdAt,
    required int updatedAt,
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String transcriptSegmentId,
    required String languageDecisionId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       transcriptSegmentId = Value(transcriptSegmentId),
       languageDecisionId = Value(languageDecisionId);
  static Insertable<TranscriptLanguageSelection> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowRevision,
    Expression<bool>? isDeleted,
    Expression<int>? deletedAt,
    Expression<String>? transcriptSegmentId,
    Expression<String>? languageDecisionId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowRevision != null) 'row_revision': rowRevision,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (transcriptSegmentId != null)
        'transcript_segment_id': transcriptSegmentId,
      if (languageDecisionId != null)
        'language_decision_id': languageDecisionId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TranscriptLanguageSelectionsCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowRevision,
    Value<bool>? isDeleted,
    Value<int?>? deletedAt,
    Value<String>? transcriptSegmentId,
    Value<String>? languageDecisionId,
    Value<int>? rowid,
  }) {
    return TranscriptLanguageSelectionsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowRevision: rowRevision ?? this.rowRevision,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      transcriptSegmentId: transcriptSegmentId ?? this.transcriptSegmentId,
      languageDecisionId: languageDecisionId ?? this.languageDecisionId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowRevision.present) {
      map['row_revision'] = Variable<int>(rowRevision.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (transcriptSegmentId.present) {
      map['transcript_segment_id'] = Variable<String>(
        transcriptSegmentId.value,
      );
    }
    if (languageDecisionId.present) {
      map['language_decision_id'] = Variable<String>(languageDecisionId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptLanguageSelectionsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('transcriptSegmentId: $transcriptSegmentId, ')
          ..write('languageDecisionId: $languageDecisionId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SpeakerAssignmentsTable extends SpeakerAssignments
    with TableInfo<$SpeakerAssignmentsTable, SpeakerAssignment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpeakerAssignmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (created_at >= 0)',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (updated_at >= created_at)',
  );
  static const VerificationMeta _rowRevisionMeta = const VerificationMeta(
    'rowRevision',
  );
  @override
  late final GeneratedColumn<int> rowRevision = GeneratedColumn<int>(
    'row_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (row_revision >= 0)',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT 0 CHECK ((is_deleted = 0 AND deleted_at IS NULL) OR (is_deleted = 1 AND deleted_at IS NOT NULL))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NULL CHECK (deleted_at IS NULL OR deleted_at >= 0)',
  );
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<String> meetingId = GeneratedColumn<String>(
    'meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meetings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _analysisRunIdMeta = const VerificationMeta(
    'analysisRunId',
  );
  @override
  late final GeneratedColumn<String> analysisRunId = GeneratedColumn<String>(
    'analysis_run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES diarization_runs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _speakerIdMeta = const VerificationMeta(
    'speakerId',
  );
  @override
  late final GeneratedColumn<String> speakerId = GeneratedColumn<String>(
    'speaker_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _speakerAnalysisRunIdMeta =
      const VerificationMeta('speakerAnalysisRunId');
  @override
  late final GeneratedColumn<String> speakerAnalysisRunId =
      GeneratedColumn<String>(
        'speaker_analysis_run_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _startUsMeta = const VerificationMeta(
    'startUs',
  );
  @override
  late final GeneratedColumn<int> startUs = GeneratedColumn<int>(
    'start_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endUsMeta = const VerificationMeta('endUs');
  @override
  late final GeneratedColumn<int> endUs = GeneratedColumn<int>(
    'end_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isOverlapMeta = const VerificationMeta(
    'isOverlap',
  );
  @override
  late final GeneratedColumn<bool> isOverlap = GeneratedColumn<bool>(
    'is_overlap',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_overlap" IN (0, 1))',
    ),
  );
  static const VerificationMeta _needsConfirmationMeta = const VerificationMeta(
    'needsConfirmation',
  );
  @override
  late final GeneratedColumn<bool> needsConfirmation = GeneratedColumn<bool>(
    'needs_confirmation',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("needs_confirmation" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    meetingId,
    analysisRunId,
    speakerId,
    speakerAnalysisRunId,
    startUs,
    endUs,
    confidence,
    isOverlap,
    needsConfirmation,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'speaker_assignments';
  @override
  VerificationContext validateIntegrity(
    Insertable<SpeakerAssignment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('row_revision')) {
      context.handle(
        _rowRevisionMeta,
        rowRevision.isAcceptableOrUnknown(
          data['row_revision']!,
          _rowRevisionMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('analysis_run_id')) {
      context.handle(
        _analysisRunIdMeta,
        analysisRunId.isAcceptableOrUnknown(
          data['analysis_run_id']!,
          _analysisRunIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_analysisRunIdMeta);
    }
    if (data.containsKey('speaker_id')) {
      context.handle(
        _speakerIdMeta,
        speakerId.isAcceptableOrUnknown(data['speaker_id']!, _speakerIdMeta),
      );
    }
    if (data.containsKey('speaker_analysis_run_id')) {
      context.handle(
        _speakerAnalysisRunIdMeta,
        speakerAnalysisRunId.isAcceptableOrUnknown(
          data['speaker_analysis_run_id']!,
          _speakerAnalysisRunIdMeta,
        ),
      );
    }
    if (data.containsKey('start_us')) {
      context.handle(
        _startUsMeta,
        startUs.isAcceptableOrUnknown(data['start_us']!, _startUsMeta),
      );
    } else if (isInserting) {
      context.missing(_startUsMeta);
    }
    if (data.containsKey('end_us')) {
      context.handle(
        _endUsMeta,
        endUs.isAcceptableOrUnknown(data['end_us']!, _endUsMeta),
      );
    } else if (isInserting) {
      context.missing(_endUsMeta);
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('is_overlap')) {
      context.handle(
        _isOverlapMeta,
        isOverlap.isAcceptableOrUnknown(data['is_overlap']!, _isOverlapMeta),
      );
    } else if (isInserting) {
      context.missing(_isOverlapMeta);
    }
    if (data.containsKey('needs_confirmation')) {
      context.handle(
        _needsConfirmationMeta,
        needsConfirmation.isAcceptableOrUnknown(
          data['needs_confirmation']!,
          _needsConfirmationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_needsConfirmationMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SpeakerAssignment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SpeakerAssignment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      rowRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_revision'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      )!,
      analysisRunId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}analysis_run_id'],
      )!,
      speakerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}speaker_id'],
      ),
      speakerAnalysisRunId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}speaker_analysis_run_id'],
      ),
      startUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_us'],
      )!,
      endUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_us'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      ),
      isOverlap: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_overlap'],
      )!,
      needsConfirmation: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}needs_confirmation'],
      )!,
    );
  }

  @override
  $SpeakerAssignmentsTable createAlias(String alias) {
    return $SpeakerAssignmentsTable(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
}

class SpeakerAssignment extends DataClass
    implements Insertable<SpeakerAssignment> {
  /// Stable UUID-style identifier.
  final String id;

  /// UTC creation instant in epoch milliseconds.
  final int createdAt;

  /// UTC last-update instant in epoch milliseconds.
  final int updatedAt;

  /// Monotonic row revision used by restore conflict handling.
  final int rowRevision;

  /// Whether this row is hidden by a soft delete.
  final bool isDeleted;

  /// UTC soft-delete instant in epoch milliseconds.
  final int? deletedAt;

  /// Denormalized owner used to enforce meeting-local references.
  final String meetingId;

  /// Owning diarization run.
  final String analysisRunId;

  /// Assigned speaker, null when deliberately unassigned.
  final String? speakerId;

  /// Run owner paired with [speakerId] for the composite foreign key.
  final String? speakerAnalysisRunId;

  /// Inclusive pause-free start in microseconds.
  final int startUs;

  /// Exclusive pause-free end in microseconds.
  final int endUs;

  /// Calibrated confidence when available.
  final double? confidence;

  /// Whether multiple speakers overlap in this interval.
  final bool isOverlap;

  /// Whether the interval needs explicit user confirmation.
  final bool needsConfirmation;
  const SpeakerAssignment({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.rowRevision,
    required this.isDeleted,
    this.deletedAt,
    required this.meetingId,
    required this.analysisRunId,
    this.speakerId,
    this.speakerAnalysisRunId,
    required this.startUs,
    required this.endUs,
    this.confidence,
    required this.isOverlap,
    required this.needsConfirmation,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['row_revision'] = Variable<int>(rowRevision);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['meeting_id'] = Variable<String>(meetingId);
    map['analysis_run_id'] = Variable<String>(analysisRunId);
    if (!nullToAbsent || speakerId != null) {
      map['speaker_id'] = Variable<String>(speakerId);
    }
    if (!nullToAbsent || speakerAnalysisRunId != null) {
      map['speaker_analysis_run_id'] = Variable<String>(speakerAnalysisRunId);
    }
    map['start_us'] = Variable<int>(startUs);
    map['end_us'] = Variable<int>(endUs);
    if (!nullToAbsent || confidence != null) {
      map['confidence'] = Variable<double>(confidence);
    }
    map['is_overlap'] = Variable<bool>(isOverlap);
    map['needs_confirmation'] = Variable<bool>(needsConfirmation);
    return map;
  }

  SpeakerAssignmentsCompanion toCompanion(bool nullToAbsent) {
    return SpeakerAssignmentsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      rowRevision: Value(rowRevision),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      meetingId: Value(meetingId),
      analysisRunId: Value(analysisRunId),
      speakerId: speakerId == null && nullToAbsent
          ? const Value.absent()
          : Value(speakerId),
      speakerAnalysisRunId: speakerAnalysisRunId == null && nullToAbsent
          ? const Value.absent()
          : Value(speakerAnalysisRunId),
      startUs: Value(startUs),
      endUs: Value(endUs),
      confidence: confidence == null && nullToAbsent
          ? const Value.absent()
          : Value(confidence),
      isOverlap: Value(isOverlap),
      needsConfirmation: Value(needsConfirmation),
    );
  }

  factory SpeakerAssignment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SpeakerAssignment(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      rowRevision: serializer.fromJson<int>(json['rowRevision']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      meetingId: serializer.fromJson<String>(json['meetingId']),
      analysisRunId: serializer.fromJson<String>(json['analysisRunId']),
      speakerId: serializer.fromJson<String?>(json['speakerId']),
      speakerAnalysisRunId: serializer.fromJson<String?>(
        json['speakerAnalysisRunId'],
      ),
      startUs: serializer.fromJson<int>(json['startUs']),
      endUs: serializer.fromJson<int>(json['endUs']),
      confidence: serializer.fromJson<double?>(json['confidence']),
      isOverlap: serializer.fromJson<bool>(json['isOverlap']),
      needsConfirmation: serializer.fromJson<bool>(json['needsConfirmation']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'rowRevision': serializer.toJson<int>(rowRevision),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'meetingId': serializer.toJson<String>(meetingId),
      'analysisRunId': serializer.toJson<String>(analysisRunId),
      'speakerId': serializer.toJson<String?>(speakerId),
      'speakerAnalysisRunId': serializer.toJson<String?>(speakerAnalysisRunId),
      'startUs': serializer.toJson<int>(startUs),
      'endUs': serializer.toJson<int>(endUs),
      'confidence': serializer.toJson<double?>(confidence),
      'isOverlap': serializer.toJson<bool>(isOverlap),
      'needsConfirmation': serializer.toJson<bool>(needsConfirmation),
    };
  }

  SpeakerAssignment copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    int? rowRevision,
    bool? isDeleted,
    Value<int?> deletedAt = const Value.absent(),
    String? meetingId,
    String? analysisRunId,
    Value<String?> speakerId = const Value.absent(),
    Value<String?> speakerAnalysisRunId = const Value.absent(),
    int? startUs,
    int? endUs,
    Value<double?> confidence = const Value.absent(),
    bool? isOverlap,
    bool? needsConfirmation,
  }) => SpeakerAssignment(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    rowRevision: rowRevision ?? this.rowRevision,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    meetingId: meetingId ?? this.meetingId,
    analysisRunId: analysisRunId ?? this.analysisRunId,
    speakerId: speakerId.present ? speakerId.value : this.speakerId,
    speakerAnalysisRunId: speakerAnalysisRunId.present
        ? speakerAnalysisRunId.value
        : this.speakerAnalysisRunId,
    startUs: startUs ?? this.startUs,
    endUs: endUs ?? this.endUs,
    confidence: confidence.present ? confidence.value : this.confidence,
    isOverlap: isOverlap ?? this.isOverlap,
    needsConfirmation: needsConfirmation ?? this.needsConfirmation,
  );
  SpeakerAssignment copyWithCompanion(SpeakerAssignmentsCompanion data) {
    return SpeakerAssignment(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      rowRevision: data.rowRevision.present
          ? data.rowRevision.value
          : this.rowRevision,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      analysisRunId: data.analysisRunId.present
          ? data.analysisRunId.value
          : this.analysisRunId,
      speakerId: data.speakerId.present ? data.speakerId.value : this.speakerId,
      speakerAnalysisRunId: data.speakerAnalysisRunId.present
          ? data.speakerAnalysisRunId.value
          : this.speakerAnalysisRunId,
      startUs: data.startUs.present ? data.startUs.value : this.startUs,
      endUs: data.endUs.present ? data.endUs.value : this.endUs,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      isOverlap: data.isOverlap.present ? data.isOverlap.value : this.isOverlap,
      needsConfirmation: data.needsConfirmation.present
          ? data.needsConfirmation.value
          : this.needsConfirmation,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SpeakerAssignment(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('meetingId: $meetingId, ')
          ..write('analysisRunId: $analysisRunId, ')
          ..write('speakerId: $speakerId, ')
          ..write('speakerAnalysisRunId: $speakerAnalysisRunId, ')
          ..write('startUs: $startUs, ')
          ..write('endUs: $endUs, ')
          ..write('confidence: $confidence, ')
          ..write('isOverlap: $isOverlap, ')
          ..write('needsConfirmation: $needsConfirmation')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    meetingId,
    analysisRunId,
    speakerId,
    speakerAnalysisRunId,
    startUs,
    endUs,
    confidence,
    isOverlap,
    needsConfirmation,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpeakerAssignment &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.rowRevision == this.rowRevision &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt &&
          other.meetingId == this.meetingId &&
          other.analysisRunId == this.analysisRunId &&
          other.speakerId == this.speakerId &&
          other.speakerAnalysisRunId == this.speakerAnalysisRunId &&
          other.startUs == this.startUs &&
          other.endUs == this.endUs &&
          other.confidence == this.confidence &&
          other.isOverlap == this.isOverlap &&
          other.needsConfirmation == this.needsConfirmation);
}

class SpeakerAssignmentsCompanion extends UpdateCompanion<SpeakerAssignment> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowRevision;
  final Value<bool> isDeleted;
  final Value<int?> deletedAt;
  final Value<String> meetingId;
  final Value<String> analysisRunId;
  final Value<String?> speakerId;
  final Value<String?> speakerAnalysisRunId;
  final Value<int> startUs;
  final Value<int> endUs;
  final Value<double?> confidence;
  final Value<bool> isOverlap;
  final Value<bool> needsConfirmation;
  final Value<int> rowid;
  const SpeakerAssignmentsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.analysisRunId = const Value.absent(),
    this.speakerId = const Value.absent(),
    this.speakerAnalysisRunId = const Value.absent(),
    this.startUs = const Value.absent(),
    this.endUs = const Value.absent(),
    this.confidence = const Value.absent(),
    this.isOverlap = const Value.absent(),
    this.needsConfirmation = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SpeakerAssignmentsCompanion.insert({
    required String id,
    required int createdAt,
    required int updatedAt,
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String meetingId,
    required String analysisRunId,
    this.speakerId = const Value.absent(),
    this.speakerAnalysisRunId = const Value.absent(),
    required int startUs,
    required int endUs,
    this.confidence = const Value.absent(),
    required bool isOverlap,
    required bool needsConfirmation,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       meetingId = Value(meetingId),
       analysisRunId = Value(analysisRunId),
       startUs = Value(startUs),
       endUs = Value(endUs),
       isOverlap = Value(isOverlap),
       needsConfirmation = Value(needsConfirmation);
  static Insertable<SpeakerAssignment> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowRevision,
    Expression<bool>? isDeleted,
    Expression<int>? deletedAt,
    Expression<String>? meetingId,
    Expression<String>? analysisRunId,
    Expression<String>? speakerId,
    Expression<String>? speakerAnalysisRunId,
    Expression<int>? startUs,
    Expression<int>? endUs,
    Expression<double>? confidence,
    Expression<bool>? isOverlap,
    Expression<bool>? needsConfirmation,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowRevision != null) 'row_revision': rowRevision,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (meetingId != null) 'meeting_id': meetingId,
      if (analysisRunId != null) 'analysis_run_id': analysisRunId,
      if (speakerId != null) 'speaker_id': speakerId,
      if (speakerAnalysisRunId != null)
        'speaker_analysis_run_id': speakerAnalysisRunId,
      if (startUs != null) 'start_us': startUs,
      if (endUs != null) 'end_us': endUs,
      if (confidence != null) 'confidence': confidence,
      if (isOverlap != null) 'is_overlap': isOverlap,
      if (needsConfirmation != null) 'needs_confirmation': needsConfirmation,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SpeakerAssignmentsCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowRevision,
    Value<bool>? isDeleted,
    Value<int?>? deletedAt,
    Value<String>? meetingId,
    Value<String>? analysisRunId,
    Value<String?>? speakerId,
    Value<String?>? speakerAnalysisRunId,
    Value<int>? startUs,
    Value<int>? endUs,
    Value<double?>? confidence,
    Value<bool>? isOverlap,
    Value<bool>? needsConfirmation,
    Value<int>? rowid,
  }) {
    return SpeakerAssignmentsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowRevision: rowRevision ?? this.rowRevision,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      meetingId: meetingId ?? this.meetingId,
      analysisRunId: analysisRunId ?? this.analysisRunId,
      speakerId: speakerId ?? this.speakerId,
      speakerAnalysisRunId: speakerAnalysisRunId ?? this.speakerAnalysisRunId,
      startUs: startUs ?? this.startUs,
      endUs: endUs ?? this.endUs,
      confidence: confidence ?? this.confidence,
      isOverlap: isOverlap ?? this.isOverlap,
      needsConfirmation: needsConfirmation ?? this.needsConfirmation,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowRevision.present) {
      map['row_revision'] = Variable<int>(rowRevision.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (meetingId.present) {
      map['meeting_id'] = Variable<String>(meetingId.value);
    }
    if (analysisRunId.present) {
      map['analysis_run_id'] = Variable<String>(analysisRunId.value);
    }
    if (speakerId.present) {
      map['speaker_id'] = Variable<String>(speakerId.value);
    }
    if (speakerAnalysisRunId.present) {
      map['speaker_analysis_run_id'] = Variable<String>(
        speakerAnalysisRunId.value,
      );
    }
    if (startUs.present) {
      map['start_us'] = Variable<int>(startUs.value);
    }
    if (endUs.present) {
      map['end_us'] = Variable<int>(endUs.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (isOverlap.present) {
      map['is_overlap'] = Variable<bool>(isOverlap.value);
    }
    if (needsConfirmation.present) {
      map['needs_confirmation'] = Variable<bool>(needsConfirmation.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpeakerAssignmentsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('meetingId: $meetingId, ')
          ..write('analysisRunId: $analysisRunId, ')
          ..write('speakerId: $speakerId, ')
          ..write('speakerAnalysisRunId: $speakerAnalysisRunId, ')
          ..write('startUs: $startUs, ')
          ..write('endUs: $endUs, ')
          ..write('confidence: $confidence, ')
          ..write('isOverlap: $isOverlap, ')
          ..write('needsConfirmation: $needsConfirmation, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RevisionsTable extends Revisions
    with TableInfo<$RevisionsTable, Revision> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RevisionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (created_at >= 0)',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (updated_at >= created_at)',
  );
  static const VerificationMeta _rowRevisionMeta = const VerificationMeta(
    'rowRevision',
  );
  @override
  late final GeneratedColumn<int> rowRevision = GeneratedColumn<int>(
    'row_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (row_revision >= 0)',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT 0 CHECK ((is_deleted = 0 AND deleted_at IS NULL) OR (is_deleted = 1 AND deleted_at IS NOT NULL))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NULL CHECK (deleted_at IS NULL OR deleted_at >= 0)',
  );
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<String> meetingId = GeneratedColumn<String>(
    'meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meetings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _transcriptSegmentIdMeta =
      const VerificationMeta('transcriptSegmentId');
  @override
  late final GeneratedColumn<String> transcriptSegmentId =
      GeneratedColumn<String>(
        'transcript_segment_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _speakerAssignmentIdMeta =
      const VerificationMeta('speakerAssignmentId');
  @override
  late final GeneratedColumn<String> speakerAssignmentId =
      GeneratedColumn<String>(
        'speaker_assignment_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _speakerIdMeta = const VerificationMeta(
    'speakerId',
  );
  @override
  late final GeneratedColumn<String> speakerId = GeneratedColumn<String>(
    'speaker_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionKindMeta = const VerificationMeta(
    'revisionKind',
  );
  @override
  late final GeneratedColumn<String> revisionKind = GeneratedColumn<String>(
    'revision_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    meetingId,
    transcriptSegmentId,
    speakerAssignmentId,
    speakerId,
    revisionKind,
    payloadJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'revisions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Revision> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('row_revision')) {
      context.handle(
        _rowRevisionMeta,
        rowRevision.isAcceptableOrUnknown(
          data['row_revision']!,
          _rowRevisionMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('transcript_segment_id')) {
      context.handle(
        _transcriptSegmentIdMeta,
        transcriptSegmentId.isAcceptableOrUnknown(
          data['transcript_segment_id']!,
          _transcriptSegmentIdMeta,
        ),
      );
    }
    if (data.containsKey('speaker_assignment_id')) {
      context.handle(
        _speakerAssignmentIdMeta,
        speakerAssignmentId.isAcceptableOrUnknown(
          data['speaker_assignment_id']!,
          _speakerAssignmentIdMeta,
        ),
      );
    }
    if (data.containsKey('speaker_id')) {
      context.handle(
        _speakerIdMeta,
        speakerId.isAcceptableOrUnknown(data['speaker_id']!, _speakerIdMeta),
      );
    }
    if (data.containsKey('revision_kind')) {
      context.handle(
        _revisionKindMeta,
        revisionKind.isAcceptableOrUnknown(
          data['revision_kind']!,
          _revisionKindMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_revisionKindMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Revision map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Revision(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      rowRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_revision'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      )!,
      transcriptSegmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript_segment_id'],
      ),
      speakerAssignmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}speaker_assignment_id'],
      ),
      speakerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}speaker_id'],
      ),
      revisionKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}revision_kind'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
    );
  }

  @override
  $RevisionsTable createAlias(String alias) {
    return $RevisionsTable(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
}

class Revision extends DataClass implements Insertable<Revision> {
  /// Stable UUID-style identifier.
  final String id;

  /// UTC creation instant in epoch milliseconds.
  final int createdAt;

  /// UTC last-update instant in epoch milliseconds.
  final int updatedAt;

  /// Monotonic row revision used by restore conflict handling.
  final int rowRevision;

  /// Whether this row is hidden by a soft delete.
  final bool isDeleted;

  /// UTC soft-delete instant in epoch milliseconds.
  final int? deletedAt;

  /// Owning meeting.
  final String meetingId;

  /// Transcript segment revised by text or language corrections.
  final String? transcriptSegmentId;

  /// Speaker interval revised by an assignment correction.
  final String? speakerAssignmentId;

  /// Meeting-local speaker revised by a label correction.
  final String? speakerId;

  /// Closed revision payload discriminator.
  final String revisionKind;

  /// Schema-shaped payload retaining typed before and after values.
  final String payloadJson;
  const Revision({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.rowRevision,
    required this.isDeleted,
    this.deletedAt,
    required this.meetingId,
    this.transcriptSegmentId,
    this.speakerAssignmentId,
    this.speakerId,
    required this.revisionKind,
    required this.payloadJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['row_revision'] = Variable<int>(rowRevision);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['meeting_id'] = Variable<String>(meetingId);
    if (!nullToAbsent || transcriptSegmentId != null) {
      map['transcript_segment_id'] = Variable<String>(transcriptSegmentId);
    }
    if (!nullToAbsent || speakerAssignmentId != null) {
      map['speaker_assignment_id'] = Variable<String>(speakerAssignmentId);
    }
    if (!nullToAbsent || speakerId != null) {
      map['speaker_id'] = Variable<String>(speakerId);
    }
    map['revision_kind'] = Variable<String>(revisionKind);
    map['payload_json'] = Variable<String>(payloadJson);
    return map;
  }

  RevisionsCompanion toCompanion(bool nullToAbsent) {
    return RevisionsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      rowRevision: Value(rowRevision),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      meetingId: Value(meetingId),
      transcriptSegmentId: transcriptSegmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(transcriptSegmentId),
      speakerAssignmentId: speakerAssignmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(speakerAssignmentId),
      speakerId: speakerId == null && nullToAbsent
          ? const Value.absent()
          : Value(speakerId),
      revisionKind: Value(revisionKind),
      payloadJson: Value(payloadJson),
    );
  }

  factory Revision.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Revision(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      rowRevision: serializer.fromJson<int>(json['rowRevision']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      meetingId: serializer.fromJson<String>(json['meetingId']),
      transcriptSegmentId: serializer.fromJson<String?>(
        json['transcriptSegmentId'],
      ),
      speakerAssignmentId: serializer.fromJson<String?>(
        json['speakerAssignmentId'],
      ),
      speakerId: serializer.fromJson<String?>(json['speakerId']),
      revisionKind: serializer.fromJson<String>(json['revisionKind']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'rowRevision': serializer.toJson<int>(rowRevision),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'meetingId': serializer.toJson<String>(meetingId),
      'transcriptSegmentId': serializer.toJson<String?>(transcriptSegmentId),
      'speakerAssignmentId': serializer.toJson<String?>(speakerAssignmentId),
      'speakerId': serializer.toJson<String?>(speakerId),
      'revisionKind': serializer.toJson<String>(revisionKind),
      'payloadJson': serializer.toJson<String>(payloadJson),
    };
  }

  Revision copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    int? rowRevision,
    bool? isDeleted,
    Value<int?> deletedAt = const Value.absent(),
    String? meetingId,
    Value<String?> transcriptSegmentId = const Value.absent(),
    Value<String?> speakerAssignmentId = const Value.absent(),
    Value<String?> speakerId = const Value.absent(),
    String? revisionKind,
    String? payloadJson,
  }) => Revision(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    rowRevision: rowRevision ?? this.rowRevision,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    meetingId: meetingId ?? this.meetingId,
    transcriptSegmentId: transcriptSegmentId.present
        ? transcriptSegmentId.value
        : this.transcriptSegmentId,
    speakerAssignmentId: speakerAssignmentId.present
        ? speakerAssignmentId.value
        : this.speakerAssignmentId,
    speakerId: speakerId.present ? speakerId.value : this.speakerId,
    revisionKind: revisionKind ?? this.revisionKind,
    payloadJson: payloadJson ?? this.payloadJson,
  );
  Revision copyWithCompanion(RevisionsCompanion data) {
    return Revision(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      rowRevision: data.rowRevision.present
          ? data.rowRevision.value
          : this.rowRevision,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      transcriptSegmentId: data.transcriptSegmentId.present
          ? data.transcriptSegmentId.value
          : this.transcriptSegmentId,
      speakerAssignmentId: data.speakerAssignmentId.present
          ? data.speakerAssignmentId.value
          : this.speakerAssignmentId,
      speakerId: data.speakerId.present ? data.speakerId.value : this.speakerId,
      revisionKind: data.revisionKind.present
          ? data.revisionKind.value
          : this.revisionKind,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Revision(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('meetingId: $meetingId, ')
          ..write('transcriptSegmentId: $transcriptSegmentId, ')
          ..write('speakerAssignmentId: $speakerAssignmentId, ')
          ..write('speakerId: $speakerId, ')
          ..write('revisionKind: $revisionKind, ')
          ..write('payloadJson: $payloadJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    meetingId,
    transcriptSegmentId,
    speakerAssignmentId,
    speakerId,
    revisionKind,
    payloadJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Revision &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.rowRevision == this.rowRevision &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt &&
          other.meetingId == this.meetingId &&
          other.transcriptSegmentId == this.transcriptSegmentId &&
          other.speakerAssignmentId == this.speakerAssignmentId &&
          other.speakerId == this.speakerId &&
          other.revisionKind == this.revisionKind &&
          other.payloadJson == this.payloadJson);
}

class RevisionsCompanion extends UpdateCompanion<Revision> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowRevision;
  final Value<bool> isDeleted;
  final Value<int?> deletedAt;
  final Value<String> meetingId;
  final Value<String?> transcriptSegmentId;
  final Value<String?> speakerAssignmentId;
  final Value<String?> speakerId;
  final Value<String> revisionKind;
  final Value<String> payloadJson;
  final Value<int> rowid;
  const RevisionsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.transcriptSegmentId = const Value.absent(),
    this.speakerAssignmentId = const Value.absent(),
    this.speakerId = const Value.absent(),
    this.revisionKind = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RevisionsCompanion.insert({
    required String id,
    required int createdAt,
    required int updatedAt,
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String meetingId,
    this.transcriptSegmentId = const Value.absent(),
    this.speakerAssignmentId = const Value.absent(),
    this.speakerId = const Value.absent(),
    required String revisionKind,
    required String payloadJson,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       meetingId = Value(meetingId),
       revisionKind = Value(revisionKind),
       payloadJson = Value(payloadJson);
  static Insertable<Revision> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowRevision,
    Expression<bool>? isDeleted,
    Expression<int>? deletedAt,
    Expression<String>? meetingId,
    Expression<String>? transcriptSegmentId,
    Expression<String>? speakerAssignmentId,
    Expression<String>? speakerId,
    Expression<String>? revisionKind,
    Expression<String>? payloadJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowRevision != null) 'row_revision': rowRevision,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (meetingId != null) 'meeting_id': meetingId,
      if (transcriptSegmentId != null)
        'transcript_segment_id': transcriptSegmentId,
      if (speakerAssignmentId != null)
        'speaker_assignment_id': speakerAssignmentId,
      if (speakerId != null) 'speaker_id': speakerId,
      if (revisionKind != null) 'revision_kind': revisionKind,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RevisionsCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowRevision,
    Value<bool>? isDeleted,
    Value<int?>? deletedAt,
    Value<String>? meetingId,
    Value<String?>? transcriptSegmentId,
    Value<String?>? speakerAssignmentId,
    Value<String?>? speakerId,
    Value<String>? revisionKind,
    Value<String>? payloadJson,
    Value<int>? rowid,
  }) {
    return RevisionsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowRevision: rowRevision ?? this.rowRevision,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      meetingId: meetingId ?? this.meetingId,
      transcriptSegmentId: transcriptSegmentId ?? this.transcriptSegmentId,
      speakerAssignmentId: speakerAssignmentId ?? this.speakerAssignmentId,
      speakerId: speakerId ?? this.speakerId,
      revisionKind: revisionKind ?? this.revisionKind,
      payloadJson: payloadJson ?? this.payloadJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowRevision.present) {
      map['row_revision'] = Variable<int>(rowRevision.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (meetingId.present) {
      map['meeting_id'] = Variable<String>(meetingId.value);
    }
    if (transcriptSegmentId.present) {
      map['transcript_segment_id'] = Variable<String>(
        transcriptSegmentId.value,
      );
    }
    if (speakerAssignmentId.present) {
      map['speaker_assignment_id'] = Variable<String>(
        speakerAssignmentId.value,
      );
    }
    if (speakerId.present) {
      map['speaker_id'] = Variable<String>(speakerId.value);
    }
    if (revisionKind.present) {
      map['revision_kind'] = Variable<String>(revisionKind.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RevisionsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('meetingId: $meetingId, ')
          ..write('transcriptSegmentId: $transcriptSegmentId, ')
          ..write('speakerAssignmentId: $speakerAssignmentId, ')
          ..write('speakerId: $speakerId, ')
          ..write('revisionKind: $revisionKind, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProcessingJobsTable extends ProcessingJobs
    with TableInfo<$ProcessingJobsTable, ProcessingJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProcessingJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (created_at >= 0)',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (updated_at >= created_at)',
  );
  static const VerificationMeta _rowRevisionMeta = const VerificationMeta(
    'rowRevision',
  );
  @override
  late final GeneratedColumn<int> rowRevision = GeneratedColumn<int>(
    'row_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (row_revision >= 0)',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT 0 CHECK ((is_deleted = 0 AND deleted_at IS NULL) OR (is_deleted = 1 AND deleted_at IS NOT NULL))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NULL CHECK (deleted_at IS NULL OR deleted_at >= 0)',
  );
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<String> meetingId = GeneratedColumn<String>(
    'meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meetings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _jobKindMeta = const VerificationMeta(
    'jobKind',
  );
  @override
  late final GeneratedColumn<String> jobKind = GeneratedColumn<String>(
    'job_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jobStateMeta = const VerificationMeta(
    'jobState',
  );
  @override
  late final GeneratedColumn<String> jobState = GeneratedColumn<String>(
    'job_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reasonCodeMeta = const VerificationMeta(
    'reasonCode',
  );
  @override
  late final GeneratedColumn<String> reasonCode = GeneratedColumn<String>(
    'reason_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _failureCodeMeta = const VerificationMeta(
    'failureCode',
  );
  @override
  late final GeneratedColumn<String> failureCode = GeneratedColumn<String>(
    'failure_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transcriptRunIdMeta = const VerificationMeta(
    'transcriptRunId',
  );
  @override
  late final GeneratedColumn<String> transcriptRunId = GeneratedColumn<String>(
    'transcript_run_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _diarizationRunIdMeta = const VerificationMeta(
    'diarizationRunId',
  );
  @override
  late final GeneratedColumn<String> diarizationRunId = GeneratedColumn<String>(
    'diarization_run_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES model_manifests (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _checkpointMeta = const VerificationMeta(
    'checkpoint',
  );
  @override
  late final GeneratedColumn<String> checkpoint = GeneratedColumn<String>(
    'checkpoint',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    meetingId,
    jobKind,
    jobState,
    progress,
    reasonCode,
    failureCode,
    transcriptRunId,
    diarizationRunId,
    modelId,
    checkpoint,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'processing_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProcessingJob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('row_revision')) {
      context.handle(
        _rowRevisionMeta,
        rowRevision.isAcceptableOrUnknown(
          data['row_revision']!,
          _rowRevisionMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('job_kind')) {
      context.handle(
        _jobKindMeta,
        jobKind.isAcceptableOrUnknown(data['job_kind']!, _jobKindMeta),
      );
    } else if (isInserting) {
      context.missing(_jobKindMeta);
    }
    if (data.containsKey('job_state')) {
      context.handle(
        _jobStateMeta,
        jobState.isAcceptableOrUnknown(data['job_state']!, _jobStateMeta),
      );
    } else if (isInserting) {
      context.missing(_jobStateMeta);
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('reason_code')) {
      context.handle(
        _reasonCodeMeta,
        reasonCode.isAcceptableOrUnknown(data['reason_code']!, _reasonCodeMeta),
      );
    }
    if (data.containsKey('failure_code')) {
      context.handle(
        _failureCodeMeta,
        failureCode.isAcceptableOrUnknown(
          data['failure_code']!,
          _failureCodeMeta,
        ),
      );
    }
    if (data.containsKey('transcript_run_id')) {
      context.handle(
        _transcriptRunIdMeta,
        transcriptRunId.isAcceptableOrUnknown(
          data['transcript_run_id']!,
          _transcriptRunIdMeta,
        ),
      );
    }
    if (data.containsKey('diarization_run_id')) {
      context.handle(
        _diarizationRunIdMeta,
        diarizationRunId.isAcceptableOrUnknown(
          data['diarization_run_id']!,
          _diarizationRunIdMeta,
        ),
      );
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    }
    if (data.containsKey('checkpoint')) {
      context.handle(
        _checkpointMeta,
        checkpoint.isAcceptableOrUnknown(data['checkpoint']!, _checkpointMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProcessingJob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProcessingJob(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      rowRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_revision'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      )!,
      jobKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}job_kind'],
      )!,
      jobState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}job_state'],
      )!,
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress'],
      ),
      reasonCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason_code'],
      ),
      failureCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failure_code'],
      ),
      transcriptRunId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript_run_id'],
      ),
      diarizationRunId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}diarization_run_id'],
      ),
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      ),
      checkpoint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checkpoint'],
      ),
    );
  }

  @override
  $ProcessingJobsTable createAlias(String alias) {
    return $ProcessingJobsTable(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
}

class ProcessingJob extends DataClass implements Insertable<ProcessingJob> {
  /// Stable UUID-style identifier.
  final String id;

  /// UTC creation instant in epoch milliseconds.
  final int createdAt;

  /// UTC last-update instant in epoch milliseconds.
  final int updatedAt;

  /// Monotonic row revision used by restore conflict handling.
  final int rowRevision;

  /// Whether this row is hidden by a soft delete.
  final bool isDeleted;

  /// UTC soft-delete instant in epoch milliseconds.
  final int? deletedAt;

  /// Owning meeting.
  final String meetingId;

  /// Requested processing capability.
  final String jobKind;

  /// Queued, running, paused, succeeded, or failed.
  final String jobState;

  /// Normalized completion fraction for active work.
  final double? progress;

  /// Stable pause reason.
  final String? reasonCode;

  /// Stable terminal failure code.
  final String? failureCode;

  /// Target transcript run for transcription or language work.
  final String? transcriptRunId;

  /// Target diarization run for speaker analysis work.
  final String? diarizationRunId;

  /// Model selected for inference, when applicable.
  final String? modelId;

  /// Opaque resumable checkpoint that excludes transcript content.
  final String? checkpoint;
  const ProcessingJob({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.rowRevision,
    required this.isDeleted,
    this.deletedAt,
    required this.meetingId,
    required this.jobKind,
    required this.jobState,
    this.progress,
    this.reasonCode,
    this.failureCode,
    this.transcriptRunId,
    this.diarizationRunId,
    this.modelId,
    this.checkpoint,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['row_revision'] = Variable<int>(rowRevision);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['meeting_id'] = Variable<String>(meetingId);
    map['job_kind'] = Variable<String>(jobKind);
    map['job_state'] = Variable<String>(jobState);
    if (!nullToAbsent || progress != null) {
      map['progress'] = Variable<double>(progress);
    }
    if (!nullToAbsent || reasonCode != null) {
      map['reason_code'] = Variable<String>(reasonCode);
    }
    if (!nullToAbsent || failureCode != null) {
      map['failure_code'] = Variable<String>(failureCode);
    }
    if (!nullToAbsent || transcriptRunId != null) {
      map['transcript_run_id'] = Variable<String>(transcriptRunId);
    }
    if (!nullToAbsent || diarizationRunId != null) {
      map['diarization_run_id'] = Variable<String>(diarizationRunId);
    }
    if (!nullToAbsent || modelId != null) {
      map['model_id'] = Variable<String>(modelId);
    }
    if (!nullToAbsent || checkpoint != null) {
      map['checkpoint'] = Variable<String>(checkpoint);
    }
    return map;
  }

  ProcessingJobsCompanion toCompanion(bool nullToAbsent) {
    return ProcessingJobsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      rowRevision: Value(rowRevision),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      meetingId: Value(meetingId),
      jobKind: Value(jobKind),
      jobState: Value(jobState),
      progress: progress == null && nullToAbsent
          ? const Value.absent()
          : Value(progress),
      reasonCode: reasonCode == null && nullToAbsent
          ? const Value.absent()
          : Value(reasonCode),
      failureCode: failureCode == null && nullToAbsent
          ? const Value.absent()
          : Value(failureCode),
      transcriptRunId: transcriptRunId == null && nullToAbsent
          ? const Value.absent()
          : Value(transcriptRunId),
      diarizationRunId: diarizationRunId == null && nullToAbsent
          ? const Value.absent()
          : Value(diarizationRunId),
      modelId: modelId == null && nullToAbsent
          ? const Value.absent()
          : Value(modelId),
      checkpoint: checkpoint == null && nullToAbsent
          ? const Value.absent()
          : Value(checkpoint),
    );
  }

  factory ProcessingJob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProcessingJob(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      rowRevision: serializer.fromJson<int>(json['rowRevision']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      meetingId: serializer.fromJson<String>(json['meetingId']),
      jobKind: serializer.fromJson<String>(json['jobKind']),
      jobState: serializer.fromJson<String>(json['jobState']),
      progress: serializer.fromJson<double?>(json['progress']),
      reasonCode: serializer.fromJson<String?>(json['reasonCode']),
      failureCode: serializer.fromJson<String?>(json['failureCode']),
      transcriptRunId: serializer.fromJson<String?>(json['transcriptRunId']),
      diarizationRunId: serializer.fromJson<String?>(json['diarizationRunId']),
      modelId: serializer.fromJson<String?>(json['modelId']),
      checkpoint: serializer.fromJson<String?>(json['checkpoint']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'rowRevision': serializer.toJson<int>(rowRevision),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'meetingId': serializer.toJson<String>(meetingId),
      'jobKind': serializer.toJson<String>(jobKind),
      'jobState': serializer.toJson<String>(jobState),
      'progress': serializer.toJson<double?>(progress),
      'reasonCode': serializer.toJson<String?>(reasonCode),
      'failureCode': serializer.toJson<String?>(failureCode),
      'transcriptRunId': serializer.toJson<String?>(transcriptRunId),
      'diarizationRunId': serializer.toJson<String?>(diarizationRunId),
      'modelId': serializer.toJson<String?>(modelId),
      'checkpoint': serializer.toJson<String?>(checkpoint),
    };
  }

  ProcessingJob copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    int? rowRevision,
    bool? isDeleted,
    Value<int?> deletedAt = const Value.absent(),
    String? meetingId,
    String? jobKind,
    String? jobState,
    Value<double?> progress = const Value.absent(),
    Value<String?> reasonCode = const Value.absent(),
    Value<String?> failureCode = const Value.absent(),
    Value<String?> transcriptRunId = const Value.absent(),
    Value<String?> diarizationRunId = const Value.absent(),
    Value<String?> modelId = const Value.absent(),
    Value<String?> checkpoint = const Value.absent(),
  }) => ProcessingJob(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    rowRevision: rowRevision ?? this.rowRevision,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    meetingId: meetingId ?? this.meetingId,
    jobKind: jobKind ?? this.jobKind,
    jobState: jobState ?? this.jobState,
    progress: progress.present ? progress.value : this.progress,
    reasonCode: reasonCode.present ? reasonCode.value : this.reasonCode,
    failureCode: failureCode.present ? failureCode.value : this.failureCode,
    transcriptRunId: transcriptRunId.present
        ? transcriptRunId.value
        : this.transcriptRunId,
    diarizationRunId: diarizationRunId.present
        ? diarizationRunId.value
        : this.diarizationRunId,
    modelId: modelId.present ? modelId.value : this.modelId,
    checkpoint: checkpoint.present ? checkpoint.value : this.checkpoint,
  );
  ProcessingJob copyWithCompanion(ProcessingJobsCompanion data) {
    return ProcessingJob(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      rowRevision: data.rowRevision.present
          ? data.rowRevision.value
          : this.rowRevision,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      jobKind: data.jobKind.present ? data.jobKind.value : this.jobKind,
      jobState: data.jobState.present ? data.jobState.value : this.jobState,
      progress: data.progress.present ? data.progress.value : this.progress,
      reasonCode: data.reasonCode.present
          ? data.reasonCode.value
          : this.reasonCode,
      failureCode: data.failureCode.present
          ? data.failureCode.value
          : this.failureCode,
      transcriptRunId: data.transcriptRunId.present
          ? data.transcriptRunId.value
          : this.transcriptRunId,
      diarizationRunId: data.diarizationRunId.present
          ? data.diarizationRunId.value
          : this.diarizationRunId,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      checkpoint: data.checkpoint.present
          ? data.checkpoint.value
          : this.checkpoint,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProcessingJob(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('meetingId: $meetingId, ')
          ..write('jobKind: $jobKind, ')
          ..write('jobState: $jobState, ')
          ..write('progress: $progress, ')
          ..write('reasonCode: $reasonCode, ')
          ..write('failureCode: $failureCode, ')
          ..write('transcriptRunId: $transcriptRunId, ')
          ..write('diarizationRunId: $diarizationRunId, ')
          ..write('modelId: $modelId, ')
          ..write('checkpoint: $checkpoint')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    meetingId,
    jobKind,
    jobState,
    progress,
    reasonCode,
    failureCode,
    transcriptRunId,
    diarizationRunId,
    modelId,
    checkpoint,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProcessingJob &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.rowRevision == this.rowRevision &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt &&
          other.meetingId == this.meetingId &&
          other.jobKind == this.jobKind &&
          other.jobState == this.jobState &&
          other.progress == this.progress &&
          other.reasonCode == this.reasonCode &&
          other.failureCode == this.failureCode &&
          other.transcriptRunId == this.transcriptRunId &&
          other.diarizationRunId == this.diarizationRunId &&
          other.modelId == this.modelId &&
          other.checkpoint == this.checkpoint);
}

class ProcessingJobsCompanion extends UpdateCompanion<ProcessingJob> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowRevision;
  final Value<bool> isDeleted;
  final Value<int?> deletedAt;
  final Value<String> meetingId;
  final Value<String> jobKind;
  final Value<String> jobState;
  final Value<double?> progress;
  final Value<String?> reasonCode;
  final Value<String?> failureCode;
  final Value<String?> transcriptRunId;
  final Value<String?> diarizationRunId;
  final Value<String?> modelId;
  final Value<String?> checkpoint;
  final Value<int> rowid;
  const ProcessingJobsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.jobKind = const Value.absent(),
    this.jobState = const Value.absent(),
    this.progress = const Value.absent(),
    this.reasonCode = const Value.absent(),
    this.failureCode = const Value.absent(),
    this.transcriptRunId = const Value.absent(),
    this.diarizationRunId = const Value.absent(),
    this.modelId = const Value.absent(),
    this.checkpoint = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProcessingJobsCompanion.insert({
    required String id,
    required int createdAt,
    required int updatedAt,
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String meetingId,
    required String jobKind,
    required String jobState,
    this.progress = const Value.absent(),
    this.reasonCode = const Value.absent(),
    this.failureCode = const Value.absent(),
    this.transcriptRunId = const Value.absent(),
    this.diarizationRunId = const Value.absent(),
    this.modelId = const Value.absent(),
    this.checkpoint = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       meetingId = Value(meetingId),
       jobKind = Value(jobKind),
       jobState = Value(jobState);
  static Insertable<ProcessingJob> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowRevision,
    Expression<bool>? isDeleted,
    Expression<int>? deletedAt,
    Expression<String>? meetingId,
    Expression<String>? jobKind,
    Expression<String>? jobState,
    Expression<double>? progress,
    Expression<String>? reasonCode,
    Expression<String>? failureCode,
    Expression<String>? transcriptRunId,
    Expression<String>? diarizationRunId,
    Expression<String>? modelId,
    Expression<String>? checkpoint,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowRevision != null) 'row_revision': rowRevision,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (meetingId != null) 'meeting_id': meetingId,
      if (jobKind != null) 'job_kind': jobKind,
      if (jobState != null) 'job_state': jobState,
      if (progress != null) 'progress': progress,
      if (reasonCode != null) 'reason_code': reasonCode,
      if (failureCode != null) 'failure_code': failureCode,
      if (transcriptRunId != null) 'transcript_run_id': transcriptRunId,
      if (diarizationRunId != null) 'diarization_run_id': diarizationRunId,
      if (modelId != null) 'model_id': modelId,
      if (checkpoint != null) 'checkpoint': checkpoint,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProcessingJobsCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowRevision,
    Value<bool>? isDeleted,
    Value<int?>? deletedAt,
    Value<String>? meetingId,
    Value<String>? jobKind,
    Value<String>? jobState,
    Value<double?>? progress,
    Value<String?>? reasonCode,
    Value<String?>? failureCode,
    Value<String?>? transcriptRunId,
    Value<String?>? diarizationRunId,
    Value<String?>? modelId,
    Value<String?>? checkpoint,
    Value<int>? rowid,
  }) {
    return ProcessingJobsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowRevision: rowRevision ?? this.rowRevision,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      meetingId: meetingId ?? this.meetingId,
      jobKind: jobKind ?? this.jobKind,
      jobState: jobState ?? this.jobState,
      progress: progress ?? this.progress,
      reasonCode: reasonCode ?? this.reasonCode,
      failureCode: failureCode ?? this.failureCode,
      transcriptRunId: transcriptRunId ?? this.transcriptRunId,
      diarizationRunId: diarizationRunId ?? this.diarizationRunId,
      modelId: modelId ?? this.modelId,
      checkpoint: checkpoint ?? this.checkpoint,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowRevision.present) {
      map['row_revision'] = Variable<int>(rowRevision.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (meetingId.present) {
      map['meeting_id'] = Variable<String>(meetingId.value);
    }
    if (jobKind.present) {
      map['job_kind'] = Variable<String>(jobKind.value);
    }
    if (jobState.present) {
      map['job_state'] = Variable<String>(jobState.value);
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (reasonCode.present) {
      map['reason_code'] = Variable<String>(reasonCode.value);
    }
    if (failureCode.present) {
      map['failure_code'] = Variable<String>(failureCode.value);
    }
    if (transcriptRunId.present) {
      map['transcript_run_id'] = Variable<String>(transcriptRunId.value);
    }
    if (diarizationRunId.present) {
      map['diarization_run_id'] = Variable<String>(diarizationRunId.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (checkpoint.present) {
      map['checkpoint'] = Variable<String>(checkpoint.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProcessingJobsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('meetingId: $meetingId, ')
          ..write('jobKind: $jobKind, ')
          ..write('jobState: $jobState, ')
          ..write('progress: $progress, ')
          ..write('reasonCode: $reasonCode, ')
          ..write('failureCode: $failureCode, ')
          ..write('transcriptRunId: $transcriptRunId, ')
          ..write('diarizationRunId: $diarizationRunId, ')
          ..write('modelId: $modelId, ')
          ..write('checkpoint: $checkpoint, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ModelCapabilityEntriesTable extends ModelCapabilityEntries
    with TableInfo<$ModelCapabilityEntriesTable, ModelCapabilityEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ModelCapabilityEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (created_at >= 0)',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (updated_at >= created_at)',
  );
  static const VerificationMeta _rowRevisionMeta = const VerificationMeta(
    'rowRevision',
  );
  @override
  late final GeneratedColumn<int> rowRevision = GeneratedColumn<int>(
    'row_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (row_revision >= 0)',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT 0 CHECK ((is_deleted = 0 AND deleted_at IS NULL) OR (is_deleted = 1 AND deleted_at IS NOT NULL))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NULL CHECK (deleted_at IS NULL OR deleted_at >= 0)',
  );
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES model_manifests (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _capabilityMeta = const VerificationMeta(
    'capability',
  );
  @override
  late final GeneratedColumn<String> capability = GeneratedColumn<String>(
    'capability',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    modelId,
    capability,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'model_capability_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ModelCapabilityEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('row_revision')) {
      context.handle(
        _rowRevisionMeta,
        rowRevision.isAcceptableOrUnknown(
          data['row_revision']!,
          _rowRevisionMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_modelIdMeta);
    }
    if (data.containsKey('capability')) {
      context.handle(
        _capabilityMeta,
        capability.isAcceptableOrUnknown(data['capability']!, _capabilityMeta),
      );
    } else if (isInserting) {
      context.missing(_capabilityMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ModelCapabilityEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ModelCapabilityEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      rowRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_revision'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      )!,
      capability: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capability'],
      )!,
    );
  }

  @override
  $ModelCapabilityEntriesTable createAlias(String alias) {
    return $ModelCapabilityEntriesTable(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
}

class ModelCapabilityEntry extends DataClass
    implements Insertable<ModelCapabilityEntry> {
  /// Stable UUID-style identifier.
  final String id;

  /// UTC creation instant in epoch milliseconds.
  final int createdAt;

  /// UTC last-update instant in epoch milliseconds.
  final int updatedAt;

  /// Monotonic row revision used by restore conflict handling.
  final int rowRevision;

  /// Whether this row is hidden by a soft delete.
  final bool isDeleted;

  /// UTC soft-delete instant in epoch milliseconds.
  final int? deletedAt;

  /// Owning model manifest.
  final String modelId;

  /// Capability name mirrored from the domain enum.
  final String capability;
  const ModelCapabilityEntry({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.rowRevision,
    required this.isDeleted,
    this.deletedAt,
    required this.modelId,
    required this.capability,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['row_revision'] = Variable<int>(rowRevision);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['model_id'] = Variable<String>(modelId);
    map['capability'] = Variable<String>(capability);
    return map;
  }

  ModelCapabilityEntriesCompanion toCompanion(bool nullToAbsent) {
    return ModelCapabilityEntriesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      rowRevision: Value(rowRevision),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      modelId: Value(modelId),
      capability: Value(capability),
    );
  }

  factory ModelCapabilityEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ModelCapabilityEntry(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      rowRevision: serializer.fromJson<int>(json['rowRevision']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      modelId: serializer.fromJson<String>(json['modelId']),
      capability: serializer.fromJson<String>(json['capability']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'rowRevision': serializer.toJson<int>(rowRevision),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'modelId': serializer.toJson<String>(modelId),
      'capability': serializer.toJson<String>(capability),
    };
  }

  ModelCapabilityEntry copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    int? rowRevision,
    bool? isDeleted,
    Value<int?> deletedAt = const Value.absent(),
    String? modelId,
    String? capability,
  }) => ModelCapabilityEntry(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    rowRevision: rowRevision ?? this.rowRevision,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    modelId: modelId ?? this.modelId,
    capability: capability ?? this.capability,
  );
  ModelCapabilityEntry copyWithCompanion(ModelCapabilityEntriesCompanion data) {
    return ModelCapabilityEntry(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      rowRevision: data.rowRevision.present
          ? data.rowRevision.value
          : this.rowRevision,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      capability: data.capability.present
          ? data.capability.value
          : this.capability,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ModelCapabilityEntry(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('modelId: $modelId, ')
          ..write('capability: $capability')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    modelId,
    capability,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelCapabilityEntry &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.rowRevision == this.rowRevision &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt &&
          other.modelId == this.modelId &&
          other.capability == this.capability);
}

class ModelCapabilityEntriesCompanion
    extends UpdateCompanion<ModelCapabilityEntry> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowRevision;
  final Value<bool> isDeleted;
  final Value<int?> deletedAt;
  final Value<String> modelId;
  final Value<String> capability;
  final Value<int> rowid;
  const ModelCapabilityEntriesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.modelId = const Value.absent(),
    this.capability = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ModelCapabilityEntriesCompanion.insert({
    required String id,
    required int createdAt,
    required int updatedAt,
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String modelId,
    required String capability,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       modelId = Value(modelId),
       capability = Value(capability);
  static Insertable<ModelCapabilityEntry> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowRevision,
    Expression<bool>? isDeleted,
    Expression<int>? deletedAt,
    Expression<String>? modelId,
    Expression<String>? capability,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowRevision != null) 'row_revision': rowRevision,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (modelId != null) 'model_id': modelId,
      if (capability != null) 'capability': capability,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ModelCapabilityEntriesCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowRevision,
    Value<bool>? isDeleted,
    Value<int?>? deletedAt,
    Value<String>? modelId,
    Value<String>? capability,
    Value<int>? rowid,
  }) {
    return ModelCapabilityEntriesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowRevision: rowRevision ?? this.rowRevision,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      modelId: modelId ?? this.modelId,
      capability: capability ?? this.capability,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowRevision.present) {
      map['row_revision'] = Variable<int>(rowRevision.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (capability.present) {
      map['capability'] = Variable<String>(capability.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ModelCapabilityEntriesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('modelId: $modelId, ')
          ..write('capability: $capability, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ModelModeEntriesTable extends ModelModeEntries
    with TableInfo<$ModelModeEntriesTable, ModelModeEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ModelModeEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (created_at >= 0)',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (updated_at >= created_at)',
  );
  static const VerificationMeta _rowRevisionMeta = const VerificationMeta(
    'rowRevision',
  );
  @override
  late final GeneratedColumn<int> rowRevision = GeneratedColumn<int>(
    'row_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (row_revision >= 0)',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT 0 CHECK ((is_deleted = 0 AND deleted_at IS NULL) OR (is_deleted = 1 AND deleted_at IS NOT NULL))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NULL CHECK (deleted_at IS NULL OR deleted_at >= 0)',
  );
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES model_manifests (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    modelId,
    mode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'model_mode_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ModelModeEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('row_revision')) {
      context.handle(
        _rowRevisionMeta,
        rowRevision.isAcceptableOrUnknown(
          data['row_revision']!,
          _rowRevisionMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_modelIdMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ModelModeEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ModelModeEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      rowRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_revision'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
    );
  }

  @override
  $ModelModeEntriesTable createAlias(String alias) {
    return $ModelModeEntriesTable(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
}

class ModelModeEntry extends DataClass implements Insertable<ModelModeEntry> {
  /// Stable UUID-style identifier.
  final String id;

  /// UTC creation instant in epoch milliseconds.
  final int createdAt;

  /// UTC last-update instant in epoch milliseconds.
  final int updatedAt;

  /// Monotonic row revision used by restore conflict handling.
  final int rowRevision;

  /// Whether this row is hidden by a soft delete.
  final bool isDeleted;

  /// UTC soft-delete instant in epoch milliseconds.
  final int? deletedAt;

  /// Owning model manifest.
  final String modelId;

  /// Enabled mode mirrored from the domain enum.
  final String mode;
  const ModelModeEntry({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.rowRevision,
    required this.isDeleted,
    this.deletedAt,
    required this.modelId,
    required this.mode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['row_revision'] = Variable<int>(rowRevision);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['model_id'] = Variable<String>(modelId);
    map['mode'] = Variable<String>(mode);
    return map;
  }

  ModelModeEntriesCompanion toCompanion(bool nullToAbsent) {
    return ModelModeEntriesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      rowRevision: Value(rowRevision),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      modelId: Value(modelId),
      mode: Value(mode),
    );
  }

  factory ModelModeEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ModelModeEntry(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      rowRevision: serializer.fromJson<int>(json['rowRevision']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      modelId: serializer.fromJson<String>(json['modelId']),
      mode: serializer.fromJson<String>(json['mode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'rowRevision': serializer.toJson<int>(rowRevision),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'modelId': serializer.toJson<String>(modelId),
      'mode': serializer.toJson<String>(mode),
    };
  }

  ModelModeEntry copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    int? rowRevision,
    bool? isDeleted,
    Value<int?> deletedAt = const Value.absent(),
    String? modelId,
    String? mode,
  }) => ModelModeEntry(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    rowRevision: rowRevision ?? this.rowRevision,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    modelId: modelId ?? this.modelId,
    mode: mode ?? this.mode,
  );
  ModelModeEntry copyWithCompanion(ModelModeEntriesCompanion data) {
    return ModelModeEntry(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      rowRevision: data.rowRevision.present
          ? data.rowRevision.value
          : this.rowRevision,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      mode: data.mode.present ? data.mode.value : this.mode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ModelModeEntry(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('modelId: $modelId, ')
          ..write('mode: $mode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    modelId,
    mode,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelModeEntry &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.rowRevision == this.rowRevision &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt &&
          other.modelId == this.modelId &&
          other.mode == this.mode);
}

class ModelModeEntriesCompanion extends UpdateCompanion<ModelModeEntry> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowRevision;
  final Value<bool> isDeleted;
  final Value<int?> deletedAt;
  final Value<String> modelId;
  final Value<String> mode;
  final Value<int> rowid;
  const ModelModeEntriesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.modelId = const Value.absent(),
    this.mode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ModelModeEntriesCompanion.insert({
    required String id,
    required int createdAt,
    required int updatedAt,
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String modelId,
    required String mode,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       modelId = Value(modelId),
       mode = Value(mode);
  static Insertable<ModelModeEntry> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowRevision,
    Expression<bool>? isDeleted,
    Expression<int>? deletedAt,
    Expression<String>? modelId,
    Expression<String>? mode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowRevision != null) 'row_revision': rowRevision,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (modelId != null) 'model_id': modelId,
      if (mode != null) 'mode': mode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ModelModeEntriesCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowRevision,
    Value<bool>? isDeleted,
    Value<int?>? deletedAt,
    Value<String>? modelId,
    Value<String>? mode,
    Value<int>? rowid,
  }) {
    return ModelModeEntriesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowRevision: rowRevision ?? this.rowRevision,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      modelId: modelId ?? this.modelId,
      mode: mode ?? this.mode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowRevision.present) {
      map['row_revision'] = Variable<int>(rowRevision.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ModelModeEntriesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('modelId: $modelId, ')
          ..write('mode: $mode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExportRecordsTable extends ExportRecords
    with TableInfo<$ExportRecordsTable, ExportRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExportRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (created_at >= 0)',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (updated_at >= created_at)',
  );
  static const VerificationMeta _rowRevisionMeta = const VerificationMeta(
    'rowRevision',
  );
  @override
  late final GeneratedColumn<int> rowRevision = GeneratedColumn<int>(
    'row_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (row_revision >= 0)',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT 0 CHECK ((is_deleted = 0 AND deleted_at IS NULL) OR (is_deleted = 1 AND deleted_at IS NOT NULL))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NULL CHECK (deleted_at IS NULL OR deleted_at >= 0)',
  );
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<String> meetingId = GeneratedColumn<String>(
    'meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meetings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exportStateMeta = const VerificationMeta(
    'exportState',
  );
  @override
  late final GeneratedColumn<String> exportState = GeneratedColumn<String>(
    'export_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _failureCodeMeta = const VerificationMeta(
    'failureCode',
  );
  @override
  late final GeneratedColumn<String> failureCode = GeneratedColumn<String>(
    'failure_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    meetingId,
    format,
    exportState,
    relativePath,
    bytes,
    failureCode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'export_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExportRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('row_revision')) {
      context.handle(
        _rowRevisionMeta,
        rowRevision.isAcceptableOrUnknown(
          data['row_revision']!,
          _rowRevisionMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('export_state')) {
      context.handle(
        _exportStateMeta,
        exportState.isAcceptableOrUnknown(
          data['export_state']!,
          _exportStateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_exportStateMeta);
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    }
    if (data.containsKey('failure_code')) {
      context.handle(
        _failureCodeMeta,
        failureCode.isAcceptableOrUnknown(
          data['failure_code']!,
          _failureCodeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExportRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExportRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      rowRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_revision'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      )!,
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      exportState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}export_state'],
      )!,
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      ),
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes'],
      ),
      failureCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failure_code'],
      ),
    );
  }

  @override
  $ExportRecordsTable createAlias(String alias) {
    return $ExportRecordsTable(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
}

class ExportRecord extends DataClass implements Insertable<ExportRecord> {
  /// Stable UUID-style identifier.
  final String id;

  /// UTC creation instant in epoch milliseconds.
  final int createdAt;

  /// UTC last-update instant in epoch milliseconds.
  final int updatedAt;

  /// Monotonic row revision used by restore conflict handling.
  final int rowRevision;

  /// Whether this row is hidden by a soft delete.
  final bool isDeleted;

  /// UTC soft-delete instant in epoch milliseconds.
  final int? deletedAt;

  /// Owning meeting.
  final String meetingId;

  /// Requested export representation.
  final String format;

  /// Pending, completed, or failed.
  final String exportState;

  /// App-relative private staging path for a completed export.
  final String? relativePath;

  /// Completed export byte length.
  final int? bytes;

  /// Stable structured failure code.
  final String? failureCode;
  const ExportRecord({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.rowRevision,
    required this.isDeleted,
    this.deletedAt,
    required this.meetingId,
    required this.format,
    required this.exportState,
    this.relativePath,
    this.bytes,
    this.failureCode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['row_revision'] = Variable<int>(rowRevision);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['meeting_id'] = Variable<String>(meetingId);
    map['format'] = Variable<String>(format);
    map['export_state'] = Variable<String>(exportState);
    if (!nullToAbsent || relativePath != null) {
      map['relative_path'] = Variable<String>(relativePath);
    }
    if (!nullToAbsent || bytes != null) {
      map['bytes'] = Variable<int>(bytes);
    }
    if (!nullToAbsent || failureCode != null) {
      map['failure_code'] = Variable<String>(failureCode);
    }
    return map;
  }

  ExportRecordsCompanion toCompanion(bool nullToAbsent) {
    return ExportRecordsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      rowRevision: Value(rowRevision),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      meetingId: Value(meetingId),
      format: Value(format),
      exportState: Value(exportState),
      relativePath: relativePath == null && nullToAbsent
          ? const Value.absent()
          : Value(relativePath),
      bytes: bytes == null && nullToAbsent
          ? const Value.absent()
          : Value(bytes),
      failureCode: failureCode == null && nullToAbsent
          ? const Value.absent()
          : Value(failureCode),
    );
  }

  factory ExportRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExportRecord(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      rowRevision: serializer.fromJson<int>(json['rowRevision']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      meetingId: serializer.fromJson<String>(json['meetingId']),
      format: serializer.fromJson<String>(json['format']),
      exportState: serializer.fromJson<String>(json['exportState']),
      relativePath: serializer.fromJson<String?>(json['relativePath']),
      bytes: serializer.fromJson<int?>(json['bytes']),
      failureCode: serializer.fromJson<String?>(json['failureCode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'rowRevision': serializer.toJson<int>(rowRevision),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'meetingId': serializer.toJson<String>(meetingId),
      'format': serializer.toJson<String>(format),
      'exportState': serializer.toJson<String>(exportState),
      'relativePath': serializer.toJson<String?>(relativePath),
      'bytes': serializer.toJson<int?>(bytes),
      'failureCode': serializer.toJson<String?>(failureCode),
    };
  }

  ExportRecord copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    int? rowRevision,
    bool? isDeleted,
    Value<int?> deletedAt = const Value.absent(),
    String? meetingId,
    String? format,
    String? exportState,
    Value<String?> relativePath = const Value.absent(),
    Value<int?> bytes = const Value.absent(),
    Value<String?> failureCode = const Value.absent(),
  }) => ExportRecord(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    rowRevision: rowRevision ?? this.rowRevision,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    meetingId: meetingId ?? this.meetingId,
    format: format ?? this.format,
    exportState: exportState ?? this.exportState,
    relativePath: relativePath.present ? relativePath.value : this.relativePath,
    bytes: bytes.present ? bytes.value : this.bytes,
    failureCode: failureCode.present ? failureCode.value : this.failureCode,
  );
  ExportRecord copyWithCompanion(ExportRecordsCompanion data) {
    return ExportRecord(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      rowRevision: data.rowRevision.present
          ? data.rowRevision.value
          : this.rowRevision,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      format: data.format.present ? data.format.value : this.format,
      exportState: data.exportState.present
          ? data.exportState.value
          : this.exportState,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      failureCode: data.failureCode.present
          ? data.failureCode.value
          : this.failureCode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExportRecord(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('meetingId: $meetingId, ')
          ..write('format: $format, ')
          ..write('exportState: $exportState, ')
          ..write('relativePath: $relativePath, ')
          ..write('bytes: $bytes, ')
          ..write('failureCode: $failureCode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    meetingId,
    format,
    exportState,
    relativePath,
    bytes,
    failureCode,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExportRecord &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.rowRevision == this.rowRevision &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt &&
          other.meetingId == this.meetingId &&
          other.format == this.format &&
          other.exportState == this.exportState &&
          other.relativePath == this.relativePath &&
          other.bytes == this.bytes &&
          other.failureCode == this.failureCode);
}

class ExportRecordsCompanion extends UpdateCompanion<ExportRecord> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowRevision;
  final Value<bool> isDeleted;
  final Value<int?> deletedAt;
  final Value<String> meetingId;
  final Value<String> format;
  final Value<String> exportState;
  final Value<String?> relativePath;
  final Value<int?> bytes;
  final Value<String?> failureCode;
  final Value<int> rowid;
  const ExportRecordsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.format = const Value.absent(),
    this.exportState = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.bytes = const Value.absent(),
    this.failureCode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExportRecordsCompanion.insert({
    required String id,
    required int createdAt,
    required int updatedAt,
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String meetingId,
    required String format,
    required String exportState,
    this.relativePath = const Value.absent(),
    this.bytes = const Value.absent(),
    this.failureCode = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       meetingId = Value(meetingId),
       format = Value(format),
       exportState = Value(exportState);
  static Insertable<ExportRecord> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowRevision,
    Expression<bool>? isDeleted,
    Expression<int>? deletedAt,
    Expression<String>? meetingId,
    Expression<String>? format,
    Expression<String>? exportState,
    Expression<String>? relativePath,
    Expression<int>? bytes,
    Expression<String>? failureCode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowRevision != null) 'row_revision': rowRevision,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (meetingId != null) 'meeting_id': meetingId,
      if (format != null) 'format': format,
      if (exportState != null) 'export_state': exportState,
      if (relativePath != null) 'relative_path': relativePath,
      if (bytes != null) 'bytes': bytes,
      if (failureCode != null) 'failure_code': failureCode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExportRecordsCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowRevision,
    Value<bool>? isDeleted,
    Value<int?>? deletedAt,
    Value<String>? meetingId,
    Value<String>? format,
    Value<String>? exportState,
    Value<String?>? relativePath,
    Value<int?>? bytes,
    Value<String?>? failureCode,
    Value<int>? rowid,
  }) {
    return ExportRecordsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowRevision: rowRevision ?? this.rowRevision,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      meetingId: meetingId ?? this.meetingId,
      format: format ?? this.format,
      exportState: exportState ?? this.exportState,
      relativePath: relativePath ?? this.relativePath,
      bytes: bytes ?? this.bytes,
      failureCode: failureCode ?? this.failureCode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowRevision.present) {
      map['row_revision'] = Variable<int>(rowRevision.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (meetingId.present) {
      map['meeting_id'] = Variable<String>(meetingId.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (exportState.present) {
      map['export_state'] = Variable<String>(exportState.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (failureCode.present) {
      map['failure_code'] = Variable<String>(failureCode.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExportRecordsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('meetingId: $meetingId, ')
          ..write('format: $format, ')
          ..write('exportState: $exportState, ')
          ..write('relativePath: $relativePath, ')
          ..write('bytes: $bytes, ')
          ..write('failureCode: $failureCode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BackupRecordsTable extends BackupRecords
    with TableInfo<$BackupRecordsTable, BackupRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BackupRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (created_at >= 0)',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (updated_at >= created_at)',
  );
  static const VerificationMeta _rowRevisionMeta = const VerificationMeta(
    'rowRevision',
  );
  @override
  late final GeneratedColumn<int> rowRevision = GeneratedColumn<int>(
    'row_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (row_revision >= 0)',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT 0 CHECK ((is_deleted = 0 AND deleted_at IS NULL) OR (is_deleted = 1 AND deleted_at IS NOT NULL))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NULL CHECK (deleted_at IS NULL OR deleted_at >= 0)',
  );
  static const VerificationMeta _backupStateMeta = const VerificationMeta(
    'backupState',
  );
  @override
  late final GeneratedColumn<String> backupState = GeneratedColumn<String>(
    'backup_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _failureCodeMeta = const VerificationMeta(
    'failureCode',
  );
  @override
  late final GeneratedColumn<String> failureCode = GeneratedColumn<String>(
    'failure_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    backupState,
    relativePath,
    sha256,
    bytes,
    failureCode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'backup_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<BackupRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('row_revision')) {
      context.handle(
        _rowRevisionMeta,
        rowRevision.isAcceptableOrUnknown(
          data['row_revision']!,
          _rowRevisionMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('backup_state')) {
      context.handle(
        _backupStateMeta,
        backupState.isAcceptableOrUnknown(
          data['backup_state']!,
          _backupStateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_backupStateMeta);
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    }
    if (data.containsKey('failure_code')) {
      context.handle(
        _failureCodeMeta,
        failureCode.isAcceptableOrUnknown(
          data['failure_code']!,
          _failureCodeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BackupRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BackupRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      rowRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_revision'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      backupState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backup_state'],
      )!,
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      ),
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      ),
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes'],
      ),
      failureCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failure_code'],
      ),
    );
  }

  @override
  $BackupRecordsTable createAlias(String alias) {
    return $BackupRecordsTable(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
}

class BackupRecord extends DataClass implements Insertable<BackupRecord> {
  /// Stable UUID-style identifier.
  final String id;

  /// UTC creation instant in epoch milliseconds.
  final int createdAt;

  /// UTC last-update instant in epoch milliseconds.
  final int updatedAt;

  /// Monotonic row revision used by restore conflict handling.
  final int rowRevision;

  /// Whether this row is hidden by a soft delete.
  final bool isDeleted;

  /// UTC soft-delete instant in epoch milliseconds.
  final int? deletedAt;

  /// Pending, completed, or failed.
  final String backupState;

  /// App-relative private staging path for a completed backup.
  final String? relativePath;

  /// SHA-256 of the portable archive when completed.
  final String? sha256;

  /// Completed archive byte length.
  final int? bytes;

  /// Stable structured failure code.
  final String? failureCode;
  const BackupRecord({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.rowRevision,
    required this.isDeleted,
    this.deletedAt,
    required this.backupState,
    this.relativePath,
    this.sha256,
    this.bytes,
    this.failureCode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['row_revision'] = Variable<int>(rowRevision);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['backup_state'] = Variable<String>(backupState);
    if (!nullToAbsent || relativePath != null) {
      map['relative_path'] = Variable<String>(relativePath);
    }
    if (!nullToAbsent || sha256 != null) {
      map['sha256'] = Variable<String>(sha256);
    }
    if (!nullToAbsent || bytes != null) {
      map['bytes'] = Variable<int>(bytes);
    }
    if (!nullToAbsent || failureCode != null) {
      map['failure_code'] = Variable<String>(failureCode);
    }
    return map;
  }

  BackupRecordsCompanion toCompanion(bool nullToAbsent) {
    return BackupRecordsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      rowRevision: Value(rowRevision),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      backupState: Value(backupState),
      relativePath: relativePath == null && nullToAbsent
          ? const Value.absent()
          : Value(relativePath),
      sha256: sha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(sha256),
      bytes: bytes == null && nullToAbsent
          ? const Value.absent()
          : Value(bytes),
      failureCode: failureCode == null && nullToAbsent
          ? const Value.absent()
          : Value(failureCode),
    );
  }

  factory BackupRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BackupRecord(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      rowRevision: serializer.fromJson<int>(json['rowRevision']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      backupState: serializer.fromJson<String>(json['backupState']),
      relativePath: serializer.fromJson<String?>(json['relativePath']),
      sha256: serializer.fromJson<String?>(json['sha256']),
      bytes: serializer.fromJson<int?>(json['bytes']),
      failureCode: serializer.fromJson<String?>(json['failureCode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'rowRevision': serializer.toJson<int>(rowRevision),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'backupState': serializer.toJson<String>(backupState),
      'relativePath': serializer.toJson<String?>(relativePath),
      'sha256': serializer.toJson<String?>(sha256),
      'bytes': serializer.toJson<int?>(bytes),
      'failureCode': serializer.toJson<String?>(failureCode),
    };
  }

  BackupRecord copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    int? rowRevision,
    bool? isDeleted,
    Value<int?> deletedAt = const Value.absent(),
    String? backupState,
    Value<String?> relativePath = const Value.absent(),
    Value<String?> sha256 = const Value.absent(),
    Value<int?> bytes = const Value.absent(),
    Value<String?> failureCode = const Value.absent(),
  }) => BackupRecord(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    rowRevision: rowRevision ?? this.rowRevision,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    backupState: backupState ?? this.backupState,
    relativePath: relativePath.present ? relativePath.value : this.relativePath,
    sha256: sha256.present ? sha256.value : this.sha256,
    bytes: bytes.present ? bytes.value : this.bytes,
    failureCode: failureCode.present ? failureCode.value : this.failureCode,
  );
  BackupRecord copyWithCompanion(BackupRecordsCompanion data) {
    return BackupRecord(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      rowRevision: data.rowRevision.present
          ? data.rowRevision.value
          : this.rowRevision,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      backupState: data.backupState.present
          ? data.backupState.value
          : this.backupState,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      failureCode: data.failureCode.present
          ? data.failureCode.value
          : this.failureCode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BackupRecord(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('backupState: $backupState, ')
          ..write('relativePath: $relativePath, ')
          ..write('sha256: $sha256, ')
          ..write('bytes: $bytes, ')
          ..write('failureCode: $failureCode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    rowRevision,
    isDeleted,
    deletedAt,
    backupState,
    relativePath,
    sha256,
    bytes,
    failureCode,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BackupRecord &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.rowRevision == this.rowRevision &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt &&
          other.backupState == this.backupState &&
          other.relativePath == this.relativePath &&
          other.sha256 == this.sha256 &&
          other.bytes == this.bytes &&
          other.failureCode == this.failureCode);
}

class BackupRecordsCompanion extends UpdateCompanion<BackupRecord> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowRevision;
  final Value<bool> isDeleted;
  final Value<int?> deletedAt;
  final Value<String> backupState;
  final Value<String?> relativePath;
  final Value<String?> sha256;
  final Value<int?> bytes;
  final Value<String?> failureCode;
  final Value<int> rowid;
  const BackupRecordsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.backupState = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.bytes = const Value.absent(),
    this.failureCode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BackupRecordsCompanion.insert({
    required String id,
    required int createdAt,
    required int updatedAt,
    this.rowRevision = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String backupState,
    this.relativePath = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.bytes = const Value.absent(),
    this.failureCode = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       backupState = Value(backupState);
  static Insertable<BackupRecord> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowRevision,
    Expression<bool>? isDeleted,
    Expression<int>? deletedAt,
    Expression<String>? backupState,
    Expression<String>? relativePath,
    Expression<String>? sha256,
    Expression<int>? bytes,
    Expression<String>? failureCode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowRevision != null) 'row_revision': rowRevision,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (backupState != null) 'backup_state': backupState,
      if (relativePath != null) 'relative_path': relativePath,
      if (sha256 != null) 'sha256': sha256,
      if (bytes != null) 'bytes': bytes,
      if (failureCode != null) 'failure_code': failureCode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BackupRecordsCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowRevision,
    Value<bool>? isDeleted,
    Value<int?>? deletedAt,
    Value<String>? backupState,
    Value<String?>? relativePath,
    Value<String?>? sha256,
    Value<int?>? bytes,
    Value<String?>? failureCode,
    Value<int>? rowid,
  }) {
    return BackupRecordsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowRevision: rowRevision ?? this.rowRevision,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      backupState: backupState ?? this.backupState,
      relativePath: relativePath ?? this.relativePath,
      sha256: sha256 ?? this.sha256,
      bytes: bytes ?? this.bytes,
      failureCode: failureCode ?? this.failureCode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowRevision.present) {
      map['row_revision'] = Variable<int>(rowRevision.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (backupState.present) {
      map['backup_state'] = Variable<String>(backupState.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (failureCode.present) {
      map['failure_code'] = Variable<String>(failureCode.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BackupRecordsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('backupState: $backupState, ')
          ..write('relativePath: $relativePath, ')
          ..write('sha256: $sha256, ')
          ..write('bytes: $bytes, ')
          ..write('failureCode: $failureCode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MeetingsTable meetings = $MeetingsTable(this);
  late final $AudioSegmentsTable audioSegments = $AudioSegmentsTable(this);
  late final $SessionEventsTable sessionEvents = $SessionEventsTable(this);
  late final $BookmarksTable bookmarks = $BookmarksTable(this);
  late final $ModelManifestsTable modelManifests = $ModelManifestsTable(this);
  late final $TranscriptRunsTable transcriptRuns = $TranscriptRunsTable(this);
  late final $MeetingTranscriptSelectionsTable meetingTranscriptSelections =
      $MeetingTranscriptSelectionsTable(this);
  late final $DiarizationRunsTable diarizationRuns = $DiarizationRunsTable(
    this,
  );
  late final $SpeakersTable speakers = $SpeakersTable(this);
  late final $TranscriptSegmentsTable transcriptSegments =
      $TranscriptSegmentsTable(this);
  late final $LanguageDecisionsTable languageDecisions =
      $LanguageDecisionsTable(this);
  late final $TranscriptLanguageSelectionsTable transcriptLanguageSelections =
      $TranscriptLanguageSelectionsTable(this);
  late final $SpeakerAssignmentsTable speakerAssignments =
      $SpeakerAssignmentsTable(this);
  late final $RevisionsTable revisions = $RevisionsTable(this);
  late final $ProcessingJobsTable processingJobs = $ProcessingJobsTable(this);
  late final $ModelCapabilityEntriesTable modelCapabilityEntries =
      $ModelCapabilityEntriesTable(this);
  late final $ModelModeEntriesTable modelModeEntries = $ModelModeEntriesTable(
    this,
  );
  late final $ExportRecordsTable exportRecords = $ExportRecordsTable(this);
  late final $BackupRecordsTable backupRecords = $BackupRecordsTable(this);
  late final Index idxMeetingsCreated = Index(
    'idx_meetings_created',
    'CREATE INDEX idx_meetings_created ON meetings (is_deleted, created_at DESC, id DESC)',
  );
  late final Index uxAudioSegmentsMeetingSequence = Index(
    'ux_audio_segments_meeting_sequence',
    'CREATE UNIQUE INDEX ux_audio_segments_meeting_sequence ON audio_segments (meeting_id, sequence)',
  );
  late final Index uxSessionEventsMeetingSequence = Index(
    'ux_session_events_meeting_sequence',
    'CREATE UNIQUE INDEX ux_session_events_meeting_sequence ON session_events (meeting_id, sequence)',
  );
  late final Index idxBookmarksMeetingMedia = Index(
    'idx_bookmarks_meeting_media',
    'CREATE INDEX idx_bookmarks_meeting_media ON bookmarks (meeting_id, media_offset_us)',
  );
  late final Index idxTranscriptRunsMeetingCreated = Index(
    'idx_transcript_runs_meeting_created',
    'CREATE INDEX idx_transcript_runs_meeting_created ON transcript_runs (meeting_id, created_at DESC)',
  );
  late final Index uxTranscriptRunOwner = Index(
    'ux_transcript_run_owner',
    'CREATE UNIQUE INDEX ux_transcript_run_owner ON transcript_runs (id, meeting_id)',
  );
  late final Index uxMeetingTranscriptSelection = Index(
    'ux_meeting_transcript_selection',
    'CREATE UNIQUE INDEX ux_meeting_transcript_selection ON meeting_transcript_selections (meeting_id)',
  );
  late final Index idxTranscriptSegmentsRunStart = Index(
    'idx_transcript_segments_run_start',
    'CREATE INDEX idx_transcript_segments_run_start ON transcript_segments (transcript_run_id, start_us)',
  );
  late final Index uxTranscriptSegmentOwner = Index(
    'ux_transcript_segment_owner',
    'CREATE UNIQUE INDEX ux_transcript_segment_owner ON transcript_segments (id, meeting_id)',
  );
  late final Index idxLanguageDecisionsSegmentCreated = Index(
    'idx_language_decisions_segment_created',
    'CREATE INDEX idx_language_decisions_segment_created ON language_decisions (transcript_segment_id, created_at DESC)',
  );
  late final Index uxLanguageDecisionOwner = Index(
    'ux_language_decision_owner',
    'CREATE UNIQUE INDEX ux_language_decision_owner ON language_decisions (id, transcript_segment_id)',
  );
  late final Index uxTranscriptLanguageSelection = Index(
    'ux_transcript_language_selection',
    'CREATE UNIQUE INDEX ux_transcript_language_selection ON transcript_language_selections (transcript_segment_id)',
  );
  late final Index idxDiarizationRunsMeetingCreated = Index(
    'idx_diarization_runs_meeting_created',
    'CREATE INDEX idx_diarization_runs_meeting_created ON diarization_runs (meeting_id, created_at DESC)',
  );
  late final Index uxDiarizationRunOwner = Index(
    'ux_diarization_run_owner',
    'CREATE UNIQUE INDEX ux_diarization_run_owner ON diarization_runs (id, meeting_id)',
  );
  late final Index uxSpeakersRunLabel = Index(
    'ux_speakers_run_label',
    'CREATE UNIQUE INDEX ux_speakers_run_label ON speakers (analysis_run_id, label)',
  );
  late final Index uxSpeakerRunOwner = Index(
    'ux_speaker_run_owner',
    'CREATE UNIQUE INDEX ux_speaker_run_owner ON speakers (id, analysis_run_id)',
  );
  late final Index uxSpeakerMeetingOwner = Index(
    'ux_speaker_meeting_owner',
    'CREATE UNIQUE INDEX ux_speaker_meeting_owner ON speakers (id, meeting_id)',
  );
  late final Index idxSpeakerAssignmentsRunStart = Index(
    'idx_speaker_assignments_run_start',
    'CREATE INDEX idx_speaker_assignments_run_start ON speaker_assignments (analysis_run_id, start_us)',
  );
  late final Index uxSpeakerAssignmentOwner = Index(
    'ux_speaker_assignment_owner',
    'CREATE UNIQUE INDEX ux_speaker_assignment_owner ON speaker_assignments (id, meeting_id)',
  );
  late final Index idxRevisionsMeetingCreated = Index(
    'idx_revisions_meeting_created',
    'CREATE INDEX idx_revisions_meeting_created ON revisions (meeting_id, created_at)',
  );
  late final Index idxRevisionsTranscriptTarget = Index(
    'idx_revisions_transcript_target',
    'CREATE INDEX idx_revisions_transcript_target ON revisions (transcript_segment_id, created_at)',
  );
  late final Index idxRevisionsAssignmentTarget = Index(
    'idx_revisions_assignment_target',
    'CREATE INDEX idx_revisions_assignment_target ON revisions (speaker_assignment_id, created_at)',
  );
  late final Index idxRevisionsSpeakerTarget = Index(
    'idx_revisions_speaker_target',
    'CREATE INDEX idx_revisions_speaker_target ON revisions (speaker_id, created_at)',
  );
  late final Index idxProcessingJobsMeetingCreated = Index(
    'idx_processing_jobs_meeting_created',
    'CREATE INDEX idx_processing_jobs_meeting_created ON processing_jobs (meeting_id, created_at DESC)',
  );
  late final Index uxModelManifestsHash = Index(
    'ux_model_manifests_hash',
    'CREATE UNIQUE INDEX ux_model_manifests_hash ON model_manifests (sha256)',
  );
  late final Index uxModelManifestProvenance = Index(
    'ux_model_manifest_provenance',
    'CREATE UNIQUE INDEX ux_model_manifest_provenance ON model_manifests (id, version, sha256, expected_engine_id)',
  );
  late final Index uxModelCapability = Index(
    'ux_model_capability',
    'CREATE UNIQUE INDEX ux_model_capability ON model_capability_entries (model_id, capability)',
  );
  late final Index uxModelMode = Index(
    'ux_model_mode',
    'CREATE UNIQUE INDEX ux_model_mode ON model_mode_entries (model_id, mode)',
  );
  late final Index idxExportRecordsMeetingCreated = Index(
    'idx_export_records_meeting_created',
    'CREATE INDEX idx_export_records_meeting_created ON export_records (meeting_id, created_at DESC)',
  );
  late final Index idxBackupRecordsCreated = Index(
    'idx_backup_records_created',
    'CREATE INDEX idx_backup_records_created ON backup_records (created_at DESC)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    meetings,
    audioSegments,
    sessionEvents,
    bookmarks,
    modelManifests,
    transcriptRuns,
    meetingTranscriptSelections,
    diarizationRuns,
    speakers,
    transcriptSegments,
    languageDecisions,
    transcriptLanguageSelections,
    speakerAssignments,
    revisions,
    processingJobs,
    modelCapabilityEntries,
    modelModeEntries,
    exportRecords,
    backupRecords,
    idxMeetingsCreated,
    uxAudioSegmentsMeetingSequence,
    uxSessionEventsMeetingSequence,
    idxBookmarksMeetingMedia,
    idxTranscriptRunsMeetingCreated,
    uxTranscriptRunOwner,
    uxMeetingTranscriptSelection,
    idxTranscriptSegmentsRunStart,
    uxTranscriptSegmentOwner,
    idxLanguageDecisionsSegmentCreated,
    uxLanguageDecisionOwner,
    uxTranscriptLanguageSelection,
    idxDiarizationRunsMeetingCreated,
    uxDiarizationRunOwner,
    uxSpeakersRunLabel,
    uxSpeakerRunOwner,
    uxSpeakerMeetingOwner,
    idxSpeakerAssignmentsRunStart,
    uxSpeakerAssignmentOwner,
    idxRevisionsMeetingCreated,
    idxRevisionsTranscriptTarget,
    idxRevisionsAssignmentTarget,
    idxRevisionsSpeakerTarget,
    idxProcessingJobsMeetingCreated,
    uxModelManifestsHash,
    uxModelManifestProvenance,
    uxModelCapability,
    uxModelMode,
    idxExportRecordsMeetingCreated,
    idxBackupRecordsCreated,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('audio_segments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('session_events', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('bookmarks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('transcript_runs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('meeting_transcript_selections', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'transcript_runs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('meeting_transcript_selections', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('diarization_runs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('speakers', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'diarization_runs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('speakers', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('transcript_segments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'transcript_runs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('transcript_segments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'transcript_segments',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('language_decisions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'transcript_segments',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('transcript_language_selections', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'language_decisions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('transcript_language_selections', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('speaker_assignments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'diarization_runs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('speaker_assignments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('revisions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('processing_jobs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'model_manifests',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('model_capability_entries', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'model_manifests',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('model_mode_entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('export_records', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$MeetingsTableCreateCompanionBuilder =
    MeetingsCompanion Function({
      required String id,
      required int createdAt,
      required int updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      required String title,
      Value<int> mediaDurationUs,
      required String lifecycle,
      required String languageMode,
      Value<int?> trashedAtUtcMs,
      Value<String?> lifecycleBeforeTrash,
      Value<int> rowid,
    });
typedef $$MeetingsTableUpdateCompanionBuilder =
    MeetingsCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      Value<String> title,
      Value<int> mediaDurationUs,
      Value<String> lifecycle,
      Value<String> languageMode,
      Value<int?> trashedAtUtcMs,
      Value<String?> lifecycleBeforeTrash,
      Value<int> rowid,
    });

final class $$MeetingsTableReferences
    extends BaseReferences<_$AppDatabase, $MeetingsTable, Meeting> {
  $$MeetingsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$AudioSegmentsTable, List<AudioSegment>>
  _audioSegmentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.audioSegments,
    aliasName: 'meetings__id__audio_segments__meeting_id',
  );

  $$AudioSegmentsTableProcessedTableManager get audioSegmentsRefs {
    final manager = $$AudioSegmentsTableTableManager(
      $_db,
      $_db.audioSegments,
    ).filter((f) => f.meetingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_audioSegmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SessionEventsTable, List<SessionEvent>>
  _sessionEventsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.sessionEvents,
    aliasName: 'meetings__id__session_events__meeting_id',
  );

  $$SessionEventsTableProcessedTableManager get sessionEventsRefs {
    final manager = $$SessionEventsTableTableManager(
      $_db,
      $_db.sessionEvents,
    ).filter((f) => f.meetingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_sessionEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BookmarksTable, List<Bookmark>>
  _bookmarksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.bookmarks,
    aliasName: 'meetings__id__bookmarks__meeting_id',
  );

  $$BookmarksTableProcessedTableManager get bookmarksRefs {
    final manager = $$BookmarksTableTableManager(
      $_db,
      $_db.bookmarks,
    ).filter((f) => f.meetingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_bookmarksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TranscriptRunsTable, List<TranscriptRun>>
  _transcriptRunsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transcriptRuns,
    aliasName: 'meetings__id__transcript_runs__meeting_id',
  );

  $$TranscriptRunsTableProcessedTableManager get transcriptRunsRefs {
    final manager = $$TranscriptRunsTableTableManager(
      $_db,
      $_db.transcriptRuns,
    ).filter((f) => f.meetingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_transcriptRunsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $MeetingTranscriptSelectionsTable,
    List<MeetingTranscriptSelection>
  >
  _meetingTranscriptSelectionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.meetingTranscriptSelections,
        aliasName: 'meetings__id__meeting_transcript_selections__meeting_id',
      );

  $$MeetingTranscriptSelectionsTableProcessedTableManager
  get meetingTranscriptSelectionsRefs {
    final manager = $$MeetingTranscriptSelectionsTableTableManager(
      $_db,
      $_db.meetingTranscriptSelections,
    ).filter((f) => f.meetingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _meetingTranscriptSelectionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DiarizationRunsTable, List<DiarizationRun>>
  _diarizationRunsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.diarizationRuns,
    aliasName: 'meetings__id__diarization_runs__meeting_id',
  );

  $$DiarizationRunsTableProcessedTableManager get diarizationRunsRefs {
    final manager = $$DiarizationRunsTableTableManager(
      $_db,
      $_db.diarizationRuns,
    ).filter((f) => f.meetingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _diarizationRunsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SpeakersTable, List<Speaker>> _speakersRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.speakers,
    aliasName: 'meetings__id__speakers__meeting_id',
  );

  $$SpeakersTableProcessedTableManager get speakersRefs {
    final manager = $$SpeakersTableTableManager(
      $_db,
      $_db.speakers,
    ).filter((f) => f.meetingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_speakersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TranscriptSegmentsTable, List<TranscriptSegment>>
  _transcriptSegmentsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.transcriptSegments,
        aliasName: 'meetings__id__transcript_segments__meeting_id',
      );

  $$TranscriptSegmentsTableProcessedTableManager get transcriptSegmentsRefs {
    final manager = $$TranscriptSegmentsTableTableManager(
      $_db,
      $_db.transcriptSegments,
    ).filter((f) => f.meetingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _transcriptSegmentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SpeakerAssignmentsTable, List<SpeakerAssignment>>
  _speakerAssignmentsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.speakerAssignments,
        aliasName: 'meetings__id__speaker_assignments__meeting_id',
      );

  $$SpeakerAssignmentsTableProcessedTableManager get speakerAssignmentsRefs {
    final manager = $$SpeakerAssignmentsTableTableManager(
      $_db,
      $_db.speakerAssignments,
    ).filter((f) => f.meetingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _speakerAssignmentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RevisionsTable, List<Revision>>
  _revisionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.revisions,
    aliasName: 'meetings__id__revisions__meeting_id',
  );

  $$RevisionsTableProcessedTableManager get revisionsRefs {
    final manager = $$RevisionsTableTableManager(
      $_db,
      $_db.revisions,
    ).filter((f) => f.meetingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_revisionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ProcessingJobsTable, List<ProcessingJob>>
  _processingJobsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.processingJobs,
    aliasName: 'meetings__id__processing_jobs__meeting_id',
  );

  $$ProcessingJobsTableProcessedTableManager get processingJobsRefs {
    final manager = $$ProcessingJobsTableTableManager(
      $_db,
      $_db.processingJobs,
    ).filter((f) => f.meetingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_processingJobsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ExportRecordsTable, List<ExportRecord>>
  _exportRecordsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.exportRecords,
    aliasName: 'meetings__id__export_records__meeting_id',
  );

  $$ExportRecordsTableProcessedTableManager get exportRecordsRefs {
    final manager = $$ExportRecordsTableTableManager(
      $_db,
      $_db.exportRecords,
    ).filter((f) => f.meetingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_exportRecordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MeetingsTableFilterComposer
    extends Composer<_$AppDatabase, $MeetingsTable> {
  $$MeetingsTableFilterComposer({
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

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mediaDurationUs => $composableBuilder(
    column: $table.mediaDurationUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lifecycle => $composableBuilder(
    column: $table.lifecycle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get languageMode => $composableBuilder(
    column: $table.languageMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trashedAtUtcMs => $composableBuilder(
    column: $table.trashedAtUtcMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lifecycleBeforeTrash => $composableBuilder(
    column: $table.lifecycleBeforeTrash,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> audioSegmentsRefs(
    Expression<bool> Function($$AudioSegmentsTableFilterComposer f) f,
  ) {
    final $$AudioSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.audioSegments,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.audioSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> sessionEventsRefs(
    Expression<bool> Function($$SessionEventsTableFilterComposer f) f,
  ) {
    final $$SessionEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessionEvents,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionEventsTableFilterComposer(
            $db: $db,
            $table: $db.sessionEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> bookmarksRefs(
    Expression<bool> Function($$BookmarksTableFilterComposer f) f,
  ) {
    final $$BookmarksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookmarks,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookmarksTableFilterComposer(
            $db: $db,
            $table: $db.bookmarks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> transcriptRunsRefs(
    Expression<bool> Function($$TranscriptRunsTableFilterComposer f) f,
  ) {
    final $$TranscriptRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transcriptRuns,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptRunsTableFilterComposer(
            $db: $db,
            $table: $db.transcriptRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> meetingTranscriptSelectionsRefs(
    Expression<bool> Function(
      $$MeetingTranscriptSelectionsTableFilterComposer f,
    )
    f,
  ) {
    final $$MeetingTranscriptSelectionsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.meetingTranscriptSelections,
          getReferencedColumn: (t) => t.meetingId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MeetingTranscriptSelectionsTableFilterComposer(
                $db: $db,
                $table: $db.meetingTranscriptSelections,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> diarizationRunsRefs(
    Expression<bool> Function($$DiarizationRunsTableFilterComposer f) f,
  ) {
    final $$DiarizationRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.diarizationRuns,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DiarizationRunsTableFilterComposer(
            $db: $db,
            $table: $db.diarizationRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> speakersRefs(
    Expression<bool> Function($$SpeakersTableFilterComposer f) f,
  ) {
    final $$SpeakersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.speakers,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakersTableFilterComposer(
            $db: $db,
            $table: $db.speakers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> transcriptSegmentsRefs(
    Expression<bool> Function($$TranscriptSegmentsTableFilterComposer f) f,
  ) {
    final $$TranscriptSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transcriptSegments,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.transcriptSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> speakerAssignmentsRefs(
    Expression<bool> Function($$SpeakerAssignmentsTableFilterComposer f) f,
  ) {
    final $$SpeakerAssignmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.speakerAssignments,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakerAssignmentsTableFilterComposer(
            $db: $db,
            $table: $db.speakerAssignments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> revisionsRefs(
    Expression<bool> Function($$RevisionsTableFilterComposer f) f,
  ) {
    final $$RevisionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.revisions,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RevisionsTableFilterComposer(
            $db: $db,
            $table: $db.revisions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> processingJobsRefs(
    Expression<bool> Function($$ProcessingJobsTableFilterComposer f) f,
  ) {
    final $$ProcessingJobsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.processingJobs,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProcessingJobsTableFilterComposer(
            $db: $db,
            $table: $db.processingJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> exportRecordsRefs(
    Expression<bool> Function($$ExportRecordsTableFilterComposer f) f,
  ) {
    final $$ExportRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.exportRecords,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExportRecordsTableFilterComposer(
            $db: $db,
            $table: $db.exportRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MeetingsTableOrderingComposer
    extends Composer<_$AppDatabase, $MeetingsTable> {
  $$MeetingsTableOrderingComposer({
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

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mediaDurationUs => $composableBuilder(
    column: $table.mediaDurationUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lifecycle => $composableBuilder(
    column: $table.lifecycle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get languageMode => $composableBuilder(
    column: $table.languageMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trashedAtUtcMs => $composableBuilder(
    column: $table.trashedAtUtcMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lifecycleBeforeTrash => $composableBuilder(
    column: $table.lifecycleBeforeTrash,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MeetingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MeetingsTable> {
  $$MeetingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get mediaDurationUs => $composableBuilder(
    column: $table.mediaDurationUs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lifecycle =>
      $composableBuilder(column: $table.lifecycle, builder: (column) => column);

  GeneratedColumn<String> get languageMode => $composableBuilder(
    column: $table.languageMode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get trashedAtUtcMs => $composableBuilder(
    column: $table.trashedAtUtcMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lifecycleBeforeTrash => $composableBuilder(
    column: $table.lifecycleBeforeTrash,
    builder: (column) => column,
  );

  Expression<T> audioSegmentsRefs<T extends Object>(
    Expression<T> Function($$AudioSegmentsTableAnnotationComposer a) f,
  ) {
    final $$AudioSegmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.audioSegments,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioSegmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.audioSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> sessionEventsRefs<T extends Object>(
    Expression<T> Function($$SessionEventsTableAnnotationComposer a) f,
  ) {
    final $$SessionEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessionEvents,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessionEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> bookmarksRefs<T extends Object>(
    Expression<T> Function($$BookmarksTableAnnotationComposer a) f,
  ) {
    final $$BookmarksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookmarks,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookmarksTableAnnotationComposer(
            $db: $db,
            $table: $db.bookmarks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> transcriptRunsRefs<T extends Object>(
    Expression<T> Function($$TranscriptRunsTableAnnotationComposer a) f,
  ) {
    final $$TranscriptRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transcriptRuns,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.transcriptRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> meetingTranscriptSelectionsRefs<T extends Object>(
    Expression<T> Function(
      $$MeetingTranscriptSelectionsTableAnnotationComposer a,
    )
    f,
  ) {
    final $$MeetingTranscriptSelectionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.meetingTranscriptSelections,
          getReferencedColumn: (t) => t.meetingId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MeetingTranscriptSelectionsTableAnnotationComposer(
                $db: $db,
                $table: $db.meetingTranscriptSelections,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> diarizationRunsRefs<T extends Object>(
    Expression<T> Function($$DiarizationRunsTableAnnotationComposer a) f,
  ) {
    final $$DiarizationRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.diarizationRuns,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DiarizationRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.diarizationRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> speakersRefs<T extends Object>(
    Expression<T> Function($$SpeakersTableAnnotationComposer a) f,
  ) {
    final $$SpeakersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.speakers,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakersTableAnnotationComposer(
            $db: $db,
            $table: $db.speakers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> transcriptSegmentsRefs<T extends Object>(
    Expression<T> Function($$TranscriptSegmentsTableAnnotationComposer a) f,
  ) {
    final $$TranscriptSegmentsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.transcriptSegments,
          getReferencedColumn: (t) => t.meetingId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TranscriptSegmentsTableAnnotationComposer(
                $db: $db,
                $table: $db.transcriptSegments,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> speakerAssignmentsRefs<T extends Object>(
    Expression<T> Function($$SpeakerAssignmentsTableAnnotationComposer a) f,
  ) {
    final $$SpeakerAssignmentsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.speakerAssignments,
          getReferencedColumn: (t) => t.meetingId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SpeakerAssignmentsTableAnnotationComposer(
                $db: $db,
                $table: $db.speakerAssignments,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> revisionsRefs<T extends Object>(
    Expression<T> Function($$RevisionsTableAnnotationComposer a) f,
  ) {
    final $$RevisionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.revisions,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RevisionsTableAnnotationComposer(
            $db: $db,
            $table: $db.revisions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> processingJobsRefs<T extends Object>(
    Expression<T> Function($$ProcessingJobsTableAnnotationComposer a) f,
  ) {
    final $$ProcessingJobsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.processingJobs,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProcessingJobsTableAnnotationComposer(
            $db: $db,
            $table: $db.processingJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> exportRecordsRefs<T extends Object>(
    Expression<T> Function($$ExportRecordsTableAnnotationComposer a) f,
  ) {
    final $$ExportRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.exportRecords,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExportRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.exportRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MeetingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MeetingsTable,
          Meeting,
          $$MeetingsTableFilterComposer,
          $$MeetingsTableOrderingComposer,
          $$MeetingsTableAnnotationComposer,
          $$MeetingsTableCreateCompanionBuilder,
          $$MeetingsTableUpdateCompanionBuilder,
          (Meeting, $$MeetingsTableReferences),
          Meeting,
          PrefetchHooks Function({
            bool audioSegmentsRefs,
            bool sessionEventsRefs,
            bool bookmarksRefs,
            bool transcriptRunsRefs,
            bool meetingTranscriptSelectionsRefs,
            bool diarizationRunsRefs,
            bool speakersRefs,
            bool transcriptSegmentsRefs,
            bool speakerAssignmentsRefs,
            bool revisionsRefs,
            bool processingJobsRefs,
            bool exportRecordsRefs,
          })
        > {
  $$MeetingsTableTableManager(_$AppDatabase db, $MeetingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MeetingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MeetingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MeetingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> mediaDurationUs = const Value.absent(),
                Value<String> lifecycle = const Value.absent(),
                Value<String> languageMode = const Value.absent(),
                Value<int?> trashedAtUtcMs = const Value.absent(),
                Value<String?> lifecycleBeforeTrash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MeetingsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                title: title,
                mediaDurationUs: mediaDurationUs,
                lifecycle: lifecycle,
                languageMode: languageMode,
                trashedAtUtcMs: trashedAtUtcMs,
                lifecycleBeforeTrash: lifecycleBeforeTrash,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int createdAt,
                required int updatedAt,
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                required String title,
                Value<int> mediaDurationUs = const Value.absent(),
                required String lifecycle,
                required String languageMode,
                Value<int?> trashedAtUtcMs = const Value.absent(),
                Value<String?> lifecycleBeforeTrash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MeetingsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                title: title,
                mediaDurationUs: mediaDurationUs,
                lifecycle: lifecycle,
                languageMode: languageMode,
                trashedAtUtcMs: trashedAtUtcMs,
                lifecycleBeforeTrash: lifecycleBeforeTrash,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MeetingsTable, Meeting>(table),
                  $$MeetingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                audioSegmentsRefs = false,
                sessionEventsRefs = false,
                bookmarksRefs = false,
                transcriptRunsRefs = false,
                meetingTranscriptSelectionsRefs = false,
                diarizationRunsRefs = false,
                speakersRefs = false,
                transcriptSegmentsRefs = false,
                speakerAssignmentsRefs = false,
                revisionsRefs = false,
                processingJobsRefs = false,
                exportRecordsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (audioSegmentsRefs) db.audioSegments,
                    if (sessionEventsRefs) db.sessionEvents,
                    if (bookmarksRefs) db.bookmarks,
                    if (transcriptRunsRefs) db.transcriptRuns,
                    if (meetingTranscriptSelectionsRefs)
                      db.meetingTranscriptSelections,
                    if (diarizationRunsRefs) db.diarizationRuns,
                    if (speakersRefs) db.speakers,
                    if (transcriptSegmentsRefs) db.transcriptSegments,
                    if (speakerAssignmentsRefs) db.speakerAssignments,
                    if (revisionsRefs) db.revisions,
                    if (processingJobsRefs) db.processingJobs,
                    if (exportRecordsRefs) db.exportRecords,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (audioSegmentsRefs)
                        await $_getPrefetchedData<
                          Meeting,
                          $MeetingsTable,
                          AudioSegment
                        >(
                          currentTable: table,
                          referencedTable: $$MeetingsTableReferences
                              ._audioSegmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MeetingsTableReferences(
                                db,
                                table,
                                p0,
                              ).audioSegmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.meetingId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (sessionEventsRefs)
                        await $_getPrefetchedData<
                          Meeting,
                          $MeetingsTable,
                          SessionEvent
                        >(
                          currentTable: table,
                          referencedTable: $$MeetingsTableReferences
                              ._sessionEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MeetingsTableReferences(
                                db,
                                table,
                                p0,
                              ).sessionEventsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.meetingId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (bookmarksRefs)
                        await $_getPrefetchedData<
                          Meeting,
                          $MeetingsTable,
                          Bookmark
                        >(
                          currentTable: table,
                          referencedTable: $$MeetingsTableReferences
                              ._bookmarksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MeetingsTableReferences(
                                db,
                                table,
                                p0,
                              ).bookmarksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.meetingId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (transcriptRunsRefs)
                        await $_getPrefetchedData<
                          Meeting,
                          $MeetingsTable,
                          TranscriptRun
                        >(
                          currentTable: table,
                          referencedTable: $$MeetingsTableReferences
                              ._transcriptRunsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MeetingsTableReferences(
                                db,
                                table,
                                p0,
                              ).transcriptRunsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.meetingId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (meetingTranscriptSelectionsRefs)
                        await $_getPrefetchedData<
                          Meeting,
                          $MeetingsTable,
                          MeetingTranscriptSelection
                        >(
                          currentTable: table,
                          referencedTable: $$MeetingsTableReferences
                              ._meetingTranscriptSelectionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MeetingsTableReferences(
                                db,
                                table,
                                p0,
                              ).meetingTranscriptSelectionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.meetingId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (diarizationRunsRefs)
                        await $_getPrefetchedData<
                          Meeting,
                          $MeetingsTable,
                          DiarizationRun
                        >(
                          currentTable: table,
                          referencedTable: $$MeetingsTableReferences
                              ._diarizationRunsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MeetingsTableReferences(
                                db,
                                table,
                                p0,
                              ).diarizationRunsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.meetingId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (speakersRefs)
                        await $_getPrefetchedData<
                          Meeting,
                          $MeetingsTable,
                          Speaker
                        >(
                          currentTable: table,
                          referencedTable: $$MeetingsTableReferences
                              ._speakersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MeetingsTableReferences(
                                db,
                                table,
                                p0,
                              ).speakersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.meetingId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (transcriptSegmentsRefs)
                        await $_getPrefetchedData<
                          Meeting,
                          $MeetingsTable,
                          TranscriptSegment
                        >(
                          currentTable: table,
                          referencedTable: $$MeetingsTableReferences
                              ._transcriptSegmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MeetingsTableReferences(
                                db,
                                table,
                                p0,
                              ).transcriptSegmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.meetingId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (speakerAssignmentsRefs)
                        await $_getPrefetchedData<
                          Meeting,
                          $MeetingsTable,
                          SpeakerAssignment
                        >(
                          currentTable: table,
                          referencedTable: $$MeetingsTableReferences
                              ._speakerAssignmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MeetingsTableReferences(
                                db,
                                table,
                                p0,
                              ).speakerAssignmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.meetingId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (revisionsRefs)
                        await $_getPrefetchedData<
                          Meeting,
                          $MeetingsTable,
                          Revision
                        >(
                          currentTable: table,
                          referencedTable: $$MeetingsTableReferences
                              ._revisionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MeetingsTableReferences(
                                db,
                                table,
                                p0,
                              ).revisionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.meetingId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (processingJobsRefs)
                        await $_getPrefetchedData<
                          Meeting,
                          $MeetingsTable,
                          ProcessingJob
                        >(
                          currentTable: table,
                          referencedTable: $$MeetingsTableReferences
                              ._processingJobsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MeetingsTableReferences(
                                db,
                                table,
                                p0,
                              ).processingJobsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.meetingId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (exportRecordsRefs)
                        await $_getPrefetchedData<
                          Meeting,
                          $MeetingsTable,
                          ExportRecord
                        >(
                          currentTable: table,
                          referencedTable: $$MeetingsTableReferences
                              ._exportRecordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MeetingsTableReferences(
                                db,
                                table,
                                p0,
                              ).exportRecordsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.meetingId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$MeetingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MeetingsTable,
      Meeting,
      $$MeetingsTableFilterComposer,
      $$MeetingsTableOrderingComposer,
      $$MeetingsTableAnnotationComposer,
      $$MeetingsTableCreateCompanionBuilder,
      $$MeetingsTableUpdateCompanionBuilder,
      (Meeting, $$MeetingsTableReferences),
      Meeting,
      PrefetchHooks Function({
        bool audioSegmentsRefs,
        bool sessionEventsRefs,
        bool bookmarksRefs,
        bool transcriptRunsRefs,
        bool meetingTranscriptSelectionsRefs,
        bool diarizationRunsRefs,
        bool speakersRefs,
        bool transcriptSegmentsRefs,
        bool speakerAssignmentsRefs,
        bool revisionsRefs,
        bool processingJobsRefs,
        bool exportRecordsRefs,
      })
    >;
typedef $$AudioSegmentsTableCreateCompanionBuilder =
    AudioSegmentsCompanion Function({
      required String id,
      required int createdAt,
      required int updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      required String meetingId,
      required int sequence,
      required String relativePath,
      required int mediaStartUs,
      required int mediaDurationUs,
      required int committedBytes,
      required String state,
      Value<int> rowid,
    });
typedef $$AudioSegmentsTableUpdateCompanionBuilder =
    AudioSegmentsCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      Value<String> meetingId,
      Value<int> sequence,
      Value<String> relativePath,
      Value<int> mediaStartUs,
      Value<int> mediaDurationUs,
      Value<int> committedBytes,
      Value<String> state,
      Value<int> rowid,
    });

final class $$AudioSegmentsTableReferences
    extends BaseReferences<_$AppDatabase, $AudioSegmentsTable, AudioSegment> {
  $$AudioSegmentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) =>
      db.meetings.createAlias('audio_segments__meeting_id__meetings__id');

  $$MeetingsTableProcessedTableManager get meetingId {
    final $_column = $_itemColumn<String>('meeting_id')!;

    final manager = $$MeetingsTableTableManager(
      $_db,
      $_db.meetings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_meetingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AudioSegmentsTableFilterComposer
    extends Composer<_$AppDatabase, $AudioSegmentsTable> {
  $$AudioSegmentsTableFilterComposer({
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

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mediaStartUs => $composableBuilder(
    column: $table.mediaStartUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mediaDurationUs => $composableBuilder(
    column: $table.mediaDurationUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get committedBytes => $composableBuilder(
    column: $table.committedBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  $$MeetingsTableFilterComposer get meetingId {
    final $$MeetingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableFilterComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AudioSegmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $AudioSegmentsTable> {
  $$AudioSegmentsTableOrderingComposer({
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

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mediaStartUs => $composableBuilder(
    column: $table.mediaStartUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mediaDurationUs => $composableBuilder(
    column: $table.mediaDurationUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get committedBytes => $composableBuilder(
    column: $table.committedBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  $$MeetingsTableOrderingComposer get meetingId {
    final $$MeetingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableOrderingComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AudioSegmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AudioSegmentsTable> {
  $$AudioSegmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get mediaStartUs => $composableBuilder(
    column: $table.mediaStartUs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get mediaDurationUs => $composableBuilder(
    column: $table.mediaDurationUs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get committedBytes => $composableBuilder(
    column: $table.committedBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  $$MeetingsTableAnnotationComposer get meetingId {
    final $$MeetingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableAnnotationComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AudioSegmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AudioSegmentsTable,
          AudioSegment,
          $$AudioSegmentsTableFilterComposer,
          $$AudioSegmentsTableOrderingComposer,
          $$AudioSegmentsTableAnnotationComposer,
          $$AudioSegmentsTableCreateCompanionBuilder,
          $$AudioSegmentsTableUpdateCompanionBuilder,
          (AudioSegment, $$AudioSegmentsTableReferences),
          AudioSegment,
          PrefetchHooks Function({bool meetingId})
        > {
  $$AudioSegmentsTableTableManager(_$AppDatabase db, $AudioSegmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AudioSegmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AudioSegmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AudioSegmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> meetingId = const Value.absent(),
                Value<int> sequence = const Value.absent(),
                Value<String> relativePath = const Value.absent(),
                Value<int> mediaStartUs = const Value.absent(),
                Value<int> mediaDurationUs = const Value.absent(),
                Value<int> committedBytes = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AudioSegmentsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                meetingId: meetingId,
                sequence: sequence,
                relativePath: relativePath,
                mediaStartUs: mediaStartUs,
                mediaDurationUs: mediaDurationUs,
                committedBytes: committedBytes,
                state: state,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int createdAt,
                required int updatedAt,
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                required String meetingId,
                required int sequence,
                required String relativePath,
                required int mediaStartUs,
                required int mediaDurationUs,
                required int committedBytes,
                required String state,
                Value<int> rowid = const Value.absent(),
              }) => AudioSegmentsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                meetingId: meetingId,
                sequence: sequence,
                relativePath: relativePath,
                mediaStartUs: mediaStartUs,
                mediaDurationUs: mediaDurationUs,
                committedBytes: committedBytes,
                state: state,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AudioSegmentsTable, AudioSegment>(table),
                  $$AudioSegmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({meetingId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (meetingId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.meetingId,
                                referencedTable: $$AudioSegmentsTableReferences
                                    ._meetingIdTable(db),
                                referencedColumn: $$AudioSegmentsTableReferences
                                    ._meetingIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AudioSegmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AudioSegmentsTable,
      AudioSegment,
      $$AudioSegmentsTableFilterComposer,
      $$AudioSegmentsTableOrderingComposer,
      $$AudioSegmentsTableAnnotationComposer,
      $$AudioSegmentsTableCreateCompanionBuilder,
      $$AudioSegmentsTableUpdateCompanionBuilder,
      (AudioSegment, $$AudioSegmentsTableReferences),
      AudioSegment,
      PrefetchHooks Function({bool meetingId})
    >;
typedef $$SessionEventsTableCreateCompanionBuilder =
    SessionEventsCompanion Function({
      required String id,
      required int createdAt,
      required int updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      required String meetingId,
      required int sequence,
      required String type,
      required int wallClockUtcMs,
      required int monotonicElapsedUs,
      required int mediaOffsetUs,
      Value<int> rowid,
    });
typedef $$SessionEventsTableUpdateCompanionBuilder =
    SessionEventsCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      Value<String> meetingId,
      Value<int> sequence,
      Value<String> type,
      Value<int> wallClockUtcMs,
      Value<int> monotonicElapsedUs,
      Value<int> mediaOffsetUs,
      Value<int> rowid,
    });

final class $$SessionEventsTableReferences
    extends BaseReferences<_$AppDatabase, $SessionEventsTable, SessionEvent> {
  $$SessionEventsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) =>
      db.meetings.createAlias('session_events__meeting_id__meetings__id');

  $$MeetingsTableProcessedTableManager get meetingId {
    final $_column = $_itemColumn<String>('meeting_id')!;

    final manager = $$MeetingsTableTableManager(
      $_db,
      $_db.meetings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_meetingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SessionEventsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionEventsTable> {
  $$SessionEventsTableFilterComposer({
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

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wallClockUtcMs => $composableBuilder(
    column: $table.wallClockUtcMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get monotonicElapsedUs => $composableBuilder(
    column: $table.monotonicElapsedUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mediaOffsetUs => $composableBuilder(
    column: $table.mediaOffsetUs,
    builder: (column) => ColumnFilters(column),
  );

  $$MeetingsTableFilterComposer get meetingId {
    final $$MeetingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableFilterComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionEventsTable> {
  $$SessionEventsTableOrderingComposer({
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

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wallClockUtcMs => $composableBuilder(
    column: $table.wallClockUtcMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get monotonicElapsedUs => $composableBuilder(
    column: $table.monotonicElapsedUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mediaOffsetUs => $composableBuilder(
    column: $table.mediaOffsetUs,
    builder: (column) => ColumnOrderings(column),
  );

  $$MeetingsTableOrderingComposer get meetingId {
    final $$MeetingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableOrderingComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionEventsTable> {
  $$SessionEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get wallClockUtcMs => $composableBuilder(
    column: $table.wallClockUtcMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get monotonicElapsedUs => $composableBuilder(
    column: $table.monotonicElapsedUs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get mediaOffsetUs => $composableBuilder(
    column: $table.mediaOffsetUs,
    builder: (column) => column,
  );

  $$MeetingsTableAnnotationComposer get meetingId {
    final $$MeetingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableAnnotationComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionEventsTable,
          SessionEvent,
          $$SessionEventsTableFilterComposer,
          $$SessionEventsTableOrderingComposer,
          $$SessionEventsTableAnnotationComposer,
          $$SessionEventsTableCreateCompanionBuilder,
          $$SessionEventsTableUpdateCompanionBuilder,
          (SessionEvent, $$SessionEventsTableReferences),
          SessionEvent,
          PrefetchHooks Function({bool meetingId})
        > {
  $$SessionEventsTableTableManager(_$AppDatabase db, $SessionEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> meetingId = const Value.absent(),
                Value<int> sequence = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> wallClockUtcMs = const Value.absent(),
                Value<int> monotonicElapsedUs = const Value.absent(),
                Value<int> mediaOffsetUs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionEventsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                meetingId: meetingId,
                sequence: sequence,
                type: type,
                wallClockUtcMs: wallClockUtcMs,
                monotonicElapsedUs: monotonicElapsedUs,
                mediaOffsetUs: mediaOffsetUs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int createdAt,
                required int updatedAt,
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                required String meetingId,
                required int sequence,
                required String type,
                required int wallClockUtcMs,
                required int monotonicElapsedUs,
                required int mediaOffsetUs,
                Value<int> rowid = const Value.absent(),
              }) => SessionEventsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                meetingId: meetingId,
                sequence: sequence,
                type: type,
                wallClockUtcMs: wallClockUtcMs,
                monotonicElapsedUs: monotonicElapsedUs,
                mediaOffsetUs: mediaOffsetUs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SessionEventsTable, SessionEvent>(table),
                  $$SessionEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({meetingId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (meetingId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.meetingId,
                                referencedTable: $$SessionEventsTableReferences
                                    ._meetingIdTable(db),
                                referencedColumn: $$SessionEventsTableReferences
                                    ._meetingIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SessionEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionEventsTable,
      SessionEvent,
      $$SessionEventsTableFilterComposer,
      $$SessionEventsTableOrderingComposer,
      $$SessionEventsTableAnnotationComposer,
      $$SessionEventsTableCreateCompanionBuilder,
      $$SessionEventsTableUpdateCompanionBuilder,
      (SessionEvent, $$SessionEventsTableReferences),
      SessionEvent,
      PrefetchHooks Function({bool meetingId})
    >;
typedef $$BookmarksTableCreateCompanionBuilder =
    BookmarksCompanion Function({
      required String id,
      required int createdAt,
      required int updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      required String meetingId,
      required int mediaOffsetUs,
      required String kind,
      Value<int> rowid,
    });
typedef $$BookmarksTableUpdateCompanionBuilder =
    BookmarksCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      Value<String> meetingId,
      Value<int> mediaOffsetUs,
      Value<String> kind,
      Value<int> rowid,
    });

final class $$BookmarksTableReferences
    extends BaseReferences<_$AppDatabase, $BookmarksTable, Bookmark> {
  $$BookmarksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) =>
      db.meetings.createAlias('bookmarks__meeting_id__meetings__id');

  $$MeetingsTableProcessedTableManager get meetingId {
    final $_column = $_itemColumn<String>('meeting_id')!;

    final manager = $$MeetingsTableTableManager(
      $_db,
      $_db.meetings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_meetingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BookmarksTableFilterComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableFilterComposer({
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

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mediaOffsetUs => $composableBuilder(
    column: $table.mediaOffsetUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  $$MeetingsTableFilterComposer get meetingId {
    final $$MeetingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableFilterComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookmarksTableOrderingComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableOrderingComposer({
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

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mediaOffsetUs => $composableBuilder(
    column: $table.mediaOffsetUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  $$MeetingsTableOrderingComposer get meetingId {
    final $$MeetingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableOrderingComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookmarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get mediaOffsetUs => $composableBuilder(
    column: $table.mediaOffsetUs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  $$MeetingsTableAnnotationComposer get meetingId {
    final $$MeetingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableAnnotationComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookmarksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookmarksTable,
          Bookmark,
          $$BookmarksTableFilterComposer,
          $$BookmarksTableOrderingComposer,
          $$BookmarksTableAnnotationComposer,
          $$BookmarksTableCreateCompanionBuilder,
          $$BookmarksTableUpdateCompanionBuilder,
          (Bookmark, $$BookmarksTableReferences),
          Bookmark,
          PrefetchHooks Function({bool meetingId})
        > {
  $$BookmarksTableTableManager(_$AppDatabase db, $BookmarksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> meetingId = const Value.absent(),
                Value<int> mediaOffsetUs = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookmarksCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                meetingId: meetingId,
                mediaOffsetUs: mediaOffsetUs,
                kind: kind,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int createdAt,
                required int updatedAt,
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                required String meetingId,
                required int mediaOffsetUs,
                required String kind,
                Value<int> rowid = const Value.absent(),
              }) => BookmarksCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                meetingId: meetingId,
                mediaOffsetUs: mediaOffsetUs,
                kind: kind,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BookmarksTable, Bookmark>(table),
                  $$BookmarksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({meetingId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (meetingId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.meetingId,
                                referencedTable: $$BookmarksTableReferences
                                    ._meetingIdTable(db),
                                referencedColumn: $$BookmarksTableReferences
                                    ._meetingIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BookmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookmarksTable,
      Bookmark,
      $$BookmarksTableFilterComposer,
      $$BookmarksTableOrderingComposer,
      $$BookmarksTableAnnotationComposer,
      $$BookmarksTableCreateCompanionBuilder,
      $$BookmarksTableUpdateCompanionBuilder,
      (Bookmark, $$BookmarksTableReferences),
      Bookmark,
      PrefetchHooks Function({bool meetingId})
    >;
typedef $$ModelManifestsTableCreateCompanionBuilder =
    ModelManifestsCompanion Function({
      required String id,
      required int createdAt,
      required int updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      required String version,
      required String source,
      required String sha256,
      required int bytes,
      required String expectedEngineId,
      required String licenseId,
      required String licenseSnapshotPath,
      Value<int> rowid,
    });
typedef $$ModelManifestsTableUpdateCompanionBuilder =
    ModelManifestsCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      Value<String> version,
      Value<String> source,
      Value<String> sha256,
      Value<int> bytes,
      Value<String> expectedEngineId,
      Value<String> licenseId,
      Value<String> licenseSnapshotPath,
      Value<int> rowid,
    });

final class $$ModelManifestsTableReferences
    extends BaseReferences<_$AppDatabase, $ModelManifestsTable, ModelManifest> {
  $$ModelManifestsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$TranscriptRunsTable, List<TranscriptRun>>
  _transcriptRunsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transcriptRuns,
    aliasName: 'model_manifests__id__transcript_runs__model_id',
  );

  $$TranscriptRunsTableProcessedTableManager get transcriptRunsRefs {
    final manager = $$TranscriptRunsTableTableManager(
      $_db,
      $_db.transcriptRuns,
    ).filter((f) => f.modelId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_transcriptRunsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DiarizationRunsTable, List<DiarizationRun>>
  _diarizationRunsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.diarizationRuns,
    aliasName: 'model_manifests__id__diarization_runs__model_id',
  );

  $$DiarizationRunsTableProcessedTableManager get diarizationRunsRefs {
    final manager = $$DiarizationRunsTableTableManager(
      $_db,
      $_db.diarizationRuns,
    ).filter((f) => f.modelId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _diarizationRunsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ProcessingJobsTable, List<ProcessingJob>>
  _processingJobsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.processingJobs,
    aliasName: 'model_manifests__id__processing_jobs__model_id',
  );

  $$ProcessingJobsTableProcessedTableManager get processingJobsRefs {
    final manager = $$ProcessingJobsTableTableManager(
      $_db,
      $_db.processingJobs,
    ).filter((f) => f.modelId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_processingJobsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ModelCapabilityEntriesTable,
    List<ModelCapabilityEntry>
  >
  _modelCapabilityEntriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.modelCapabilityEntries,
        aliasName: 'model_manifests__id__model_capability_entries__model_id',
      );

  $$ModelCapabilityEntriesTableProcessedTableManager
  get modelCapabilityEntriesRefs {
    final manager = $$ModelCapabilityEntriesTableTableManager(
      $_db,
      $_db.modelCapabilityEntries,
    ).filter((f) => f.modelId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _modelCapabilityEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ModelModeEntriesTable, List<ModelModeEntry>>
  _modelModeEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.modelModeEntries,
    aliasName: 'model_manifests__id__model_mode_entries__model_id',
  );

  $$ModelModeEntriesTableProcessedTableManager get modelModeEntriesRefs {
    final manager = $$ModelModeEntriesTableTableManager(
      $_db,
      $_db.modelModeEntries,
    ).filter((f) => f.modelId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _modelModeEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ModelManifestsTableFilterComposer
    extends Composer<_$AppDatabase, $ModelManifestsTable> {
  $$ModelManifestsTableFilterComposer({
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

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expectedEngineId => $composableBuilder(
    column: $table.expectedEngineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get licenseId => $composableBuilder(
    column: $table.licenseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get licenseSnapshotPath => $composableBuilder(
    column: $table.licenseSnapshotPath,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> transcriptRunsRefs(
    Expression<bool> Function($$TranscriptRunsTableFilterComposer f) f,
  ) {
    final $$TranscriptRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transcriptRuns,
      getReferencedColumn: (t) => t.modelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptRunsTableFilterComposer(
            $db: $db,
            $table: $db.transcriptRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> diarizationRunsRefs(
    Expression<bool> Function($$DiarizationRunsTableFilterComposer f) f,
  ) {
    final $$DiarizationRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.diarizationRuns,
      getReferencedColumn: (t) => t.modelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DiarizationRunsTableFilterComposer(
            $db: $db,
            $table: $db.diarizationRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> processingJobsRefs(
    Expression<bool> Function($$ProcessingJobsTableFilterComposer f) f,
  ) {
    final $$ProcessingJobsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.processingJobs,
      getReferencedColumn: (t) => t.modelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProcessingJobsTableFilterComposer(
            $db: $db,
            $table: $db.processingJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> modelCapabilityEntriesRefs(
    Expression<bool> Function($$ModelCapabilityEntriesTableFilterComposer f) f,
  ) {
    final $$ModelCapabilityEntriesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.modelCapabilityEntries,
          getReferencedColumn: (t) => t.modelId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ModelCapabilityEntriesTableFilterComposer(
                $db: $db,
                $table: $db.modelCapabilityEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> modelModeEntriesRefs(
    Expression<bool> Function($$ModelModeEntriesTableFilterComposer f) f,
  ) {
    final $$ModelModeEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.modelModeEntries,
      getReferencedColumn: (t) => t.modelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModelModeEntriesTableFilterComposer(
            $db: $db,
            $table: $db.modelModeEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ModelManifestsTableOrderingComposer
    extends Composer<_$AppDatabase, $ModelManifestsTable> {
  $$ModelManifestsTableOrderingComposer({
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

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expectedEngineId => $composableBuilder(
    column: $table.expectedEngineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get licenseId => $composableBuilder(
    column: $table.licenseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get licenseSnapshotPath => $composableBuilder(
    column: $table.licenseSnapshotPath,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ModelManifestsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ModelManifestsTable> {
  $$ModelManifestsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<String> get expectedEngineId => $composableBuilder(
    column: $table.expectedEngineId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get licenseId =>
      $composableBuilder(column: $table.licenseId, builder: (column) => column);

  GeneratedColumn<String> get licenseSnapshotPath => $composableBuilder(
    column: $table.licenseSnapshotPath,
    builder: (column) => column,
  );

  Expression<T> transcriptRunsRefs<T extends Object>(
    Expression<T> Function($$TranscriptRunsTableAnnotationComposer a) f,
  ) {
    final $$TranscriptRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transcriptRuns,
      getReferencedColumn: (t) => t.modelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.transcriptRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> diarizationRunsRefs<T extends Object>(
    Expression<T> Function($$DiarizationRunsTableAnnotationComposer a) f,
  ) {
    final $$DiarizationRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.diarizationRuns,
      getReferencedColumn: (t) => t.modelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DiarizationRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.diarizationRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> processingJobsRefs<T extends Object>(
    Expression<T> Function($$ProcessingJobsTableAnnotationComposer a) f,
  ) {
    final $$ProcessingJobsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.processingJobs,
      getReferencedColumn: (t) => t.modelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProcessingJobsTableAnnotationComposer(
            $db: $db,
            $table: $db.processingJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> modelCapabilityEntriesRefs<T extends Object>(
    Expression<T> Function($$ModelCapabilityEntriesTableAnnotationComposer a) f,
  ) {
    final $$ModelCapabilityEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.modelCapabilityEntries,
          getReferencedColumn: (t) => t.modelId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ModelCapabilityEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.modelCapabilityEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> modelModeEntriesRefs<T extends Object>(
    Expression<T> Function($$ModelModeEntriesTableAnnotationComposer a) f,
  ) {
    final $$ModelModeEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.modelModeEntries,
      getReferencedColumn: (t) => t.modelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModelModeEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.modelModeEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ModelManifestsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ModelManifestsTable,
          ModelManifest,
          $$ModelManifestsTableFilterComposer,
          $$ModelManifestsTableOrderingComposer,
          $$ModelManifestsTableAnnotationComposer,
          $$ModelManifestsTableCreateCompanionBuilder,
          $$ModelManifestsTableUpdateCompanionBuilder,
          (ModelManifest, $$ModelManifestsTableReferences),
          ModelManifest,
          PrefetchHooks Function({
            bool transcriptRunsRefs,
            bool diarizationRunsRefs,
            bool processingJobsRefs,
            bool modelCapabilityEntriesRefs,
            bool modelModeEntriesRefs,
          })
        > {
  $$ModelManifestsTableTableManager(
    _$AppDatabase db,
    $ModelManifestsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ModelManifestsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ModelManifestsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ModelManifestsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> sha256 = const Value.absent(),
                Value<int> bytes = const Value.absent(),
                Value<String> expectedEngineId = const Value.absent(),
                Value<String> licenseId = const Value.absent(),
                Value<String> licenseSnapshotPath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ModelManifestsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                version: version,
                source: source,
                sha256: sha256,
                bytes: bytes,
                expectedEngineId: expectedEngineId,
                licenseId: licenseId,
                licenseSnapshotPath: licenseSnapshotPath,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int createdAt,
                required int updatedAt,
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                required String version,
                required String source,
                required String sha256,
                required int bytes,
                required String expectedEngineId,
                required String licenseId,
                required String licenseSnapshotPath,
                Value<int> rowid = const Value.absent(),
              }) => ModelManifestsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                version: version,
                source: source,
                sha256: sha256,
                bytes: bytes,
                expectedEngineId: expectedEngineId,
                licenseId: licenseId,
                licenseSnapshotPath: licenseSnapshotPath,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ModelManifestsTable, ModelManifest>(table),
                  $$ModelManifestsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                transcriptRunsRefs = false,
                diarizationRunsRefs = false,
                processingJobsRefs = false,
                modelCapabilityEntriesRefs = false,
                modelModeEntriesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (transcriptRunsRefs) db.transcriptRuns,
                    if (diarizationRunsRefs) db.diarizationRuns,
                    if (processingJobsRefs) db.processingJobs,
                    if (modelCapabilityEntriesRefs) db.modelCapabilityEntries,
                    if (modelModeEntriesRefs) db.modelModeEntries,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (transcriptRunsRefs)
                        await $_getPrefetchedData<
                          ModelManifest,
                          $ModelManifestsTable,
                          TranscriptRun
                        >(
                          currentTable: table,
                          referencedTable: $$ModelManifestsTableReferences
                              ._transcriptRunsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ModelManifestsTableReferences(
                                db,
                                table,
                                p0,
                              ).transcriptRunsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.modelId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (diarizationRunsRefs)
                        await $_getPrefetchedData<
                          ModelManifest,
                          $ModelManifestsTable,
                          DiarizationRun
                        >(
                          currentTable: table,
                          referencedTable: $$ModelManifestsTableReferences
                              ._diarizationRunsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ModelManifestsTableReferences(
                                db,
                                table,
                                p0,
                              ).diarizationRunsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.modelId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (processingJobsRefs)
                        await $_getPrefetchedData<
                          ModelManifest,
                          $ModelManifestsTable,
                          ProcessingJob
                        >(
                          currentTable: table,
                          referencedTable: $$ModelManifestsTableReferences
                              ._processingJobsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ModelManifestsTableReferences(
                                db,
                                table,
                                p0,
                              ).processingJobsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.modelId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (modelCapabilityEntriesRefs)
                        await $_getPrefetchedData<
                          ModelManifest,
                          $ModelManifestsTable,
                          ModelCapabilityEntry
                        >(
                          currentTable: table,
                          referencedTable: $$ModelManifestsTableReferences
                              ._modelCapabilityEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ModelManifestsTableReferences(
                                db,
                                table,
                                p0,
                              ).modelCapabilityEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.modelId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (modelModeEntriesRefs)
                        await $_getPrefetchedData<
                          ModelManifest,
                          $ModelManifestsTable,
                          ModelModeEntry
                        >(
                          currentTable: table,
                          referencedTable: $$ModelManifestsTableReferences
                              ._modelModeEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ModelManifestsTableReferences(
                                db,
                                table,
                                p0,
                              ).modelModeEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.modelId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ModelManifestsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ModelManifestsTable,
      ModelManifest,
      $$ModelManifestsTableFilterComposer,
      $$ModelManifestsTableOrderingComposer,
      $$ModelManifestsTableAnnotationComposer,
      $$ModelManifestsTableCreateCompanionBuilder,
      $$ModelManifestsTableUpdateCompanionBuilder,
      (ModelManifest, $$ModelManifestsTableReferences),
      ModelManifest,
      PrefetchHooks Function({
        bool transcriptRunsRefs,
        bool diarizationRunsRefs,
        bool processingJobsRefs,
        bool modelCapabilityEntriesRefs,
        bool modelModeEntriesRefs,
      })
    >;
typedef $$TranscriptRunsTableCreateCompanionBuilder =
    TranscriptRunsCompanion Function({
      required String id,
      required int createdAt,
      required int updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      required String meetingId,
      required String engineId,
      required String engineVersion,
      required String modelId,
      required String modelVersion,
      required String modelSha256,
      required String parametersJson,
      required String runState,
      Value<int?> startedAtUtcMs,
      Value<int?> endedAtUtcMs,
      Value<double> progress,
      Value<String?> failureCode,
      Value<int> rowid,
    });
typedef $$TranscriptRunsTableUpdateCompanionBuilder =
    TranscriptRunsCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      Value<String> meetingId,
      Value<String> engineId,
      Value<String> engineVersion,
      Value<String> modelId,
      Value<String> modelVersion,
      Value<String> modelSha256,
      Value<String> parametersJson,
      Value<String> runState,
      Value<int?> startedAtUtcMs,
      Value<int?> endedAtUtcMs,
      Value<double> progress,
      Value<String?> failureCode,
      Value<int> rowid,
    });

final class $$TranscriptRunsTableReferences
    extends BaseReferences<_$AppDatabase, $TranscriptRunsTable, TranscriptRun> {
  $$TranscriptRunsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) =>
      db.meetings.createAlias('transcript_runs__meeting_id__meetings__id');

  $$MeetingsTableProcessedTableManager get meetingId {
    final $_column = $_itemColumn<String>('meeting_id')!;

    final manager = $$MeetingsTableTableManager(
      $_db,
      $_db.meetings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_meetingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ModelManifestsTable _modelIdTable(_$AppDatabase db) => db
      .modelManifests
      .createAlias('transcript_runs__model_id__model_manifests__id');

  $$ModelManifestsTableProcessedTableManager get modelId {
    final $_column = $_itemColumn<String>('model_id')!;

    final manager = $$ModelManifestsTableTableManager(
      $_db,
      $_db.modelManifests,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_modelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $MeetingTranscriptSelectionsTable,
    List<MeetingTranscriptSelection>
  >
  _meetingTranscriptSelectionsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.meetingTranscriptSelections,
    aliasName:
        'transcript_runs__id__meeting_transcript_selections__transcript_run_id',
  );

  $$MeetingTranscriptSelectionsTableProcessedTableManager
  get meetingTranscriptSelectionsRefs {
    final manager =
        $$MeetingTranscriptSelectionsTableTableManager(
          $_db,
          $_db.meetingTranscriptSelections,
        ).filter(
          (f) => f.transcriptRunId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _meetingTranscriptSelectionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TranscriptSegmentsTable, List<TranscriptSegment>>
  _transcriptSegmentsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.transcriptSegments,
        aliasName:
            'transcript_runs__id__transcript_segments__transcript_run_id',
      );

  $$TranscriptSegmentsTableProcessedTableManager get transcriptSegmentsRefs {
    final manager =
        $$TranscriptSegmentsTableTableManager(
          $_db,
          $_db.transcriptSegments,
        ).filter(
          (f) => f.transcriptRunId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _transcriptSegmentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TranscriptRunsTableFilterComposer
    extends Composer<_$AppDatabase, $TranscriptRunsTable> {
  $$TranscriptRunsTableFilterComposer({
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

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get engineId => $composableBuilder(
    column: $table.engineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get engineVersion => $composableBuilder(
    column: $table.engineVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelVersion => $composableBuilder(
    column: $table.modelVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelSha256 => $composableBuilder(
    column: $table.modelSha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parametersJson => $composableBuilder(
    column: $table.parametersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get runState => $composableBuilder(
    column: $table.runState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAtUtcMs => $composableBuilder(
    column: $table.startedAtUtcMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endedAtUtcMs => $composableBuilder(
    column: $table.endedAtUtcMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => ColumnFilters(column),
  );

  $$MeetingsTableFilterComposer get meetingId {
    final $$MeetingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableFilterComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ModelManifestsTableFilterComposer get modelId {
    final $$ModelManifestsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.modelId,
      referencedTable: $db.modelManifests,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModelManifestsTableFilterComposer(
            $db: $db,
            $table: $db.modelManifests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> meetingTranscriptSelectionsRefs(
    Expression<bool> Function(
      $$MeetingTranscriptSelectionsTableFilterComposer f,
    )
    f,
  ) {
    final $$MeetingTranscriptSelectionsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.meetingTranscriptSelections,
          getReferencedColumn: (t) => t.transcriptRunId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MeetingTranscriptSelectionsTableFilterComposer(
                $db: $db,
                $table: $db.meetingTranscriptSelections,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> transcriptSegmentsRefs(
    Expression<bool> Function($$TranscriptSegmentsTableFilterComposer f) f,
  ) {
    final $$TranscriptSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transcriptSegments,
      getReferencedColumn: (t) => t.transcriptRunId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.transcriptSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TranscriptRunsTableOrderingComposer
    extends Composer<_$AppDatabase, $TranscriptRunsTable> {
  $$TranscriptRunsTableOrderingComposer({
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

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get engineId => $composableBuilder(
    column: $table.engineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get engineVersion => $composableBuilder(
    column: $table.engineVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelVersion => $composableBuilder(
    column: $table.modelVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelSha256 => $composableBuilder(
    column: $table.modelSha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parametersJson => $composableBuilder(
    column: $table.parametersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get runState => $composableBuilder(
    column: $table.runState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAtUtcMs => $composableBuilder(
    column: $table.startedAtUtcMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endedAtUtcMs => $composableBuilder(
    column: $table.endedAtUtcMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => ColumnOrderings(column),
  );

  $$MeetingsTableOrderingComposer get meetingId {
    final $$MeetingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableOrderingComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ModelManifestsTableOrderingComposer get modelId {
    final $$ModelManifestsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.modelId,
      referencedTable: $db.modelManifests,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModelManifestsTableOrderingComposer(
            $db: $db,
            $table: $db.modelManifests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TranscriptRunsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TranscriptRunsTable> {
  $$TranscriptRunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get engineId =>
      $composableBuilder(column: $table.engineId, builder: (column) => column);

  GeneratedColumn<String> get engineVersion => $composableBuilder(
    column: $table.engineVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get modelVersion => $composableBuilder(
    column: $table.modelVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get modelSha256 => $composableBuilder(
    column: $table.modelSha256,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parametersJson => $composableBuilder(
    column: $table.parametersJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get runState =>
      $composableBuilder(column: $table.runState, builder: (column) => column);

  GeneratedColumn<int> get startedAtUtcMs => $composableBuilder(
    column: $table.startedAtUtcMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endedAtUtcMs => $composableBuilder(
    column: $table.endedAtUtcMs,
    builder: (column) => column,
  );

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => column,
  );

  $$MeetingsTableAnnotationComposer get meetingId {
    final $$MeetingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableAnnotationComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ModelManifestsTableAnnotationComposer get modelId {
    final $$ModelManifestsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.modelId,
      referencedTable: $db.modelManifests,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModelManifestsTableAnnotationComposer(
            $db: $db,
            $table: $db.modelManifests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> meetingTranscriptSelectionsRefs<T extends Object>(
    Expression<T> Function(
      $$MeetingTranscriptSelectionsTableAnnotationComposer a,
    )
    f,
  ) {
    final $$MeetingTranscriptSelectionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.meetingTranscriptSelections,
          getReferencedColumn: (t) => t.transcriptRunId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MeetingTranscriptSelectionsTableAnnotationComposer(
                $db: $db,
                $table: $db.meetingTranscriptSelections,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> transcriptSegmentsRefs<T extends Object>(
    Expression<T> Function($$TranscriptSegmentsTableAnnotationComposer a) f,
  ) {
    final $$TranscriptSegmentsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.transcriptSegments,
          getReferencedColumn: (t) => t.transcriptRunId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TranscriptSegmentsTableAnnotationComposer(
                $db: $db,
                $table: $db.transcriptSegments,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$TranscriptRunsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TranscriptRunsTable,
          TranscriptRun,
          $$TranscriptRunsTableFilterComposer,
          $$TranscriptRunsTableOrderingComposer,
          $$TranscriptRunsTableAnnotationComposer,
          $$TranscriptRunsTableCreateCompanionBuilder,
          $$TranscriptRunsTableUpdateCompanionBuilder,
          (TranscriptRun, $$TranscriptRunsTableReferences),
          TranscriptRun,
          PrefetchHooks Function({
            bool meetingId,
            bool modelId,
            bool meetingTranscriptSelectionsRefs,
            bool transcriptSegmentsRefs,
          })
        > {
  $$TranscriptRunsTableTableManager(
    _$AppDatabase db,
    $TranscriptRunsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TranscriptRunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TranscriptRunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TranscriptRunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> meetingId = const Value.absent(),
                Value<String> engineId = const Value.absent(),
                Value<String> engineVersion = const Value.absent(),
                Value<String> modelId = const Value.absent(),
                Value<String> modelVersion = const Value.absent(),
                Value<String> modelSha256 = const Value.absent(),
                Value<String> parametersJson = const Value.absent(),
                Value<String> runState = const Value.absent(),
                Value<int?> startedAtUtcMs = const Value.absent(),
                Value<int?> endedAtUtcMs = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<String?> failureCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TranscriptRunsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                meetingId: meetingId,
                engineId: engineId,
                engineVersion: engineVersion,
                modelId: modelId,
                modelVersion: modelVersion,
                modelSha256: modelSha256,
                parametersJson: parametersJson,
                runState: runState,
                startedAtUtcMs: startedAtUtcMs,
                endedAtUtcMs: endedAtUtcMs,
                progress: progress,
                failureCode: failureCode,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int createdAt,
                required int updatedAt,
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                required String meetingId,
                required String engineId,
                required String engineVersion,
                required String modelId,
                required String modelVersion,
                required String modelSha256,
                required String parametersJson,
                required String runState,
                Value<int?> startedAtUtcMs = const Value.absent(),
                Value<int?> endedAtUtcMs = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<String?> failureCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TranscriptRunsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                meetingId: meetingId,
                engineId: engineId,
                engineVersion: engineVersion,
                modelId: modelId,
                modelVersion: modelVersion,
                modelSha256: modelSha256,
                parametersJson: parametersJson,
                runState: runState,
                startedAtUtcMs: startedAtUtcMs,
                endedAtUtcMs: endedAtUtcMs,
                progress: progress,
                failureCode: failureCode,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TranscriptRunsTable, TranscriptRun>(table),
                  $$TranscriptRunsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                meetingId = false,
                modelId = false,
                meetingTranscriptSelectionsRefs = false,
                transcriptSegmentsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (meetingTranscriptSelectionsRefs)
                      db.meetingTranscriptSelections,
                    if (transcriptSegmentsRefs) db.transcriptSegments,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (meetingId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.meetingId,
                                    referencedTable:
                                        $$TranscriptRunsTableReferences
                                            ._meetingIdTable(db),
                                    referencedColumn:
                                        $$TranscriptRunsTableReferences
                                            ._meetingIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (modelId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.modelId,
                                    referencedTable:
                                        $$TranscriptRunsTableReferences
                                            ._modelIdTable(db),
                                    referencedColumn:
                                        $$TranscriptRunsTableReferences
                                            ._modelIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (meetingTranscriptSelectionsRefs)
                        await $_getPrefetchedData<
                          TranscriptRun,
                          $TranscriptRunsTable,
                          MeetingTranscriptSelection
                        >(
                          currentTable: table,
                          referencedTable: $$TranscriptRunsTableReferences
                              ._meetingTranscriptSelectionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TranscriptRunsTableReferences(
                                db,
                                table,
                                p0,
                              ).meetingTranscriptSelectionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.transcriptRunId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (transcriptSegmentsRefs)
                        await $_getPrefetchedData<
                          TranscriptRun,
                          $TranscriptRunsTable,
                          TranscriptSegment
                        >(
                          currentTable: table,
                          referencedTable: $$TranscriptRunsTableReferences
                              ._transcriptSegmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TranscriptRunsTableReferences(
                                db,
                                table,
                                p0,
                              ).transcriptSegmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.transcriptRunId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TranscriptRunsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TranscriptRunsTable,
      TranscriptRun,
      $$TranscriptRunsTableFilterComposer,
      $$TranscriptRunsTableOrderingComposer,
      $$TranscriptRunsTableAnnotationComposer,
      $$TranscriptRunsTableCreateCompanionBuilder,
      $$TranscriptRunsTableUpdateCompanionBuilder,
      (TranscriptRun, $$TranscriptRunsTableReferences),
      TranscriptRun,
      PrefetchHooks Function({
        bool meetingId,
        bool modelId,
        bool meetingTranscriptSelectionsRefs,
        bool transcriptSegmentsRefs,
      })
    >;
typedef $$MeetingTranscriptSelectionsTableCreateCompanionBuilder =
    MeetingTranscriptSelectionsCompanion Function({
      required String id,
      required int createdAt,
      required int updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      required String meetingId,
      required String transcriptRunId,
      Value<int> rowid,
    });
typedef $$MeetingTranscriptSelectionsTableUpdateCompanionBuilder =
    MeetingTranscriptSelectionsCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      Value<String> meetingId,
      Value<String> transcriptRunId,
      Value<int> rowid,
    });

final class $$MeetingTranscriptSelectionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $MeetingTranscriptSelectionsTable,
          MeetingTranscriptSelection
        > {
  $$MeetingTranscriptSelectionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) => db.meetings
      .createAlias('meeting_transcript_selections__meeting_id__meetings__id');

  $$MeetingsTableProcessedTableManager get meetingId {
    final $_column = $_itemColumn<String>('meeting_id')!;

    final manager = $$MeetingsTableTableManager(
      $_db,
      $_db.meetings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_meetingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TranscriptRunsTable _transcriptRunIdTable(_$AppDatabase db) =>
      db.transcriptRuns.createAlias(
        'meeting_transcript_selections__transcript_run_id__transcript_runs__id',
      );

  $$TranscriptRunsTableProcessedTableManager get transcriptRunId {
    final $_column = $_itemColumn<String>('transcript_run_id')!;

    final manager = $$TranscriptRunsTableTableManager(
      $_db,
      $_db.transcriptRuns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transcriptRunIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MeetingTranscriptSelectionsTableFilterComposer
    extends Composer<_$AppDatabase, $MeetingTranscriptSelectionsTable> {
  $$MeetingTranscriptSelectionsTableFilterComposer({
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

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MeetingsTableFilterComposer get meetingId {
    final $$MeetingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableFilterComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TranscriptRunsTableFilterComposer get transcriptRunId {
    final $$TranscriptRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transcriptRunId,
      referencedTable: $db.transcriptRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptRunsTableFilterComposer(
            $db: $db,
            $table: $db.transcriptRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MeetingTranscriptSelectionsTableOrderingComposer
    extends Composer<_$AppDatabase, $MeetingTranscriptSelectionsTable> {
  $$MeetingTranscriptSelectionsTableOrderingComposer({
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

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MeetingsTableOrderingComposer get meetingId {
    final $$MeetingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableOrderingComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TranscriptRunsTableOrderingComposer get transcriptRunId {
    final $$TranscriptRunsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transcriptRunId,
      referencedTable: $db.transcriptRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptRunsTableOrderingComposer(
            $db: $db,
            $table: $db.transcriptRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MeetingTranscriptSelectionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MeetingTranscriptSelectionsTable> {
  $$MeetingTranscriptSelectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$MeetingsTableAnnotationComposer get meetingId {
    final $$MeetingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableAnnotationComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TranscriptRunsTableAnnotationComposer get transcriptRunId {
    final $$TranscriptRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transcriptRunId,
      referencedTable: $db.transcriptRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.transcriptRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MeetingTranscriptSelectionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MeetingTranscriptSelectionsTable,
          MeetingTranscriptSelection,
          $$MeetingTranscriptSelectionsTableFilterComposer,
          $$MeetingTranscriptSelectionsTableOrderingComposer,
          $$MeetingTranscriptSelectionsTableAnnotationComposer,
          $$MeetingTranscriptSelectionsTableCreateCompanionBuilder,
          $$MeetingTranscriptSelectionsTableUpdateCompanionBuilder,
          (
            MeetingTranscriptSelection,
            $$MeetingTranscriptSelectionsTableReferences,
          ),
          MeetingTranscriptSelection,
          PrefetchHooks Function({bool meetingId, bool transcriptRunId})
        > {
  $$MeetingTranscriptSelectionsTableTableManager(
    _$AppDatabase db,
    $MeetingTranscriptSelectionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MeetingTranscriptSelectionsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$MeetingTranscriptSelectionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MeetingTranscriptSelectionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> meetingId = const Value.absent(),
                Value<String> transcriptRunId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MeetingTranscriptSelectionsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                meetingId: meetingId,
                transcriptRunId: transcriptRunId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int createdAt,
                required int updatedAt,
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                required String meetingId,
                required String transcriptRunId,
                Value<int> rowid = const Value.absent(),
              }) => MeetingTranscriptSelectionsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                meetingId: meetingId,
                transcriptRunId: transcriptRunId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $MeetingTranscriptSelectionsTable,
                    MeetingTranscriptSelection
                  >(table),
                  $$MeetingTranscriptSelectionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({meetingId = false, transcriptRunId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (meetingId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.meetingId,
                                referencedTable:
                                    $$MeetingTranscriptSelectionsTableReferences
                                        ._meetingIdTable(db),
                                referencedColumn:
                                    $$MeetingTranscriptSelectionsTableReferences
                                        ._meetingIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (transcriptRunId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.transcriptRunId,
                                referencedTable:
                                    $$MeetingTranscriptSelectionsTableReferences
                                        ._transcriptRunIdTable(db),
                                referencedColumn:
                                    $$MeetingTranscriptSelectionsTableReferences
                                        ._transcriptRunIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MeetingTranscriptSelectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MeetingTranscriptSelectionsTable,
      MeetingTranscriptSelection,
      $$MeetingTranscriptSelectionsTableFilterComposer,
      $$MeetingTranscriptSelectionsTableOrderingComposer,
      $$MeetingTranscriptSelectionsTableAnnotationComposer,
      $$MeetingTranscriptSelectionsTableCreateCompanionBuilder,
      $$MeetingTranscriptSelectionsTableUpdateCompanionBuilder,
      (
        MeetingTranscriptSelection,
        $$MeetingTranscriptSelectionsTableReferences,
      ),
      MeetingTranscriptSelection,
      PrefetchHooks Function({bool meetingId, bool transcriptRunId})
    >;
typedef $$DiarizationRunsTableCreateCompanionBuilder =
    DiarizationRunsCompanion Function({
      required String id,
      required int createdAt,
      required int updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      required String meetingId,
      required String engineId,
      required String engineVersion,
      required String modelId,
      required String modelVersion,
      required String modelSha256,
      required String parametersJson,
      required String runState,
      Value<int?> startedAtUtcMs,
      Value<int?> endedAtUtcMs,
      Value<double> progress,
      Value<String?> failureCode,
      Value<int> rowid,
    });
typedef $$DiarizationRunsTableUpdateCompanionBuilder =
    DiarizationRunsCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      Value<String> meetingId,
      Value<String> engineId,
      Value<String> engineVersion,
      Value<String> modelId,
      Value<String> modelVersion,
      Value<String> modelSha256,
      Value<String> parametersJson,
      Value<String> runState,
      Value<int?> startedAtUtcMs,
      Value<int?> endedAtUtcMs,
      Value<double> progress,
      Value<String?> failureCode,
      Value<int> rowid,
    });

final class $$DiarizationRunsTableReferences
    extends
        BaseReferences<_$AppDatabase, $DiarizationRunsTable, DiarizationRun> {
  $$DiarizationRunsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) =>
      db.meetings.createAlias('diarization_runs__meeting_id__meetings__id');

  $$MeetingsTableProcessedTableManager get meetingId {
    final $_column = $_itemColumn<String>('meeting_id')!;

    final manager = $$MeetingsTableTableManager(
      $_db,
      $_db.meetings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_meetingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ModelManifestsTable _modelIdTable(_$AppDatabase db) => db
      .modelManifests
      .createAlias('diarization_runs__model_id__model_manifests__id');

  $$ModelManifestsTableProcessedTableManager get modelId {
    final $_column = $_itemColumn<String>('model_id')!;

    final manager = $$ModelManifestsTableTableManager(
      $_db,
      $_db.modelManifests,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_modelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SpeakersTable, List<Speaker>> _speakersRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.speakers,
    aliasName: 'diarization_runs__id__speakers__analysis_run_id',
  );

  $$SpeakersTableProcessedTableManager get speakersRefs {
    final manager = $$SpeakersTableTableManager(
      $_db,
      $_db.speakers,
    ).filter((f) => f.analysisRunId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_speakersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SpeakerAssignmentsTable, List<SpeakerAssignment>>
  _speakerAssignmentsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.speakerAssignments,
        aliasName: 'diarization_runs__id__speaker_assignments__analysis_run_id',
      );

  $$SpeakerAssignmentsTableProcessedTableManager get speakerAssignmentsRefs {
    final manager = $$SpeakerAssignmentsTableTableManager(
      $_db,
      $_db.speakerAssignments,
    ).filter((f) => f.analysisRunId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _speakerAssignmentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DiarizationRunsTableFilterComposer
    extends Composer<_$AppDatabase, $DiarizationRunsTable> {
  $$DiarizationRunsTableFilterComposer({
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

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get engineId => $composableBuilder(
    column: $table.engineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get engineVersion => $composableBuilder(
    column: $table.engineVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelVersion => $composableBuilder(
    column: $table.modelVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelSha256 => $composableBuilder(
    column: $table.modelSha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parametersJson => $composableBuilder(
    column: $table.parametersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get runState => $composableBuilder(
    column: $table.runState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAtUtcMs => $composableBuilder(
    column: $table.startedAtUtcMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endedAtUtcMs => $composableBuilder(
    column: $table.endedAtUtcMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => ColumnFilters(column),
  );

  $$MeetingsTableFilterComposer get meetingId {
    final $$MeetingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableFilterComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ModelManifestsTableFilterComposer get modelId {
    final $$ModelManifestsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.modelId,
      referencedTable: $db.modelManifests,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModelManifestsTableFilterComposer(
            $db: $db,
            $table: $db.modelManifests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> speakersRefs(
    Expression<bool> Function($$SpeakersTableFilterComposer f) f,
  ) {
    final $$SpeakersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.speakers,
      getReferencedColumn: (t) => t.analysisRunId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakersTableFilterComposer(
            $db: $db,
            $table: $db.speakers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> speakerAssignmentsRefs(
    Expression<bool> Function($$SpeakerAssignmentsTableFilterComposer f) f,
  ) {
    final $$SpeakerAssignmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.speakerAssignments,
      getReferencedColumn: (t) => t.analysisRunId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakerAssignmentsTableFilterComposer(
            $db: $db,
            $table: $db.speakerAssignments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DiarizationRunsTableOrderingComposer
    extends Composer<_$AppDatabase, $DiarizationRunsTable> {
  $$DiarizationRunsTableOrderingComposer({
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

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get engineId => $composableBuilder(
    column: $table.engineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get engineVersion => $composableBuilder(
    column: $table.engineVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelVersion => $composableBuilder(
    column: $table.modelVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelSha256 => $composableBuilder(
    column: $table.modelSha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parametersJson => $composableBuilder(
    column: $table.parametersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get runState => $composableBuilder(
    column: $table.runState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAtUtcMs => $composableBuilder(
    column: $table.startedAtUtcMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endedAtUtcMs => $composableBuilder(
    column: $table.endedAtUtcMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => ColumnOrderings(column),
  );

  $$MeetingsTableOrderingComposer get meetingId {
    final $$MeetingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableOrderingComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ModelManifestsTableOrderingComposer get modelId {
    final $$ModelManifestsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.modelId,
      referencedTable: $db.modelManifests,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModelManifestsTableOrderingComposer(
            $db: $db,
            $table: $db.modelManifests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DiarizationRunsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiarizationRunsTable> {
  $$DiarizationRunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get engineId =>
      $composableBuilder(column: $table.engineId, builder: (column) => column);

  GeneratedColumn<String> get engineVersion => $composableBuilder(
    column: $table.engineVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get modelVersion => $composableBuilder(
    column: $table.modelVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get modelSha256 => $composableBuilder(
    column: $table.modelSha256,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parametersJson => $composableBuilder(
    column: $table.parametersJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get runState =>
      $composableBuilder(column: $table.runState, builder: (column) => column);

  GeneratedColumn<int> get startedAtUtcMs => $composableBuilder(
    column: $table.startedAtUtcMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endedAtUtcMs => $composableBuilder(
    column: $table.endedAtUtcMs,
    builder: (column) => column,
  );

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => column,
  );

  $$MeetingsTableAnnotationComposer get meetingId {
    final $$MeetingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableAnnotationComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ModelManifestsTableAnnotationComposer get modelId {
    final $$ModelManifestsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.modelId,
      referencedTable: $db.modelManifests,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModelManifestsTableAnnotationComposer(
            $db: $db,
            $table: $db.modelManifests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> speakersRefs<T extends Object>(
    Expression<T> Function($$SpeakersTableAnnotationComposer a) f,
  ) {
    final $$SpeakersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.speakers,
      getReferencedColumn: (t) => t.analysisRunId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakersTableAnnotationComposer(
            $db: $db,
            $table: $db.speakers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> speakerAssignmentsRefs<T extends Object>(
    Expression<T> Function($$SpeakerAssignmentsTableAnnotationComposer a) f,
  ) {
    final $$SpeakerAssignmentsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.speakerAssignments,
          getReferencedColumn: (t) => t.analysisRunId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SpeakerAssignmentsTableAnnotationComposer(
                $db: $db,
                $table: $db.speakerAssignments,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$DiarizationRunsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiarizationRunsTable,
          DiarizationRun,
          $$DiarizationRunsTableFilterComposer,
          $$DiarizationRunsTableOrderingComposer,
          $$DiarizationRunsTableAnnotationComposer,
          $$DiarizationRunsTableCreateCompanionBuilder,
          $$DiarizationRunsTableUpdateCompanionBuilder,
          (DiarizationRun, $$DiarizationRunsTableReferences),
          DiarizationRun,
          PrefetchHooks Function({
            bool meetingId,
            bool modelId,
            bool speakersRefs,
            bool speakerAssignmentsRefs,
          })
        > {
  $$DiarizationRunsTableTableManager(
    _$AppDatabase db,
    $DiarizationRunsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiarizationRunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiarizationRunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiarizationRunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> meetingId = const Value.absent(),
                Value<String> engineId = const Value.absent(),
                Value<String> engineVersion = const Value.absent(),
                Value<String> modelId = const Value.absent(),
                Value<String> modelVersion = const Value.absent(),
                Value<String> modelSha256 = const Value.absent(),
                Value<String> parametersJson = const Value.absent(),
                Value<String> runState = const Value.absent(),
                Value<int?> startedAtUtcMs = const Value.absent(),
                Value<int?> endedAtUtcMs = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<String?> failureCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiarizationRunsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                meetingId: meetingId,
                engineId: engineId,
                engineVersion: engineVersion,
                modelId: modelId,
                modelVersion: modelVersion,
                modelSha256: modelSha256,
                parametersJson: parametersJson,
                runState: runState,
                startedAtUtcMs: startedAtUtcMs,
                endedAtUtcMs: endedAtUtcMs,
                progress: progress,
                failureCode: failureCode,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int createdAt,
                required int updatedAt,
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                required String meetingId,
                required String engineId,
                required String engineVersion,
                required String modelId,
                required String modelVersion,
                required String modelSha256,
                required String parametersJson,
                required String runState,
                Value<int?> startedAtUtcMs = const Value.absent(),
                Value<int?> endedAtUtcMs = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<String?> failureCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiarizationRunsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                meetingId: meetingId,
                engineId: engineId,
                engineVersion: engineVersion,
                modelId: modelId,
                modelVersion: modelVersion,
                modelSha256: modelSha256,
                parametersJson: parametersJson,
                runState: runState,
                startedAtUtcMs: startedAtUtcMs,
                endedAtUtcMs: endedAtUtcMs,
                progress: progress,
                failureCode: failureCode,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DiarizationRunsTable, DiarizationRun>(table),
                  $$DiarizationRunsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                meetingId = false,
                modelId = false,
                speakersRefs = false,
                speakerAssignmentsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (speakersRefs) db.speakers,
                    if (speakerAssignmentsRefs) db.speakerAssignments,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (meetingId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.meetingId,
                                    referencedTable:
                                        $$DiarizationRunsTableReferences
                                            ._meetingIdTable(db),
                                    referencedColumn:
                                        $$DiarizationRunsTableReferences
                                            ._meetingIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (modelId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.modelId,
                                    referencedTable:
                                        $$DiarizationRunsTableReferences
                                            ._modelIdTable(db),
                                    referencedColumn:
                                        $$DiarizationRunsTableReferences
                                            ._modelIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (speakersRefs)
                        await $_getPrefetchedData<
                          DiarizationRun,
                          $DiarizationRunsTable,
                          Speaker
                        >(
                          currentTable: table,
                          referencedTable: $$DiarizationRunsTableReferences
                              ._speakersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DiarizationRunsTableReferences(
                                db,
                                table,
                                p0,
                              ).speakersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.analysisRunId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (speakerAssignmentsRefs)
                        await $_getPrefetchedData<
                          DiarizationRun,
                          $DiarizationRunsTable,
                          SpeakerAssignment
                        >(
                          currentTable: table,
                          referencedTable: $$DiarizationRunsTableReferences
                              ._speakerAssignmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DiarizationRunsTableReferences(
                                db,
                                table,
                                p0,
                              ).speakerAssignmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.analysisRunId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$DiarizationRunsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiarizationRunsTable,
      DiarizationRun,
      $$DiarizationRunsTableFilterComposer,
      $$DiarizationRunsTableOrderingComposer,
      $$DiarizationRunsTableAnnotationComposer,
      $$DiarizationRunsTableCreateCompanionBuilder,
      $$DiarizationRunsTableUpdateCompanionBuilder,
      (DiarizationRun, $$DiarizationRunsTableReferences),
      DiarizationRun,
      PrefetchHooks Function({
        bool meetingId,
        bool modelId,
        bool speakersRefs,
        bool speakerAssignmentsRefs,
      })
    >;
typedef $$SpeakersTableCreateCompanionBuilder =
    SpeakersCompanion Function({
      required String id,
      required int createdAt,
      required int updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      required String meetingId,
      required String analysisRunId,
      required String label,
      Value<int> rowid,
    });
typedef $$SpeakersTableUpdateCompanionBuilder =
    SpeakersCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      Value<String> meetingId,
      Value<String> analysisRunId,
      Value<String> label,
      Value<int> rowid,
    });

final class $$SpeakersTableReferences
    extends BaseReferences<_$AppDatabase, $SpeakersTable, Speaker> {
  $$SpeakersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) =>
      db.meetings.createAlias('speakers__meeting_id__meetings__id');

  $$MeetingsTableProcessedTableManager get meetingId {
    final $_column = $_itemColumn<String>('meeting_id')!;

    final manager = $$MeetingsTableTableManager(
      $_db,
      $_db.meetings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_meetingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $DiarizationRunsTable _analysisRunIdTable(_$AppDatabase db) => db
      .diarizationRuns
      .createAlias('speakers__analysis_run_id__diarization_runs__id');

  $$DiarizationRunsTableProcessedTableManager get analysisRunId {
    final $_column = $_itemColumn<String>('analysis_run_id')!;

    final manager = $$DiarizationRunsTableTableManager(
      $_db,
      $_db.diarizationRuns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_analysisRunIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SpeakersTableFilterComposer
    extends Composer<_$AppDatabase, $SpeakersTable> {
  $$SpeakersTableFilterComposer({
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

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  $$MeetingsTableFilterComposer get meetingId {
    final $$MeetingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableFilterComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DiarizationRunsTableFilterComposer get analysisRunId {
    final $$DiarizationRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.analysisRunId,
      referencedTable: $db.diarizationRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DiarizationRunsTableFilterComposer(
            $db: $db,
            $table: $db.diarizationRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SpeakersTableOrderingComposer
    extends Composer<_$AppDatabase, $SpeakersTable> {
  $$SpeakersTableOrderingComposer({
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

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  $$MeetingsTableOrderingComposer get meetingId {
    final $$MeetingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableOrderingComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DiarizationRunsTableOrderingComposer get analysisRunId {
    final $$DiarizationRunsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.analysisRunId,
      referencedTable: $db.diarizationRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DiarizationRunsTableOrderingComposer(
            $db: $db,
            $table: $db.diarizationRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SpeakersTableAnnotationComposer
    extends Composer<_$AppDatabase, $SpeakersTable> {
  $$SpeakersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  $$MeetingsTableAnnotationComposer get meetingId {
    final $$MeetingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableAnnotationComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DiarizationRunsTableAnnotationComposer get analysisRunId {
    final $$DiarizationRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.analysisRunId,
      referencedTable: $db.diarizationRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DiarizationRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.diarizationRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SpeakersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SpeakersTable,
          Speaker,
          $$SpeakersTableFilterComposer,
          $$SpeakersTableOrderingComposer,
          $$SpeakersTableAnnotationComposer,
          $$SpeakersTableCreateCompanionBuilder,
          $$SpeakersTableUpdateCompanionBuilder,
          (Speaker, $$SpeakersTableReferences),
          Speaker,
          PrefetchHooks Function({bool meetingId, bool analysisRunId})
        > {
  $$SpeakersTableTableManager(_$AppDatabase db, $SpeakersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpeakersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpeakersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SpeakersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> meetingId = const Value.absent(),
                Value<String> analysisRunId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SpeakersCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                meetingId: meetingId,
                analysisRunId: analysisRunId,
                label: label,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int createdAt,
                required int updatedAt,
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                required String meetingId,
                required String analysisRunId,
                required String label,
                Value<int> rowid = const Value.absent(),
              }) => SpeakersCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                meetingId: meetingId,
                analysisRunId: analysisRunId,
                label: label,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SpeakersTable, Speaker>(table),
                  $$SpeakersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({meetingId = false, analysisRunId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (meetingId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.meetingId,
                                referencedTable: $$SpeakersTableReferences
                                    ._meetingIdTable(db),
                                referencedColumn: $$SpeakersTableReferences
                                    ._meetingIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (analysisRunId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.analysisRunId,
                                referencedTable: $$SpeakersTableReferences
                                    ._analysisRunIdTable(db),
                                referencedColumn: $$SpeakersTableReferences
                                    ._analysisRunIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SpeakersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SpeakersTable,
      Speaker,
      $$SpeakersTableFilterComposer,
      $$SpeakersTableOrderingComposer,
      $$SpeakersTableAnnotationComposer,
      $$SpeakersTableCreateCompanionBuilder,
      $$SpeakersTableUpdateCompanionBuilder,
      (Speaker, $$SpeakersTableReferences),
      Speaker,
      PrefetchHooks Function({bool meetingId, bool analysisRunId})
    >;
typedef $$TranscriptSegmentsTableCreateCompanionBuilder =
    TranscriptSegmentsCompanion Function({
      required String id,
      required int createdAt,
      required int updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      required String meetingId,
      required String transcriptRunId,
      required int startUs,
      required int endUs,
      required String rawModelText,
      required String displayedText,
      required String revisionState,
      Value<String?> speakerId,
      Value<String?> speakerMeetingId,
      Value<int> rowid,
    });
typedef $$TranscriptSegmentsTableUpdateCompanionBuilder =
    TranscriptSegmentsCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      Value<String> meetingId,
      Value<String> transcriptRunId,
      Value<int> startUs,
      Value<int> endUs,
      Value<String> rawModelText,
      Value<String> displayedText,
      Value<String> revisionState,
      Value<String?> speakerId,
      Value<String?> speakerMeetingId,
      Value<int> rowid,
    });

final class $$TranscriptSegmentsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $TranscriptSegmentsTable,
          TranscriptSegment
        > {
  $$TranscriptSegmentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) =>
      db.meetings.createAlias('transcript_segments__meeting_id__meetings__id');

  $$MeetingsTableProcessedTableManager get meetingId {
    final $_column = $_itemColumn<String>('meeting_id')!;

    final manager = $$MeetingsTableTableManager(
      $_db,
      $_db.meetings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_meetingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TranscriptRunsTable _transcriptRunIdTable(_$AppDatabase db) =>
      db.transcriptRuns.createAlias(
        'transcript_segments__transcript_run_id__transcript_runs__id',
      );

  $$TranscriptRunsTableProcessedTableManager get transcriptRunId {
    final $_column = $_itemColumn<String>('transcript_run_id')!;

    final manager = $$TranscriptRunsTableTableManager(
      $_db,
      $_db.transcriptRuns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transcriptRunIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$LanguageDecisionsTable, List<LanguageDecision>>
  _languageDecisionsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.languageDecisions,
    aliasName:
        'transcript_segments__id__language_decisions__transcript_segment_id',
  );

  $$LanguageDecisionsTableProcessedTableManager get languageDecisionsRefs {
    final manager =
        $$LanguageDecisionsTableTableManager(
          $_db,
          $_db.languageDecisions,
        ).filter(
          (f) =>
              f.transcriptSegmentId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _languageDecisionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $TranscriptLanguageSelectionsTable,
    List<TranscriptLanguageSelection>
  >
  _transcriptLanguageSelectionsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.transcriptLanguageSelections,
    aliasName:
        'transcript_segments__id__transcript_language_selections__transcript_segment_id',
  );

  $$TranscriptLanguageSelectionsTableProcessedTableManager
  get transcriptLanguageSelectionsRefs {
    final manager =
        $$TranscriptLanguageSelectionsTableTableManager(
          $_db,
          $_db.transcriptLanguageSelections,
        ).filter(
          (f) =>
              f.transcriptSegmentId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _transcriptLanguageSelectionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TranscriptSegmentsTableFilterComposer
    extends Composer<_$AppDatabase, $TranscriptSegmentsTable> {
  $$TranscriptSegmentsTableFilterComposer({
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

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startUs => $composableBuilder(
    column: $table.startUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endUs => $composableBuilder(
    column: $table.endUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawModelText => $composableBuilder(
    column: $table.rawModelText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayedText => $composableBuilder(
    column: $table.displayedText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get revisionState => $composableBuilder(
    column: $table.revisionState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get speakerId => $composableBuilder(
    column: $table.speakerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get speakerMeetingId => $composableBuilder(
    column: $table.speakerMeetingId,
    builder: (column) => ColumnFilters(column),
  );

  $$MeetingsTableFilterComposer get meetingId {
    final $$MeetingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableFilterComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TranscriptRunsTableFilterComposer get transcriptRunId {
    final $$TranscriptRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transcriptRunId,
      referencedTable: $db.transcriptRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptRunsTableFilterComposer(
            $db: $db,
            $table: $db.transcriptRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> languageDecisionsRefs(
    Expression<bool> Function($$LanguageDecisionsTableFilterComposer f) f,
  ) {
    final $$LanguageDecisionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.languageDecisions,
      getReferencedColumn: (t) => t.transcriptSegmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LanguageDecisionsTableFilterComposer(
            $db: $db,
            $table: $db.languageDecisions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> transcriptLanguageSelectionsRefs(
    Expression<bool> Function(
      $$TranscriptLanguageSelectionsTableFilterComposer f,
    )
    f,
  ) {
    final $$TranscriptLanguageSelectionsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.transcriptLanguageSelections,
          getReferencedColumn: (t) => t.transcriptSegmentId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TranscriptLanguageSelectionsTableFilterComposer(
                $db: $db,
                $table: $db.transcriptLanguageSelections,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$TranscriptSegmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $TranscriptSegmentsTable> {
  $$TranscriptSegmentsTableOrderingComposer({
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

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startUs => $composableBuilder(
    column: $table.startUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endUs => $composableBuilder(
    column: $table.endUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawModelText => $composableBuilder(
    column: $table.rawModelText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayedText => $composableBuilder(
    column: $table.displayedText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get revisionState => $composableBuilder(
    column: $table.revisionState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get speakerId => $composableBuilder(
    column: $table.speakerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get speakerMeetingId => $composableBuilder(
    column: $table.speakerMeetingId,
    builder: (column) => ColumnOrderings(column),
  );

  $$MeetingsTableOrderingComposer get meetingId {
    final $$MeetingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableOrderingComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TranscriptRunsTableOrderingComposer get transcriptRunId {
    final $$TranscriptRunsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transcriptRunId,
      referencedTable: $db.transcriptRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptRunsTableOrderingComposer(
            $db: $db,
            $table: $db.transcriptRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TranscriptSegmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TranscriptSegmentsTable> {
  $$TranscriptSegmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get startUs =>
      $composableBuilder(column: $table.startUs, builder: (column) => column);

  GeneratedColumn<int> get endUs =>
      $composableBuilder(column: $table.endUs, builder: (column) => column);

  GeneratedColumn<String> get rawModelText => $composableBuilder(
    column: $table.rawModelText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayedText => $composableBuilder(
    column: $table.displayedText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get revisionState => $composableBuilder(
    column: $table.revisionState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get speakerId =>
      $composableBuilder(column: $table.speakerId, builder: (column) => column);

  GeneratedColumn<String> get speakerMeetingId => $composableBuilder(
    column: $table.speakerMeetingId,
    builder: (column) => column,
  );

  $$MeetingsTableAnnotationComposer get meetingId {
    final $$MeetingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableAnnotationComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TranscriptRunsTableAnnotationComposer get transcriptRunId {
    final $$TranscriptRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transcriptRunId,
      referencedTable: $db.transcriptRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.transcriptRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> languageDecisionsRefs<T extends Object>(
    Expression<T> Function($$LanguageDecisionsTableAnnotationComposer a) f,
  ) {
    final $$LanguageDecisionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.languageDecisions,
          getReferencedColumn: (t) => t.transcriptSegmentId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LanguageDecisionsTableAnnotationComposer(
                $db: $db,
                $table: $db.languageDecisions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> transcriptLanguageSelectionsRefs<T extends Object>(
    Expression<T> Function(
      $$TranscriptLanguageSelectionsTableAnnotationComposer a,
    )
    f,
  ) {
    final $$TranscriptLanguageSelectionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.transcriptLanguageSelections,
          getReferencedColumn: (t) => t.transcriptSegmentId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TranscriptLanguageSelectionsTableAnnotationComposer(
                $db: $db,
                $table: $db.transcriptLanguageSelections,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$TranscriptSegmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TranscriptSegmentsTable,
          TranscriptSegment,
          $$TranscriptSegmentsTableFilterComposer,
          $$TranscriptSegmentsTableOrderingComposer,
          $$TranscriptSegmentsTableAnnotationComposer,
          $$TranscriptSegmentsTableCreateCompanionBuilder,
          $$TranscriptSegmentsTableUpdateCompanionBuilder,
          (TranscriptSegment, $$TranscriptSegmentsTableReferences),
          TranscriptSegment,
          PrefetchHooks Function({
            bool meetingId,
            bool transcriptRunId,
            bool languageDecisionsRefs,
            bool transcriptLanguageSelectionsRefs,
          })
        > {
  $$TranscriptSegmentsTableTableManager(
    _$AppDatabase db,
    $TranscriptSegmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TranscriptSegmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TranscriptSegmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TranscriptSegmentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> meetingId = const Value.absent(),
                Value<String> transcriptRunId = const Value.absent(),
                Value<int> startUs = const Value.absent(),
                Value<int> endUs = const Value.absent(),
                Value<String> rawModelText = const Value.absent(),
                Value<String> displayedText = const Value.absent(),
                Value<String> revisionState = const Value.absent(),
                Value<String?> speakerId = const Value.absent(),
                Value<String?> speakerMeetingId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TranscriptSegmentsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                meetingId: meetingId,
                transcriptRunId: transcriptRunId,
                startUs: startUs,
                endUs: endUs,
                rawModelText: rawModelText,
                displayedText: displayedText,
                revisionState: revisionState,
                speakerId: speakerId,
                speakerMeetingId: speakerMeetingId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int createdAt,
                required int updatedAt,
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                required String meetingId,
                required String transcriptRunId,
                required int startUs,
                required int endUs,
                required String rawModelText,
                required String displayedText,
                required String revisionState,
                Value<String?> speakerId = const Value.absent(),
                Value<String?> speakerMeetingId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TranscriptSegmentsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                meetingId: meetingId,
                transcriptRunId: transcriptRunId,
                startUs: startUs,
                endUs: endUs,
                rawModelText: rawModelText,
                displayedText: displayedText,
                revisionState: revisionState,
                speakerId: speakerId,
                speakerMeetingId: speakerMeetingId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TranscriptSegmentsTable, TranscriptSegment>(
                    table,
                  ),
                  $$TranscriptSegmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                meetingId = false,
                transcriptRunId = false,
                languageDecisionsRefs = false,
                transcriptLanguageSelectionsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (languageDecisionsRefs) db.languageDecisions,
                    if (transcriptLanguageSelectionsRefs)
                      db.transcriptLanguageSelections,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (meetingId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.meetingId,
                                    referencedTable:
                                        $$TranscriptSegmentsTableReferences
                                            ._meetingIdTable(db),
                                    referencedColumn:
                                        $$TranscriptSegmentsTableReferences
                                            ._meetingIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (transcriptRunId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.transcriptRunId,
                                    referencedTable:
                                        $$TranscriptSegmentsTableReferences
                                            ._transcriptRunIdTable(db),
                                    referencedColumn:
                                        $$TranscriptSegmentsTableReferences
                                            ._transcriptRunIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (languageDecisionsRefs)
                        await $_getPrefetchedData<
                          TranscriptSegment,
                          $TranscriptSegmentsTable,
                          LanguageDecision
                        >(
                          currentTable: table,
                          referencedTable: $$TranscriptSegmentsTableReferences
                              ._languageDecisionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TranscriptSegmentsTableReferences(
                                db,
                                table,
                                p0,
                              ).languageDecisionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.transcriptSegmentId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (transcriptLanguageSelectionsRefs)
                        await $_getPrefetchedData<
                          TranscriptSegment,
                          $TranscriptSegmentsTable,
                          TranscriptLanguageSelection
                        >(
                          currentTable: table,
                          referencedTable: $$TranscriptSegmentsTableReferences
                              ._transcriptLanguageSelectionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TranscriptSegmentsTableReferences(
                                db,
                                table,
                                p0,
                              ).transcriptLanguageSelectionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.transcriptSegmentId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TranscriptSegmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TranscriptSegmentsTable,
      TranscriptSegment,
      $$TranscriptSegmentsTableFilterComposer,
      $$TranscriptSegmentsTableOrderingComposer,
      $$TranscriptSegmentsTableAnnotationComposer,
      $$TranscriptSegmentsTableCreateCompanionBuilder,
      $$TranscriptSegmentsTableUpdateCompanionBuilder,
      (TranscriptSegment, $$TranscriptSegmentsTableReferences),
      TranscriptSegment,
      PrefetchHooks Function({
        bool meetingId,
        bool transcriptRunId,
        bool languageDecisionsRefs,
        bool transcriptLanguageSelectionsRefs,
      })
    >;
typedef $$LanguageDecisionsTableCreateCompanionBuilder =
    LanguageDecisionsCompanion Function({
      required String id,
      required int createdAt,
      required int updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      required String transcriptSegmentId,
      required String tag,
      required String source,
      Value<double?> confidence,
      Value<int> rowid,
    });
typedef $$LanguageDecisionsTableUpdateCompanionBuilder =
    LanguageDecisionsCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      Value<String> transcriptSegmentId,
      Value<String> tag,
      Value<String> source,
      Value<double?> confidence,
      Value<int> rowid,
    });

final class $$LanguageDecisionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $LanguageDecisionsTable,
          LanguageDecision
        > {
  $$LanguageDecisionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TranscriptSegmentsTable _transcriptSegmentIdTable(_$AppDatabase db) =>
      db.transcriptSegments.createAlias(
        'language_decisions__transcript_segment_id__transcript_segments__id',
      );

  $$TranscriptSegmentsTableProcessedTableManager get transcriptSegmentId {
    final $_column = $_itemColumn<String>('transcript_segment_id')!;

    final manager = $$TranscriptSegmentsTableTableManager(
      $_db,
      $_db.transcriptSegments,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transcriptSegmentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $TranscriptLanguageSelectionsTable,
    List<TranscriptLanguageSelection>
  >
  _transcriptLanguageSelectionsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.transcriptLanguageSelections,
    aliasName:
        'language_decisions__id__transcript_language_selections__language_decision_id',
  );

  $$TranscriptLanguageSelectionsTableProcessedTableManager
  get transcriptLanguageSelectionsRefs {
    final manager =
        $$TranscriptLanguageSelectionsTableTableManager(
          $_db,
          $_db.transcriptLanguageSelections,
        ).filter(
          (f) => f.languageDecisionId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _transcriptLanguageSelectionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LanguageDecisionsTableFilterComposer
    extends Composer<_$AppDatabase, $LanguageDecisionsTable> {
  $$LanguageDecisionsTableFilterComposer({
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

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  $$TranscriptSegmentsTableFilterComposer get transcriptSegmentId {
    final $$TranscriptSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transcriptSegmentId,
      referencedTable: $db.transcriptSegments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.transcriptSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> transcriptLanguageSelectionsRefs(
    Expression<bool> Function(
      $$TranscriptLanguageSelectionsTableFilterComposer f,
    )
    f,
  ) {
    final $$TranscriptLanguageSelectionsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.transcriptLanguageSelections,
          getReferencedColumn: (t) => t.languageDecisionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TranscriptLanguageSelectionsTableFilterComposer(
                $db: $db,
                $table: $db.transcriptLanguageSelections,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$LanguageDecisionsTableOrderingComposer
    extends Composer<_$AppDatabase, $LanguageDecisionsTable> {
  $$LanguageDecisionsTableOrderingComposer({
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

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  $$TranscriptSegmentsTableOrderingComposer get transcriptSegmentId {
    final $$TranscriptSegmentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transcriptSegmentId,
      referencedTable: $db.transcriptSegments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptSegmentsTableOrderingComposer(
            $db: $db,
            $table: $db.transcriptSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LanguageDecisionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LanguageDecisionsTable> {
  $$LanguageDecisionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  $$TranscriptSegmentsTableAnnotationComposer get transcriptSegmentId {
    final $$TranscriptSegmentsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.transcriptSegmentId,
          referencedTable: $db.transcriptSegments,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TranscriptSegmentsTableAnnotationComposer(
                $db: $db,
                $table: $db.transcriptSegments,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  Expression<T> transcriptLanguageSelectionsRefs<T extends Object>(
    Expression<T> Function(
      $$TranscriptLanguageSelectionsTableAnnotationComposer a,
    )
    f,
  ) {
    final $$TranscriptLanguageSelectionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.transcriptLanguageSelections,
          getReferencedColumn: (t) => t.languageDecisionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TranscriptLanguageSelectionsTableAnnotationComposer(
                $db: $db,
                $table: $db.transcriptLanguageSelections,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$LanguageDecisionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LanguageDecisionsTable,
          LanguageDecision,
          $$LanguageDecisionsTableFilterComposer,
          $$LanguageDecisionsTableOrderingComposer,
          $$LanguageDecisionsTableAnnotationComposer,
          $$LanguageDecisionsTableCreateCompanionBuilder,
          $$LanguageDecisionsTableUpdateCompanionBuilder,
          (LanguageDecision, $$LanguageDecisionsTableReferences),
          LanguageDecision,
          PrefetchHooks Function({
            bool transcriptSegmentId,
            bool transcriptLanguageSelectionsRefs,
          })
        > {
  $$LanguageDecisionsTableTableManager(
    _$AppDatabase db,
    $LanguageDecisionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LanguageDecisionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LanguageDecisionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LanguageDecisionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> transcriptSegmentId = const Value.absent(),
                Value<String> tag = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<double?> confidence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LanguageDecisionsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                transcriptSegmentId: transcriptSegmentId,
                tag: tag,
                source: source,
                confidence: confidence,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int createdAt,
                required int updatedAt,
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                required String transcriptSegmentId,
                required String tag,
                required String source,
                Value<double?> confidence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LanguageDecisionsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                transcriptSegmentId: transcriptSegmentId,
                tag: tag,
                source: source,
                confidence: confidence,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LanguageDecisionsTable, LanguageDecision>(table),
                  $$LanguageDecisionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                transcriptSegmentId = false,
                transcriptLanguageSelectionsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (transcriptLanguageSelectionsRefs)
                      db.transcriptLanguageSelections,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (transcriptSegmentId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.transcriptSegmentId,
                                    referencedTable:
                                        $$LanguageDecisionsTableReferences
                                            ._transcriptSegmentIdTable(db),
                                    referencedColumn:
                                        $$LanguageDecisionsTableReferences
                                            ._transcriptSegmentIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (transcriptLanguageSelectionsRefs)
                        await $_getPrefetchedData<
                          LanguageDecision,
                          $LanguageDecisionsTable,
                          TranscriptLanguageSelection
                        >(
                          currentTable: table,
                          referencedTable: $$LanguageDecisionsTableReferences
                              ._transcriptLanguageSelectionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LanguageDecisionsTableReferences(
                                db,
                                table,
                                p0,
                              ).transcriptLanguageSelectionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.languageDecisionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$LanguageDecisionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LanguageDecisionsTable,
      LanguageDecision,
      $$LanguageDecisionsTableFilterComposer,
      $$LanguageDecisionsTableOrderingComposer,
      $$LanguageDecisionsTableAnnotationComposer,
      $$LanguageDecisionsTableCreateCompanionBuilder,
      $$LanguageDecisionsTableUpdateCompanionBuilder,
      (LanguageDecision, $$LanguageDecisionsTableReferences),
      LanguageDecision,
      PrefetchHooks Function({
        bool transcriptSegmentId,
        bool transcriptLanguageSelectionsRefs,
      })
    >;
typedef $$TranscriptLanguageSelectionsTableCreateCompanionBuilder =
    TranscriptLanguageSelectionsCompanion Function({
      required String id,
      required int createdAt,
      required int updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      required String transcriptSegmentId,
      required String languageDecisionId,
      Value<int> rowid,
    });
typedef $$TranscriptLanguageSelectionsTableUpdateCompanionBuilder =
    TranscriptLanguageSelectionsCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      Value<String> transcriptSegmentId,
      Value<String> languageDecisionId,
      Value<int> rowid,
    });

final class $$TranscriptLanguageSelectionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $TranscriptLanguageSelectionsTable,
          TranscriptLanguageSelection
        > {
  $$TranscriptLanguageSelectionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TranscriptSegmentsTable _transcriptSegmentIdTable(
    _$AppDatabase db,
  ) => db.transcriptSegments.createAlias(
    'transcript_language_selections__transcript_segment_id__transcript_segments__id',
  );

  $$TranscriptSegmentsTableProcessedTableManager get transcriptSegmentId {
    final $_column = $_itemColumn<String>('transcript_segment_id')!;

    final manager = $$TranscriptSegmentsTableTableManager(
      $_db,
      $_db.transcriptSegments,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transcriptSegmentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $LanguageDecisionsTable _languageDecisionIdTable(
    _$AppDatabase db,
  ) => db.languageDecisions.createAlias(
    'transcript_language_selections__language_decision_id__language_decisions__id',
  );

  $$LanguageDecisionsTableProcessedTableManager get languageDecisionId {
    final $_column = $_itemColumn<String>('language_decision_id')!;

    final manager = $$LanguageDecisionsTableTableManager(
      $_db,
      $_db.languageDecisions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_languageDecisionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TranscriptLanguageSelectionsTableFilterComposer
    extends Composer<_$AppDatabase, $TranscriptLanguageSelectionsTable> {
  $$TranscriptLanguageSelectionsTableFilterComposer({
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

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TranscriptSegmentsTableFilterComposer get transcriptSegmentId {
    final $$TranscriptSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transcriptSegmentId,
      referencedTable: $db.transcriptSegments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.transcriptSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LanguageDecisionsTableFilterComposer get languageDecisionId {
    final $$LanguageDecisionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.languageDecisionId,
      referencedTable: $db.languageDecisions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LanguageDecisionsTableFilterComposer(
            $db: $db,
            $table: $db.languageDecisions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TranscriptLanguageSelectionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TranscriptLanguageSelectionsTable> {
  $$TranscriptLanguageSelectionsTableOrderingComposer({
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

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TranscriptSegmentsTableOrderingComposer get transcriptSegmentId {
    final $$TranscriptSegmentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transcriptSegmentId,
      referencedTable: $db.transcriptSegments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptSegmentsTableOrderingComposer(
            $db: $db,
            $table: $db.transcriptSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LanguageDecisionsTableOrderingComposer get languageDecisionId {
    final $$LanguageDecisionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.languageDecisionId,
      referencedTable: $db.languageDecisions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LanguageDecisionsTableOrderingComposer(
            $db: $db,
            $table: $db.languageDecisions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TranscriptLanguageSelectionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TranscriptLanguageSelectionsTable> {
  $$TranscriptLanguageSelectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$TranscriptSegmentsTableAnnotationComposer get transcriptSegmentId {
    final $$TranscriptSegmentsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.transcriptSegmentId,
          referencedTable: $db.transcriptSegments,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TranscriptSegmentsTableAnnotationComposer(
                $db: $db,
                $table: $db.transcriptSegments,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$LanguageDecisionsTableAnnotationComposer get languageDecisionId {
    final $$LanguageDecisionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.languageDecisionId,
          referencedTable: $db.languageDecisions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LanguageDecisionsTableAnnotationComposer(
                $db: $db,
                $table: $db.languageDecisions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$TranscriptLanguageSelectionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TranscriptLanguageSelectionsTable,
          TranscriptLanguageSelection,
          $$TranscriptLanguageSelectionsTableFilterComposer,
          $$TranscriptLanguageSelectionsTableOrderingComposer,
          $$TranscriptLanguageSelectionsTableAnnotationComposer,
          $$TranscriptLanguageSelectionsTableCreateCompanionBuilder,
          $$TranscriptLanguageSelectionsTableUpdateCompanionBuilder,
          (
            TranscriptLanguageSelection,
            $$TranscriptLanguageSelectionsTableReferences,
          ),
          TranscriptLanguageSelection,
          PrefetchHooks Function({
            bool transcriptSegmentId,
            bool languageDecisionId,
          })
        > {
  $$TranscriptLanguageSelectionsTableTableManager(
    _$AppDatabase db,
    $TranscriptLanguageSelectionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TranscriptLanguageSelectionsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$TranscriptLanguageSelectionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$TranscriptLanguageSelectionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> transcriptSegmentId = const Value.absent(),
                Value<String> languageDecisionId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TranscriptLanguageSelectionsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                transcriptSegmentId: transcriptSegmentId,
                languageDecisionId: languageDecisionId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int createdAt,
                required int updatedAt,
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                required String transcriptSegmentId,
                required String languageDecisionId,
                Value<int> rowid = const Value.absent(),
              }) => TranscriptLanguageSelectionsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                transcriptSegmentId: transcriptSegmentId,
                languageDecisionId: languageDecisionId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $TranscriptLanguageSelectionsTable,
                    TranscriptLanguageSelection
                  >(table),
                  $$TranscriptLanguageSelectionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({transcriptSegmentId = false, languageDecisionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (transcriptSegmentId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.transcriptSegmentId,
                                referencedTable:
                                    $$TranscriptLanguageSelectionsTableReferences
                                        ._transcriptSegmentIdTable(db),
                                referencedColumn:
                                    $$TranscriptLanguageSelectionsTableReferences
                                        ._transcriptSegmentIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (languageDecisionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.languageDecisionId,
                                referencedTable:
                                    $$TranscriptLanguageSelectionsTableReferences
                                        ._languageDecisionIdTable(db),
                                referencedColumn:
                                    $$TranscriptLanguageSelectionsTableReferences
                                        ._languageDecisionIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TranscriptLanguageSelectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TranscriptLanguageSelectionsTable,
      TranscriptLanguageSelection,
      $$TranscriptLanguageSelectionsTableFilterComposer,
      $$TranscriptLanguageSelectionsTableOrderingComposer,
      $$TranscriptLanguageSelectionsTableAnnotationComposer,
      $$TranscriptLanguageSelectionsTableCreateCompanionBuilder,
      $$TranscriptLanguageSelectionsTableUpdateCompanionBuilder,
      (
        TranscriptLanguageSelection,
        $$TranscriptLanguageSelectionsTableReferences,
      ),
      TranscriptLanguageSelection,
      PrefetchHooks Function({
        bool transcriptSegmentId,
        bool languageDecisionId,
      })
    >;
typedef $$SpeakerAssignmentsTableCreateCompanionBuilder =
    SpeakerAssignmentsCompanion Function({
      required String id,
      required int createdAt,
      required int updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      required String meetingId,
      required String analysisRunId,
      Value<String?> speakerId,
      Value<String?> speakerAnalysisRunId,
      required int startUs,
      required int endUs,
      Value<double?> confidence,
      required bool isOverlap,
      required bool needsConfirmation,
      Value<int> rowid,
    });
typedef $$SpeakerAssignmentsTableUpdateCompanionBuilder =
    SpeakerAssignmentsCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      Value<String> meetingId,
      Value<String> analysisRunId,
      Value<String?> speakerId,
      Value<String?> speakerAnalysisRunId,
      Value<int> startUs,
      Value<int> endUs,
      Value<double?> confidence,
      Value<bool> isOverlap,
      Value<bool> needsConfirmation,
      Value<int> rowid,
    });

final class $$SpeakerAssignmentsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $SpeakerAssignmentsTable,
          SpeakerAssignment
        > {
  $$SpeakerAssignmentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) =>
      db.meetings.createAlias('speaker_assignments__meeting_id__meetings__id');

  $$MeetingsTableProcessedTableManager get meetingId {
    final $_column = $_itemColumn<String>('meeting_id')!;

    final manager = $$MeetingsTableTableManager(
      $_db,
      $_db.meetings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_meetingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $DiarizationRunsTable _analysisRunIdTable(_$AppDatabase db) =>
      db.diarizationRuns.createAlias(
        'speaker_assignments__analysis_run_id__diarization_runs__id',
      );

  $$DiarizationRunsTableProcessedTableManager get analysisRunId {
    final $_column = $_itemColumn<String>('analysis_run_id')!;

    final manager = $$DiarizationRunsTableTableManager(
      $_db,
      $_db.diarizationRuns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_analysisRunIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SpeakerAssignmentsTableFilterComposer
    extends Composer<_$AppDatabase, $SpeakerAssignmentsTable> {
  $$SpeakerAssignmentsTableFilterComposer({
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

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get speakerId => $composableBuilder(
    column: $table.speakerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get speakerAnalysisRunId => $composableBuilder(
    column: $table.speakerAnalysisRunId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startUs => $composableBuilder(
    column: $table.startUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endUs => $composableBuilder(
    column: $table.endUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isOverlap => $composableBuilder(
    column: $table.isOverlap,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get needsConfirmation => $composableBuilder(
    column: $table.needsConfirmation,
    builder: (column) => ColumnFilters(column),
  );

  $$MeetingsTableFilterComposer get meetingId {
    final $$MeetingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableFilterComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DiarizationRunsTableFilterComposer get analysisRunId {
    final $$DiarizationRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.analysisRunId,
      referencedTable: $db.diarizationRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DiarizationRunsTableFilterComposer(
            $db: $db,
            $table: $db.diarizationRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SpeakerAssignmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $SpeakerAssignmentsTable> {
  $$SpeakerAssignmentsTableOrderingComposer({
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

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get speakerId => $composableBuilder(
    column: $table.speakerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get speakerAnalysisRunId => $composableBuilder(
    column: $table.speakerAnalysisRunId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startUs => $composableBuilder(
    column: $table.startUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endUs => $composableBuilder(
    column: $table.endUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isOverlap => $composableBuilder(
    column: $table.isOverlap,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get needsConfirmation => $composableBuilder(
    column: $table.needsConfirmation,
    builder: (column) => ColumnOrderings(column),
  );

  $$MeetingsTableOrderingComposer get meetingId {
    final $$MeetingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableOrderingComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DiarizationRunsTableOrderingComposer get analysisRunId {
    final $$DiarizationRunsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.analysisRunId,
      referencedTable: $db.diarizationRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DiarizationRunsTableOrderingComposer(
            $db: $db,
            $table: $db.diarizationRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SpeakerAssignmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SpeakerAssignmentsTable> {
  $$SpeakerAssignmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get speakerId =>
      $composableBuilder(column: $table.speakerId, builder: (column) => column);

  GeneratedColumn<String> get speakerAnalysisRunId => $composableBuilder(
    column: $table.speakerAnalysisRunId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startUs =>
      $composableBuilder(column: $table.startUs, builder: (column) => column);

  GeneratedColumn<int> get endUs =>
      $composableBuilder(column: $table.endUs, builder: (column) => column);

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isOverlap =>
      $composableBuilder(column: $table.isOverlap, builder: (column) => column);

  GeneratedColumn<bool> get needsConfirmation => $composableBuilder(
    column: $table.needsConfirmation,
    builder: (column) => column,
  );

  $$MeetingsTableAnnotationComposer get meetingId {
    final $$MeetingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableAnnotationComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DiarizationRunsTableAnnotationComposer get analysisRunId {
    final $$DiarizationRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.analysisRunId,
      referencedTable: $db.diarizationRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DiarizationRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.diarizationRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SpeakerAssignmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SpeakerAssignmentsTable,
          SpeakerAssignment,
          $$SpeakerAssignmentsTableFilterComposer,
          $$SpeakerAssignmentsTableOrderingComposer,
          $$SpeakerAssignmentsTableAnnotationComposer,
          $$SpeakerAssignmentsTableCreateCompanionBuilder,
          $$SpeakerAssignmentsTableUpdateCompanionBuilder,
          (SpeakerAssignment, $$SpeakerAssignmentsTableReferences),
          SpeakerAssignment,
          PrefetchHooks Function({bool meetingId, bool analysisRunId})
        > {
  $$SpeakerAssignmentsTableTableManager(
    _$AppDatabase db,
    $SpeakerAssignmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpeakerAssignmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpeakerAssignmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SpeakerAssignmentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> meetingId = const Value.absent(),
                Value<String> analysisRunId = const Value.absent(),
                Value<String?> speakerId = const Value.absent(),
                Value<String?> speakerAnalysisRunId = const Value.absent(),
                Value<int> startUs = const Value.absent(),
                Value<int> endUs = const Value.absent(),
                Value<double?> confidence = const Value.absent(),
                Value<bool> isOverlap = const Value.absent(),
                Value<bool> needsConfirmation = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SpeakerAssignmentsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                meetingId: meetingId,
                analysisRunId: analysisRunId,
                speakerId: speakerId,
                speakerAnalysisRunId: speakerAnalysisRunId,
                startUs: startUs,
                endUs: endUs,
                confidence: confidence,
                isOverlap: isOverlap,
                needsConfirmation: needsConfirmation,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int createdAt,
                required int updatedAt,
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                required String meetingId,
                required String analysisRunId,
                Value<String?> speakerId = const Value.absent(),
                Value<String?> speakerAnalysisRunId = const Value.absent(),
                required int startUs,
                required int endUs,
                Value<double?> confidence = const Value.absent(),
                required bool isOverlap,
                required bool needsConfirmation,
                Value<int> rowid = const Value.absent(),
              }) => SpeakerAssignmentsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                meetingId: meetingId,
                analysisRunId: analysisRunId,
                speakerId: speakerId,
                speakerAnalysisRunId: speakerAnalysisRunId,
                startUs: startUs,
                endUs: endUs,
                confidence: confidence,
                isOverlap: isOverlap,
                needsConfirmation: needsConfirmation,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SpeakerAssignmentsTable, SpeakerAssignment>(
                    table,
                  ),
                  $$SpeakerAssignmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({meetingId = false, analysisRunId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (meetingId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.meetingId,
                                referencedTable:
                                    $$SpeakerAssignmentsTableReferences
                                        ._meetingIdTable(db),
                                referencedColumn:
                                    $$SpeakerAssignmentsTableReferences
                                        ._meetingIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (analysisRunId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.analysisRunId,
                                referencedTable:
                                    $$SpeakerAssignmentsTableReferences
                                        ._analysisRunIdTable(db),
                                referencedColumn:
                                    $$SpeakerAssignmentsTableReferences
                                        ._analysisRunIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SpeakerAssignmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SpeakerAssignmentsTable,
      SpeakerAssignment,
      $$SpeakerAssignmentsTableFilterComposer,
      $$SpeakerAssignmentsTableOrderingComposer,
      $$SpeakerAssignmentsTableAnnotationComposer,
      $$SpeakerAssignmentsTableCreateCompanionBuilder,
      $$SpeakerAssignmentsTableUpdateCompanionBuilder,
      (SpeakerAssignment, $$SpeakerAssignmentsTableReferences),
      SpeakerAssignment,
      PrefetchHooks Function({bool meetingId, bool analysisRunId})
    >;
typedef $$RevisionsTableCreateCompanionBuilder =
    RevisionsCompanion Function({
      required String id,
      required int createdAt,
      required int updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      required String meetingId,
      Value<String?> transcriptSegmentId,
      Value<String?> speakerAssignmentId,
      Value<String?> speakerId,
      required String revisionKind,
      required String payloadJson,
      Value<int> rowid,
    });
typedef $$RevisionsTableUpdateCompanionBuilder =
    RevisionsCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      Value<String> meetingId,
      Value<String?> transcriptSegmentId,
      Value<String?> speakerAssignmentId,
      Value<String?> speakerId,
      Value<String> revisionKind,
      Value<String> payloadJson,
      Value<int> rowid,
    });

final class $$RevisionsTableReferences
    extends BaseReferences<_$AppDatabase, $RevisionsTable, Revision> {
  $$RevisionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) =>
      db.meetings.createAlias('revisions__meeting_id__meetings__id');

  $$MeetingsTableProcessedTableManager get meetingId {
    final $_column = $_itemColumn<String>('meeting_id')!;

    final manager = $$MeetingsTableTableManager(
      $_db,
      $_db.meetings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_meetingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RevisionsTableFilterComposer
    extends Composer<_$AppDatabase, $RevisionsTable> {
  $$RevisionsTableFilterComposer({
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

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcriptSegmentId => $composableBuilder(
    column: $table.transcriptSegmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get speakerAssignmentId => $composableBuilder(
    column: $table.speakerAssignmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get speakerId => $composableBuilder(
    column: $table.speakerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get revisionKind => $composableBuilder(
    column: $table.revisionKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  $$MeetingsTableFilterComposer get meetingId {
    final $$MeetingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableFilterComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RevisionsTableOrderingComposer
    extends Composer<_$AppDatabase, $RevisionsTable> {
  $$RevisionsTableOrderingComposer({
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

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcriptSegmentId => $composableBuilder(
    column: $table.transcriptSegmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get speakerAssignmentId => $composableBuilder(
    column: $table.speakerAssignmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get speakerId => $composableBuilder(
    column: $table.speakerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get revisionKind => $composableBuilder(
    column: $table.revisionKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$MeetingsTableOrderingComposer get meetingId {
    final $$MeetingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableOrderingComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RevisionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RevisionsTable> {
  $$RevisionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get transcriptSegmentId => $composableBuilder(
    column: $table.transcriptSegmentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get speakerAssignmentId => $composableBuilder(
    column: $table.speakerAssignmentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get speakerId =>
      $composableBuilder(column: $table.speakerId, builder: (column) => column);

  GeneratedColumn<String> get revisionKind => $composableBuilder(
    column: $table.revisionKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  $$MeetingsTableAnnotationComposer get meetingId {
    final $$MeetingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableAnnotationComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RevisionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RevisionsTable,
          Revision,
          $$RevisionsTableFilterComposer,
          $$RevisionsTableOrderingComposer,
          $$RevisionsTableAnnotationComposer,
          $$RevisionsTableCreateCompanionBuilder,
          $$RevisionsTableUpdateCompanionBuilder,
          (Revision, $$RevisionsTableReferences),
          Revision,
          PrefetchHooks Function({bool meetingId})
        > {
  $$RevisionsTableTableManager(_$AppDatabase db, $RevisionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RevisionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RevisionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RevisionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> meetingId = const Value.absent(),
                Value<String?> transcriptSegmentId = const Value.absent(),
                Value<String?> speakerAssignmentId = const Value.absent(),
                Value<String?> speakerId = const Value.absent(),
                Value<String> revisionKind = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RevisionsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                meetingId: meetingId,
                transcriptSegmentId: transcriptSegmentId,
                speakerAssignmentId: speakerAssignmentId,
                speakerId: speakerId,
                revisionKind: revisionKind,
                payloadJson: payloadJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int createdAt,
                required int updatedAt,
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                required String meetingId,
                Value<String?> transcriptSegmentId = const Value.absent(),
                Value<String?> speakerAssignmentId = const Value.absent(),
                Value<String?> speakerId = const Value.absent(),
                required String revisionKind,
                required String payloadJson,
                Value<int> rowid = const Value.absent(),
              }) => RevisionsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                meetingId: meetingId,
                transcriptSegmentId: transcriptSegmentId,
                speakerAssignmentId: speakerAssignmentId,
                speakerId: speakerId,
                revisionKind: revisionKind,
                payloadJson: payloadJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RevisionsTable, Revision>(table),
                  $$RevisionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({meetingId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (meetingId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.meetingId,
                                referencedTable: $$RevisionsTableReferences
                                    ._meetingIdTable(db),
                                referencedColumn: $$RevisionsTableReferences
                                    ._meetingIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RevisionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RevisionsTable,
      Revision,
      $$RevisionsTableFilterComposer,
      $$RevisionsTableOrderingComposer,
      $$RevisionsTableAnnotationComposer,
      $$RevisionsTableCreateCompanionBuilder,
      $$RevisionsTableUpdateCompanionBuilder,
      (Revision, $$RevisionsTableReferences),
      Revision,
      PrefetchHooks Function({bool meetingId})
    >;
typedef $$ProcessingJobsTableCreateCompanionBuilder =
    ProcessingJobsCompanion Function({
      required String id,
      required int createdAt,
      required int updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      required String meetingId,
      required String jobKind,
      required String jobState,
      Value<double?> progress,
      Value<String?> reasonCode,
      Value<String?> failureCode,
      Value<String?> transcriptRunId,
      Value<String?> diarizationRunId,
      Value<String?> modelId,
      Value<String?> checkpoint,
      Value<int> rowid,
    });
typedef $$ProcessingJobsTableUpdateCompanionBuilder =
    ProcessingJobsCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      Value<String> meetingId,
      Value<String> jobKind,
      Value<String> jobState,
      Value<double?> progress,
      Value<String?> reasonCode,
      Value<String?> failureCode,
      Value<String?> transcriptRunId,
      Value<String?> diarizationRunId,
      Value<String?> modelId,
      Value<String?> checkpoint,
      Value<int> rowid,
    });

final class $$ProcessingJobsTableReferences
    extends BaseReferences<_$AppDatabase, $ProcessingJobsTable, ProcessingJob> {
  $$ProcessingJobsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) =>
      db.meetings.createAlias('processing_jobs__meeting_id__meetings__id');

  $$MeetingsTableProcessedTableManager get meetingId {
    final $_column = $_itemColumn<String>('meeting_id')!;

    final manager = $$MeetingsTableTableManager(
      $_db,
      $_db.meetings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_meetingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ModelManifestsTable _modelIdTable(_$AppDatabase db) => db
      .modelManifests
      .createAlias('processing_jobs__model_id__model_manifests__id');

  $$ModelManifestsTableProcessedTableManager? get modelId {
    final $_column = $_itemColumn<String>('model_id');
    if ($_column == null) return null;
    final manager = $$ModelManifestsTableTableManager(
      $_db,
      $_db.modelManifests,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_modelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ProcessingJobsTableFilterComposer
    extends Composer<_$AppDatabase, $ProcessingJobsTable> {
  $$ProcessingJobsTableFilterComposer({
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

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jobKind => $composableBuilder(
    column: $table.jobKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jobState => $composableBuilder(
    column: $table.jobState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reasonCode => $composableBuilder(
    column: $table.reasonCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcriptRunId => $composableBuilder(
    column: $table.transcriptRunId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get diarizationRunId => $composableBuilder(
    column: $table.diarizationRunId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checkpoint => $composableBuilder(
    column: $table.checkpoint,
    builder: (column) => ColumnFilters(column),
  );

  $$MeetingsTableFilterComposer get meetingId {
    final $$MeetingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableFilterComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ModelManifestsTableFilterComposer get modelId {
    final $$ModelManifestsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.modelId,
      referencedTable: $db.modelManifests,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModelManifestsTableFilterComposer(
            $db: $db,
            $table: $db.modelManifests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProcessingJobsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProcessingJobsTable> {
  $$ProcessingJobsTableOrderingComposer({
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

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jobKind => $composableBuilder(
    column: $table.jobKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jobState => $composableBuilder(
    column: $table.jobState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reasonCode => $composableBuilder(
    column: $table.reasonCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcriptRunId => $composableBuilder(
    column: $table.transcriptRunId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get diarizationRunId => $composableBuilder(
    column: $table.diarizationRunId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checkpoint => $composableBuilder(
    column: $table.checkpoint,
    builder: (column) => ColumnOrderings(column),
  );

  $$MeetingsTableOrderingComposer get meetingId {
    final $$MeetingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableOrderingComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ModelManifestsTableOrderingComposer get modelId {
    final $$ModelManifestsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.modelId,
      referencedTable: $db.modelManifests,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModelManifestsTableOrderingComposer(
            $db: $db,
            $table: $db.modelManifests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProcessingJobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProcessingJobsTable> {
  $$ProcessingJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get jobKind =>
      $composableBuilder(column: $table.jobKind, builder: (column) => column);

  GeneratedColumn<String> get jobState =>
      $composableBuilder(column: $table.jobState, builder: (column) => column);

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<String> get reasonCode => $composableBuilder(
    column: $table.reasonCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transcriptRunId => $composableBuilder(
    column: $table.transcriptRunId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get diarizationRunId => $composableBuilder(
    column: $table.diarizationRunId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get checkpoint => $composableBuilder(
    column: $table.checkpoint,
    builder: (column) => column,
  );

  $$MeetingsTableAnnotationComposer get meetingId {
    final $$MeetingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableAnnotationComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ModelManifestsTableAnnotationComposer get modelId {
    final $$ModelManifestsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.modelId,
      referencedTable: $db.modelManifests,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModelManifestsTableAnnotationComposer(
            $db: $db,
            $table: $db.modelManifests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProcessingJobsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProcessingJobsTable,
          ProcessingJob,
          $$ProcessingJobsTableFilterComposer,
          $$ProcessingJobsTableOrderingComposer,
          $$ProcessingJobsTableAnnotationComposer,
          $$ProcessingJobsTableCreateCompanionBuilder,
          $$ProcessingJobsTableUpdateCompanionBuilder,
          (ProcessingJob, $$ProcessingJobsTableReferences),
          ProcessingJob,
          PrefetchHooks Function({bool meetingId, bool modelId})
        > {
  $$ProcessingJobsTableTableManager(
    _$AppDatabase db,
    $ProcessingJobsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProcessingJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProcessingJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProcessingJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> meetingId = const Value.absent(),
                Value<String> jobKind = const Value.absent(),
                Value<String> jobState = const Value.absent(),
                Value<double?> progress = const Value.absent(),
                Value<String?> reasonCode = const Value.absent(),
                Value<String?> failureCode = const Value.absent(),
                Value<String?> transcriptRunId = const Value.absent(),
                Value<String?> diarizationRunId = const Value.absent(),
                Value<String?> modelId = const Value.absent(),
                Value<String?> checkpoint = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProcessingJobsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                meetingId: meetingId,
                jobKind: jobKind,
                jobState: jobState,
                progress: progress,
                reasonCode: reasonCode,
                failureCode: failureCode,
                transcriptRunId: transcriptRunId,
                diarizationRunId: diarizationRunId,
                modelId: modelId,
                checkpoint: checkpoint,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int createdAt,
                required int updatedAt,
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                required String meetingId,
                required String jobKind,
                required String jobState,
                Value<double?> progress = const Value.absent(),
                Value<String?> reasonCode = const Value.absent(),
                Value<String?> failureCode = const Value.absent(),
                Value<String?> transcriptRunId = const Value.absent(),
                Value<String?> diarizationRunId = const Value.absent(),
                Value<String?> modelId = const Value.absent(),
                Value<String?> checkpoint = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProcessingJobsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                meetingId: meetingId,
                jobKind: jobKind,
                jobState: jobState,
                progress: progress,
                reasonCode: reasonCode,
                failureCode: failureCode,
                transcriptRunId: transcriptRunId,
                diarizationRunId: diarizationRunId,
                modelId: modelId,
                checkpoint: checkpoint,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProcessingJobsTable, ProcessingJob>(table),
                  $$ProcessingJobsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({meetingId = false, modelId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (meetingId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.meetingId,
                                referencedTable: $$ProcessingJobsTableReferences
                                    ._meetingIdTable(db),
                                referencedColumn:
                                    $$ProcessingJobsTableReferences
                                        ._meetingIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (modelId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.modelId,
                                referencedTable: $$ProcessingJobsTableReferences
                                    ._modelIdTable(db),
                                referencedColumn:
                                    $$ProcessingJobsTableReferences
                                        ._modelIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ProcessingJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProcessingJobsTable,
      ProcessingJob,
      $$ProcessingJobsTableFilterComposer,
      $$ProcessingJobsTableOrderingComposer,
      $$ProcessingJobsTableAnnotationComposer,
      $$ProcessingJobsTableCreateCompanionBuilder,
      $$ProcessingJobsTableUpdateCompanionBuilder,
      (ProcessingJob, $$ProcessingJobsTableReferences),
      ProcessingJob,
      PrefetchHooks Function({bool meetingId, bool modelId})
    >;
typedef $$ModelCapabilityEntriesTableCreateCompanionBuilder =
    ModelCapabilityEntriesCompanion Function({
      required String id,
      required int createdAt,
      required int updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      required String modelId,
      required String capability,
      Value<int> rowid,
    });
typedef $$ModelCapabilityEntriesTableUpdateCompanionBuilder =
    ModelCapabilityEntriesCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      Value<String> modelId,
      Value<String> capability,
      Value<int> rowid,
    });

final class $$ModelCapabilityEntriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ModelCapabilityEntriesTable,
          ModelCapabilityEntry
        > {
  $$ModelCapabilityEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ModelManifestsTable _modelIdTable(_$AppDatabase db) => db
      .modelManifests
      .createAlias('model_capability_entries__model_id__model_manifests__id');

  $$ModelManifestsTableProcessedTableManager get modelId {
    final $_column = $_itemColumn<String>('model_id')!;

    final manager = $$ModelManifestsTableTableManager(
      $_db,
      $_db.modelManifests,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_modelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ModelCapabilityEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $ModelCapabilityEntriesTable> {
  $$ModelCapabilityEntriesTableFilterComposer({
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

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capability => $composableBuilder(
    column: $table.capability,
    builder: (column) => ColumnFilters(column),
  );

  $$ModelManifestsTableFilterComposer get modelId {
    final $$ModelManifestsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.modelId,
      referencedTable: $db.modelManifests,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModelManifestsTableFilterComposer(
            $db: $db,
            $table: $db.modelManifests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ModelCapabilityEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ModelCapabilityEntriesTable> {
  $$ModelCapabilityEntriesTableOrderingComposer({
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

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capability => $composableBuilder(
    column: $table.capability,
    builder: (column) => ColumnOrderings(column),
  );

  $$ModelManifestsTableOrderingComposer get modelId {
    final $$ModelManifestsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.modelId,
      referencedTable: $db.modelManifests,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModelManifestsTableOrderingComposer(
            $db: $db,
            $table: $db.modelManifests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ModelCapabilityEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ModelCapabilityEntriesTable> {
  $$ModelCapabilityEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get capability => $composableBuilder(
    column: $table.capability,
    builder: (column) => column,
  );

  $$ModelManifestsTableAnnotationComposer get modelId {
    final $$ModelManifestsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.modelId,
      referencedTable: $db.modelManifests,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModelManifestsTableAnnotationComposer(
            $db: $db,
            $table: $db.modelManifests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ModelCapabilityEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ModelCapabilityEntriesTable,
          ModelCapabilityEntry,
          $$ModelCapabilityEntriesTableFilterComposer,
          $$ModelCapabilityEntriesTableOrderingComposer,
          $$ModelCapabilityEntriesTableAnnotationComposer,
          $$ModelCapabilityEntriesTableCreateCompanionBuilder,
          $$ModelCapabilityEntriesTableUpdateCompanionBuilder,
          (ModelCapabilityEntry, $$ModelCapabilityEntriesTableReferences),
          ModelCapabilityEntry,
          PrefetchHooks Function({bool modelId})
        > {
  $$ModelCapabilityEntriesTableTableManager(
    _$AppDatabase db,
    $ModelCapabilityEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ModelCapabilityEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ModelCapabilityEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ModelCapabilityEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> modelId = const Value.absent(),
                Value<String> capability = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ModelCapabilityEntriesCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                modelId: modelId,
                capability: capability,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int createdAt,
                required int updatedAt,
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                required String modelId,
                required String capability,
                Value<int> rowid = const Value.absent(),
              }) => ModelCapabilityEntriesCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                modelId: modelId,
                capability: capability,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $ModelCapabilityEntriesTable,
                    ModelCapabilityEntry
                  >(table),
                  $$ModelCapabilityEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({modelId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (modelId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.modelId,
                                referencedTable:
                                    $$ModelCapabilityEntriesTableReferences
                                        ._modelIdTable(db),
                                referencedColumn:
                                    $$ModelCapabilityEntriesTableReferences
                                        ._modelIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ModelCapabilityEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ModelCapabilityEntriesTable,
      ModelCapabilityEntry,
      $$ModelCapabilityEntriesTableFilterComposer,
      $$ModelCapabilityEntriesTableOrderingComposer,
      $$ModelCapabilityEntriesTableAnnotationComposer,
      $$ModelCapabilityEntriesTableCreateCompanionBuilder,
      $$ModelCapabilityEntriesTableUpdateCompanionBuilder,
      (ModelCapabilityEntry, $$ModelCapabilityEntriesTableReferences),
      ModelCapabilityEntry,
      PrefetchHooks Function({bool modelId})
    >;
typedef $$ModelModeEntriesTableCreateCompanionBuilder =
    ModelModeEntriesCompanion Function({
      required String id,
      required int createdAt,
      required int updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      required String modelId,
      required String mode,
      Value<int> rowid,
    });
typedef $$ModelModeEntriesTableUpdateCompanionBuilder =
    ModelModeEntriesCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      Value<String> modelId,
      Value<String> mode,
      Value<int> rowid,
    });

final class $$ModelModeEntriesTableReferences
    extends
        BaseReferences<_$AppDatabase, $ModelModeEntriesTable, ModelModeEntry> {
  $$ModelModeEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ModelManifestsTable _modelIdTable(_$AppDatabase db) => db
      .modelManifests
      .createAlias('model_mode_entries__model_id__model_manifests__id');

  $$ModelManifestsTableProcessedTableManager get modelId {
    final $_column = $_itemColumn<String>('model_id')!;

    final manager = $$ModelManifestsTableTableManager(
      $_db,
      $_db.modelManifests,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_modelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ModelModeEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $ModelModeEntriesTable> {
  $$ModelModeEntriesTableFilterComposer({
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

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  $$ModelManifestsTableFilterComposer get modelId {
    final $$ModelManifestsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.modelId,
      referencedTable: $db.modelManifests,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModelManifestsTableFilterComposer(
            $db: $db,
            $table: $db.modelManifests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ModelModeEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ModelModeEntriesTable> {
  $$ModelModeEntriesTableOrderingComposer({
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

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  $$ModelManifestsTableOrderingComposer get modelId {
    final $$ModelManifestsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.modelId,
      referencedTable: $db.modelManifests,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModelManifestsTableOrderingComposer(
            $db: $db,
            $table: $db.modelManifests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ModelModeEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ModelModeEntriesTable> {
  $$ModelModeEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  $$ModelManifestsTableAnnotationComposer get modelId {
    final $$ModelManifestsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.modelId,
      referencedTable: $db.modelManifests,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModelManifestsTableAnnotationComposer(
            $db: $db,
            $table: $db.modelManifests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ModelModeEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ModelModeEntriesTable,
          ModelModeEntry,
          $$ModelModeEntriesTableFilterComposer,
          $$ModelModeEntriesTableOrderingComposer,
          $$ModelModeEntriesTableAnnotationComposer,
          $$ModelModeEntriesTableCreateCompanionBuilder,
          $$ModelModeEntriesTableUpdateCompanionBuilder,
          (ModelModeEntry, $$ModelModeEntriesTableReferences),
          ModelModeEntry,
          PrefetchHooks Function({bool modelId})
        > {
  $$ModelModeEntriesTableTableManager(
    _$AppDatabase db,
    $ModelModeEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ModelModeEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ModelModeEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ModelModeEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> modelId = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ModelModeEntriesCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                modelId: modelId,
                mode: mode,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int createdAt,
                required int updatedAt,
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                required String modelId,
                required String mode,
                Value<int> rowid = const Value.absent(),
              }) => ModelModeEntriesCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                modelId: modelId,
                mode: mode,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ModelModeEntriesTable, ModelModeEntry>(table),
                  $$ModelModeEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({modelId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (modelId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.modelId,
                                referencedTable:
                                    $$ModelModeEntriesTableReferences
                                        ._modelIdTable(db),
                                referencedColumn:
                                    $$ModelModeEntriesTableReferences
                                        ._modelIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ModelModeEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ModelModeEntriesTable,
      ModelModeEntry,
      $$ModelModeEntriesTableFilterComposer,
      $$ModelModeEntriesTableOrderingComposer,
      $$ModelModeEntriesTableAnnotationComposer,
      $$ModelModeEntriesTableCreateCompanionBuilder,
      $$ModelModeEntriesTableUpdateCompanionBuilder,
      (ModelModeEntry, $$ModelModeEntriesTableReferences),
      ModelModeEntry,
      PrefetchHooks Function({bool modelId})
    >;
typedef $$ExportRecordsTableCreateCompanionBuilder =
    ExportRecordsCompanion Function({
      required String id,
      required int createdAt,
      required int updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      required String meetingId,
      required String format,
      required String exportState,
      Value<String?> relativePath,
      Value<int?> bytes,
      Value<String?> failureCode,
      Value<int> rowid,
    });
typedef $$ExportRecordsTableUpdateCompanionBuilder =
    ExportRecordsCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      Value<String> meetingId,
      Value<String> format,
      Value<String> exportState,
      Value<String?> relativePath,
      Value<int?> bytes,
      Value<String?> failureCode,
      Value<int> rowid,
    });

final class $$ExportRecordsTableReferences
    extends BaseReferences<_$AppDatabase, $ExportRecordsTable, ExportRecord> {
  $$ExportRecordsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) =>
      db.meetings.createAlias('export_records__meeting_id__meetings__id');

  $$MeetingsTableProcessedTableManager get meetingId {
    final $_column = $_itemColumn<String>('meeting_id')!;

    final manager = $$MeetingsTableTableManager(
      $_db,
      $_db.meetings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_meetingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ExportRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $ExportRecordsTable> {
  $$ExportRecordsTableFilterComposer({
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

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exportState => $composableBuilder(
    column: $table.exportState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => ColumnFilters(column),
  );

  $$MeetingsTableFilterComposer get meetingId {
    final $$MeetingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableFilterComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExportRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $ExportRecordsTable> {
  $$ExportRecordsTableOrderingComposer({
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

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exportState => $composableBuilder(
    column: $table.exportState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => ColumnOrderings(column),
  );

  $$MeetingsTableOrderingComposer get meetingId {
    final $$MeetingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableOrderingComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExportRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExportRecordsTable> {
  $$ExportRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get exportState => $composableBuilder(
    column: $table.exportState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => column,
  );

  $$MeetingsTableAnnotationComposer get meetingId {
    final $$MeetingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableAnnotationComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExportRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExportRecordsTable,
          ExportRecord,
          $$ExportRecordsTableFilterComposer,
          $$ExportRecordsTableOrderingComposer,
          $$ExportRecordsTableAnnotationComposer,
          $$ExportRecordsTableCreateCompanionBuilder,
          $$ExportRecordsTableUpdateCompanionBuilder,
          (ExportRecord, $$ExportRecordsTableReferences),
          ExportRecord,
          PrefetchHooks Function({bool meetingId})
        > {
  $$ExportRecordsTableTableManager(_$AppDatabase db, $ExportRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExportRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExportRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExportRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> meetingId = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<String> exportState = const Value.absent(),
                Value<String?> relativePath = const Value.absent(),
                Value<int?> bytes = const Value.absent(),
                Value<String?> failureCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExportRecordsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                meetingId: meetingId,
                format: format,
                exportState: exportState,
                relativePath: relativePath,
                bytes: bytes,
                failureCode: failureCode,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int createdAt,
                required int updatedAt,
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                required String meetingId,
                required String format,
                required String exportState,
                Value<String?> relativePath = const Value.absent(),
                Value<int?> bytes = const Value.absent(),
                Value<String?> failureCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExportRecordsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                meetingId: meetingId,
                format: format,
                exportState: exportState,
                relativePath: relativePath,
                bytes: bytes,
                failureCode: failureCode,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ExportRecordsTable, ExportRecord>(table),
                  $$ExportRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({meetingId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (meetingId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.meetingId,
                                referencedTable: $$ExportRecordsTableReferences
                                    ._meetingIdTable(db),
                                referencedColumn: $$ExportRecordsTableReferences
                                    ._meetingIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ExportRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExportRecordsTable,
      ExportRecord,
      $$ExportRecordsTableFilterComposer,
      $$ExportRecordsTableOrderingComposer,
      $$ExportRecordsTableAnnotationComposer,
      $$ExportRecordsTableCreateCompanionBuilder,
      $$ExportRecordsTableUpdateCompanionBuilder,
      (ExportRecord, $$ExportRecordsTableReferences),
      ExportRecord,
      PrefetchHooks Function({bool meetingId})
    >;
typedef $$BackupRecordsTableCreateCompanionBuilder =
    BackupRecordsCompanion Function({
      required String id,
      required int createdAt,
      required int updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      required String backupState,
      Value<String?> relativePath,
      Value<String?> sha256,
      Value<int?> bytes,
      Value<String?> failureCode,
      Value<int> rowid,
    });
typedef $$BackupRecordsTableUpdateCompanionBuilder =
    BackupRecordsCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowRevision,
      Value<bool> isDeleted,
      Value<int?> deletedAt,
      Value<String> backupState,
      Value<String?> relativePath,
      Value<String?> sha256,
      Value<int?> bytes,
      Value<String?> failureCode,
      Value<int> rowid,
    });

class $$BackupRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $BackupRecordsTable> {
  $$BackupRecordsTableFilterComposer({
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

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backupState => $composableBuilder(
    column: $table.backupState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BackupRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $BackupRecordsTable> {
  $$BackupRecordsTableOrderingComposer({
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

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backupState => $composableBuilder(
    column: $table.backupState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BackupRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BackupRecordsTable> {
  $$BackupRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get backupState => $composableBuilder(
    column: $table.backupState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => column,
  );
}

class $$BackupRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BackupRecordsTable,
          BackupRecord,
          $$BackupRecordsTableFilterComposer,
          $$BackupRecordsTableOrderingComposer,
          $$BackupRecordsTableAnnotationComposer,
          $$BackupRecordsTableCreateCompanionBuilder,
          $$BackupRecordsTableUpdateCompanionBuilder,
          (
            BackupRecord,
            BaseReferences<_$AppDatabase, $BackupRecordsTable, BackupRecord>,
          ),
          BackupRecord,
          PrefetchHooks Function()
        > {
  $$BackupRecordsTableTableManager(_$AppDatabase db, $BackupRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BackupRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BackupRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BackupRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> backupState = const Value.absent(),
                Value<String?> relativePath = const Value.absent(),
                Value<String?> sha256 = const Value.absent(),
                Value<int?> bytes = const Value.absent(),
                Value<String?> failureCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BackupRecordsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                backupState: backupState,
                relativePath: relativePath,
                sha256: sha256,
                bytes: bytes,
                failureCode: failureCode,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int createdAt,
                required int updatedAt,
                Value<int> rowRevision = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                required String backupState,
                Value<String?> relativePath = const Value.absent(),
                Value<String?> sha256 = const Value.absent(),
                Value<int?> bytes = const Value.absent(),
                Value<String?> failureCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BackupRecordsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowRevision: rowRevision,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                backupState: backupState,
                relativePath: relativePath,
                sha256: sha256,
                bytes: bytes,
                failureCode: failureCode,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BackupRecordsTable, BackupRecord>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $BackupRecordsTable,
                    BackupRecord
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BackupRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BackupRecordsTable,
      BackupRecord,
      $$BackupRecordsTableFilterComposer,
      $$BackupRecordsTableOrderingComposer,
      $$BackupRecordsTableAnnotationComposer,
      $$BackupRecordsTableCreateCompanionBuilder,
      $$BackupRecordsTableUpdateCompanionBuilder,
      (
        BackupRecord,
        BaseReferences<_$AppDatabase, $BackupRecordsTable, BackupRecord>,
      ),
      BackupRecord,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MeetingsTableTableManager get meetings =>
      $$MeetingsTableTableManager(_db, _db.meetings);
  $$AudioSegmentsTableTableManager get audioSegments =>
      $$AudioSegmentsTableTableManager(_db, _db.audioSegments);
  $$SessionEventsTableTableManager get sessionEvents =>
      $$SessionEventsTableTableManager(_db, _db.sessionEvents);
  $$BookmarksTableTableManager get bookmarks =>
      $$BookmarksTableTableManager(_db, _db.bookmarks);
  $$ModelManifestsTableTableManager get modelManifests =>
      $$ModelManifestsTableTableManager(_db, _db.modelManifests);
  $$TranscriptRunsTableTableManager get transcriptRuns =>
      $$TranscriptRunsTableTableManager(_db, _db.transcriptRuns);
  $$MeetingTranscriptSelectionsTableTableManager
  get meetingTranscriptSelections =>
      $$MeetingTranscriptSelectionsTableTableManager(
        _db,
        _db.meetingTranscriptSelections,
      );
  $$DiarizationRunsTableTableManager get diarizationRuns =>
      $$DiarizationRunsTableTableManager(_db, _db.diarizationRuns);
  $$SpeakersTableTableManager get speakers =>
      $$SpeakersTableTableManager(_db, _db.speakers);
  $$TranscriptSegmentsTableTableManager get transcriptSegments =>
      $$TranscriptSegmentsTableTableManager(_db, _db.transcriptSegments);
  $$LanguageDecisionsTableTableManager get languageDecisions =>
      $$LanguageDecisionsTableTableManager(_db, _db.languageDecisions);
  $$TranscriptLanguageSelectionsTableTableManager
  get transcriptLanguageSelections =>
      $$TranscriptLanguageSelectionsTableTableManager(
        _db,
        _db.transcriptLanguageSelections,
      );
  $$SpeakerAssignmentsTableTableManager get speakerAssignments =>
      $$SpeakerAssignmentsTableTableManager(_db, _db.speakerAssignments);
  $$RevisionsTableTableManager get revisions =>
      $$RevisionsTableTableManager(_db, _db.revisions);
  $$ProcessingJobsTableTableManager get processingJobs =>
      $$ProcessingJobsTableTableManager(_db, _db.processingJobs);
  $$ModelCapabilityEntriesTableTableManager get modelCapabilityEntries =>
      $$ModelCapabilityEntriesTableTableManager(
        _db,
        _db.modelCapabilityEntries,
      );
  $$ModelModeEntriesTableTableManager get modelModeEntries =>
      $$ModelModeEntriesTableTableManager(_db, _db.modelModeEntries);
  $$ExportRecordsTableTableManager get exportRecords =>
      $$ExportRecordsTableTableManager(_db, _db.exportRecords);
  $$BackupRecordsTableTableManager get backupRecords =>
      $$BackupRecordsTableTableManager(_db, _db.backupRecords);
}
