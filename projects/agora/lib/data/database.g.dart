// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SessionsTable extends Sessions with TableInfo<$SessionsTable, Session> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Untitled session'),
  );
  static const VerificationMeta _promptMeta = const VerificationMeta('prompt');
  @override
  late final GeneratedColumn<String> prompt = GeneratedColumn<String>(
    'prompt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _leaderIdMeta = const VerificationMeta(
    'leaderId',
  );
  @override
  late final GeneratedColumn<String> leaderId = GeneratedColumn<String>(
    'leader_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roundMeta = const VerificationMeta('round');
  @override
  late final GeneratedColumn<int> round = GeneratedColumn<int>(
    'round',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _maxRoundsMeta = const VerificationMeta(
    'maxRounds',
  );
  @override
  late final GeneratedColumn<int> maxRounds = GeneratedColumn<int>(
    'max_rounds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(12),
  );
  static const VerificationMeta _budgetSecondsMeta = const VerificationMeta(
    'budgetSeconds',
  );
  @override
  late final GeneratedColumn<int> budgetSeconds = GeneratedColumn<int>(
    'budget_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1800),
  );
  static const VerificationMeta _elapsedSecondsMeta = const VerificationMeta(
    'elapsedSeconds',
  );
  @override
  late final GeneratedColumn<int> elapsedSeconds = GeneratedColumn<int>(
    'elapsed_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('idle'),
  );
  static const VerificationMeta _contextStrategyMeta = const VerificationMeta(
    'contextStrategy',
  );
  @override
  late final GeneratedColumn<String> contextStrategy = GeneratedColumn<String>(
    'context_strategy',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('delta'),
  );
  static const VerificationMeta _templateIdMeta = const VerificationMeta(
    'templateId',
  );
  @override
  late final GeneratedColumn<String> templateId = GeneratedColumn<String>(
    'template_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    prompt,
    leaderId,
    round,
    maxRounds,
    budgetSeconds,
    elapsedSeconds,
    status,
    contextStrategy,
    templateId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Session> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('prompt')) {
      context.handle(
        _promptMeta,
        prompt.isAcceptableOrUnknown(data['prompt']!, _promptMeta),
      );
    } else if (isInserting) {
      context.missing(_promptMeta);
    }
    if (data.containsKey('leader_id')) {
      context.handle(
        _leaderIdMeta,
        leaderId.isAcceptableOrUnknown(data['leader_id']!, _leaderIdMeta),
      );
    }
    if (data.containsKey('round')) {
      context.handle(
        _roundMeta,
        round.isAcceptableOrUnknown(data['round']!, _roundMeta),
      );
    }
    if (data.containsKey('max_rounds')) {
      context.handle(
        _maxRoundsMeta,
        maxRounds.isAcceptableOrUnknown(data['max_rounds']!, _maxRoundsMeta),
      );
    }
    if (data.containsKey('budget_seconds')) {
      context.handle(
        _budgetSecondsMeta,
        budgetSeconds.isAcceptableOrUnknown(
          data['budget_seconds']!,
          _budgetSecondsMeta,
        ),
      );
    }
    if (data.containsKey('elapsed_seconds')) {
      context.handle(
        _elapsedSecondsMeta,
        elapsedSeconds.isAcceptableOrUnknown(
          data['elapsed_seconds']!,
          _elapsedSecondsMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('context_strategy')) {
      context.handle(
        _contextStrategyMeta,
        contextStrategy.isAcceptableOrUnknown(
          data['context_strategy']!,
          _contextStrategyMeta,
        ),
      );
    }
    if (data.containsKey('template_id')) {
      context.handle(
        _templateIdMeta,
        templateId.isAcceptableOrUnknown(data['template_id']!, _templateIdMeta),
      );
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Session map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Session(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      prompt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prompt'],
      )!,
      leaderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}leader_id'],
      ),
      round: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}round'],
      )!,
      maxRounds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_rounds'],
      )!,
      budgetSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}budget_seconds'],
      )!,
      elapsedSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}elapsed_seconds'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      contextStrategy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}context_strategy'],
      )!,
      templateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class Session extends DataClass implements Insertable<Session> {
  final String id;
  final String title;

  /// The user's opening problem statement.
  final String prompt;
  final String? leaderId;

  /// Current round number (1-based while running).
  final int round;

  /// Hard stops. These are what make "until solved" safe.
  final int maxRounds;
  final int budgetSeconds;
  final int elapsedSeconds;

  /// 'idle' | 'running' | 'paused' | 'solved' | 'blocked' | 'failed'
  final String status;

  /// 'delta' | 'window' | 'full' | 'scratchpad' (see ContextStrategist).
  final String contextStrategy;

  /// Template this session was created from, if any.
  final String? templateId;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Session({
    required this.id,
    required this.title,
    required this.prompt,
    this.leaderId,
    required this.round,
    required this.maxRounds,
    required this.budgetSeconds,
    required this.elapsedSeconds,
    required this.status,
    required this.contextStrategy,
    this.templateId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['prompt'] = Variable<String>(prompt);
    if (!nullToAbsent || leaderId != null) {
      map['leader_id'] = Variable<String>(leaderId);
    }
    map['round'] = Variable<int>(round);
    map['max_rounds'] = Variable<int>(maxRounds);
    map['budget_seconds'] = Variable<int>(budgetSeconds);
    map['elapsed_seconds'] = Variable<int>(elapsedSeconds);
    map['status'] = Variable<String>(status);
    map['context_strategy'] = Variable<String>(contextStrategy);
    if (!nullToAbsent || templateId != null) {
      map['template_id'] = Variable<String>(templateId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      title: Value(title),
      prompt: Value(prompt),
      leaderId: leaderId == null && nullToAbsent
          ? const Value.absent()
          : Value(leaderId),
      round: Value(round),
      maxRounds: Value(maxRounds),
      budgetSeconds: Value(budgetSeconds),
      elapsedSeconds: Value(elapsedSeconds),
      status: Value(status),
      contextStrategy: Value(contextStrategy),
      templateId: templateId == null && nullToAbsent
          ? const Value.absent()
          : Value(templateId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Session.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Session(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      prompt: serializer.fromJson<String>(json['prompt']),
      leaderId: serializer.fromJson<String?>(json['leaderId']),
      round: serializer.fromJson<int>(json['round']),
      maxRounds: serializer.fromJson<int>(json['maxRounds']),
      budgetSeconds: serializer.fromJson<int>(json['budgetSeconds']),
      elapsedSeconds: serializer.fromJson<int>(json['elapsedSeconds']),
      status: serializer.fromJson<String>(json['status']),
      contextStrategy: serializer.fromJson<String>(json['contextStrategy']),
      templateId: serializer.fromJson<String?>(json['templateId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'prompt': serializer.toJson<String>(prompt),
      'leaderId': serializer.toJson<String?>(leaderId),
      'round': serializer.toJson<int>(round),
      'maxRounds': serializer.toJson<int>(maxRounds),
      'budgetSeconds': serializer.toJson<int>(budgetSeconds),
      'elapsedSeconds': serializer.toJson<int>(elapsedSeconds),
      'status': serializer.toJson<String>(status),
      'contextStrategy': serializer.toJson<String>(contextStrategy),
      'templateId': serializer.toJson<String?>(templateId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Session copyWith({
    String? id,
    String? title,
    String? prompt,
    Value<String?> leaderId = const Value.absent(),
    int? round,
    int? maxRounds,
    int? budgetSeconds,
    int? elapsedSeconds,
    String? status,
    String? contextStrategy,
    Value<String?> templateId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Session(
    id: id ?? this.id,
    title: title ?? this.title,
    prompt: prompt ?? this.prompt,
    leaderId: leaderId.present ? leaderId.value : this.leaderId,
    round: round ?? this.round,
    maxRounds: maxRounds ?? this.maxRounds,
    budgetSeconds: budgetSeconds ?? this.budgetSeconds,
    elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    status: status ?? this.status,
    contextStrategy: contextStrategy ?? this.contextStrategy,
    templateId: templateId.present ? templateId.value : this.templateId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Session copyWithCompanion(SessionsCompanion data) {
    return Session(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      prompt: data.prompt.present ? data.prompt.value : this.prompt,
      leaderId: data.leaderId.present ? data.leaderId.value : this.leaderId,
      round: data.round.present ? data.round.value : this.round,
      maxRounds: data.maxRounds.present ? data.maxRounds.value : this.maxRounds,
      budgetSeconds: data.budgetSeconds.present
          ? data.budgetSeconds.value
          : this.budgetSeconds,
      elapsedSeconds: data.elapsedSeconds.present
          ? data.elapsedSeconds.value
          : this.elapsedSeconds,
      status: data.status.present ? data.status.value : this.status,
      contextStrategy: data.contextStrategy.present
          ? data.contextStrategy.value
          : this.contextStrategy,
      templateId: data.templateId.present
          ? data.templateId.value
          : this.templateId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Session(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('prompt: $prompt, ')
          ..write('leaderId: $leaderId, ')
          ..write('round: $round, ')
          ..write('maxRounds: $maxRounds, ')
          ..write('budgetSeconds: $budgetSeconds, ')
          ..write('elapsedSeconds: $elapsedSeconds, ')
          ..write('status: $status, ')
          ..write('contextStrategy: $contextStrategy, ')
          ..write('templateId: $templateId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    prompt,
    leaderId,
    round,
    maxRounds,
    budgetSeconds,
    elapsedSeconds,
    status,
    contextStrategy,
    templateId,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.id == this.id &&
          other.title == this.title &&
          other.prompt == this.prompt &&
          other.leaderId == this.leaderId &&
          other.round == this.round &&
          other.maxRounds == this.maxRounds &&
          other.budgetSeconds == this.budgetSeconds &&
          other.elapsedSeconds == this.elapsedSeconds &&
          other.status == this.status &&
          other.contextStrategy == this.contextStrategy &&
          other.templateId == this.templateId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SessionsCompanion extends UpdateCompanion<Session> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> prompt;
  final Value<String?> leaderId;
  final Value<int> round;
  final Value<int> maxRounds;
  final Value<int> budgetSeconds;
  final Value<int> elapsedSeconds;
  final Value<String> status;
  final Value<String> contextStrategy;
  final Value<String?> templateId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.prompt = const Value.absent(),
    this.leaderId = const Value.absent(),
    this.round = const Value.absent(),
    this.maxRounds = const Value.absent(),
    this.budgetSeconds = const Value.absent(),
    this.elapsedSeconds = const Value.absent(),
    this.status = const Value.absent(),
    this.contextStrategy = const Value.absent(),
    this.templateId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsCompanion.insert({
    required String id,
    this.title = const Value.absent(),
    required String prompt,
    this.leaderId = const Value.absent(),
    this.round = const Value.absent(),
    this.maxRounds = const Value.absent(),
    this.budgetSeconds = const Value.absent(),
    this.elapsedSeconds = const Value.absent(),
    this.status = const Value.absent(),
    this.contextStrategy = const Value.absent(),
    this.templateId = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       prompt = Value(prompt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Session> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? prompt,
    Expression<String>? leaderId,
    Expression<int>? round,
    Expression<int>? maxRounds,
    Expression<int>? budgetSeconds,
    Expression<int>? elapsedSeconds,
    Expression<String>? status,
    Expression<String>? contextStrategy,
    Expression<String>? templateId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (prompt != null) 'prompt': prompt,
      if (leaderId != null) 'leader_id': leaderId,
      if (round != null) 'round': round,
      if (maxRounds != null) 'max_rounds': maxRounds,
      if (budgetSeconds != null) 'budget_seconds': budgetSeconds,
      if (elapsedSeconds != null) 'elapsed_seconds': elapsedSeconds,
      if (status != null) 'status': status,
      if (contextStrategy != null) 'context_strategy': contextStrategy,
      if (templateId != null) 'template_id': templateId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? prompt,
    Value<String?>? leaderId,
    Value<int>? round,
    Value<int>? maxRounds,
    Value<int>? budgetSeconds,
    Value<int>? elapsedSeconds,
    Value<String>? status,
    Value<String>? contextStrategy,
    Value<String?>? templateId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      prompt: prompt ?? this.prompt,
      leaderId: leaderId ?? this.leaderId,
      round: round ?? this.round,
      maxRounds: maxRounds ?? this.maxRounds,
      budgetSeconds: budgetSeconds ?? this.budgetSeconds,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      status: status ?? this.status,
      contextStrategy: contextStrategy ?? this.contextStrategy,
      templateId: templateId ?? this.templateId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (prompt.present) {
      map['prompt'] = Variable<String>(prompt.value);
    }
    if (leaderId.present) {
      map['leader_id'] = Variable<String>(leaderId.value);
    }
    if (round.present) {
      map['round'] = Variable<int>(round.value);
    }
    if (maxRounds.present) {
      map['max_rounds'] = Variable<int>(maxRounds.value);
    }
    if (budgetSeconds.present) {
      map['budget_seconds'] = Variable<int>(budgetSeconds.value);
    }
    if (elapsedSeconds.present) {
      map['elapsed_seconds'] = Variable<int>(elapsedSeconds.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (contextStrategy.present) {
      map['context_strategy'] = Variable<String>(contextStrategy.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<String>(templateId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('prompt: $prompt, ')
          ..write('leaderId: $leaderId, ')
          ..write('round: $round, ')
          ..write('maxRounds: $maxRounds, ')
          ..write('budgetSeconds: $budgetSeconds, ')
          ..write('elapsedSeconds: $elapsedSeconds, ')
          ..write('status: $status, ')
          ..write('contextStrategy: $contextStrategy, ')
          ..write('templateId: $templateId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AgentsTable extends Agents with TableInfo<$AgentsTable, Agent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AgentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xFF78909C),
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _adapterVersionMeta = const VerificationMeta(
    'adapterVersion',
  );
  @override
  late final GeneratedColumn<String> adapterVersion = GeneratedColumn<String>(
    'adapter_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    displayName,
    colorValue,
    url,
    adapterVersion,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'agents';
  @override
  VerificationContext validateIntegrity(
    Insertable<Agent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('adapter_version')) {
      context.handle(
        _adapterVersionMeta,
        adapterVersion.isAcceptableOrUnknown(
          data['adapter_version']!,
          _adapterVersionMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Agent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Agent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      adapterVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}adapter_version'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AgentsTable createAlias(String alias) {
    return $AgentsTable(attachedDatabase, alias);
  }
}

class Agent extends DataClass implements Insertable<Agent> {
  final String id;

  /// 'chatgpt' | 'gemini' | 'deepseek' | 'claude' | ...
  final String kind;
  final String displayName;

  /// Packed ARGB, e.g. 0xFF10A37F — drives the colour coding in the council.
  final int colorValue;

  /// Entry point Agora navigates to.
  final String url;

  /// Selector/version of the adapter this agent is pinned to.
  final String? adapterVersion;
  final DateTime createdAt;
  const Agent({
    required this.id,
    required this.kind,
    required this.displayName,
    required this.colorValue,
    required this.url,
    this.adapterVersion,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['display_name'] = Variable<String>(displayName);
    map['color_value'] = Variable<int>(colorValue);
    map['url'] = Variable<String>(url);
    if (!nullToAbsent || adapterVersion != null) {
      map['adapter_version'] = Variable<String>(adapterVersion);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AgentsCompanion toCompanion(bool nullToAbsent) {
    return AgentsCompanion(
      id: Value(id),
      kind: Value(kind),
      displayName: Value(displayName),
      colorValue: Value(colorValue),
      url: Value(url),
      adapterVersion: adapterVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(adapterVersion),
      createdAt: Value(createdAt),
    );
  }

  factory Agent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Agent(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      displayName: serializer.fromJson<String>(json['displayName']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      url: serializer.fromJson<String>(json['url']),
      adapterVersion: serializer.fromJson<String?>(json['adapterVersion']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'displayName': serializer.toJson<String>(displayName),
      'colorValue': serializer.toJson<int>(colorValue),
      'url': serializer.toJson<String>(url),
      'adapterVersion': serializer.toJson<String?>(adapterVersion),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Agent copyWith({
    String? id,
    String? kind,
    String? displayName,
    int? colorValue,
    String? url,
    Value<String?> adapterVersion = const Value.absent(),
    DateTime? createdAt,
  }) => Agent(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    displayName: displayName ?? this.displayName,
    colorValue: colorValue ?? this.colorValue,
    url: url ?? this.url,
    adapterVersion: adapterVersion.present
        ? adapterVersion.value
        : this.adapterVersion,
    createdAt: createdAt ?? this.createdAt,
  );
  Agent copyWithCompanion(AgentsCompanion data) {
    return Agent(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      url: data.url.present ? data.url.value : this.url,
      adapterVersion: data.adapterVersion.present
          ? data.adapterVersion.value
          : this.adapterVersion,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Agent(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('displayName: $displayName, ')
          ..write('colorValue: $colorValue, ')
          ..write('url: $url, ')
          ..write('adapterVersion: $adapterVersion, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    displayName,
    colorValue,
    url,
    adapterVersion,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Agent &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.displayName == this.displayName &&
          other.colorValue == this.colorValue &&
          other.url == this.url &&
          other.adapterVersion == this.adapterVersion &&
          other.createdAt == this.createdAt);
}

class AgentsCompanion extends UpdateCompanion<Agent> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> displayName;
  final Value<int> colorValue;
  final Value<String> url;
  final Value<String?> adapterVersion;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AgentsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.displayName = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.url = const Value.absent(),
    this.adapterVersion = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AgentsCompanion.insert({
    required String id,
    required String kind,
    required String displayName,
    this.colorValue = const Value.absent(),
    required String url,
    this.adapterVersion = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       displayName = Value(displayName),
       url = Value(url),
       createdAt = Value(createdAt);
  static Insertable<Agent> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? displayName,
    Expression<int>? colorValue,
    Expression<String>? url,
    Expression<String>? adapterVersion,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (displayName != null) 'display_name': displayName,
      if (colorValue != null) 'color_value': colorValue,
      if (url != null) 'url': url,
      if (adapterVersion != null) 'adapter_version': adapterVersion,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AgentsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? displayName,
    Value<int>? colorValue,
    Value<String>? url,
    Value<String?>? adapterVersion,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return AgentsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      displayName: displayName ?? this.displayName,
      colorValue: colorValue ?? this.colorValue,
      url: url ?? this.url,
      adapterVersion: adapterVersion ?? this.adapterVersion,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (adapterVersion.present) {
      map['adapter_version'] = Variable<String>(adapterVersion.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AgentsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('displayName: $displayName, ')
          ..write('colorValue: $colorValue, ')
          ..write('url: $url, ')
          ..write('adapterVersion: $adapterVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionAgentsTable extends SessionAgents
    with TableInfo<$SessionAgentsTable, SessionAgent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionAgentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _agentIdMeta = const VerificationMeta(
    'agentId',
  );
  @override
  late final GeneratedColumn<String> agentId = GeneratedColumn<String>(
    'agent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleCardMeta = const VerificationMeta(
    'roleCard',
  );
  @override
  late final GeneratedColumn<String> roleCard = GeneratedColumn<String>(
    'role_card',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isLeaderMeta = const VerificationMeta(
    'isLeader',
  );
  @override
  late final GeneratedColumn<bool> isLeader = GeneratedColumn<bool>(
    'is_leader',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_leader" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('enabled'),
  );
  static const VerificationMeta _modelLabelMeta = const VerificationMeta(
    'modelLabel',
  );
  @override
  late final GeneratedColumn<String> modelLabel = GeneratedColumn<String>(
    'model_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  List<GeneratedColumn> get $columns => [
    sessionId,
    agentId,
    roleCard,
    sortOrder,
    isLeader,
    status,
    modelLabel,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_agents';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionAgent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('agent_id')) {
      context.handle(
        _agentIdMeta,
        agentId.isAcceptableOrUnknown(data['agent_id']!, _agentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_agentIdMeta);
    }
    if (data.containsKey('role_card')) {
      context.handle(
        _roleCardMeta,
        roleCard.isAcceptableOrUnknown(data['role_card']!, _roleCardMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('is_leader')) {
      context.handle(
        _isLeaderMeta,
        isLeader.isAcceptableOrUnknown(data['is_leader']!, _isLeaderMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('model_label')) {
      context.handle(
        _modelLabelMeta,
        modelLabel.isAcceptableOrUnknown(data['model_label']!, _modelLabelMeta),
      );
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
  Set<GeneratedColumn> get $primaryKey => {sessionId, agentId};
  @override
  SessionAgent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionAgent(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      agentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_id'],
      )!,
      roleCard: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role_card'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      isLeader: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_leader'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      modelLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_label'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $SessionAgentsTable createAlias(String alias) {
    return $SessionAgentsTable(attachedDatabase, alias);
  }
}

class SessionAgent extends DataClass implements Insertable<SessionAgent> {
  final String sessionId;
  final String agentId;

  /// Role Card text (e.g. "You are a battery electrochemist. Be sceptical of
  /// optimistic cycle-life claims."). This is what stops five generalists
  /// from politely agreeing with each other.
  final String? roleCard;
  final int sortOrder;
  final bool isLeader;

  /// 'enabled' | 'disabled' | 'login_required' | 'error'
  final String status;

  /// Model label chosen on the site's own model picker, if any.
  final String? modelLabel;
  final DateTime addedAt;
  const SessionAgent({
    required this.sessionId,
    required this.agentId,
    this.roleCard,
    required this.sortOrder,
    required this.isLeader,
    required this.status,
    this.modelLabel,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['agent_id'] = Variable<String>(agentId);
    if (!nullToAbsent || roleCard != null) {
      map['role_card'] = Variable<String>(roleCard);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_leader'] = Variable<bool>(isLeader);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || modelLabel != null) {
      map['model_label'] = Variable<String>(modelLabel);
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  SessionAgentsCompanion toCompanion(bool nullToAbsent) {
    return SessionAgentsCompanion(
      sessionId: Value(sessionId),
      agentId: Value(agentId),
      roleCard: roleCard == null && nullToAbsent
          ? const Value.absent()
          : Value(roleCard),
      sortOrder: Value(sortOrder),
      isLeader: Value(isLeader),
      status: Value(status),
      modelLabel: modelLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(modelLabel),
      addedAt: Value(addedAt),
    );
  }

  factory SessionAgent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionAgent(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      agentId: serializer.fromJson<String>(json['agentId']),
      roleCard: serializer.fromJson<String?>(json['roleCard']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isLeader: serializer.fromJson<bool>(json['isLeader']),
      status: serializer.fromJson<String>(json['status']),
      modelLabel: serializer.fromJson<String?>(json['modelLabel']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'agentId': serializer.toJson<String>(agentId),
      'roleCard': serializer.toJson<String?>(roleCard),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isLeader': serializer.toJson<bool>(isLeader),
      'status': serializer.toJson<String>(status),
      'modelLabel': serializer.toJson<String?>(modelLabel),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  SessionAgent copyWith({
    String? sessionId,
    String? agentId,
    Value<String?> roleCard = const Value.absent(),
    int? sortOrder,
    bool? isLeader,
    String? status,
    Value<String?> modelLabel = const Value.absent(),
    DateTime? addedAt,
  }) => SessionAgent(
    sessionId: sessionId ?? this.sessionId,
    agentId: agentId ?? this.agentId,
    roleCard: roleCard.present ? roleCard.value : this.roleCard,
    sortOrder: sortOrder ?? this.sortOrder,
    isLeader: isLeader ?? this.isLeader,
    status: status ?? this.status,
    modelLabel: modelLabel.present ? modelLabel.value : this.modelLabel,
    addedAt: addedAt ?? this.addedAt,
  );
  SessionAgent copyWithCompanion(SessionAgentsCompanion data) {
    return SessionAgent(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      agentId: data.agentId.present ? data.agentId.value : this.agentId,
      roleCard: data.roleCard.present ? data.roleCard.value : this.roleCard,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isLeader: data.isLeader.present ? data.isLeader.value : this.isLeader,
      status: data.status.present ? data.status.value : this.status,
      modelLabel: data.modelLabel.present
          ? data.modelLabel.value
          : this.modelLabel,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionAgent(')
          ..write('sessionId: $sessionId, ')
          ..write('agentId: $agentId, ')
          ..write('roleCard: $roleCard, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isLeader: $isLeader, ')
          ..write('status: $status, ')
          ..write('modelLabel: $modelLabel, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sessionId,
    agentId,
    roleCard,
    sortOrder,
    isLeader,
    status,
    modelLabel,
    addedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionAgent &&
          other.sessionId == this.sessionId &&
          other.agentId == this.agentId &&
          other.roleCard == this.roleCard &&
          other.sortOrder == this.sortOrder &&
          other.isLeader == this.isLeader &&
          other.status == this.status &&
          other.modelLabel == this.modelLabel &&
          other.addedAt == this.addedAt);
}

class SessionAgentsCompanion extends UpdateCompanion<SessionAgent> {
  final Value<String> sessionId;
  final Value<String> agentId;
  final Value<String?> roleCard;
  final Value<int> sortOrder;
  final Value<bool> isLeader;
  final Value<String> status;
  final Value<String?> modelLabel;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const SessionAgentsCompanion({
    this.sessionId = const Value.absent(),
    this.agentId = const Value.absent(),
    this.roleCard = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isLeader = const Value.absent(),
    this.status = const Value.absent(),
    this.modelLabel = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionAgentsCompanion.insert({
    required String sessionId,
    required String agentId,
    this.roleCard = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isLeader = const Value.absent(),
    this.status = const Value.absent(),
    this.modelLabel = const Value.absent(),
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  }) : sessionId = Value(sessionId),
       agentId = Value(agentId),
       addedAt = Value(addedAt);
  static Insertable<SessionAgent> custom({
    Expression<String>? sessionId,
    Expression<String>? agentId,
    Expression<String>? roleCard,
    Expression<int>? sortOrder,
    Expression<bool>? isLeader,
    Expression<String>? status,
    Expression<String>? modelLabel,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (agentId != null) 'agent_id': agentId,
      if (roleCard != null) 'role_card': roleCard,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isLeader != null) 'is_leader': isLeader,
      if (status != null) 'status': status,
      if (modelLabel != null) 'model_label': modelLabel,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionAgentsCompanion copyWith({
    Value<String>? sessionId,
    Value<String>? agentId,
    Value<String?>? roleCard,
    Value<int>? sortOrder,
    Value<bool>? isLeader,
    Value<String>? status,
    Value<String?>? modelLabel,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return SessionAgentsCompanion(
      sessionId: sessionId ?? this.sessionId,
      agentId: agentId ?? this.agentId,
      roleCard: roleCard ?? this.roleCard,
      sortOrder: sortOrder ?? this.sortOrder,
      isLeader: isLeader ?? this.isLeader,
      status: status ?? this.status,
      modelLabel: modelLabel ?? this.modelLabel,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (agentId.present) {
      map['agent_id'] = Variable<String>(agentId.value);
    }
    if (roleCard.present) {
      map['role_card'] = Variable<String>(roleCard.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isLeader.present) {
      map['is_leader'] = Variable<bool>(isLeader.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (modelLabel.present) {
      map['model_label'] = Variable<String>(modelLabel.value);
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
    return (StringBuffer('SessionAgentsCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('agentId: $agentId, ')
          ..write('roleCard: $roleCard, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isLeader: $isLeader, ')
          ..write('status: $status, ')
          ..write('modelLabel: $modelLabel, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages with TableInfo<$MessagesTable, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roundMeta = const VerificationMeta('round');
  @override
  late final GeneratedColumn<int> round = GeneratedColumn<int>(
    'round',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _agentIdMeta = const VerificationMeta(
    'agentId',
  );
  @override
  late final GeneratedColumn<String> agentId = GeneratedColumn<String>(
    'agent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawTextMeta = const VerificationMeta(
    'rawText',
  );
  @override
  late final GeneratedColumn<String> rawText = GeneratedColumn<String>(
    'raw_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawHtmlMeta = const VerificationMeta(
    'rawHtml',
  );
  @override
  late final GeneratedColumn<String> rawHtml = GeneratedColumn<String>(
    'raw_html',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _screenshotPathMeta = const VerificationMeta(
    'screenshotPath',
  );
  @override
  late final GeneratedColumn<String> screenshotPath = GeneratedColumn<String>(
    'screenshot_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latencyMsMeta = const VerificationMeta(
    'latencyMs',
  );
  @override
  late final GeneratedColumn<int> latencyMs = GeneratedColumn<int>(
    'latency_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _packetRefMeta = const VerificationMeta(
    'packetRef',
  );
  @override
  late final GeneratedColumn<String> packetRef = GeneratedColumn<String>(
    'packet_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metaMeta = const VerificationMeta('meta');
  @override
  late final GeneratedColumn<String> meta = GeneratedColumn<String>(
    'meta',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    round,
    agentId,
    role,
    direction,
    rawText,
    rawHtml,
    screenshotPath,
    contentHash,
    latencyMs,
    packetRef,
    meta,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<Message> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('round')) {
      context.handle(
        _roundMeta,
        round.isAcceptableOrUnknown(data['round']!, _roundMeta),
      );
    }
    if (data.containsKey('agent_id')) {
      context.handle(
        _agentIdMeta,
        agentId.isAcceptableOrUnknown(data['agent_id']!, _agentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_agentIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('raw_text')) {
      context.handle(
        _rawTextMeta,
        rawText.isAcceptableOrUnknown(data['raw_text']!, _rawTextMeta),
      );
    } else if (isInserting) {
      context.missing(_rawTextMeta);
    }
    if (data.containsKey('raw_html')) {
      context.handle(
        _rawHtmlMeta,
        rawHtml.isAcceptableOrUnknown(data['raw_html']!, _rawHtmlMeta),
      );
    }
    if (data.containsKey('screenshot_path')) {
      context.handle(
        _screenshotPathMeta,
        screenshotPath.isAcceptableOrUnknown(
          data['screenshot_path']!,
          _screenshotPathMeta,
        ),
      );
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    if (data.containsKey('latency_ms')) {
      context.handle(
        _latencyMsMeta,
        latencyMs.isAcceptableOrUnknown(data['latency_ms']!, _latencyMsMeta),
      );
    }
    if (data.containsKey('packet_ref')) {
      context.handle(
        _packetRefMeta,
        packetRef.isAcceptableOrUnknown(data['packet_ref']!, _packetRefMeta),
      );
    }
    if (data.containsKey('meta')) {
      context.handle(
        _metaMeta,
        meta.isAcceptableOrUnknown(data['meta']!, _metaMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      round: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}round'],
      )!,
      agentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction'],
      )!,
      rawText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_text'],
      )!,
      rawHtml: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_html'],
      ),
      screenshotPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}screenshot_path'],
      ),
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
      latencyMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}latency_ms'],
      ),
      packetRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}packet_ref'],
      ),
      meta: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meta'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class Message extends DataClass implements Insertable<Message> {
  final String id;
  final String sessionId;
  final int round;

  /// Agent id, or 'user' / 'system' / 'orchestrator'.
  final String agentId;

  /// 'user' | 'agent' | 'system' | 'orchestrator'
  final String role;

  /// 'in' | 'out' — whose words are these.
  final String direction;

  /// The exact characters the agent produced. Source of truth.
  final String rawText;

  /// The exact DOM the agent rendered, for the Raw view.
  final String? rawHtml;

  /// Path into AgoraPaths.vaultDir; null when screenshots are disabled.
  final String? screenshotPath;

  /// sha256 of [rawText]. Recomputable, so alteration is detectable.
  final String contentHash;
  final int? latencyMs;

  /// The context packet this reply answers, for audit.
  final String? packetRef;

  /// Orchestrator annotations (protocol warnings, dissent, scores) as JSON.
  final String? meta;
  final DateTime createdAt;
  const Message({
    required this.id,
    required this.sessionId,
    required this.round,
    required this.agentId,
    required this.role,
    required this.direction,
    required this.rawText,
    this.rawHtml,
    this.screenshotPath,
    required this.contentHash,
    this.latencyMs,
    this.packetRef,
    this.meta,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['round'] = Variable<int>(round);
    map['agent_id'] = Variable<String>(agentId);
    map['role'] = Variable<String>(role);
    map['direction'] = Variable<String>(direction);
    map['raw_text'] = Variable<String>(rawText);
    if (!nullToAbsent || rawHtml != null) {
      map['raw_html'] = Variable<String>(rawHtml);
    }
    if (!nullToAbsent || screenshotPath != null) {
      map['screenshot_path'] = Variable<String>(screenshotPath);
    }
    map['content_hash'] = Variable<String>(contentHash);
    if (!nullToAbsent || latencyMs != null) {
      map['latency_ms'] = Variable<int>(latencyMs);
    }
    if (!nullToAbsent || packetRef != null) {
      map['packet_ref'] = Variable<String>(packetRef);
    }
    if (!nullToAbsent || meta != null) {
      map['meta'] = Variable<String>(meta);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      round: Value(round),
      agentId: Value(agentId),
      role: Value(role),
      direction: Value(direction),
      rawText: Value(rawText),
      rawHtml: rawHtml == null && nullToAbsent
          ? const Value.absent()
          : Value(rawHtml),
      screenshotPath: screenshotPath == null && nullToAbsent
          ? const Value.absent()
          : Value(screenshotPath),
      contentHash: Value(contentHash),
      latencyMs: latencyMs == null && nullToAbsent
          ? const Value.absent()
          : Value(latencyMs),
      packetRef: packetRef == null && nullToAbsent
          ? const Value.absent()
          : Value(packetRef),
      meta: meta == null && nullToAbsent ? const Value.absent() : Value(meta),
      createdAt: Value(createdAt),
    );
  }

  factory Message.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      round: serializer.fromJson<int>(json['round']),
      agentId: serializer.fromJson<String>(json['agentId']),
      role: serializer.fromJson<String>(json['role']),
      direction: serializer.fromJson<String>(json['direction']),
      rawText: serializer.fromJson<String>(json['rawText']),
      rawHtml: serializer.fromJson<String?>(json['rawHtml']),
      screenshotPath: serializer.fromJson<String?>(json['screenshotPath']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
      latencyMs: serializer.fromJson<int?>(json['latencyMs']),
      packetRef: serializer.fromJson<String?>(json['packetRef']),
      meta: serializer.fromJson<String?>(json['meta']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'round': serializer.toJson<int>(round),
      'agentId': serializer.toJson<String>(agentId),
      'role': serializer.toJson<String>(role),
      'direction': serializer.toJson<String>(direction),
      'rawText': serializer.toJson<String>(rawText),
      'rawHtml': serializer.toJson<String?>(rawHtml),
      'screenshotPath': serializer.toJson<String?>(screenshotPath),
      'contentHash': serializer.toJson<String>(contentHash),
      'latencyMs': serializer.toJson<int?>(latencyMs),
      'packetRef': serializer.toJson<String?>(packetRef),
      'meta': serializer.toJson<String?>(meta),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Message copyWith({
    String? id,
    String? sessionId,
    int? round,
    String? agentId,
    String? role,
    String? direction,
    String? rawText,
    Value<String?> rawHtml = const Value.absent(),
    Value<String?> screenshotPath = const Value.absent(),
    String? contentHash,
    Value<int?> latencyMs = const Value.absent(),
    Value<String?> packetRef = const Value.absent(),
    Value<String?> meta = const Value.absent(),
    DateTime? createdAt,
  }) => Message(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    round: round ?? this.round,
    agentId: agentId ?? this.agentId,
    role: role ?? this.role,
    direction: direction ?? this.direction,
    rawText: rawText ?? this.rawText,
    rawHtml: rawHtml.present ? rawHtml.value : this.rawHtml,
    screenshotPath: screenshotPath.present
        ? screenshotPath.value
        : this.screenshotPath,
    contentHash: contentHash ?? this.contentHash,
    latencyMs: latencyMs.present ? latencyMs.value : this.latencyMs,
    packetRef: packetRef.present ? packetRef.value : this.packetRef,
    meta: meta.present ? meta.value : this.meta,
    createdAt: createdAt ?? this.createdAt,
  );
  Message copyWithCompanion(MessagesCompanion data) {
    return Message(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      round: data.round.present ? data.round.value : this.round,
      agentId: data.agentId.present ? data.agentId.value : this.agentId,
      role: data.role.present ? data.role.value : this.role,
      direction: data.direction.present ? data.direction.value : this.direction,
      rawText: data.rawText.present ? data.rawText.value : this.rawText,
      rawHtml: data.rawHtml.present ? data.rawHtml.value : this.rawHtml,
      screenshotPath: data.screenshotPath.present
          ? data.screenshotPath.value
          : this.screenshotPath,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      latencyMs: data.latencyMs.present ? data.latencyMs.value : this.latencyMs,
      packetRef: data.packetRef.present ? data.packetRef.value : this.packetRef,
      meta: data.meta.present ? data.meta.value : this.meta,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('round: $round, ')
          ..write('agentId: $agentId, ')
          ..write('role: $role, ')
          ..write('direction: $direction, ')
          ..write('rawText: $rawText, ')
          ..write('rawHtml: $rawHtml, ')
          ..write('screenshotPath: $screenshotPath, ')
          ..write('contentHash: $contentHash, ')
          ..write('latencyMs: $latencyMs, ')
          ..write('packetRef: $packetRef, ')
          ..write('meta: $meta, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    round,
    agentId,
    role,
    direction,
    rawText,
    rawHtml,
    screenshotPath,
    contentHash,
    latencyMs,
    packetRef,
    meta,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.round == this.round &&
          other.agentId == this.agentId &&
          other.role == this.role &&
          other.direction == this.direction &&
          other.rawText == this.rawText &&
          other.rawHtml == this.rawHtml &&
          other.screenshotPath == this.screenshotPath &&
          other.contentHash == this.contentHash &&
          other.latencyMs == this.latencyMs &&
          other.packetRef == this.packetRef &&
          other.meta == this.meta &&
          other.createdAt == this.createdAt);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<int> round;
  final Value<String> agentId;
  final Value<String> role;
  final Value<String> direction;
  final Value<String> rawText;
  final Value<String?> rawHtml;
  final Value<String?> screenshotPath;
  final Value<String> contentHash;
  final Value<int?> latencyMs;
  final Value<String?> packetRef;
  final Value<String?> meta;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.round = const Value.absent(),
    this.agentId = const Value.absent(),
    this.role = const Value.absent(),
    this.direction = const Value.absent(),
    this.rawText = const Value.absent(),
    this.rawHtml = const Value.absent(),
    this.screenshotPath = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.latencyMs = const Value.absent(),
    this.packetRef = const Value.absent(),
    this.meta = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String id,
    required String sessionId,
    this.round = const Value.absent(),
    required String agentId,
    required String role,
    required String direction,
    required String rawText,
    this.rawHtml = const Value.absent(),
    this.screenshotPath = const Value.absent(),
    required String contentHash,
    this.latencyMs = const Value.absent(),
    this.packetRef = const Value.absent(),
    this.meta = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       agentId = Value(agentId),
       role = Value(role),
       direction = Value(direction),
       rawText = Value(rawText),
       contentHash = Value(contentHash),
       createdAt = Value(createdAt);
  static Insertable<Message> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<int>? round,
    Expression<String>? agentId,
    Expression<String>? role,
    Expression<String>? direction,
    Expression<String>? rawText,
    Expression<String>? rawHtml,
    Expression<String>? screenshotPath,
    Expression<String>? contentHash,
    Expression<int>? latencyMs,
    Expression<String>? packetRef,
    Expression<String>? meta,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (round != null) 'round': round,
      if (agentId != null) 'agent_id': agentId,
      if (role != null) 'role': role,
      if (direction != null) 'direction': direction,
      if (rawText != null) 'raw_text': rawText,
      if (rawHtml != null) 'raw_html': rawHtml,
      if (screenshotPath != null) 'screenshot_path': screenshotPath,
      if (contentHash != null) 'content_hash': contentHash,
      if (latencyMs != null) 'latency_ms': latencyMs,
      if (packetRef != null) 'packet_ref': packetRef,
      if (meta != null) 'meta': meta,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<int>? round,
    Value<String>? agentId,
    Value<String>? role,
    Value<String>? direction,
    Value<String>? rawText,
    Value<String?>? rawHtml,
    Value<String?>? screenshotPath,
    Value<String>? contentHash,
    Value<int?>? latencyMs,
    Value<String?>? packetRef,
    Value<String?>? meta,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      round: round ?? this.round,
      agentId: agentId ?? this.agentId,
      role: role ?? this.role,
      direction: direction ?? this.direction,
      rawText: rawText ?? this.rawText,
      rawHtml: rawHtml ?? this.rawHtml,
      screenshotPath: screenshotPath ?? this.screenshotPath,
      contentHash: contentHash ?? this.contentHash,
      latencyMs: latencyMs ?? this.latencyMs,
      packetRef: packetRef ?? this.packetRef,
      meta: meta ?? this.meta,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (round.present) {
      map['round'] = Variable<int>(round.value);
    }
    if (agentId.present) {
      map['agent_id'] = Variable<String>(agentId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (rawText.present) {
      map['raw_text'] = Variable<String>(rawText.value);
    }
    if (rawHtml.present) {
      map['raw_html'] = Variable<String>(rawHtml.value);
    }
    if (screenshotPath.present) {
      map['screenshot_path'] = Variable<String>(screenshotPath.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (latencyMs.present) {
      map['latency_ms'] = Variable<int>(latencyMs.value);
    }
    if (packetRef.present) {
      map['packet_ref'] = Variable<String>(packetRef.value);
    }
    if (meta.present) {
      map['meta'] = Variable<String>(meta.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('round: $round, ')
          ..write('agentId: $agentId, ')
          ..write('role: $role, ')
          ..write('direction: $direction, ')
          ..write('rawText: $rawText, ')
          ..write('rawHtml: $rawHtml, ')
          ..write('screenshotPath: $screenshotPath, ')
          ..write('contentHash: $contentHash, ')
          ..write('latencyMs: $latencyMs, ')
          ..write('packetRef: $packetRef, ')
          ..write('meta: $meta, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PacketsTable extends Packets with TableInfo<$PacketsTable, Packet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PacketsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roundMeta = const VerificationMeta('round');
  @override
  late final GeneratedColumn<int> round = GeneratedColumn<int>(
    'round',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _targetAgentIdMeta = const VerificationMeta(
    'targetAgentId',
  );
  @override
  late final GeneratedColumn<String> targetAgentId = GeneratedColumn<String>(
    'target_agent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _strategyMeta = const VerificationMeta(
    'strategy',
  );
  @override
  late final GeneratedColumn<String> strategy = GeneratedColumn<String>(
    'strategy',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _byteSizeMeta = const VerificationMeta(
    'byteSize',
  );
  @override
  late final GeneratedColumn<int> byteSize = GeneratedColumn<int>(
    'byte_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _bodyHashMeta = const VerificationMeta(
    'bodyHash',
  );
  @override
  late final GeneratedColumn<String> bodyHash = GeneratedColumn<String>(
    'body_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    round,
    targetAgentId,
    strategy,
    byteSize,
    bodyHash,
    body,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'packets';
  @override
  VerificationContext validateIntegrity(
    Insertable<Packet> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('round')) {
      context.handle(
        _roundMeta,
        round.isAcceptableOrUnknown(data['round']!, _roundMeta),
      );
    }
    if (data.containsKey('target_agent_id')) {
      context.handle(
        _targetAgentIdMeta,
        targetAgentId.isAcceptableOrUnknown(
          data['target_agent_id']!,
          _targetAgentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetAgentIdMeta);
    }
    if (data.containsKey('strategy')) {
      context.handle(
        _strategyMeta,
        strategy.isAcceptableOrUnknown(data['strategy']!, _strategyMeta),
      );
    } else if (isInserting) {
      context.missing(_strategyMeta);
    }
    if (data.containsKey('byte_size')) {
      context.handle(
        _byteSizeMeta,
        byteSize.isAcceptableOrUnknown(data['byte_size']!, _byteSizeMeta),
      );
    }
    if (data.containsKey('body_hash')) {
      context.handle(
        _bodyHashMeta,
        bodyHash.isAcceptableOrUnknown(data['body_hash']!, _bodyHashMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyHashMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Packet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Packet(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      round: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}round'],
      )!,
      targetAgentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_agent_id'],
      )!,
      strategy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}strategy'],
      )!,
      byteSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_size'],
      )!,
      bodyHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_hash'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PacketsTable createAlias(String alias) {
    return $PacketsTable(attachedDatabase, alias);
  }
}

class Packet extends DataClass implements Insertable<Packet> {
  final String id;
  final String sessionId;
  final int round;
  final String targetAgentId;

  /// 'delta' | 'window' | 'full' | 'scratchpad'
  final String strategy;
  final int byteSize;
  final String bodyHash;
  final String body;
  final DateTime createdAt;
  const Packet({
    required this.id,
    required this.sessionId,
    required this.round,
    required this.targetAgentId,
    required this.strategy,
    required this.byteSize,
    required this.bodyHash,
    required this.body,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['round'] = Variable<int>(round);
    map['target_agent_id'] = Variable<String>(targetAgentId);
    map['strategy'] = Variable<String>(strategy);
    map['byte_size'] = Variable<int>(byteSize);
    map['body_hash'] = Variable<String>(bodyHash);
    map['body'] = Variable<String>(body);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PacketsCompanion toCompanion(bool nullToAbsent) {
    return PacketsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      round: Value(round),
      targetAgentId: Value(targetAgentId),
      strategy: Value(strategy),
      byteSize: Value(byteSize),
      bodyHash: Value(bodyHash),
      body: Value(body),
      createdAt: Value(createdAt),
    );
  }

  factory Packet.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Packet(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      round: serializer.fromJson<int>(json['round']),
      targetAgentId: serializer.fromJson<String>(json['targetAgentId']),
      strategy: serializer.fromJson<String>(json['strategy']),
      byteSize: serializer.fromJson<int>(json['byteSize']),
      bodyHash: serializer.fromJson<String>(json['bodyHash']),
      body: serializer.fromJson<String>(json['body']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'round': serializer.toJson<int>(round),
      'targetAgentId': serializer.toJson<String>(targetAgentId),
      'strategy': serializer.toJson<String>(strategy),
      'byteSize': serializer.toJson<int>(byteSize),
      'bodyHash': serializer.toJson<String>(bodyHash),
      'body': serializer.toJson<String>(body),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Packet copyWith({
    String? id,
    String? sessionId,
    int? round,
    String? targetAgentId,
    String? strategy,
    int? byteSize,
    String? bodyHash,
    String? body,
    DateTime? createdAt,
  }) => Packet(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    round: round ?? this.round,
    targetAgentId: targetAgentId ?? this.targetAgentId,
    strategy: strategy ?? this.strategy,
    byteSize: byteSize ?? this.byteSize,
    bodyHash: bodyHash ?? this.bodyHash,
    body: body ?? this.body,
    createdAt: createdAt ?? this.createdAt,
  );
  Packet copyWithCompanion(PacketsCompanion data) {
    return Packet(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      round: data.round.present ? data.round.value : this.round,
      targetAgentId: data.targetAgentId.present
          ? data.targetAgentId.value
          : this.targetAgentId,
      strategy: data.strategy.present ? data.strategy.value : this.strategy,
      byteSize: data.byteSize.present ? data.byteSize.value : this.byteSize,
      bodyHash: data.bodyHash.present ? data.bodyHash.value : this.bodyHash,
      body: data.body.present ? data.body.value : this.body,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Packet(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('round: $round, ')
          ..write('targetAgentId: $targetAgentId, ')
          ..write('strategy: $strategy, ')
          ..write('byteSize: $byteSize, ')
          ..write('bodyHash: $bodyHash, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    round,
    targetAgentId,
    strategy,
    byteSize,
    bodyHash,
    body,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Packet &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.round == this.round &&
          other.targetAgentId == this.targetAgentId &&
          other.strategy == this.strategy &&
          other.byteSize == this.byteSize &&
          other.bodyHash == this.bodyHash &&
          other.body == this.body &&
          other.createdAt == this.createdAt);
}

class PacketsCompanion extends UpdateCompanion<Packet> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<int> round;
  final Value<String> targetAgentId;
  final Value<String> strategy;
  final Value<int> byteSize;
  final Value<String> bodyHash;
  final Value<String> body;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PacketsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.round = const Value.absent(),
    this.targetAgentId = const Value.absent(),
    this.strategy = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.bodyHash = const Value.absent(),
    this.body = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PacketsCompanion.insert({
    required String id,
    required String sessionId,
    this.round = const Value.absent(),
    required String targetAgentId,
    required String strategy,
    this.byteSize = const Value.absent(),
    required String bodyHash,
    required String body,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       targetAgentId = Value(targetAgentId),
       strategy = Value(strategy),
       bodyHash = Value(bodyHash),
       body = Value(body),
       createdAt = Value(createdAt);
  static Insertable<Packet> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<int>? round,
    Expression<String>? targetAgentId,
    Expression<String>? strategy,
    Expression<int>? byteSize,
    Expression<String>? bodyHash,
    Expression<String>? body,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (round != null) 'round': round,
      if (targetAgentId != null) 'target_agent_id': targetAgentId,
      if (strategy != null) 'strategy': strategy,
      if (byteSize != null) 'byte_size': byteSize,
      if (bodyHash != null) 'body_hash': bodyHash,
      if (body != null) 'body': body,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PacketsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<int>? round,
    Value<String>? targetAgentId,
    Value<String>? strategy,
    Value<int>? byteSize,
    Value<String>? bodyHash,
    Value<String>? body,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PacketsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      round: round ?? this.round,
      targetAgentId: targetAgentId ?? this.targetAgentId,
      strategy: strategy ?? this.strategy,
      byteSize: byteSize ?? this.byteSize,
      bodyHash: bodyHash ?? this.bodyHash,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (round.present) {
      map['round'] = Variable<int>(round.value);
    }
    if (targetAgentId.present) {
      map['target_agent_id'] = Variable<String>(targetAgentId.value);
    }
    if (strategy.present) {
      map['strategy'] = Variable<String>(strategy.value);
    }
    if (byteSize.present) {
      map['byte_size'] = Variable<int>(byteSize.value);
    }
    if (bodyHash.present) {
      map['body_hash'] = Variable<String>(bodyHash.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PacketsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('round: $round, ')
          ..write('targetAgentId: $targetAgentId, ')
          ..write('strategy: $strategy, ')
          ..write('byteSize: $byteSize, ')
          ..write('bodyHash: $bodyHash, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AgentFactsTable extends AgentFacts
    with TableInfo<$AgentFactsTable, AgentFact> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AgentFactsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _factMeta = const VerificationMeta('fact');
  @override
  late final GeneratedColumn<String> fact = GeneratedColumn<String>(
    'fact',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMessageIdMeta = const VerificationMeta(
    'sourceMessageId',
  );
  @override
  late final GeneratedColumn<String> sourceMessageId = GeneratedColumn<String>(
    'source_message_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('archivist'),
  );
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
    'pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    fact,
    sourceMessageId,
    origin,
    pinned,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'agent_facts';
  @override
  VerificationContext validateIntegrity(
    Insertable<AgentFact> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('fact')) {
      context.handle(
        _factMeta,
        fact.isAcceptableOrUnknown(data['fact']!, _factMeta),
      );
    } else if (isInserting) {
      context.missing(_factMeta);
    }
    if (data.containsKey('source_message_id')) {
      context.handle(
        _sourceMessageIdMeta,
        sourceMessageId.isAcceptableOrUnknown(
          data['source_message_id']!,
          _sourceMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    }
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AgentFact map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AgentFact(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      fact: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fact'],
      )!,
      sourceMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_message_id'],
      ),
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      )!,
      pinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pinned'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AgentFactsTable createAlias(String alias) {
    return $AgentFactsTable(attachedDatabase, alias);
  }
}

class AgentFact extends DataClass implements Insertable<AgentFact> {
  final String id;
  final String sessionId;

  /// The fact, one per row, phrased so it can be re-injected verbatim.
  final String fact;

  /// Which message produced it.
  final String? sourceMessageId;

  /// 'archivist' | 'pinned' | 'agent'
  final String origin;

  /// Pinned facts are never compacted away.
  final bool pinned;
  final DateTime createdAt;
  const AgentFact({
    required this.id,
    required this.sessionId,
    required this.fact,
    this.sourceMessageId,
    required this.origin,
    required this.pinned,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['fact'] = Variable<String>(fact);
    if (!nullToAbsent || sourceMessageId != null) {
      map['source_message_id'] = Variable<String>(sourceMessageId);
    }
    map['origin'] = Variable<String>(origin);
    map['pinned'] = Variable<bool>(pinned);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AgentFactsCompanion toCompanion(bool nullToAbsent) {
    return AgentFactsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      fact: Value(fact),
      sourceMessageId: sourceMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceMessageId),
      origin: Value(origin),
      pinned: Value(pinned),
      createdAt: Value(createdAt),
    );
  }

  factory AgentFact.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AgentFact(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      fact: serializer.fromJson<String>(json['fact']),
      sourceMessageId: serializer.fromJson<String?>(json['sourceMessageId']),
      origin: serializer.fromJson<String>(json['origin']),
      pinned: serializer.fromJson<bool>(json['pinned']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'fact': serializer.toJson<String>(fact),
      'sourceMessageId': serializer.toJson<String?>(sourceMessageId),
      'origin': serializer.toJson<String>(origin),
      'pinned': serializer.toJson<bool>(pinned),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AgentFact copyWith({
    String? id,
    String? sessionId,
    String? fact,
    Value<String?> sourceMessageId = const Value.absent(),
    String? origin,
    bool? pinned,
    DateTime? createdAt,
  }) => AgentFact(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    fact: fact ?? this.fact,
    sourceMessageId: sourceMessageId.present
        ? sourceMessageId.value
        : this.sourceMessageId,
    origin: origin ?? this.origin,
    pinned: pinned ?? this.pinned,
    createdAt: createdAt ?? this.createdAt,
  );
  AgentFact copyWithCompanion(AgentFactsCompanion data) {
    return AgentFact(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      fact: data.fact.present ? data.fact.value : this.fact,
      sourceMessageId: data.sourceMessageId.present
          ? data.sourceMessageId.value
          : this.sourceMessageId,
      origin: data.origin.present ? data.origin.value : this.origin,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AgentFact(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('fact: $fact, ')
          ..write('sourceMessageId: $sourceMessageId, ')
          ..write('origin: $origin, ')
          ..write('pinned: $pinned, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    fact,
    sourceMessageId,
    origin,
    pinned,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentFact &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.fact == this.fact &&
          other.sourceMessageId == this.sourceMessageId &&
          other.origin == this.origin &&
          other.pinned == this.pinned &&
          other.createdAt == this.createdAt);
}

class AgentFactsCompanion extends UpdateCompanion<AgentFact> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> fact;
  final Value<String?> sourceMessageId;
  final Value<String> origin;
  final Value<bool> pinned;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AgentFactsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.fact = const Value.absent(),
    this.sourceMessageId = const Value.absent(),
    this.origin = const Value.absent(),
    this.pinned = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AgentFactsCompanion.insert({
    required String id,
    required String sessionId,
    required String fact,
    this.sourceMessageId = const Value.absent(),
    this.origin = const Value.absent(),
    this.pinned = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       fact = Value(fact),
       createdAt = Value(createdAt);
  static Insertable<AgentFact> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? fact,
    Expression<String>? sourceMessageId,
    Expression<String>? origin,
    Expression<bool>? pinned,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (fact != null) 'fact': fact,
      if (sourceMessageId != null) 'source_message_id': sourceMessageId,
      if (origin != null) 'origin': origin,
      if (pinned != null) 'pinned': pinned,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AgentFactsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? fact,
    Value<String?>? sourceMessageId,
    Value<String>? origin,
    Value<bool>? pinned,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return AgentFactsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      fact: fact ?? this.fact,
      sourceMessageId: sourceMessageId ?? this.sourceMessageId,
      origin: origin ?? this.origin,
      pinned: pinned ?? this.pinned,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (fact.present) {
      map['fact'] = Variable<String>(fact.value);
    }
    if (sourceMessageId.present) {
      map['source_message_id'] = Variable<String>(sourceMessageId.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AgentFactsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('fact: $fact, ')
          ..write('sourceMessageId: $sourceMessageId, ')
          ..write('origin: $origin, ')
          ..write('pinned: $pinned, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JournalEventsTable extends JournalEvents
    with TableInfo<$JournalEventsTable, JournalEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JournalEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
  static const VerificationMeta _agentIdMeta = const VerificationMeta(
    'agentId',
  );
  @override
  late final GeneratedColumn<String> agentId = GeneratedColumn<String>(
    'agent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    kind,
    agentId,
    payload,
    at,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'journal_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<JournalEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('agent_id')) {
      context.handle(
        _agentIdMeta,
        agentId.isAcceptableOrUnknown(data['agent_id']!, _agentIdMeta),
      );
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  JournalEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JournalEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      agentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_id'],
      ),
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}at'],
      )!,
    );
  }

  @override
  $JournalEventsTable createAlias(String alias) {
    return $JournalEventsTable(attachedDatabase, alias);
  }
}

class JournalEvent extends DataClass implements Insertable<JournalEvent> {
  final String id;
  final String sessionId;

  /// 'launch' | 'navigate' | 'send' | 'extract' | 'round' | 'stop' | ...
  final String kind;
  final String? agentId;
  final String payload;
  final DateTime at;
  const JournalEvent({
    required this.id,
    required this.sessionId,
    required this.kind,
    this.agentId,
    required this.payload,
    required this.at,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || agentId != null) {
      map['agent_id'] = Variable<String>(agentId);
    }
    map['payload'] = Variable<String>(payload);
    map['at'] = Variable<DateTime>(at);
    return map;
  }

  JournalEventsCompanion toCompanion(bool nullToAbsent) {
    return JournalEventsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      kind: Value(kind),
      agentId: agentId == null && nullToAbsent
          ? const Value.absent()
          : Value(agentId),
      payload: Value(payload),
      at: Value(at),
    );
  }

  factory JournalEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JournalEvent(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      kind: serializer.fromJson<String>(json['kind']),
      agentId: serializer.fromJson<String?>(json['agentId']),
      payload: serializer.fromJson<String>(json['payload']),
      at: serializer.fromJson<DateTime>(json['at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'kind': serializer.toJson<String>(kind),
      'agentId': serializer.toJson<String?>(agentId),
      'payload': serializer.toJson<String>(payload),
      'at': serializer.toJson<DateTime>(at),
    };
  }

  JournalEvent copyWith({
    String? id,
    String? sessionId,
    String? kind,
    Value<String?> agentId = const Value.absent(),
    String? payload,
    DateTime? at,
  }) => JournalEvent(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    kind: kind ?? this.kind,
    agentId: agentId.present ? agentId.value : this.agentId,
    payload: payload ?? this.payload,
    at: at ?? this.at,
  );
  JournalEvent copyWithCompanion(JournalEventsCompanion data) {
    return JournalEvent(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      kind: data.kind.present ? data.kind.value : this.kind,
      agentId: data.agentId.present ? data.agentId.value : this.agentId,
      payload: data.payload.present ? data.payload.value : this.payload,
      at: data.at.present ? data.at.value : this.at,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JournalEvent(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('kind: $kind, ')
          ..write('agentId: $agentId, ')
          ..write('payload: $payload, ')
          ..write('at: $at')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sessionId, kind, agentId, payload, at);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JournalEvent &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.kind == this.kind &&
          other.agentId == this.agentId &&
          other.payload == this.payload &&
          other.at == this.at);
}

class JournalEventsCompanion extends UpdateCompanion<JournalEvent> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> kind;
  final Value<String?> agentId;
  final Value<String> payload;
  final Value<DateTime> at;
  final Value<int> rowid;
  const JournalEventsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.kind = const Value.absent(),
    this.agentId = const Value.absent(),
    this.payload = const Value.absent(),
    this.at = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JournalEventsCompanion.insert({
    required String id,
    required String sessionId,
    required String kind,
    this.agentId = const Value.absent(),
    this.payload = const Value.absent(),
    required DateTime at,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       kind = Value(kind),
       at = Value(at);
  static Insertable<JournalEvent> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? kind,
    Expression<String>? agentId,
    Expression<String>? payload,
    Expression<DateTime>? at,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (kind != null) 'kind': kind,
      if (agentId != null) 'agent_id': agentId,
      if (payload != null) 'payload': payload,
      if (at != null) 'at': at,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JournalEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? kind,
    Value<String?>? agentId,
    Value<String>? payload,
    Value<DateTime>? at,
    Value<int>? rowid,
  }) {
    return JournalEventsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      kind: kind ?? this.kind,
      agentId: agentId ?? this.agentId,
      payload: payload ?? this.payload,
      at: at ?? this.at,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (agentId.present) {
      map['agent_id'] = Variable<String>(agentId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JournalEventsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('kind: $kind, ')
          ..write('agentId: $agentId, ')
          ..write('payload: $payload, ')
          ..write('at: $at, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AdaptersTable extends Adapters with TableInfo<$AdaptersTable, Adapter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AdaptersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _configMeta = const VerificationMeta('config');
  @override
  late final GeneratedColumn<String> config = GeneratedColumn<String>(
    'config',
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
    requiredDuringInsert: false,
    defaultValue: const Constant('bundled'),
  );
  static const VerificationMeta _verifiedMeta = const VerificationMeta(
    'verified',
  );
  @override
  late final GeneratedColumn<bool> verified = GeneratedColumn<bool>(
    'verified',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("verified" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _installedAtMeta = const VerificationMeta(
    'installedAt',
  );
  @override
  late final GeneratedColumn<DateTime> installedAt = GeneratedColumn<DateTime>(
    'installed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    provider,
    version,
    config,
    source,
    verified,
    installedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'adapters';
  @override
  VerificationContext validateIntegrity(
    Insertable<Adapter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('config')) {
      context.handle(
        _configMeta,
        config.isAcceptableOrUnknown(data['config']!, _configMeta),
      );
    } else if (isInserting) {
      context.missing(_configMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('verified')) {
      context.handle(
        _verifiedMeta,
        verified.isAcceptableOrUnknown(data['verified']!, _verifiedMeta),
      );
    }
    if (data.containsKey('installed_at')) {
      context.handle(
        _installedAtMeta,
        installedAt.isAcceptableOrUnknown(
          data['installed_at']!,
          _installedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_installedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Adapter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Adapter(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
      config: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      verified: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}verified'],
      )!,
      installedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}installed_at'],
      )!,
    );
  }

  @override
  $AdaptersTable createAlias(String alias) {
    return $AdaptersTable(attachedDatabase, alias);
  }
}

class Adapter extends DataClass implements Insertable<Adapter> {
  final String id;
  final String provider;
  final String version;

  /// The selector document as JSON.
  final String config;

  /// 'bundled' | 'user' | 'remote'
  final String source;
  final bool verified;
  final DateTime installedAt;
  const Adapter({
    required this.id,
    required this.provider,
    required this.version,
    required this.config,
    required this.source,
    required this.verified,
    required this.installedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['provider'] = Variable<String>(provider);
    map['version'] = Variable<String>(version);
    map['config'] = Variable<String>(config);
    map['source'] = Variable<String>(source);
    map['verified'] = Variable<bool>(verified);
    map['installed_at'] = Variable<DateTime>(installedAt);
    return map;
  }

  AdaptersCompanion toCompanion(bool nullToAbsent) {
    return AdaptersCompanion(
      id: Value(id),
      provider: Value(provider),
      version: Value(version),
      config: Value(config),
      source: Value(source),
      verified: Value(verified),
      installedAt: Value(installedAt),
    );
  }

  factory Adapter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Adapter(
      id: serializer.fromJson<String>(json['id']),
      provider: serializer.fromJson<String>(json['provider']),
      version: serializer.fromJson<String>(json['version']),
      config: serializer.fromJson<String>(json['config']),
      source: serializer.fromJson<String>(json['source']),
      verified: serializer.fromJson<bool>(json['verified']),
      installedAt: serializer.fromJson<DateTime>(json['installedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'provider': serializer.toJson<String>(provider),
      'version': serializer.toJson<String>(version),
      'config': serializer.toJson<String>(config),
      'source': serializer.toJson<String>(source),
      'verified': serializer.toJson<bool>(verified),
      'installedAt': serializer.toJson<DateTime>(installedAt),
    };
  }

  Adapter copyWith({
    String? id,
    String? provider,
    String? version,
    String? config,
    String? source,
    bool? verified,
    DateTime? installedAt,
  }) => Adapter(
    id: id ?? this.id,
    provider: provider ?? this.provider,
    version: version ?? this.version,
    config: config ?? this.config,
    source: source ?? this.source,
    verified: verified ?? this.verified,
    installedAt: installedAt ?? this.installedAt,
  );
  Adapter copyWithCompanion(AdaptersCompanion data) {
    return Adapter(
      id: data.id.present ? data.id.value : this.id,
      provider: data.provider.present ? data.provider.value : this.provider,
      version: data.version.present ? data.version.value : this.version,
      config: data.config.present ? data.config.value : this.config,
      source: data.source.present ? data.source.value : this.source,
      verified: data.verified.present ? data.verified.value : this.verified,
      installedAt: data.installedAt.present
          ? data.installedAt.value
          : this.installedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Adapter(')
          ..write('id: $id, ')
          ..write('provider: $provider, ')
          ..write('version: $version, ')
          ..write('config: $config, ')
          ..write('source: $source, ')
          ..write('verified: $verified, ')
          ..write('installedAt: $installedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, provider, version, config, source, verified, installedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Adapter &&
          other.id == this.id &&
          other.provider == this.provider &&
          other.version == this.version &&
          other.config == this.config &&
          other.source == this.source &&
          other.verified == this.verified &&
          other.installedAt == this.installedAt);
}

class AdaptersCompanion extends UpdateCompanion<Adapter> {
  final Value<String> id;
  final Value<String> provider;
  final Value<String> version;
  final Value<String> config;
  final Value<String> source;
  final Value<bool> verified;
  final Value<DateTime> installedAt;
  final Value<int> rowid;
  const AdaptersCompanion({
    this.id = const Value.absent(),
    this.provider = const Value.absent(),
    this.version = const Value.absent(),
    this.config = const Value.absent(),
    this.source = const Value.absent(),
    this.verified = const Value.absent(),
    this.installedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AdaptersCompanion.insert({
    required String id,
    required String provider,
    required String version,
    required String config,
    this.source = const Value.absent(),
    this.verified = const Value.absent(),
    required DateTime installedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       provider = Value(provider),
       version = Value(version),
       config = Value(config),
       installedAt = Value(installedAt);
  static Insertable<Adapter> custom({
    Expression<String>? id,
    Expression<String>? provider,
    Expression<String>? version,
    Expression<String>? config,
    Expression<String>? source,
    Expression<bool>? verified,
    Expression<DateTime>? installedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (provider != null) 'provider': provider,
      if (version != null) 'version': version,
      if (config != null) 'config': config,
      if (source != null) 'source': source,
      if (verified != null) 'verified': verified,
      if (installedAt != null) 'installed_at': installedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AdaptersCompanion copyWith({
    Value<String>? id,
    Value<String>? provider,
    Value<String>? version,
    Value<String>? config,
    Value<String>? source,
    Value<bool>? verified,
    Value<DateTime>? installedAt,
    Value<int>? rowid,
  }) {
    return AdaptersCompanion(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      version: version ?? this.version,
      config: config ?? this.config,
      source: source ?? this.source,
      verified: verified ?? this.verified,
      installedAt: installedAt ?? this.installedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (config.present) {
      map['config'] = Variable<String>(config.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (verified.present) {
      map['verified'] = Variable<bool>(verified.value);
    }
    if (installedAt.present) {
      map['installed_at'] = Variable<DateTime>(installedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AdaptersCompanion(')
          ..write('id: $id, ')
          ..write('provider: $provider, ')
          ..write('version: $version, ')
          ..write('config: $config, ')
          ..write('source: $source, ')
          ..write('verified: $verified, ')
          ..write('installedAt: $installedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UsageCountersTable extends UsageCounters
    with TableInfo<$UsageCountersTable, UsageCounter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsageCountersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _agentKindMeta = const VerificationMeta(
    'agentKind',
  );
  @override
  late final GeneratedColumn<String> agentKind = GeneratedColumn<String>(
    'agent_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<String> day = GeneratedColumn<String>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageCountMeta = const VerificationMeta(
    'messageCount',
  );
  @override
  late final GeneratedColumn<int> messageCount = GeneratedColumn<int>(
    'message_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _byteCountMeta = const VerificationMeta(
    'byteCount',
  );
  @override
  late final GeneratedColumn<int> byteCount = GeneratedColumn<int>(
    'byte_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    agentKind,
    day,
    messageCount,
    byteCount,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'usage_counters';
  @override
  VerificationContext validateIntegrity(
    Insertable<UsageCounter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('agent_kind')) {
      context.handle(
        _agentKindMeta,
        agentKind.isAcceptableOrUnknown(data['agent_kind']!, _agentKindMeta),
      );
    } else if (isInserting) {
      context.missing(_agentKindMeta);
    }
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('message_count')) {
      context.handle(
        _messageCountMeta,
        messageCount.isAcceptableOrUnknown(
          data['message_count']!,
          _messageCountMeta,
        ),
      );
    }
    if (data.containsKey('byte_count')) {
      context.handle(
        _byteCountMeta,
        byteCount.isAcceptableOrUnknown(data['byte_count']!, _byteCountMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {agentKind, day};
  @override
  UsageCounter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UsageCounter(
      agentKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_kind'],
      )!,
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day'],
      )!,
      messageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}message_count'],
      )!,
      byteCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_count'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UsageCountersTable createAlias(String alias) {
    return $UsageCountersTable(attachedDatabase, alias);
  }
}

class UsageCounter extends DataClass implements Insertable<UsageCounter> {
  final String agentKind;

  /// Local calendar day, 'YYYY-MM-DD'.
  final String day;
  final int messageCount;
  final int byteCount;
  final DateTime updatedAt;
  const UsageCounter({
    required this.agentKind,
    required this.day,
    required this.messageCount,
    required this.byteCount,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['agent_kind'] = Variable<String>(agentKind);
    map['day'] = Variable<String>(day);
    map['message_count'] = Variable<int>(messageCount);
    map['byte_count'] = Variable<int>(byteCount);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UsageCountersCompanion toCompanion(bool nullToAbsent) {
    return UsageCountersCompanion(
      agentKind: Value(agentKind),
      day: Value(day),
      messageCount: Value(messageCount),
      byteCount: Value(byteCount),
      updatedAt: Value(updatedAt),
    );
  }

  factory UsageCounter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UsageCounter(
      agentKind: serializer.fromJson<String>(json['agentKind']),
      day: serializer.fromJson<String>(json['day']),
      messageCount: serializer.fromJson<int>(json['messageCount']),
      byteCount: serializer.fromJson<int>(json['byteCount']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'agentKind': serializer.toJson<String>(agentKind),
      'day': serializer.toJson<String>(day),
      'messageCount': serializer.toJson<int>(messageCount),
      'byteCount': serializer.toJson<int>(byteCount),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UsageCounter copyWith({
    String? agentKind,
    String? day,
    int? messageCount,
    int? byteCount,
    DateTime? updatedAt,
  }) => UsageCounter(
    agentKind: agentKind ?? this.agentKind,
    day: day ?? this.day,
    messageCount: messageCount ?? this.messageCount,
    byteCount: byteCount ?? this.byteCount,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UsageCounter copyWithCompanion(UsageCountersCompanion data) {
    return UsageCounter(
      agentKind: data.agentKind.present ? data.agentKind.value : this.agentKind,
      day: data.day.present ? data.day.value : this.day,
      messageCount: data.messageCount.present
          ? data.messageCount.value
          : this.messageCount,
      byteCount: data.byteCount.present ? data.byteCount.value : this.byteCount,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UsageCounter(')
          ..write('agentKind: $agentKind, ')
          ..write('day: $day, ')
          ..write('messageCount: $messageCount, ')
          ..write('byteCount: $byteCount, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(agentKind, day, messageCount, byteCount, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UsageCounter &&
          other.agentKind == this.agentKind &&
          other.day == this.day &&
          other.messageCount == this.messageCount &&
          other.byteCount == this.byteCount &&
          other.updatedAt == this.updatedAt);
}

class UsageCountersCompanion extends UpdateCompanion<UsageCounter> {
  final Value<String> agentKind;
  final Value<String> day;
  final Value<int> messageCount;
  final Value<int> byteCount;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const UsageCountersCompanion({
    this.agentKind = const Value.absent(),
    this.day = const Value.absent(),
    this.messageCount = const Value.absent(),
    this.byteCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsageCountersCompanion.insert({
    required String agentKind,
    required String day,
    this.messageCount = const Value.absent(),
    this.byteCount = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : agentKind = Value(agentKind),
       day = Value(day),
       updatedAt = Value(updatedAt);
  static Insertable<UsageCounter> custom({
    Expression<String>? agentKind,
    Expression<String>? day,
    Expression<int>? messageCount,
    Expression<int>? byteCount,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (agentKind != null) 'agent_kind': agentKind,
      if (day != null) 'day': day,
      if (messageCount != null) 'message_count': messageCount,
      if (byteCount != null) 'byte_count': byteCount,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsageCountersCompanion copyWith({
    Value<String>? agentKind,
    Value<String>? day,
    Value<int>? messageCount,
    Value<int>? byteCount,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return UsageCountersCompanion(
      agentKind: agentKind ?? this.agentKind,
      day: day ?? this.day,
      messageCount: messageCount ?? this.messageCount,
      byteCount: byteCount ?? this.byteCount,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (agentKind.present) {
      map['agent_kind'] = Variable<String>(agentKind.value);
    }
    if (day.present) {
      map['day'] = Variable<String>(day.value);
    }
    if (messageCount.present) {
      map['message_count'] = Variable<int>(messageCount.value);
    }
    if (byteCount.present) {
      map['byte_count'] = Variable<int>(byteCount.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsageCountersCompanion(')
          ..write('agentKind: $agentKind, ')
          ..write('day: $day, ')
          ..write('messageCount: $messageCount, ')
          ..write('byteCount: $byteCount, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AgoraDb extends GeneratedDatabase {
  _$AgoraDb(QueryExecutor e) : super(e);
  $AgoraDbManager get managers => $AgoraDbManager(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $AgentsTable agents = $AgentsTable(this);
  late final $SessionAgentsTable sessionAgents = $SessionAgentsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $PacketsTable packets = $PacketsTable(this);
  late final $AgentFactsTable agentFacts = $AgentFactsTable(this);
  late final $JournalEventsTable journalEvents = $JournalEventsTable(this);
  late final $AdaptersTable adapters = $AdaptersTable(this);
  late final $UsageCountersTable usageCounters = $UsageCountersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    sessions,
    agents,
    sessionAgents,
    messages,
    packets,
    agentFacts,
    journalEvents,
    adapters,
    usageCounters,
  ];
}

typedef $$SessionsTableCreateCompanionBuilder =
    SessionsCompanion Function({
      required String id,
      Value<String> title,
      required String prompt,
      Value<String?> leaderId,
      Value<int> round,
      Value<int> maxRounds,
      Value<int> budgetSeconds,
      Value<int> elapsedSeconds,
      Value<String> status,
      Value<String> contextStrategy,
      Value<String?> templateId,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$SessionsTableUpdateCompanionBuilder =
    SessionsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> prompt,
      Value<String?> leaderId,
      Value<int> round,
      Value<int> maxRounds,
      Value<int> budgetSeconds,
      Value<int> elapsedSeconds,
      Value<String> status,
      Value<String> contextStrategy,
      Value<String?> templateId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$SessionsTableFilterComposer
    extends Composer<_$AgoraDb, $SessionsTable> {
  $$SessionsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prompt => $composableBuilder(
    column: $table.prompt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get leaderId => $composableBuilder(
    column: $table.leaderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get round => $composableBuilder(
    column: $table.round,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxRounds => $composableBuilder(
    column: $table.maxRounds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get budgetSeconds => $composableBuilder(
    column: $table.budgetSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get elapsedSeconds => $composableBuilder(
    column: $table.elapsedSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contextStrategy => $composableBuilder(
    column: $table.contextStrategy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionsTableOrderingComposer
    extends Composer<_$AgoraDb, $SessionsTable> {
  $$SessionsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prompt => $composableBuilder(
    column: $table.prompt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get leaderId => $composableBuilder(
    column: $table.leaderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get round => $composableBuilder(
    column: $table.round,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxRounds => $composableBuilder(
    column: $table.maxRounds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get budgetSeconds => $composableBuilder(
    column: $table.budgetSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get elapsedSeconds => $composableBuilder(
    column: $table.elapsedSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contextStrategy => $composableBuilder(
    column: $table.contextStrategy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$AgoraDb, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get prompt =>
      $composableBuilder(column: $table.prompt, builder: (column) => column);

  GeneratedColumn<String> get leaderId =>
      $composableBuilder(column: $table.leaderId, builder: (column) => column);

  GeneratedColumn<int> get round =>
      $composableBuilder(column: $table.round, builder: (column) => column);

  GeneratedColumn<int> get maxRounds =>
      $composableBuilder(column: $table.maxRounds, builder: (column) => column);

  GeneratedColumn<int> get budgetSeconds => $composableBuilder(
    column: $table.budgetSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get elapsedSeconds => $composableBuilder(
    column: $table.elapsedSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get contextStrategy => $composableBuilder(
    column: $table.contextStrategy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$AgoraDb,
          $SessionsTable,
          Session,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (Session, BaseReferences<_$AgoraDb, $SessionsTable, Session>),
          Session,
          PrefetchHooks Function()
        > {
  $$SessionsTableTableManager(_$AgoraDb db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> prompt = const Value.absent(),
                Value<String?> leaderId = const Value.absent(),
                Value<int> round = const Value.absent(),
                Value<int> maxRounds = const Value.absent(),
                Value<int> budgetSeconds = const Value.absent(),
                Value<int> elapsedSeconds = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> contextStrategy = const Value.absent(),
                Value<String?> templateId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                title: title,
                prompt: prompt,
                leaderId: leaderId,
                round: round,
                maxRounds: maxRounds,
                budgetSeconds: budgetSeconds,
                elapsedSeconds: elapsedSeconds,
                status: status,
                contextStrategy: contextStrategy,
                templateId: templateId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> title = const Value.absent(),
                required String prompt,
                Value<String?> leaderId = const Value.absent(),
                Value<int> round = const Value.absent(),
                Value<int> maxRounds = const Value.absent(),
                Value<int> budgetSeconds = const Value.absent(),
                Value<int> elapsedSeconds = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> contextStrategy = const Value.absent(),
                Value<String?> templateId = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion.insert(
                id: id,
                title: title,
                prompt: prompt,
                leaderId: leaderId,
                round: round,
                maxRounds: maxRounds,
                budgetSeconds: budgetSeconds,
                elapsedSeconds: elapsedSeconds,
                status: status,
                contextStrategy: contextStrategy,
                templateId: templateId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SessionsTable, Session>(table),
                  BaseReferences<_$AgoraDb, $SessionsTable, Session>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AgoraDb,
      $SessionsTable,
      Session,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (Session, BaseReferences<_$AgoraDb, $SessionsTable, Session>),
      Session,
      PrefetchHooks Function()
    >;
typedef $$AgentsTableCreateCompanionBuilder =
    AgentsCompanion Function({
      required String id,
      required String kind,
      required String displayName,
      Value<int> colorValue,
      required String url,
      Value<String?> adapterVersion,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$AgentsTableUpdateCompanionBuilder =
    AgentsCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> displayName,
      Value<int> colorValue,
      Value<String> url,
      Value<String?> adapterVersion,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$AgentsTableFilterComposer extends Composer<_$AgoraDb, $AgentsTable> {
  $$AgentsTableFilterComposer({
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get adapterVersion => $composableBuilder(
    column: $table.adapterVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AgentsTableOrderingComposer extends Composer<_$AgoraDb, $AgentsTable> {
  $$AgentsTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get adapterVersion => $composableBuilder(
    column: $table.adapterVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AgentsTableAnnotationComposer
    extends Composer<_$AgoraDb, $AgentsTable> {
  $$AgentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get adapterVersion => $composableBuilder(
    column: $table.adapterVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AgentsTableTableManager
    extends
        RootTableManager<
          _$AgoraDb,
          $AgentsTable,
          Agent,
          $$AgentsTableFilterComposer,
          $$AgentsTableOrderingComposer,
          $$AgentsTableAnnotationComposer,
          $$AgentsTableCreateCompanionBuilder,
          $$AgentsTableUpdateCompanionBuilder,
          (Agent, BaseReferences<_$AgoraDb, $AgentsTable, Agent>),
          Agent,
          PrefetchHooks Function()
        > {
  $$AgentsTableTableManager(_$AgoraDb db, $AgentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AgentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AgentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AgentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String?> adapterVersion = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AgentsCompanion(
                id: id,
                kind: kind,
                displayName: displayName,
                colorValue: colorValue,
                url: url,
                adapterVersion: adapterVersion,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String displayName,
                Value<int> colorValue = const Value.absent(),
                required String url,
                Value<String?> adapterVersion = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => AgentsCompanion.insert(
                id: id,
                kind: kind,
                displayName: displayName,
                colorValue: colorValue,
                url: url,
                adapterVersion: adapterVersion,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AgentsTable, Agent>(table),
                  BaseReferences<_$AgoraDb, $AgentsTable, Agent>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AgentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AgoraDb,
      $AgentsTable,
      Agent,
      $$AgentsTableFilterComposer,
      $$AgentsTableOrderingComposer,
      $$AgentsTableAnnotationComposer,
      $$AgentsTableCreateCompanionBuilder,
      $$AgentsTableUpdateCompanionBuilder,
      (Agent, BaseReferences<_$AgoraDb, $AgentsTable, Agent>),
      Agent,
      PrefetchHooks Function()
    >;
typedef $$SessionAgentsTableCreateCompanionBuilder =
    SessionAgentsCompanion Function({
      required String sessionId,
      required String agentId,
      Value<String?> roleCard,
      Value<int> sortOrder,
      Value<bool> isLeader,
      Value<String> status,
      Value<String?> modelLabel,
      required DateTime addedAt,
      Value<int> rowid,
    });
typedef $$SessionAgentsTableUpdateCompanionBuilder =
    SessionAgentsCompanion Function({
      Value<String> sessionId,
      Value<String> agentId,
      Value<String?> roleCard,
      Value<int> sortOrder,
      Value<bool> isLeader,
      Value<String> status,
      Value<String?> modelLabel,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

class $$SessionAgentsTableFilterComposer
    extends Composer<_$AgoraDb, $SessionAgentsTable> {
  $$SessionAgentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get roleCard => $composableBuilder(
    column: $table.roleCard,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isLeader => $composableBuilder(
    column: $table.isLeader,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelLabel => $composableBuilder(
    column: $table.modelLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionAgentsTableOrderingComposer
    extends Composer<_$AgoraDb, $SessionAgentsTable> {
  $$SessionAgentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roleCard => $composableBuilder(
    column: $table.roleCard,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isLeader => $composableBuilder(
    column: $table.isLeader,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelLabel => $composableBuilder(
    column: $table.modelLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionAgentsTableAnnotationComposer
    extends Composer<_$AgoraDb, $SessionAgentsTable> {
  $$SessionAgentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get agentId =>
      $composableBuilder(column: $table.agentId, builder: (column) => column);

  GeneratedColumn<String> get roleCard =>
      $composableBuilder(column: $table.roleCard, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isLeader =>
      $composableBuilder(column: $table.isLeader, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get modelLabel => $composableBuilder(
    column: $table.modelLabel,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$SessionAgentsTableTableManager
    extends
        RootTableManager<
          _$AgoraDb,
          $SessionAgentsTable,
          SessionAgent,
          $$SessionAgentsTableFilterComposer,
          $$SessionAgentsTableOrderingComposer,
          $$SessionAgentsTableAnnotationComposer,
          $$SessionAgentsTableCreateCompanionBuilder,
          $$SessionAgentsTableUpdateCompanionBuilder,
          (
            SessionAgent,
            BaseReferences<_$AgoraDb, $SessionAgentsTable, SessionAgent>,
          ),
          SessionAgent,
          PrefetchHooks Function()
        > {
  $$SessionAgentsTableTableManager(_$AgoraDb db, $SessionAgentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionAgentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionAgentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionAgentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<String> agentId = const Value.absent(),
                Value<String?> roleCard = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isLeader = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> modelLabel = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionAgentsCompanion(
                sessionId: sessionId,
                agentId: agentId,
                roleCard: roleCard,
                sortOrder: sortOrder,
                isLeader: isLeader,
                status: status,
                modelLabel: modelLabel,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required String agentId,
                Value<String?> roleCard = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isLeader = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> modelLabel = const Value.absent(),
                required DateTime addedAt,
                Value<int> rowid = const Value.absent(),
              }) => SessionAgentsCompanion.insert(
                sessionId: sessionId,
                agentId: agentId,
                roleCard: roleCard,
                sortOrder: sortOrder,
                isLeader: isLeader,
                status: status,
                modelLabel: modelLabel,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SessionAgentsTable, SessionAgent>(table),
                  BaseReferences<_$AgoraDb, $SessionAgentsTable, SessionAgent>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionAgentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AgoraDb,
      $SessionAgentsTable,
      SessionAgent,
      $$SessionAgentsTableFilterComposer,
      $$SessionAgentsTableOrderingComposer,
      $$SessionAgentsTableAnnotationComposer,
      $$SessionAgentsTableCreateCompanionBuilder,
      $$SessionAgentsTableUpdateCompanionBuilder,
      (
        SessionAgent,
        BaseReferences<_$AgoraDb, $SessionAgentsTable, SessionAgent>,
      ),
      SessionAgent,
      PrefetchHooks Function()
    >;
typedef $$MessagesTableCreateCompanionBuilder =
    MessagesCompanion Function({
      required String id,
      required String sessionId,
      Value<int> round,
      required String agentId,
      required String role,
      required String direction,
      required String rawText,
      Value<String?> rawHtml,
      Value<String?> screenshotPath,
      required String contentHash,
      Value<int?> latencyMs,
      Value<String?> packetRef,
      Value<String?> meta,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$MessagesTableUpdateCompanionBuilder =
    MessagesCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<int> round,
      Value<String> agentId,
      Value<String> role,
      Value<String> direction,
      Value<String> rawText,
      Value<String?> rawHtml,
      Value<String?> screenshotPath,
      Value<String> contentHash,
      Value<int?> latencyMs,
      Value<String?> packetRef,
      Value<String?> meta,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$MessagesTableFilterComposer
    extends Composer<_$AgoraDb, $MessagesTable> {
  $$MessagesTableFilterComposer({
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

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get round => $composableBuilder(
    column: $table.round,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawText => $composableBuilder(
    column: $table.rawText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawHtml => $composableBuilder(
    column: $table.rawHtml,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get screenshotPath => $composableBuilder(
    column: $table.screenshotPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get latencyMs => $composableBuilder(
    column: $table.latencyMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get packetRef => $composableBuilder(
    column: $table.packetRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get meta => $composableBuilder(
    column: $table.meta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MessagesTableOrderingComposer
    extends Composer<_$AgoraDb, $MessagesTable> {
  $$MessagesTableOrderingComposer({
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

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get round => $composableBuilder(
    column: $table.round,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawText => $composableBuilder(
    column: $table.rawText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawHtml => $composableBuilder(
    column: $table.rawHtml,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get screenshotPath => $composableBuilder(
    column: $table.screenshotPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get latencyMs => $composableBuilder(
    column: $table.latencyMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get packetRef => $composableBuilder(
    column: $table.packetRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meta => $composableBuilder(
    column: $table.meta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$AgoraDb, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<int> get round =>
      $composableBuilder(column: $table.round, builder: (column) => column);

  GeneratedColumn<String> get agentId =>
      $composableBuilder(column: $table.agentId, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<String> get rawText =>
      $composableBuilder(column: $table.rawText, builder: (column) => column);

  GeneratedColumn<String> get rawHtml =>
      $composableBuilder(column: $table.rawHtml, builder: (column) => column);

  GeneratedColumn<String> get screenshotPath => $composableBuilder(
    column: $table.screenshotPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get latencyMs =>
      $composableBuilder(column: $table.latencyMs, builder: (column) => column);

  GeneratedColumn<String> get packetRef =>
      $composableBuilder(column: $table.packetRef, builder: (column) => column);

  GeneratedColumn<String> get meta =>
      $composableBuilder(column: $table.meta, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$MessagesTableTableManager
    extends
        RootTableManager<
          _$AgoraDb,
          $MessagesTable,
          Message,
          $$MessagesTableFilterComposer,
          $$MessagesTableOrderingComposer,
          $$MessagesTableAnnotationComposer,
          $$MessagesTableCreateCompanionBuilder,
          $$MessagesTableUpdateCompanionBuilder,
          (Message, BaseReferences<_$AgoraDb, $MessagesTable, Message>),
          Message,
          PrefetchHooks Function()
        > {
  $$MessagesTableTableManager(_$AgoraDb db, $MessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<int> round = const Value.absent(),
                Value<String> agentId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> direction = const Value.absent(),
                Value<String> rawText = const Value.absent(),
                Value<String?> rawHtml = const Value.absent(),
                Value<String?> screenshotPath = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<int?> latencyMs = const Value.absent(),
                Value<String?> packetRef = const Value.absent(),
                Value<String?> meta = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                sessionId: sessionId,
                round: round,
                agentId: agentId,
                role: role,
                direction: direction,
                rawText: rawText,
                rawHtml: rawHtml,
                screenshotPath: screenshotPath,
                contentHash: contentHash,
                latencyMs: latencyMs,
                packetRef: packetRef,
                meta: meta,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                Value<int> round = const Value.absent(),
                required String agentId,
                required String role,
                required String direction,
                required String rawText,
                Value<String?> rawHtml = const Value.absent(),
                Value<String?> screenshotPath = const Value.absent(),
                required String contentHash,
                Value<int?> latencyMs = const Value.absent(),
                Value<String?> packetRef = const Value.absent(),
                Value<String?> meta = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion.insert(
                id: id,
                sessionId: sessionId,
                round: round,
                agentId: agentId,
                role: role,
                direction: direction,
                rawText: rawText,
                rawHtml: rawHtml,
                screenshotPath: screenshotPath,
                contentHash: contentHash,
                latencyMs: latencyMs,
                packetRef: packetRef,
                meta: meta,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MessagesTable, Message>(table),
                  BaseReferences<_$AgoraDb, $MessagesTable, Message>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AgoraDb,
      $MessagesTable,
      Message,
      $$MessagesTableFilterComposer,
      $$MessagesTableOrderingComposer,
      $$MessagesTableAnnotationComposer,
      $$MessagesTableCreateCompanionBuilder,
      $$MessagesTableUpdateCompanionBuilder,
      (Message, BaseReferences<_$AgoraDb, $MessagesTable, Message>),
      Message,
      PrefetchHooks Function()
    >;
typedef $$PacketsTableCreateCompanionBuilder =
    PacketsCompanion Function({
      required String id,
      required String sessionId,
      Value<int> round,
      required String targetAgentId,
      required String strategy,
      Value<int> byteSize,
      required String bodyHash,
      required String body,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$PacketsTableUpdateCompanionBuilder =
    PacketsCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<int> round,
      Value<String> targetAgentId,
      Value<String> strategy,
      Value<int> byteSize,
      Value<String> bodyHash,
      Value<String> body,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$PacketsTableFilterComposer extends Composer<_$AgoraDb, $PacketsTable> {
  $$PacketsTableFilterComposer({
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

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get round => $composableBuilder(
    column: $table.round,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetAgentId => $composableBuilder(
    column: $table.targetAgentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get strategy => $composableBuilder(
    column: $table.strategy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyHash => $composableBuilder(
    column: $table.bodyHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PacketsTableOrderingComposer
    extends Composer<_$AgoraDb, $PacketsTable> {
  $$PacketsTableOrderingComposer({
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

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get round => $composableBuilder(
    column: $table.round,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetAgentId => $composableBuilder(
    column: $table.targetAgentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get strategy => $composableBuilder(
    column: $table.strategy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyHash => $composableBuilder(
    column: $table.bodyHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PacketsTableAnnotationComposer
    extends Composer<_$AgoraDb, $PacketsTable> {
  $$PacketsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<int> get round =>
      $composableBuilder(column: $table.round, builder: (column) => column);

  GeneratedColumn<String> get targetAgentId => $composableBuilder(
    column: $table.targetAgentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get strategy =>
      $composableBuilder(column: $table.strategy, builder: (column) => column);

  GeneratedColumn<int> get byteSize =>
      $composableBuilder(column: $table.byteSize, builder: (column) => column);

  GeneratedColumn<String> get bodyHash =>
      $composableBuilder(column: $table.bodyHash, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PacketsTableTableManager
    extends
        RootTableManager<
          _$AgoraDb,
          $PacketsTable,
          Packet,
          $$PacketsTableFilterComposer,
          $$PacketsTableOrderingComposer,
          $$PacketsTableAnnotationComposer,
          $$PacketsTableCreateCompanionBuilder,
          $$PacketsTableUpdateCompanionBuilder,
          (Packet, BaseReferences<_$AgoraDb, $PacketsTable, Packet>),
          Packet,
          PrefetchHooks Function()
        > {
  $$PacketsTableTableManager(_$AgoraDb db, $PacketsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PacketsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PacketsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PacketsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<int> round = const Value.absent(),
                Value<String> targetAgentId = const Value.absent(),
                Value<String> strategy = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                Value<String> bodyHash = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PacketsCompanion(
                id: id,
                sessionId: sessionId,
                round: round,
                targetAgentId: targetAgentId,
                strategy: strategy,
                byteSize: byteSize,
                bodyHash: bodyHash,
                body: body,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                Value<int> round = const Value.absent(),
                required String targetAgentId,
                required String strategy,
                Value<int> byteSize = const Value.absent(),
                required String bodyHash,
                required String body,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => PacketsCompanion.insert(
                id: id,
                sessionId: sessionId,
                round: round,
                targetAgentId: targetAgentId,
                strategy: strategy,
                byteSize: byteSize,
                bodyHash: bodyHash,
                body: body,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PacketsTable, Packet>(table),
                  BaseReferences<_$AgoraDb, $PacketsTable, Packet>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PacketsTableProcessedTableManager =
    ProcessedTableManager<
      _$AgoraDb,
      $PacketsTable,
      Packet,
      $$PacketsTableFilterComposer,
      $$PacketsTableOrderingComposer,
      $$PacketsTableAnnotationComposer,
      $$PacketsTableCreateCompanionBuilder,
      $$PacketsTableUpdateCompanionBuilder,
      (Packet, BaseReferences<_$AgoraDb, $PacketsTable, Packet>),
      Packet,
      PrefetchHooks Function()
    >;
typedef $$AgentFactsTableCreateCompanionBuilder =
    AgentFactsCompanion Function({
      required String id,
      required String sessionId,
      required String fact,
      Value<String?> sourceMessageId,
      Value<String> origin,
      Value<bool> pinned,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$AgentFactsTableUpdateCompanionBuilder =
    AgentFactsCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<String> fact,
      Value<String?> sourceMessageId,
      Value<String> origin,
      Value<bool> pinned,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$AgentFactsTableFilterComposer
    extends Composer<_$AgoraDb, $AgentFactsTable> {
  $$AgentFactsTableFilterComposer({
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

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fact => $composableBuilder(
    column: $table.fact,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceMessageId => $composableBuilder(
    column: $table.sourceMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AgentFactsTableOrderingComposer
    extends Composer<_$AgoraDb, $AgentFactsTable> {
  $$AgentFactsTableOrderingComposer({
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

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fact => $composableBuilder(
    column: $table.fact,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceMessageId => $composableBuilder(
    column: $table.sourceMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AgentFactsTableAnnotationComposer
    extends Composer<_$AgoraDb, $AgentFactsTable> {
  $$AgentFactsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get fact =>
      $composableBuilder(column: $table.fact, builder: (column) => column);

  GeneratedColumn<String> get sourceMessageId => $composableBuilder(
    column: $table.sourceMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AgentFactsTableTableManager
    extends
        RootTableManager<
          _$AgoraDb,
          $AgentFactsTable,
          AgentFact,
          $$AgentFactsTableFilterComposer,
          $$AgentFactsTableOrderingComposer,
          $$AgentFactsTableAnnotationComposer,
          $$AgentFactsTableCreateCompanionBuilder,
          $$AgentFactsTableUpdateCompanionBuilder,
          (AgentFact, BaseReferences<_$AgoraDb, $AgentFactsTable, AgentFact>),
          AgentFact,
          PrefetchHooks Function()
        > {
  $$AgentFactsTableTableManager(_$AgoraDb db, $AgentFactsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AgentFactsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AgentFactsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AgentFactsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> fact = const Value.absent(),
                Value<String?> sourceMessageId = const Value.absent(),
                Value<String> origin = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AgentFactsCompanion(
                id: id,
                sessionId: sessionId,
                fact: fact,
                sourceMessageId: sourceMessageId,
                origin: origin,
                pinned: pinned,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required String fact,
                Value<String?> sourceMessageId = const Value.absent(),
                Value<String> origin = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => AgentFactsCompanion.insert(
                id: id,
                sessionId: sessionId,
                fact: fact,
                sourceMessageId: sourceMessageId,
                origin: origin,
                pinned: pinned,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AgentFactsTable, AgentFact>(table),
                  BaseReferences<_$AgoraDb, $AgentFactsTable, AgentFact>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AgentFactsTableProcessedTableManager =
    ProcessedTableManager<
      _$AgoraDb,
      $AgentFactsTable,
      AgentFact,
      $$AgentFactsTableFilterComposer,
      $$AgentFactsTableOrderingComposer,
      $$AgentFactsTableAnnotationComposer,
      $$AgentFactsTableCreateCompanionBuilder,
      $$AgentFactsTableUpdateCompanionBuilder,
      (AgentFact, BaseReferences<_$AgoraDb, $AgentFactsTable, AgentFact>),
      AgentFact,
      PrefetchHooks Function()
    >;
typedef $$JournalEventsTableCreateCompanionBuilder =
    JournalEventsCompanion Function({
      required String id,
      required String sessionId,
      required String kind,
      Value<String?> agentId,
      Value<String> payload,
      required DateTime at,
      Value<int> rowid,
    });
typedef $$JournalEventsTableUpdateCompanionBuilder =
    JournalEventsCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<String> kind,
      Value<String?> agentId,
      Value<String> payload,
      Value<DateTime> at,
      Value<int> rowid,
    });

class $$JournalEventsTableFilterComposer
    extends Composer<_$AgoraDb, $JournalEventsTable> {
  $$JournalEventsTableFilterComposer({
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

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );
}

class $$JournalEventsTableOrderingComposer
    extends Composer<_$AgoraDb, $JournalEventsTable> {
  $$JournalEventsTableOrderingComposer({
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

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$JournalEventsTableAnnotationComposer
    extends Composer<_$AgoraDb, $JournalEventsTable> {
  $$JournalEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get agentId =>
      $composableBuilder(column: $table.agentId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);
}

class $$JournalEventsTableTableManager
    extends
        RootTableManager<
          _$AgoraDb,
          $JournalEventsTable,
          JournalEvent,
          $$JournalEventsTableFilterComposer,
          $$JournalEventsTableOrderingComposer,
          $$JournalEventsTableAnnotationComposer,
          $$JournalEventsTableCreateCompanionBuilder,
          $$JournalEventsTableUpdateCompanionBuilder,
          (
            JournalEvent,
            BaseReferences<_$AgoraDb, $JournalEventsTable, JournalEvent>,
          ),
          JournalEvent,
          PrefetchHooks Function()
        > {
  $$JournalEventsTableTableManager(_$AgoraDb db, $JournalEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JournalEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JournalEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JournalEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> agentId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JournalEventsCompanion(
                id: id,
                sessionId: sessionId,
                kind: kind,
                agentId: agentId,
                payload: payload,
                at: at,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required String kind,
                Value<String?> agentId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                required DateTime at,
                Value<int> rowid = const Value.absent(),
              }) => JournalEventsCompanion.insert(
                id: id,
                sessionId: sessionId,
                kind: kind,
                agentId: agentId,
                payload: payload,
                at: at,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$JournalEventsTable, JournalEvent>(table),
                  BaseReferences<_$AgoraDb, $JournalEventsTable, JournalEvent>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$JournalEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AgoraDb,
      $JournalEventsTable,
      JournalEvent,
      $$JournalEventsTableFilterComposer,
      $$JournalEventsTableOrderingComposer,
      $$JournalEventsTableAnnotationComposer,
      $$JournalEventsTableCreateCompanionBuilder,
      $$JournalEventsTableUpdateCompanionBuilder,
      (
        JournalEvent,
        BaseReferences<_$AgoraDb, $JournalEventsTable, JournalEvent>,
      ),
      JournalEvent,
      PrefetchHooks Function()
    >;
typedef $$AdaptersTableCreateCompanionBuilder =
    AdaptersCompanion Function({
      required String id,
      required String provider,
      required String version,
      required String config,
      Value<String> source,
      Value<bool> verified,
      required DateTime installedAt,
      Value<int> rowid,
    });
typedef $$AdaptersTableUpdateCompanionBuilder =
    AdaptersCompanion Function({
      Value<String> id,
      Value<String> provider,
      Value<String> version,
      Value<String> config,
      Value<String> source,
      Value<bool> verified,
      Value<DateTime> installedAt,
      Value<int> rowid,
    });

class $$AdaptersTableFilterComposer
    extends Composer<_$AgoraDb, $AdaptersTable> {
  $$AdaptersTableFilterComposer({
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

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get config => $composableBuilder(
    column: $table.config,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get verified => $composableBuilder(
    column: $table.verified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AdaptersTableOrderingComposer
    extends Composer<_$AgoraDb, $AdaptersTable> {
  $$AdaptersTableOrderingComposer({
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

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get config => $composableBuilder(
    column: $table.config,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get verified => $composableBuilder(
    column: $table.verified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AdaptersTableAnnotationComposer
    extends Composer<_$AgoraDb, $AdaptersTable> {
  $$AdaptersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get config =>
      $composableBuilder(column: $table.config, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<bool> get verified =>
      $composableBuilder(column: $table.verified, builder: (column) => column);

  GeneratedColumn<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => column,
  );
}

class $$AdaptersTableTableManager
    extends
        RootTableManager<
          _$AgoraDb,
          $AdaptersTable,
          Adapter,
          $$AdaptersTableFilterComposer,
          $$AdaptersTableOrderingComposer,
          $$AdaptersTableAnnotationComposer,
          $$AdaptersTableCreateCompanionBuilder,
          $$AdaptersTableUpdateCompanionBuilder,
          (Adapter, BaseReferences<_$AgoraDb, $AdaptersTable, Adapter>),
          Adapter,
          PrefetchHooks Function()
        > {
  $$AdaptersTableTableManager(_$AgoraDb db, $AdaptersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AdaptersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AdaptersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AdaptersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<String> config = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<bool> verified = const Value.absent(),
                Value<DateTime> installedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AdaptersCompanion(
                id: id,
                provider: provider,
                version: version,
                config: config,
                source: source,
                verified: verified,
                installedAt: installedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String provider,
                required String version,
                required String config,
                Value<String> source = const Value.absent(),
                Value<bool> verified = const Value.absent(),
                required DateTime installedAt,
                Value<int> rowid = const Value.absent(),
              }) => AdaptersCompanion.insert(
                id: id,
                provider: provider,
                version: version,
                config: config,
                source: source,
                verified: verified,
                installedAt: installedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AdaptersTable, Adapter>(table),
                  BaseReferences<_$AgoraDb, $AdaptersTable, Adapter>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AdaptersTableProcessedTableManager =
    ProcessedTableManager<
      _$AgoraDb,
      $AdaptersTable,
      Adapter,
      $$AdaptersTableFilterComposer,
      $$AdaptersTableOrderingComposer,
      $$AdaptersTableAnnotationComposer,
      $$AdaptersTableCreateCompanionBuilder,
      $$AdaptersTableUpdateCompanionBuilder,
      (Adapter, BaseReferences<_$AgoraDb, $AdaptersTable, Adapter>),
      Adapter,
      PrefetchHooks Function()
    >;
typedef $$UsageCountersTableCreateCompanionBuilder =
    UsageCountersCompanion Function({
      required String agentKind,
      required String day,
      Value<int> messageCount,
      Value<int> byteCount,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$UsageCountersTableUpdateCompanionBuilder =
    UsageCountersCompanion Function({
      Value<String> agentKind,
      Value<String> day,
      Value<int> messageCount,
      Value<int> byteCount,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$UsageCountersTableFilterComposer
    extends Composer<_$AgoraDb, $UsageCountersTable> {
  $$UsageCountersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get agentKind => $composableBuilder(
    column: $table.agentKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get messageCount => $composableBuilder(
    column: $table.messageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteCount => $composableBuilder(
    column: $table.byteCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsageCountersTableOrderingComposer
    extends Composer<_$AgoraDb, $UsageCountersTable> {
  $$UsageCountersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get agentKind => $composableBuilder(
    column: $table.agentKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get messageCount => $composableBuilder(
    column: $table.messageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteCount => $composableBuilder(
    column: $table.byteCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsageCountersTableAnnotationComposer
    extends Composer<_$AgoraDb, $UsageCountersTable> {
  $$UsageCountersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get agentKind =>
      $composableBuilder(column: $table.agentKind, builder: (column) => column);

  GeneratedColumn<String> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<int> get messageCount => $composableBuilder(
    column: $table.messageCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get byteCount =>
      $composableBuilder(column: $table.byteCount, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UsageCountersTableTableManager
    extends
        RootTableManager<
          _$AgoraDb,
          $UsageCountersTable,
          UsageCounter,
          $$UsageCountersTableFilterComposer,
          $$UsageCountersTableOrderingComposer,
          $$UsageCountersTableAnnotationComposer,
          $$UsageCountersTableCreateCompanionBuilder,
          $$UsageCountersTableUpdateCompanionBuilder,
          (
            UsageCounter,
            BaseReferences<_$AgoraDb, $UsageCountersTable, UsageCounter>,
          ),
          UsageCounter,
          PrefetchHooks Function()
        > {
  $$UsageCountersTableTableManager(_$AgoraDb db, $UsageCountersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsageCountersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsageCountersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsageCountersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> agentKind = const Value.absent(),
                Value<String> day = const Value.absent(),
                Value<int> messageCount = const Value.absent(),
                Value<int> byteCount = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsageCountersCompanion(
                agentKind: agentKind,
                day: day,
                messageCount: messageCount,
                byteCount: byteCount,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String agentKind,
                required String day,
                Value<int> messageCount = const Value.absent(),
                Value<int> byteCount = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => UsageCountersCompanion.insert(
                agentKind: agentKind,
                day: day,
                messageCount: messageCount,
                byteCount: byteCount,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UsageCountersTable, UsageCounter>(table),
                  BaseReferences<_$AgoraDb, $UsageCountersTable, UsageCounter>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsageCountersTableProcessedTableManager =
    ProcessedTableManager<
      _$AgoraDb,
      $UsageCountersTable,
      UsageCounter,
      $$UsageCountersTableFilterComposer,
      $$UsageCountersTableOrderingComposer,
      $$UsageCountersTableAnnotationComposer,
      $$UsageCountersTableCreateCompanionBuilder,
      $$UsageCountersTableUpdateCompanionBuilder,
      (
        UsageCounter,
        BaseReferences<_$AgoraDb, $UsageCountersTable, UsageCounter>,
      ),
      UsageCounter,
      PrefetchHooks Function()
    >;

class $AgoraDbManager {
  final _$AgoraDb _db;
  $AgoraDbManager(this._db);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$AgentsTableTableManager get agents =>
      $$AgentsTableTableManager(_db, _db.agents);
  $$SessionAgentsTableTableManager get sessionAgents =>
      $$SessionAgentsTableTableManager(_db, _db.sessionAgents);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$PacketsTableTableManager get packets =>
      $$PacketsTableTableManager(_db, _db.packets);
  $$AgentFactsTableTableManager get agentFacts =>
      $$AgentFactsTableTableManager(_db, _db.agentFacts);
  $$JournalEventsTableTableManager get journalEvents =>
      $$JournalEventsTableTableManager(_db, _db.journalEvents);
  $$AdaptersTableTableManager get adapters =>
      $$AdaptersTableTableManager(_db, _db.adapters);
  $$UsageCountersTableTableManager get usageCounters =>
      $$UsageCountersTableTableManager(_db, _db.usageCounters);
}
