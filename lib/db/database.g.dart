// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CardsTable extends Cards with TableInfo<$CardsTable, CardRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _kanjiMeta = const VerificationMeta('kanji');
  @override
  late final GeneratedColumn<String> kanji = GeneratedColumn<String>(
    'kanji',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kanaMeta = const VerificationMeta('kana');
  @override
  late final GeneratedColumn<String> kana = GeneratedColumn<String>(
    'kana',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _furiganaMeta = const VerificationMeta(
    'furigana',
  );
  @override
  late final GeneratedColumn<String> furigana = GeneratedColumn<String>(
    'furigana',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _meaningMeta = const VerificationMeta(
    'meaning',
  );
  @override
  late final GeneratedColumn<String> meaning = GeneratedColumn<String>(
    'meaning',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Rarity, int> rarity =
      GeneratedColumn<int>(
        'rarity',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: Constant(Rarity.common.index),
      ).withConverter<Rarity>($CardsTable.$converterrarity);
  static const VerificationMeta _jlptLevelMeta = const VerificationMeta(
    'jlptLevel',
  );
  @override
  late final GeneratedColumn<int> jlptLevel = GeneratedColumn<int>(
    'jlpt_level',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioPathMeta = const VerificationMeta(
    'audioPath',
  );
  @override
  late final GeneratedColumn<String> audioPath = GeneratedColumn<String>(
    'audio_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CardSource, int> source =
      GeneratedColumn<int>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: Constant(CardSource.seed.index),
      ).withConverter<CardSource>($CardsTable.$convertersource);
  static const VerificationMeta _packMeta = const VerificationMeta('pack');
  @override
  late final GeneratedColumn<String> pack = GeneratedColumn<String>(
    'pack',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kanji,
    kana,
    furigana,
    meaning,
    rarity,
    jlptLevel,
    audioPath,
    imagePath,
    source,
    pack,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<CardRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('kanji')) {
      context.handle(
        _kanjiMeta,
        kanji.isAcceptableOrUnknown(data['kanji']!, _kanjiMeta),
      );
    } else if (isInserting) {
      context.missing(_kanjiMeta);
    }
    if (data.containsKey('kana')) {
      context.handle(
        _kanaMeta,
        kana.isAcceptableOrUnknown(data['kana']!, _kanaMeta),
      );
    } else if (isInserting) {
      context.missing(_kanaMeta);
    }
    if (data.containsKey('furigana')) {
      context.handle(
        _furiganaMeta,
        furigana.isAcceptableOrUnknown(data['furigana']!, _furiganaMeta),
      );
    }
    if (data.containsKey('meaning')) {
      context.handle(
        _meaningMeta,
        meaning.isAcceptableOrUnknown(data['meaning']!, _meaningMeta),
      );
    } else if (isInserting) {
      context.missing(_meaningMeta);
    }
    if (data.containsKey('jlpt_level')) {
      context.handle(
        _jlptLevelMeta,
        jlptLevel.isAcceptableOrUnknown(data['jlpt_level']!, _jlptLevelMeta),
      );
    }
    if (data.containsKey('audio_path')) {
      context.handle(
        _audioPathMeta,
        audioPath.isAcceptableOrUnknown(data['audio_path']!, _audioPathMeta),
      );
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    }
    if (data.containsKey('pack')) {
      context.handle(
        _packMeta,
        pack.isAcceptableOrUnknown(data['pack']!, _packMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {kanji, kana},
  ];
  @override
  CardRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kanji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kanji'],
      )!,
      kana: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kana'],
      )!,
      furigana: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}furigana'],
      ),
      meaning: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meaning'],
      )!,
      rarity: $CardsTable.$converterrarity.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}rarity'],
        )!,
      ),
      jlptLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}jlpt_level'],
      ),
      audioPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_path'],
      ),
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      ),
      source: $CardsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}source'],
        )!,
      ),
      pack: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pack'],
      ),
    );
  }

  @override
  $CardsTable createAlias(String alias) {
    return $CardsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<Rarity, int, int> $converterrarity =
      const EnumIndexConverter<Rarity>(Rarity.values);
  static JsonTypeConverter2<CardSource, int, int> $convertersource =
      const EnumIndexConverter<CardSource>(CardSource.values);
}

class CardRow extends DataClass implements Insertable<CardRow> {
  final int id;
  final String kanji;
  final String kana;

  /// Positional furigana, e.g. `食[た]べる`. Optional.
  final String? furigana;

  /// Denormalized short headline used in lists / collection grid /
  /// review-card front. Typically the glosses of the first sense joined
  /// with `; ` (e.g. "to take; to pick up"). Full per-sense data lives
  /// in [CardSenses].
  final String meaning;
  final Rarity rarity;

  /// JLPT level 1..5 (5 = N5 / easiest). Null for cards that don't map
  /// onto the JLPT scale (e.g. user-added words).
  final int? jlptLevel;
  final String? audioPath;
  final String? imagePath;
  final CardSource source;

  /// Name of the themed pack this card belongs to, e.g. `science`. Null
  /// for the general dictionary. Packs are downloaded and applied by
  /// `IunaRepository.applyPack`; the tag both drives the "pack only"
  /// booster filter and gives the stats screen something to chart
  /// progress against.
  final String? pack;
  const CardRow({
    required this.id,
    required this.kanji,
    required this.kana,
    this.furigana,
    required this.meaning,
    required this.rarity,
    this.jlptLevel,
    this.audioPath,
    this.imagePath,
    required this.source,
    this.pack,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['kanji'] = Variable<String>(kanji);
    map['kana'] = Variable<String>(kana);
    if (!nullToAbsent || furigana != null) {
      map['furigana'] = Variable<String>(furigana);
    }
    map['meaning'] = Variable<String>(meaning);
    {
      map['rarity'] = Variable<int>($CardsTable.$converterrarity.toSql(rarity));
    }
    if (!nullToAbsent || jlptLevel != null) {
      map['jlpt_level'] = Variable<int>(jlptLevel);
    }
    if (!nullToAbsent || audioPath != null) {
      map['audio_path'] = Variable<String>(audioPath);
    }
    if (!nullToAbsent || imagePath != null) {
      map['image_path'] = Variable<String>(imagePath);
    }
    {
      map['source'] = Variable<int>($CardsTable.$convertersource.toSql(source));
    }
    if (!nullToAbsent || pack != null) {
      map['pack'] = Variable<String>(pack);
    }
    return map;
  }

  CardsCompanion toCompanion(bool nullToAbsent) {
    return CardsCompanion(
      id: Value(id),
      kanji: Value(kanji),
      kana: Value(kana),
      furigana: furigana == null && nullToAbsent
          ? const Value.absent()
          : Value(furigana),
      meaning: Value(meaning),
      rarity: Value(rarity),
      jlptLevel: jlptLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(jlptLevel),
      audioPath: audioPath == null && nullToAbsent
          ? const Value.absent()
          : Value(audioPath),
      imagePath: imagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(imagePath),
      source: Value(source),
      pack: pack == null && nullToAbsent ? const Value.absent() : Value(pack),
    );
  }

  factory CardRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CardRow(
      id: serializer.fromJson<int>(json['id']),
      kanji: serializer.fromJson<String>(json['kanji']),
      kana: serializer.fromJson<String>(json['kana']),
      furigana: serializer.fromJson<String?>(json['furigana']),
      meaning: serializer.fromJson<String>(json['meaning']),
      rarity: $CardsTable.$converterrarity.fromJson(
        serializer.fromJson<int>(json['rarity']),
      ),
      jlptLevel: serializer.fromJson<int?>(json['jlptLevel']),
      audioPath: serializer.fromJson<String?>(json['audioPath']),
      imagePath: serializer.fromJson<String?>(json['imagePath']),
      source: $CardsTable.$convertersource.fromJson(
        serializer.fromJson<int>(json['source']),
      ),
      pack: serializer.fromJson<String?>(json['pack']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kanji': serializer.toJson<String>(kanji),
      'kana': serializer.toJson<String>(kana),
      'furigana': serializer.toJson<String?>(furigana),
      'meaning': serializer.toJson<String>(meaning),
      'rarity': serializer.toJson<int>(
        $CardsTable.$converterrarity.toJson(rarity),
      ),
      'jlptLevel': serializer.toJson<int?>(jlptLevel),
      'audioPath': serializer.toJson<String?>(audioPath),
      'imagePath': serializer.toJson<String?>(imagePath),
      'source': serializer.toJson<int>(
        $CardsTable.$convertersource.toJson(source),
      ),
      'pack': serializer.toJson<String?>(pack),
    };
  }

  CardRow copyWith({
    int? id,
    String? kanji,
    String? kana,
    Value<String?> furigana = const Value.absent(),
    String? meaning,
    Rarity? rarity,
    Value<int?> jlptLevel = const Value.absent(),
    Value<String?> audioPath = const Value.absent(),
    Value<String?> imagePath = const Value.absent(),
    CardSource? source,
    Value<String?> pack = const Value.absent(),
  }) => CardRow(
    id: id ?? this.id,
    kanji: kanji ?? this.kanji,
    kana: kana ?? this.kana,
    furigana: furigana.present ? furigana.value : this.furigana,
    meaning: meaning ?? this.meaning,
    rarity: rarity ?? this.rarity,
    jlptLevel: jlptLevel.present ? jlptLevel.value : this.jlptLevel,
    audioPath: audioPath.present ? audioPath.value : this.audioPath,
    imagePath: imagePath.present ? imagePath.value : this.imagePath,
    source: source ?? this.source,
    pack: pack.present ? pack.value : this.pack,
  );
  CardRow copyWithCompanion(CardsCompanion data) {
    return CardRow(
      id: data.id.present ? data.id.value : this.id,
      kanji: data.kanji.present ? data.kanji.value : this.kanji,
      kana: data.kana.present ? data.kana.value : this.kana,
      furigana: data.furigana.present ? data.furigana.value : this.furigana,
      meaning: data.meaning.present ? data.meaning.value : this.meaning,
      rarity: data.rarity.present ? data.rarity.value : this.rarity,
      jlptLevel: data.jlptLevel.present ? data.jlptLevel.value : this.jlptLevel,
      audioPath: data.audioPath.present ? data.audioPath.value : this.audioPath,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      source: data.source.present ? data.source.value : this.source,
      pack: data.pack.present ? data.pack.value : this.pack,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CardRow(')
          ..write('id: $id, ')
          ..write('kanji: $kanji, ')
          ..write('kana: $kana, ')
          ..write('furigana: $furigana, ')
          ..write('meaning: $meaning, ')
          ..write('rarity: $rarity, ')
          ..write('jlptLevel: $jlptLevel, ')
          ..write('audioPath: $audioPath, ')
          ..write('imagePath: $imagePath, ')
          ..write('source: $source, ')
          ..write('pack: $pack')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kanji,
    kana,
    furigana,
    meaning,
    rarity,
    jlptLevel,
    audioPath,
    imagePath,
    source,
    pack,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CardRow &&
          other.id == this.id &&
          other.kanji == this.kanji &&
          other.kana == this.kana &&
          other.furigana == this.furigana &&
          other.meaning == this.meaning &&
          other.rarity == this.rarity &&
          other.jlptLevel == this.jlptLevel &&
          other.audioPath == this.audioPath &&
          other.imagePath == this.imagePath &&
          other.source == this.source &&
          other.pack == this.pack);
}

class CardsCompanion extends UpdateCompanion<CardRow> {
  final Value<int> id;
  final Value<String> kanji;
  final Value<String> kana;
  final Value<String?> furigana;
  final Value<String> meaning;
  final Value<Rarity> rarity;
  final Value<int?> jlptLevel;
  final Value<String?> audioPath;
  final Value<String?> imagePath;
  final Value<CardSource> source;
  final Value<String?> pack;
  const CardsCompanion({
    this.id = const Value.absent(),
    this.kanji = const Value.absent(),
    this.kana = const Value.absent(),
    this.furigana = const Value.absent(),
    this.meaning = const Value.absent(),
    this.rarity = const Value.absent(),
    this.jlptLevel = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.source = const Value.absent(),
    this.pack = const Value.absent(),
  });
  CardsCompanion.insert({
    this.id = const Value.absent(),
    required String kanji,
    required String kana,
    this.furigana = const Value.absent(),
    required String meaning,
    this.rarity = const Value.absent(),
    this.jlptLevel = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.source = const Value.absent(),
    this.pack = const Value.absent(),
  }) : kanji = Value(kanji),
       kana = Value(kana),
       meaning = Value(meaning);
  static Insertable<CardRow> custom({
    Expression<int>? id,
    Expression<String>? kanji,
    Expression<String>? kana,
    Expression<String>? furigana,
    Expression<String>? meaning,
    Expression<int>? rarity,
    Expression<int>? jlptLevel,
    Expression<String>? audioPath,
    Expression<String>? imagePath,
    Expression<int>? source,
    Expression<String>? pack,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kanji != null) 'kanji': kanji,
      if (kana != null) 'kana': kana,
      if (furigana != null) 'furigana': furigana,
      if (meaning != null) 'meaning': meaning,
      if (rarity != null) 'rarity': rarity,
      if (jlptLevel != null) 'jlpt_level': jlptLevel,
      if (audioPath != null) 'audio_path': audioPath,
      if (imagePath != null) 'image_path': imagePath,
      if (source != null) 'source': source,
      if (pack != null) 'pack': pack,
    });
  }

  CardsCompanion copyWith({
    Value<int>? id,
    Value<String>? kanji,
    Value<String>? kana,
    Value<String?>? furigana,
    Value<String>? meaning,
    Value<Rarity>? rarity,
    Value<int?>? jlptLevel,
    Value<String?>? audioPath,
    Value<String?>? imagePath,
    Value<CardSource>? source,
    Value<String?>? pack,
  }) {
    return CardsCompanion(
      id: id ?? this.id,
      kanji: kanji ?? this.kanji,
      kana: kana ?? this.kana,
      furigana: furigana ?? this.furigana,
      meaning: meaning ?? this.meaning,
      rarity: rarity ?? this.rarity,
      jlptLevel: jlptLevel ?? this.jlptLevel,
      audioPath: audioPath ?? this.audioPath,
      imagePath: imagePath ?? this.imagePath,
      source: source ?? this.source,
      pack: pack ?? this.pack,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kanji.present) {
      map['kanji'] = Variable<String>(kanji.value);
    }
    if (kana.present) {
      map['kana'] = Variable<String>(kana.value);
    }
    if (furigana.present) {
      map['furigana'] = Variable<String>(furigana.value);
    }
    if (meaning.present) {
      map['meaning'] = Variable<String>(meaning.value);
    }
    if (rarity.present) {
      map['rarity'] = Variable<int>(
        $CardsTable.$converterrarity.toSql(rarity.value),
      );
    }
    if (jlptLevel.present) {
      map['jlpt_level'] = Variable<int>(jlptLevel.value);
    }
    if (audioPath.present) {
      map['audio_path'] = Variable<String>(audioPath.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (source.present) {
      map['source'] = Variable<int>(
        $CardsTable.$convertersource.toSql(source.value),
      );
    }
    if (pack.present) {
      map['pack'] = Variable<String>(pack.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardsCompanion(')
          ..write('id: $id, ')
          ..write('kanji: $kanji, ')
          ..write('kana: $kana, ')
          ..write('furigana: $furigana, ')
          ..write('meaning: $meaning, ')
          ..write('rarity: $rarity, ')
          ..write('jlptLevel: $jlptLevel, ')
          ..write('audioPath: $audioPath, ')
          ..write('imagePath: $imagePath, ')
          ..write('source: $source, ')
          ..write('pack: $pack')
          ..write(')'))
        .toString();
  }
}

class $CardSensesTable extends CardSenses
    with TableInfo<$CardSensesTable, CardSenseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardSensesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<int> cardId = GeneratedColumn<int>(
    'card_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cards (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _ordinalMeta = const VerificationMeta(
    'ordinal',
  );
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
    'ordinal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _posMeta = const VerificationMeta('pos');
  @override
  late final GeneratedColumn<String> pos = GeneratedColumn<String>(
    'pos',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _glossMeta = const VerificationMeta('gloss');
  @override
  late final GeneratedColumn<String> gloss = GeneratedColumn<String>(
    'gloss',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _definitionMeta = const VerificationMeta(
    'definition',
  );
  @override
  late final GeneratedColumn<String> definition = GeneratedColumn<String>(
    'definition',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cardId,
    ordinal,
    pos,
    gloss,
    definition,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'card_senses';
  @override
  VerificationContext validateIntegrity(
    Insertable<CardSenseRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('card_id')) {
      context.handle(
        _cardIdMeta,
        cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cardIdMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(
        _ordinalMeta,
        ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta),
      );
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    if (data.containsKey('pos')) {
      context.handle(
        _posMeta,
        pos.isAcceptableOrUnknown(data['pos']!, _posMeta),
      );
    }
    if (data.containsKey('gloss')) {
      context.handle(
        _glossMeta,
        gloss.isAcceptableOrUnknown(data['gloss']!, _glossMeta),
      );
    } else if (isInserting) {
      context.missing(_glossMeta);
    }
    if (data.containsKey('definition')) {
      context.handle(
        _definitionMeta,
        definition.isAcceptableOrUnknown(data['definition']!, _definitionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {cardId, ordinal},
  ];
  @override
  CardSenseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardSenseRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}card_id'],
      )!,
      ordinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordinal'],
      )!,
      pos: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pos'],
      )!,
      gloss: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gloss'],
      )!,
      definition: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}definition'],
      )!,
    );
  }

  @override
  $CardSensesTable createAlias(String alias) {
    return $CardSensesTable(attachedDatabase, alias);
  }
}

class CardSenseRow extends DataClass implements Insertable<CardSenseRow> {
  final int id;
  final int cardId;

  /// 1-based position of this sense within the dictionary entry.
  final int ordinal;

  /// POS / grammar tags for this sense, comma-separated (e.g. "v5r,vt").
  final String pos;

  /// English glosses for this sense, comma-separated
  /// (e.g. "to take, to pick up, to grab"). At least one is required.
  final String gloss;

  /// Optional longer prose explanation for this sense.
  final String definition;
  const CardSenseRow({
    required this.id,
    required this.cardId,
    required this.ordinal,
    required this.pos,
    required this.gloss,
    required this.definition,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['card_id'] = Variable<int>(cardId);
    map['ordinal'] = Variable<int>(ordinal);
    map['pos'] = Variable<String>(pos);
    map['gloss'] = Variable<String>(gloss);
    map['definition'] = Variable<String>(definition);
    return map;
  }

  CardSensesCompanion toCompanion(bool nullToAbsent) {
    return CardSensesCompanion(
      id: Value(id),
      cardId: Value(cardId),
      ordinal: Value(ordinal),
      pos: Value(pos),
      gloss: Value(gloss),
      definition: Value(definition),
    );
  }

  factory CardSenseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CardSenseRow(
      id: serializer.fromJson<int>(json['id']),
      cardId: serializer.fromJson<int>(json['cardId']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
      pos: serializer.fromJson<String>(json['pos']),
      gloss: serializer.fromJson<String>(json['gloss']),
      definition: serializer.fromJson<String>(json['definition']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'cardId': serializer.toJson<int>(cardId),
      'ordinal': serializer.toJson<int>(ordinal),
      'pos': serializer.toJson<String>(pos),
      'gloss': serializer.toJson<String>(gloss),
      'definition': serializer.toJson<String>(definition),
    };
  }

  CardSenseRow copyWith({
    int? id,
    int? cardId,
    int? ordinal,
    String? pos,
    String? gloss,
    String? definition,
  }) => CardSenseRow(
    id: id ?? this.id,
    cardId: cardId ?? this.cardId,
    ordinal: ordinal ?? this.ordinal,
    pos: pos ?? this.pos,
    gloss: gloss ?? this.gloss,
    definition: definition ?? this.definition,
  );
  CardSenseRow copyWithCompanion(CardSensesCompanion data) {
    return CardSenseRow(
      id: data.id.present ? data.id.value : this.id,
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
      pos: data.pos.present ? data.pos.value : this.pos,
      gloss: data.gloss.present ? data.gloss.value : this.gloss,
      definition: data.definition.present
          ? data.definition.value
          : this.definition,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CardSenseRow(')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('ordinal: $ordinal, ')
          ..write('pos: $pos, ')
          ..write('gloss: $gloss, ')
          ..write('definition: $definition')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, cardId, ordinal, pos, gloss, definition);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CardSenseRow &&
          other.id == this.id &&
          other.cardId == this.cardId &&
          other.ordinal == this.ordinal &&
          other.pos == this.pos &&
          other.gloss == this.gloss &&
          other.definition == this.definition);
}

class CardSensesCompanion extends UpdateCompanion<CardSenseRow> {
  final Value<int> id;
  final Value<int> cardId;
  final Value<int> ordinal;
  final Value<String> pos;
  final Value<String> gloss;
  final Value<String> definition;
  const CardSensesCompanion({
    this.id = const Value.absent(),
    this.cardId = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.pos = const Value.absent(),
    this.gloss = const Value.absent(),
    this.definition = const Value.absent(),
  });
  CardSensesCompanion.insert({
    this.id = const Value.absent(),
    required int cardId,
    required int ordinal,
    this.pos = const Value.absent(),
    required String gloss,
    this.definition = const Value.absent(),
  }) : cardId = Value(cardId),
       ordinal = Value(ordinal),
       gloss = Value(gloss);
  static Insertable<CardSenseRow> custom({
    Expression<int>? id,
    Expression<int>? cardId,
    Expression<int>? ordinal,
    Expression<String>? pos,
    Expression<String>? gloss,
    Expression<String>? definition,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cardId != null) 'card_id': cardId,
      if (ordinal != null) 'ordinal': ordinal,
      if (pos != null) 'pos': pos,
      if (gloss != null) 'gloss': gloss,
      if (definition != null) 'definition': definition,
    });
  }

  CardSensesCompanion copyWith({
    Value<int>? id,
    Value<int>? cardId,
    Value<int>? ordinal,
    Value<String>? pos,
    Value<String>? gloss,
    Value<String>? definition,
  }) {
    return CardSensesCompanion(
      id: id ?? this.id,
      cardId: cardId ?? this.cardId,
      ordinal: ordinal ?? this.ordinal,
      pos: pos ?? this.pos,
      gloss: gloss ?? this.gloss,
      definition: definition ?? this.definition,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (cardId.present) {
      map['card_id'] = Variable<int>(cardId.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (pos.present) {
      map['pos'] = Variable<String>(pos.value);
    }
    if (gloss.present) {
      map['gloss'] = Variable<String>(gloss.value);
    }
    if (definition.present) {
      map['definition'] = Variable<String>(definition.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardSensesCompanion(')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('ordinal: $ordinal, ')
          ..write('pos: $pos, ')
          ..write('gloss: $gloss, ')
          ..write('definition: $definition')
          ..write(')'))
        .toString();
  }
}

class $ExamplesTable extends Examples
    with TableInfo<$ExamplesTable, ExampleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExamplesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sentenceMeta = const VerificationMeta(
    'sentence',
  );
  @override
  late final GeneratedColumn<String> sentence = GeneratedColumn<String>(
    'sentence',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceTitleMeta = const VerificationMeta(
    'sourceTitle',
  );
  @override
  late final GeneratedColumn<String> sourceTitle = GeneratedColumn<String>(
    'source_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, sentence, sourceTitle];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'examples';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExampleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('sentence')) {
      context.handle(
        _sentenceMeta,
        sentence.isAcceptableOrUnknown(data['sentence']!, _sentenceMeta),
      );
    } else if (isInserting) {
      context.missing(_sentenceMeta);
    }
    if (data.containsKey('source_title')) {
      context.handle(
        _sourceTitleMeta,
        sourceTitle.isAcceptableOrUnknown(
          data['source_title']!,
          _sourceTitleMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExampleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExampleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sentence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sentence'],
      )!,
      sourceTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_title'],
      ),
    );
  }

  @override
  $ExamplesTable createAlias(String alias) {
    return $ExamplesTable(attachedDatabase, alias);
  }
}

class ExampleRow extends DataClass implements Insertable<ExampleRow> {
  final int id;
  final String sentence;
  final String? sourceTitle;
  const ExampleRow({
    required this.id,
    required this.sentence,
    this.sourceTitle,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['sentence'] = Variable<String>(sentence);
    if (!nullToAbsent || sourceTitle != null) {
      map['source_title'] = Variable<String>(sourceTitle);
    }
    return map;
  }

  ExamplesCompanion toCompanion(bool nullToAbsent) {
    return ExamplesCompanion(
      id: Value(id),
      sentence: Value(sentence),
      sourceTitle: sourceTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceTitle),
    );
  }

  factory ExampleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExampleRow(
      id: serializer.fromJson<int>(json['id']),
      sentence: serializer.fromJson<String>(json['sentence']),
      sourceTitle: serializer.fromJson<String?>(json['sourceTitle']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sentence': serializer.toJson<String>(sentence),
      'sourceTitle': serializer.toJson<String?>(sourceTitle),
    };
  }

  ExampleRow copyWith({
    int? id,
    String? sentence,
    Value<String?> sourceTitle = const Value.absent(),
  }) => ExampleRow(
    id: id ?? this.id,
    sentence: sentence ?? this.sentence,
    sourceTitle: sourceTitle.present ? sourceTitle.value : this.sourceTitle,
  );
  ExampleRow copyWithCompanion(ExamplesCompanion data) {
    return ExampleRow(
      id: data.id.present ? data.id.value : this.id,
      sentence: data.sentence.present ? data.sentence.value : this.sentence,
      sourceTitle: data.sourceTitle.present
          ? data.sourceTitle.value
          : this.sourceTitle,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExampleRow(')
          ..write('id: $id, ')
          ..write('sentence: $sentence, ')
          ..write('sourceTitle: $sourceTitle')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sentence, sourceTitle);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExampleRow &&
          other.id == this.id &&
          other.sentence == this.sentence &&
          other.sourceTitle == this.sourceTitle);
}

class ExamplesCompanion extends UpdateCompanion<ExampleRow> {
  final Value<int> id;
  final Value<String> sentence;
  final Value<String?> sourceTitle;
  const ExamplesCompanion({
    this.id = const Value.absent(),
    this.sentence = const Value.absent(),
    this.sourceTitle = const Value.absent(),
  });
  ExamplesCompanion.insert({
    this.id = const Value.absent(),
    required String sentence,
    this.sourceTitle = const Value.absent(),
  }) : sentence = Value(sentence);
  static Insertable<ExampleRow> custom({
    Expression<int>? id,
    Expression<String>? sentence,
    Expression<String>? sourceTitle,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sentence != null) 'sentence': sentence,
      if (sourceTitle != null) 'source_title': sourceTitle,
    });
  }

  ExamplesCompanion copyWith({
    Value<int>? id,
    Value<String>? sentence,
    Value<String?>? sourceTitle,
  }) {
    return ExamplesCompanion(
      id: id ?? this.id,
      sentence: sentence ?? this.sentence,
      sourceTitle: sourceTitle ?? this.sourceTitle,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sentence.present) {
      map['sentence'] = Variable<String>(sentence.value);
    }
    if (sourceTitle.present) {
      map['source_title'] = Variable<String>(sourceTitle.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExamplesCompanion(')
          ..write('id: $id, ')
          ..write('sentence: $sentence, ')
          ..write('sourceTitle: $sourceTitle')
          ..write(')'))
        .toString();
  }
}

class $CardExamplesTable extends CardExamples
    with TableInfo<$CardExamplesTable, CardExampleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardExamplesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<int> cardId = GeneratedColumn<int>(
    'card_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cards (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _exampleIdMeta = const VerificationMeta(
    'exampleId',
  );
  @override
  late final GeneratedColumn<int> exampleId = GeneratedColumn<int>(
    'example_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES examples (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [cardId, exampleId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'card_examples';
  @override
  VerificationContext validateIntegrity(
    Insertable<CardExampleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('card_id')) {
      context.handle(
        _cardIdMeta,
        cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cardIdMeta);
    }
    if (data.containsKey('example_id')) {
      context.handle(
        _exampleIdMeta,
        exampleId.isAcceptableOrUnknown(data['example_id']!, _exampleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exampleIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cardId, exampleId};
  @override
  CardExampleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardExampleRow(
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}card_id'],
      )!,
      exampleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}example_id'],
      )!,
    );
  }

  @override
  $CardExamplesTable createAlias(String alias) {
    return $CardExamplesTable(attachedDatabase, alias);
  }
}

class CardExampleRow extends DataClass implements Insertable<CardExampleRow> {
  final int cardId;
  final int exampleId;
  const CardExampleRow({required this.cardId, required this.exampleId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['card_id'] = Variable<int>(cardId);
    map['example_id'] = Variable<int>(exampleId);
    return map;
  }

  CardExamplesCompanion toCompanion(bool nullToAbsent) {
    return CardExamplesCompanion(
      cardId: Value(cardId),
      exampleId: Value(exampleId),
    );
  }

  factory CardExampleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CardExampleRow(
      cardId: serializer.fromJson<int>(json['cardId']),
      exampleId: serializer.fromJson<int>(json['exampleId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cardId': serializer.toJson<int>(cardId),
      'exampleId': serializer.toJson<int>(exampleId),
    };
  }

  CardExampleRow copyWith({int? cardId, int? exampleId}) => CardExampleRow(
    cardId: cardId ?? this.cardId,
    exampleId: exampleId ?? this.exampleId,
  );
  CardExampleRow copyWithCompanion(CardExamplesCompanion data) {
    return CardExampleRow(
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      exampleId: data.exampleId.present ? data.exampleId.value : this.exampleId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CardExampleRow(')
          ..write('cardId: $cardId, ')
          ..write('exampleId: $exampleId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cardId, exampleId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CardExampleRow &&
          other.cardId == this.cardId &&
          other.exampleId == this.exampleId);
}

class CardExamplesCompanion extends UpdateCompanion<CardExampleRow> {
  final Value<int> cardId;
  final Value<int> exampleId;
  final Value<int> rowid;
  const CardExamplesCompanion({
    this.cardId = const Value.absent(),
    this.exampleId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CardExamplesCompanion.insert({
    required int cardId,
    required int exampleId,
    this.rowid = const Value.absent(),
  }) : cardId = Value(cardId),
       exampleId = Value(exampleId);
  static Insertable<CardExampleRow> custom({
    Expression<int>? cardId,
    Expression<int>? exampleId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cardId != null) 'card_id': cardId,
      if (exampleId != null) 'example_id': exampleId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CardExamplesCompanion copyWith({
    Value<int>? cardId,
    Value<int>? exampleId,
    Value<int>? rowid,
  }) {
    return CardExamplesCompanion(
      cardId: cardId ?? this.cardId,
      exampleId: exampleId ?? this.exampleId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cardId.present) {
      map['card_id'] = Variable<int>(cardId.value);
    }
    if (exampleId.present) {
      map['example_id'] = Variable<int>(exampleId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardExamplesCompanion(')
          ..write('cardId: $cardId, ')
          ..write('exampleId: $exampleId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserCardsTable extends UserCards
    with TableInfo<$UserCardsTable, UserCardRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserCardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<int> cardId = GeneratedColumn<int>(
    'card_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cards (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<int> level = GeneratedColumn<int>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _easeMeta = const VerificationMeta('ease');
  @override
  late final GeneratedColumn<double> ease = GeneratedColumn<double>(
    'ease',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(2.0),
  );
  static const VerificationMeta _intervalMinutesMeta = const VerificationMeta(
    'intervalMinutes',
  );
  @override
  late final GeneratedColumn<int> intervalMinutes = GeneratedColumn<int>(
    'interval_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastReviewedMeta = const VerificationMeta(
    'lastReviewed',
  );
  @override
  late final GeneratedColumn<DateTime> lastReviewed = GeneratedColumn<DateTime>(
    'last_reviewed',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextDueMeta = const VerificationMeta(
    'nextDue',
  );
  @override
  late final GeneratedColumn<DateTime> nextDue = GeneratedColumn<DateTime>(
    'next_due',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _obtainedAtMeta = const VerificationMeta(
    'obtainedAt',
  );
  @override
  late final GeneratedColumn<DateTime> obtainedAt = GeneratedColumn<DateTime>(
    'obtained_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isNewMeta = const VerificationMeta('isNew');
  @override
  late final GeneratedColumn<bool> isNew = GeneratedColumn<bool>(
    'is_new',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_new" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _failCountMeta = const VerificationMeta(
    'failCount',
  );
  @override
  late final GeneratedColumn<int> failCount = GeneratedColumn<int>(
    'fail_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _suspendedMeta = const VerificationMeta(
    'suspended',
  );
  @override
  late final GeneratedColumn<bool> suspended = GeneratedColumn<bool>(
    'suspended',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("suspended" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    cardId,
    level,
    ease,
    intervalMinutes,
    lastReviewed,
    nextDue,
    obtainedAt,
    isNew,
    failCount,
    suspended,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserCardRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('card_id')) {
      context.handle(
        _cardIdMeta,
        cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta),
      );
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    }
    if (data.containsKey('ease')) {
      context.handle(
        _easeMeta,
        ease.isAcceptableOrUnknown(data['ease']!, _easeMeta),
      );
    }
    if (data.containsKey('interval_minutes')) {
      context.handle(
        _intervalMinutesMeta,
        intervalMinutes.isAcceptableOrUnknown(
          data['interval_minutes']!,
          _intervalMinutesMeta,
        ),
      );
    }
    if (data.containsKey('last_reviewed')) {
      context.handle(
        _lastReviewedMeta,
        lastReviewed.isAcceptableOrUnknown(
          data['last_reviewed']!,
          _lastReviewedMeta,
        ),
      );
    }
    if (data.containsKey('next_due')) {
      context.handle(
        _nextDueMeta,
        nextDue.isAcceptableOrUnknown(data['next_due']!, _nextDueMeta),
      );
    } else if (isInserting) {
      context.missing(_nextDueMeta);
    }
    if (data.containsKey('obtained_at')) {
      context.handle(
        _obtainedAtMeta,
        obtainedAt.isAcceptableOrUnknown(data['obtained_at']!, _obtainedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_obtainedAtMeta);
    }
    if (data.containsKey('is_new')) {
      context.handle(
        _isNewMeta,
        isNew.isAcceptableOrUnknown(data['is_new']!, _isNewMeta),
      );
    }
    if (data.containsKey('fail_count')) {
      context.handle(
        _failCountMeta,
        failCount.isAcceptableOrUnknown(data['fail_count']!, _failCountMeta),
      );
    }
    if (data.containsKey('suspended')) {
      context.handle(
        _suspendedMeta,
        suspended.isAcceptableOrUnknown(data['suspended']!, _suspendedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cardId};
  @override
  UserCardRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserCardRow(
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}card_id'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}level'],
      )!,
      ease: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ease'],
      )!,
      intervalMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval_minutes'],
      )!,
      lastReviewed: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_reviewed'],
      ),
      nextDue: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_due'],
      )!,
      obtainedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}obtained_at'],
      )!,
      isNew: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_new'],
      )!,
      failCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fail_count'],
      )!,
      suspended: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}suspended'],
      )!,
    );
  }

  @override
  $UserCardsTable createAlias(String alias) {
    return $UserCardsTable(attachedDatabase, alias);
  }
}

class UserCardRow extends DataClass implements Insertable<UserCardRow> {
  final int cardId;
  final int level;
  final double ease;

  /// Current scheduling interval in minutes.
  final int intervalMinutes;
  final DateTime? lastReviewed;
  final DateTime nextDue;
  final DateTime obtainedAt;

  /// True until the card has been reviewed for the first time. Used by the
  /// review flow to trigger the booster-reveal animation.
  final bool isNew;

  /// Lifetime count of wrong answers. Powers the "leeches" stat list.
  final int failCount;

  /// Cards the user has shelved. They stay in the collection and keep
  /// their scheduling state frozen, but never appear in the review
  /// queue. Toggled from review (info sheet), card detail, or the
  /// booster reveal — and reversed via the same surfaces.
  final bool suspended;
  const UserCardRow({
    required this.cardId,
    required this.level,
    required this.ease,
    required this.intervalMinutes,
    this.lastReviewed,
    required this.nextDue,
    required this.obtainedAt,
    required this.isNew,
    required this.failCount,
    required this.suspended,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['card_id'] = Variable<int>(cardId);
    map['level'] = Variable<int>(level);
    map['ease'] = Variable<double>(ease);
    map['interval_minutes'] = Variable<int>(intervalMinutes);
    if (!nullToAbsent || lastReviewed != null) {
      map['last_reviewed'] = Variable<DateTime>(lastReviewed);
    }
    map['next_due'] = Variable<DateTime>(nextDue);
    map['obtained_at'] = Variable<DateTime>(obtainedAt);
    map['is_new'] = Variable<bool>(isNew);
    map['fail_count'] = Variable<int>(failCount);
    map['suspended'] = Variable<bool>(suspended);
    return map;
  }

  UserCardsCompanion toCompanion(bool nullToAbsent) {
    return UserCardsCompanion(
      cardId: Value(cardId),
      level: Value(level),
      ease: Value(ease),
      intervalMinutes: Value(intervalMinutes),
      lastReviewed: lastReviewed == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReviewed),
      nextDue: Value(nextDue),
      obtainedAt: Value(obtainedAt),
      isNew: Value(isNew),
      failCount: Value(failCount),
      suspended: Value(suspended),
    );
  }

  factory UserCardRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserCardRow(
      cardId: serializer.fromJson<int>(json['cardId']),
      level: serializer.fromJson<int>(json['level']),
      ease: serializer.fromJson<double>(json['ease']),
      intervalMinutes: serializer.fromJson<int>(json['intervalMinutes']),
      lastReviewed: serializer.fromJson<DateTime?>(json['lastReviewed']),
      nextDue: serializer.fromJson<DateTime>(json['nextDue']),
      obtainedAt: serializer.fromJson<DateTime>(json['obtainedAt']),
      isNew: serializer.fromJson<bool>(json['isNew']),
      failCount: serializer.fromJson<int>(json['failCount']),
      suspended: serializer.fromJson<bool>(json['suspended']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cardId': serializer.toJson<int>(cardId),
      'level': serializer.toJson<int>(level),
      'ease': serializer.toJson<double>(ease),
      'intervalMinutes': serializer.toJson<int>(intervalMinutes),
      'lastReviewed': serializer.toJson<DateTime?>(lastReviewed),
      'nextDue': serializer.toJson<DateTime>(nextDue),
      'obtainedAt': serializer.toJson<DateTime>(obtainedAt),
      'isNew': serializer.toJson<bool>(isNew),
      'failCount': serializer.toJson<int>(failCount),
      'suspended': serializer.toJson<bool>(suspended),
    };
  }

  UserCardRow copyWith({
    int? cardId,
    int? level,
    double? ease,
    int? intervalMinutes,
    Value<DateTime?> lastReviewed = const Value.absent(),
    DateTime? nextDue,
    DateTime? obtainedAt,
    bool? isNew,
    int? failCount,
    bool? suspended,
  }) => UserCardRow(
    cardId: cardId ?? this.cardId,
    level: level ?? this.level,
    ease: ease ?? this.ease,
    intervalMinutes: intervalMinutes ?? this.intervalMinutes,
    lastReviewed: lastReviewed.present ? lastReviewed.value : this.lastReviewed,
    nextDue: nextDue ?? this.nextDue,
    obtainedAt: obtainedAt ?? this.obtainedAt,
    isNew: isNew ?? this.isNew,
    failCount: failCount ?? this.failCount,
    suspended: suspended ?? this.suspended,
  );
  UserCardRow copyWithCompanion(UserCardsCompanion data) {
    return UserCardRow(
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      level: data.level.present ? data.level.value : this.level,
      ease: data.ease.present ? data.ease.value : this.ease,
      intervalMinutes: data.intervalMinutes.present
          ? data.intervalMinutes.value
          : this.intervalMinutes,
      lastReviewed: data.lastReviewed.present
          ? data.lastReviewed.value
          : this.lastReviewed,
      nextDue: data.nextDue.present ? data.nextDue.value : this.nextDue,
      obtainedAt: data.obtainedAt.present
          ? data.obtainedAt.value
          : this.obtainedAt,
      isNew: data.isNew.present ? data.isNew.value : this.isNew,
      failCount: data.failCount.present ? data.failCount.value : this.failCount,
      suspended: data.suspended.present ? data.suspended.value : this.suspended,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserCardRow(')
          ..write('cardId: $cardId, ')
          ..write('level: $level, ')
          ..write('ease: $ease, ')
          ..write('intervalMinutes: $intervalMinutes, ')
          ..write('lastReviewed: $lastReviewed, ')
          ..write('nextDue: $nextDue, ')
          ..write('obtainedAt: $obtainedAt, ')
          ..write('isNew: $isNew, ')
          ..write('failCount: $failCount, ')
          ..write('suspended: $suspended')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    cardId,
    level,
    ease,
    intervalMinutes,
    lastReviewed,
    nextDue,
    obtainedAt,
    isNew,
    failCount,
    suspended,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserCardRow &&
          other.cardId == this.cardId &&
          other.level == this.level &&
          other.ease == this.ease &&
          other.intervalMinutes == this.intervalMinutes &&
          other.lastReviewed == this.lastReviewed &&
          other.nextDue == this.nextDue &&
          other.obtainedAt == this.obtainedAt &&
          other.isNew == this.isNew &&
          other.failCount == this.failCount &&
          other.suspended == this.suspended);
}

class UserCardsCompanion extends UpdateCompanion<UserCardRow> {
  final Value<int> cardId;
  final Value<int> level;
  final Value<double> ease;
  final Value<int> intervalMinutes;
  final Value<DateTime?> lastReviewed;
  final Value<DateTime> nextDue;
  final Value<DateTime> obtainedAt;
  final Value<bool> isNew;
  final Value<int> failCount;
  final Value<bool> suspended;
  const UserCardsCompanion({
    this.cardId = const Value.absent(),
    this.level = const Value.absent(),
    this.ease = const Value.absent(),
    this.intervalMinutes = const Value.absent(),
    this.lastReviewed = const Value.absent(),
    this.nextDue = const Value.absent(),
    this.obtainedAt = const Value.absent(),
    this.isNew = const Value.absent(),
    this.failCount = const Value.absent(),
    this.suspended = const Value.absent(),
  });
  UserCardsCompanion.insert({
    this.cardId = const Value.absent(),
    this.level = const Value.absent(),
    this.ease = const Value.absent(),
    this.intervalMinutes = const Value.absent(),
    this.lastReviewed = const Value.absent(),
    required DateTime nextDue,
    required DateTime obtainedAt,
    this.isNew = const Value.absent(),
    this.failCount = const Value.absent(),
    this.suspended = const Value.absent(),
  }) : nextDue = Value(nextDue),
       obtainedAt = Value(obtainedAt);
  static Insertable<UserCardRow> custom({
    Expression<int>? cardId,
    Expression<int>? level,
    Expression<double>? ease,
    Expression<int>? intervalMinutes,
    Expression<DateTime>? lastReviewed,
    Expression<DateTime>? nextDue,
    Expression<DateTime>? obtainedAt,
    Expression<bool>? isNew,
    Expression<int>? failCount,
    Expression<bool>? suspended,
  }) {
    return RawValuesInsertable({
      if (cardId != null) 'card_id': cardId,
      if (level != null) 'level': level,
      if (ease != null) 'ease': ease,
      if (intervalMinutes != null) 'interval_minutes': intervalMinutes,
      if (lastReviewed != null) 'last_reviewed': lastReviewed,
      if (nextDue != null) 'next_due': nextDue,
      if (obtainedAt != null) 'obtained_at': obtainedAt,
      if (isNew != null) 'is_new': isNew,
      if (failCount != null) 'fail_count': failCount,
      if (suspended != null) 'suspended': suspended,
    });
  }

  UserCardsCompanion copyWith({
    Value<int>? cardId,
    Value<int>? level,
    Value<double>? ease,
    Value<int>? intervalMinutes,
    Value<DateTime?>? lastReviewed,
    Value<DateTime>? nextDue,
    Value<DateTime>? obtainedAt,
    Value<bool>? isNew,
    Value<int>? failCount,
    Value<bool>? suspended,
  }) {
    return UserCardsCompanion(
      cardId: cardId ?? this.cardId,
      level: level ?? this.level,
      ease: ease ?? this.ease,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      lastReviewed: lastReviewed ?? this.lastReviewed,
      nextDue: nextDue ?? this.nextDue,
      obtainedAt: obtainedAt ?? this.obtainedAt,
      isNew: isNew ?? this.isNew,
      failCount: failCount ?? this.failCount,
      suspended: suspended ?? this.suspended,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cardId.present) {
      map['card_id'] = Variable<int>(cardId.value);
    }
    if (level.present) {
      map['level'] = Variable<int>(level.value);
    }
    if (ease.present) {
      map['ease'] = Variable<double>(ease.value);
    }
    if (intervalMinutes.present) {
      map['interval_minutes'] = Variable<int>(intervalMinutes.value);
    }
    if (lastReviewed.present) {
      map['last_reviewed'] = Variable<DateTime>(lastReviewed.value);
    }
    if (nextDue.present) {
      map['next_due'] = Variable<DateTime>(nextDue.value);
    }
    if (obtainedAt.present) {
      map['obtained_at'] = Variable<DateTime>(obtainedAt.value);
    }
    if (isNew.present) {
      map['is_new'] = Variable<bool>(isNew.value);
    }
    if (failCount.present) {
      map['fail_count'] = Variable<int>(failCount.value);
    }
    if (suspended.present) {
      map['suspended'] = Variable<bool>(suspended.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserCardsCompanion(')
          ..write('cardId: $cardId, ')
          ..write('level: $level, ')
          ..write('ease: $ease, ')
          ..write('intervalMinutes: $intervalMinutes, ')
          ..write('lastReviewed: $lastReviewed, ')
          ..write('nextDue: $nextDue, ')
          ..write('obtainedAt: $obtainedAt, ')
          ..write('isNew: $isNew, ')
          ..write('failCount: $failCount, ')
          ..write('suspended: $suspended')
          ..write(')'))
        .toString();
  }
}

class $MetaTable extends Meta with TableInfo<$MetaTable, MetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  MetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $MetaTable createAlias(String alias) {
    return $MetaTable(attachedDatabase, alias);
  }
}

class MetaRow extends DataClass implements Insertable<MetaRow> {
  final String key;
  final String value;
  const MetaRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  MetaCompanion toCompanion(bool nullToAbsent) {
    return MetaCompanion(key: Value(key), value: Value(value));
  }

  factory MetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  MetaRow copyWith({String? key, String? value}) =>
      MetaRow(key: key ?? this.key, value: value ?? this.value);
  MetaRow copyWithCompanion(MetaCompanion data) {
    return MetaRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetaRow && other.key == this.key && other.value == this.value);
}

class MetaCompanion extends UpdateCompanion<MetaRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const MetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<MetaRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return MetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WishlistTable extends Wishlist
    with TableInfo<$WishlistTable, WishlistRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WishlistTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<int> cardId = GeneratedColumn<int>(
    'card_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cards (id) ON DELETE CASCADE',
    ),
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
  List<GeneratedColumn> get $columns => [cardId, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wishlist';
  @override
  VerificationContext validateIntegrity(
    Insertable<WishlistRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('card_id')) {
      context.handle(
        _cardIdMeta,
        cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta),
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
  Set<GeneratedColumn> get $primaryKey => {cardId};
  @override
  WishlistRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WishlistRow(
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}card_id'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $WishlistTable createAlias(String alias) {
    return $WishlistTable(attachedDatabase, alias);
  }
}

class WishlistRow extends DataClass implements Insertable<WishlistRow> {
  final int cardId;
  final DateTime addedAt;
  const WishlistRow({required this.cardId, required this.addedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['card_id'] = Variable<int>(cardId);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  WishlistCompanion toCompanion(bool nullToAbsent) {
    return WishlistCompanion(cardId: Value(cardId), addedAt: Value(addedAt));
  }

  factory WishlistRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WishlistRow(
      cardId: serializer.fromJson<int>(json['cardId']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cardId': serializer.toJson<int>(cardId),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  WishlistRow copyWith({int? cardId, DateTime? addedAt}) => WishlistRow(
    cardId: cardId ?? this.cardId,
    addedAt: addedAt ?? this.addedAt,
  );
  WishlistRow copyWithCompanion(WishlistCompanion data) {
    return WishlistRow(
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WishlistRow(')
          ..write('cardId: $cardId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cardId, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WishlistRow &&
          other.cardId == this.cardId &&
          other.addedAt == this.addedAt);
}

class WishlistCompanion extends UpdateCompanion<WishlistRow> {
  final Value<int> cardId;
  final Value<DateTime> addedAt;
  const WishlistCompanion({
    this.cardId = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  WishlistCompanion.insert({
    this.cardId = const Value.absent(),
    required DateTime addedAt,
  }) : addedAt = Value(addedAt);
  static Insertable<WishlistRow> custom({
    Expression<int>? cardId,
    Expression<DateTime>? addedAt,
  }) {
    return RawValuesInsertable({
      if (cardId != null) 'card_id': cardId,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  WishlistCompanion copyWith({Value<int>? cardId, Value<DateTime>? addedAt}) {
    return WishlistCompanion(
      cardId: cardId ?? this.cardId,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cardId.present) {
      map['card_id'] = Variable<int>(cardId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WishlistCompanion(')
          ..write('cardId: $cardId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

class $DailyStatsTable extends DailyStats
    with TableInfo<$DailyStatsTable, DailyStatRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cTotalMeta = const VerificationMeta('cTotal');
  @override
  late final GeneratedColumn<int> cTotal = GeneratedColumn<int>(
    'c_total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _cCorrectMeta = const VerificationMeta(
    'cCorrect',
  );
  @override
  late final GeneratedColumn<int> cCorrect = GeneratedColumn<int>(
    'c_correct',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _rTotalMeta = const VerificationMeta('rTotal');
  @override
  late final GeneratedColumn<int> rTotal = GeneratedColumn<int>(
    'r_total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _rCorrectMeta = const VerificationMeta(
    'rCorrect',
  );
  @override
  late final GeneratedColumn<int> rCorrect = GeneratedColumn<int>(
    'r_correct',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _srTotalMeta = const VerificationMeta(
    'srTotal',
  );
  @override
  late final GeneratedColumn<int> srTotal = GeneratedColumn<int>(
    'sr_total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _srCorrectMeta = const VerificationMeta(
    'srCorrect',
  );
  @override
  late final GeneratedColumn<int> srCorrect = GeneratedColumn<int>(
    'sr_correct',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _ssrTotalMeta = const VerificationMeta(
    'ssrTotal',
  );
  @override
  late final GeneratedColumn<int> ssrTotal = GeneratedColumn<int>(
    'ssr_total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _ssrCorrectMeta = const VerificationMeta(
    'ssrCorrect',
  );
  @override
  late final GeneratedColumn<int> ssrCorrect = GeneratedColumn<int>(
    'ssr_correct',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _urTotalMeta = const VerificationMeta(
    'urTotal',
  );
  @override
  late final GeneratedColumn<int> urTotal = GeneratedColumn<int>(
    'ur_total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _urCorrectMeta = const VerificationMeta(
    'urCorrect',
  );
  @override
  late final GeneratedColumn<int> urCorrect = GeneratedColumn<int>(
    'ur_correct',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _newCardsMeta = const VerificationMeta(
    'newCards',
  );
  @override
  late final GeneratedColumn<int> newCards = GeneratedColumn<int>(
    'new_cards',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    date,
    cTotal,
    cCorrect,
    rTotal,
    rCorrect,
    srTotal,
    srCorrect,
    ssrTotal,
    ssrCorrect,
    urTotal,
    urCorrect,
    newCards,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_stats';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyStatRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('c_total')) {
      context.handle(
        _cTotalMeta,
        cTotal.isAcceptableOrUnknown(data['c_total']!, _cTotalMeta),
      );
    }
    if (data.containsKey('c_correct')) {
      context.handle(
        _cCorrectMeta,
        cCorrect.isAcceptableOrUnknown(data['c_correct']!, _cCorrectMeta),
      );
    }
    if (data.containsKey('r_total')) {
      context.handle(
        _rTotalMeta,
        rTotal.isAcceptableOrUnknown(data['r_total']!, _rTotalMeta),
      );
    }
    if (data.containsKey('r_correct')) {
      context.handle(
        _rCorrectMeta,
        rCorrect.isAcceptableOrUnknown(data['r_correct']!, _rCorrectMeta),
      );
    }
    if (data.containsKey('sr_total')) {
      context.handle(
        _srTotalMeta,
        srTotal.isAcceptableOrUnknown(data['sr_total']!, _srTotalMeta),
      );
    }
    if (data.containsKey('sr_correct')) {
      context.handle(
        _srCorrectMeta,
        srCorrect.isAcceptableOrUnknown(data['sr_correct']!, _srCorrectMeta),
      );
    }
    if (data.containsKey('ssr_total')) {
      context.handle(
        _ssrTotalMeta,
        ssrTotal.isAcceptableOrUnknown(data['ssr_total']!, _ssrTotalMeta),
      );
    }
    if (data.containsKey('ssr_correct')) {
      context.handle(
        _ssrCorrectMeta,
        ssrCorrect.isAcceptableOrUnknown(data['ssr_correct']!, _ssrCorrectMeta),
      );
    }
    if (data.containsKey('ur_total')) {
      context.handle(
        _urTotalMeta,
        urTotal.isAcceptableOrUnknown(data['ur_total']!, _urTotalMeta),
      );
    }
    if (data.containsKey('ur_correct')) {
      context.handle(
        _urCorrectMeta,
        urCorrect.isAcceptableOrUnknown(data['ur_correct']!, _urCorrectMeta),
      );
    }
    if (data.containsKey('new_cards')) {
      context.handle(
        _newCardsMeta,
        newCards.isAcceptableOrUnknown(data['new_cards']!, _newCardsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date};
  @override
  DailyStatRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyStatRow(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      cTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}c_total'],
      )!,
      cCorrect: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}c_correct'],
      )!,
      rTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}r_total'],
      )!,
      rCorrect: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}r_correct'],
      )!,
      srTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sr_total'],
      )!,
      srCorrect: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sr_correct'],
      )!,
      ssrTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ssr_total'],
      )!,
      ssrCorrect: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ssr_correct'],
      )!,
      urTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ur_total'],
      )!,
      urCorrect: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ur_correct'],
      )!,
      newCards: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}new_cards'],
      )!,
    );
  }

  @override
  $DailyStatsTable createAlias(String alias) {
    return $DailyStatsTable(attachedDatabase, alias);
  }
}

class DailyStatRow extends DataClass implements Insertable<DailyStatRow> {
  final String date;
  final int cTotal;
  final int cCorrect;
  final int rTotal;
  final int rCorrect;
  final int srTotal;
  final int srCorrect;
  final int ssrTotal;
  final int ssrCorrect;
  final int urTotal;
  final int urCorrect;

  /// Cards reviewed for the very first time on this logical day.
  final int newCards;
  const DailyStatRow({
    required this.date,
    required this.cTotal,
    required this.cCorrect,
    required this.rTotal,
    required this.rCorrect,
    required this.srTotal,
    required this.srCorrect,
    required this.ssrTotal,
    required this.ssrCorrect,
    required this.urTotal,
    required this.urCorrect,
    required this.newCards,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<String>(date);
    map['c_total'] = Variable<int>(cTotal);
    map['c_correct'] = Variable<int>(cCorrect);
    map['r_total'] = Variable<int>(rTotal);
    map['r_correct'] = Variable<int>(rCorrect);
    map['sr_total'] = Variable<int>(srTotal);
    map['sr_correct'] = Variable<int>(srCorrect);
    map['ssr_total'] = Variable<int>(ssrTotal);
    map['ssr_correct'] = Variable<int>(ssrCorrect);
    map['ur_total'] = Variable<int>(urTotal);
    map['ur_correct'] = Variable<int>(urCorrect);
    map['new_cards'] = Variable<int>(newCards);
    return map;
  }

  DailyStatsCompanion toCompanion(bool nullToAbsent) {
    return DailyStatsCompanion(
      date: Value(date),
      cTotal: Value(cTotal),
      cCorrect: Value(cCorrect),
      rTotal: Value(rTotal),
      rCorrect: Value(rCorrect),
      srTotal: Value(srTotal),
      srCorrect: Value(srCorrect),
      ssrTotal: Value(ssrTotal),
      ssrCorrect: Value(ssrCorrect),
      urTotal: Value(urTotal),
      urCorrect: Value(urCorrect),
      newCards: Value(newCards),
    );
  }

  factory DailyStatRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyStatRow(
      date: serializer.fromJson<String>(json['date']),
      cTotal: serializer.fromJson<int>(json['cTotal']),
      cCorrect: serializer.fromJson<int>(json['cCorrect']),
      rTotal: serializer.fromJson<int>(json['rTotal']),
      rCorrect: serializer.fromJson<int>(json['rCorrect']),
      srTotal: serializer.fromJson<int>(json['srTotal']),
      srCorrect: serializer.fromJson<int>(json['srCorrect']),
      ssrTotal: serializer.fromJson<int>(json['ssrTotal']),
      ssrCorrect: serializer.fromJson<int>(json['ssrCorrect']),
      urTotal: serializer.fromJson<int>(json['urTotal']),
      urCorrect: serializer.fromJson<int>(json['urCorrect']),
      newCards: serializer.fromJson<int>(json['newCards']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<String>(date),
      'cTotal': serializer.toJson<int>(cTotal),
      'cCorrect': serializer.toJson<int>(cCorrect),
      'rTotal': serializer.toJson<int>(rTotal),
      'rCorrect': serializer.toJson<int>(rCorrect),
      'srTotal': serializer.toJson<int>(srTotal),
      'srCorrect': serializer.toJson<int>(srCorrect),
      'ssrTotal': serializer.toJson<int>(ssrTotal),
      'ssrCorrect': serializer.toJson<int>(ssrCorrect),
      'urTotal': serializer.toJson<int>(urTotal),
      'urCorrect': serializer.toJson<int>(urCorrect),
      'newCards': serializer.toJson<int>(newCards),
    };
  }

  DailyStatRow copyWith({
    String? date,
    int? cTotal,
    int? cCorrect,
    int? rTotal,
    int? rCorrect,
    int? srTotal,
    int? srCorrect,
    int? ssrTotal,
    int? ssrCorrect,
    int? urTotal,
    int? urCorrect,
    int? newCards,
  }) => DailyStatRow(
    date: date ?? this.date,
    cTotal: cTotal ?? this.cTotal,
    cCorrect: cCorrect ?? this.cCorrect,
    rTotal: rTotal ?? this.rTotal,
    rCorrect: rCorrect ?? this.rCorrect,
    srTotal: srTotal ?? this.srTotal,
    srCorrect: srCorrect ?? this.srCorrect,
    ssrTotal: ssrTotal ?? this.ssrTotal,
    ssrCorrect: ssrCorrect ?? this.ssrCorrect,
    urTotal: urTotal ?? this.urTotal,
    urCorrect: urCorrect ?? this.urCorrect,
    newCards: newCards ?? this.newCards,
  );
  DailyStatRow copyWithCompanion(DailyStatsCompanion data) {
    return DailyStatRow(
      date: data.date.present ? data.date.value : this.date,
      cTotal: data.cTotal.present ? data.cTotal.value : this.cTotal,
      cCorrect: data.cCorrect.present ? data.cCorrect.value : this.cCorrect,
      rTotal: data.rTotal.present ? data.rTotal.value : this.rTotal,
      rCorrect: data.rCorrect.present ? data.rCorrect.value : this.rCorrect,
      srTotal: data.srTotal.present ? data.srTotal.value : this.srTotal,
      srCorrect: data.srCorrect.present ? data.srCorrect.value : this.srCorrect,
      ssrTotal: data.ssrTotal.present ? data.ssrTotal.value : this.ssrTotal,
      ssrCorrect: data.ssrCorrect.present
          ? data.ssrCorrect.value
          : this.ssrCorrect,
      urTotal: data.urTotal.present ? data.urTotal.value : this.urTotal,
      urCorrect: data.urCorrect.present ? data.urCorrect.value : this.urCorrect,
      newCards: data.newCards.present ? data.newCards.value : this.newCards,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyStatRow(')
          ..write('date: $date, ')
          ..write('cTotal: $cTotal, ')
          ..write('cCorrect: $cCorrect, ')
          ..write('rTotal: $rTotal, ')
          ..write('rCorrect: $rCorrect, ')
          ..write('srTotal: $srTotal, ')
          ..write('srCorrect: $srCorrect, ')
          ..write('ssrTotal: $ssrTotal, ')
          ..write('ssrCorrect: $ssrCorrect, ')
          ..write('urTotal: $urTotal, ')
          ..write('urCorrect: $urCorrect, ')
          ..write('newCards: $newCards')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    date,
    cTotal,
    cCorrect,
    rTotal,
    rCorrect,
    srTotal,
    srCorrect,
    ssrTotal,
    ssrCorrect,
    urTotal,
    urCorrect,
    newCards,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyStatRow &&
          other.date == this.date &&
          other.cTotal == this.cTotal &&
          other.cCorrect == this.cCorrect &&
          other.rTotal == this.rTotal &&
          other.rCorrect == this.rCorrect &&
          other.srTotal == this.srTotal &&
          other.srCorrect == this.srCorrect &&
          other.ssrTotal == this.ssrTotal &&
          other.ssrCorrect == this.ssrCorrect &&
          other.urTotal == this.urTotal &&
          other.urCorrect == this.urCorrect &&
          other.newCards == this.newCards);
}

class DailyStatsCompanion extends UpdateCompanion<DailyStatRow> {
  final Value<String> date;
  final Value<int> cTotal;
  final Value<int> cCorrect;
  final Value<int> rTotal;
  final Value<int> rCorrect;
  final Value<int> srTotal;
  final Value<int> srCorrect;
  final Value<int> ssrTotal;
  final Value<int> ssrCorrect;
  final Value<int> urTotal;
  final Value<int> urCorrect;
  final Value<int> newCards;
  final Value<int> rowid;
  const DailyStatsCompanion({
    this.date = const Value.absent(),
    this.cTotal = const Value.absent(),
    this.cCorrect = const Value.absent(),
    this.rTotal = const Value.absent(),
    this.rCorrect = const Value.absent(),
    this.srTotal = const Value.absent(),
    this.srCorrect = const Value.absent(),
    this.ssrTotal = const Value.absent(),
    this.ssrCorrect = const Value.absent(),
    this.urTotal = const Value.absent(),
    this.urCorrect = const Value.absent(),
    this.newCards = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailyStatsCompanion.insert({
    required String date,
    this.cTotal = const Value.absent(),
    this.cCorrect = const Value.absent(),
    this.rTotal = const Value.absent(),
    this.rCorrect = const Value.absent(),
    this.srTotal = const Value.absent(),
    this.srCorrect = const Value.absent(),
    this.ssrTotal = const Value.absent(),
    this.ssrCorrect = const Value.absent(),
    this.urTotal = const Value.absent(),
    this.urCorrect = const Value.absent(),
    this.newCards = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : date = Value(date);
  static Insertable<DailyStatRow> custom({
    Expression<String>? date,
    Expression<int>? cTotal,
    Expression<int>? cCorrect,
    Expression<int>? rTotal,
    Expression<int>? rCorrect,
    Expression<int>? srTotal,
    Expression<int>? srCorrect,
    Expression<int>? ssrTotal,
    Expression<int>? ssrCorrect,
    Expression<int>? urTotal,
    Expression<int>? urCorrect,
    Expression<int>? newCards,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (cTotal != null) 'c_total': cTotal,
      if (cCorrect != null) 'c_correct': cCorrect,
      if (rTotal != null) 'r_total': rTotal,
      if (rCorrect != null) 'r_correct': rCorrect,
      if (srTotal != null) 'sr_total': srTotal,
      if (srCorrect != null) 'sr_correct': srCorrect,
      if (ssrTotal != null) 'ssr_total': ssrTotal,
      if (ssrCorrect != null) 'ssr_correct': ssrCorrect,
      if (urTotal != null) 'ur_total': urTotal,
      if (urCorrect != null) 'ur_correct': urCorrect,
      if (newCards != null) 'new_cards': newCards,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailyStatsCompanion copyWith({
    Value<String>? date,
    Value<int>? cTotal,
    Value<int>? cCorrect,
    Value<int>? rTotal,
    Value<int>? rCorrect,
    Value<int>? srTotal,
    Value<int>? srCorrect,
    Value<int>? ssrTotal,
    Value<int>? ssrCorrect,
    Value<int>? urTotal,
    Value<int>? urCorrect,
    Value<int>? newCards,
    Value<int>? rowid,
  }) {
    return DailyStatsCompanion(
      date: date ?? this.date,
      cTotal: cTotal ?? this.cTotal,
      cCorrect: cCorrect ?? this.cCorrect,
      rTotal: rTotal ?? this.rTotal,
      rCorrect: rCorrect ?? this.rCorrect,
      srTotal: srTotal ?? this.srTotal,
      srCorrect: srCorrect ?? this.srCorrect,
      ssrTotal: ssrTotal ?? this.ssrTotal,
      ssrCorrect: ssrCorrect ?? this.ssrCorrect,
      urTotal: urTotal ?? this.urTotal,
      urCorrect: urCorrect ?? this.urCorrect,
      newCards: newCards ?? this.newCards,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (cTotal.present) {
      map['c_total'] = Variable<int>(cTotal.value);
    }
    if (cCorrect.present) {
      map['c_correct'] = Variable<int>(cCorrect.value);
    }
    if (rTotal.present) {
      map['r_total'] = Variable<int>(rTotal.value);
    }
    if (rCorrect.present) {
      map['r_correct'] = Variable<int>(rCorrect.value);
    }
    if (srTotal.present) {
      map['sr_total'] = Variable<int>(srTotal.value);
    }
    if (srCorrect.present) {
      map['sr_correct'] = Variable<int>(srCorrect.value);
    }
    if (ssrTotal.present) {
      map['ssr_total'] = Variable<int>(ssrTotal.value);
    }
    if (ssrCorrect.present) {
      map['ssr_correct'] = Variable<int>(ssrCorrect.value);
    }
    if (urTotal.present) {
      map['ur_total'] = Variable<int>(urTotal.value);
    }
    if (urCorrect.present) {
      map['ur_correct'] = Variable<int>(urCorrect.value);
    }
    if (newCards.present) {
      map['new_cards'] = Variable<int>(newCards.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyStatsCompanion(')
          ..write('date: $date, ')
          ..write('cTotal: $cTotal, ')
          ..write('cCorrect: $cCorrect, ')
          ..write('rTotal: $rTotal, ')
          ..write('rCorrect: $rCorrect, ')
          ..write('srTotal: $srTotal, ')
          ..write('srCorrect: $srCorrect, ')
          ..write('ssrTotal: $ssrTotal, ')
          ..write('ssrCorrect: $ssrCorrect, ')
          ..write('urTotal: $urTotal, ')
          ..write('urCorrect: $urCorrect, ')
          ..write('newCards: $newCards, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReviewLogTable extends ReviewLog
    with TableInfo<$ReviewLogTable, ReviewLogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReviewLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _reviewedAtMeta = const VerificationMeta(
    'reviewedAt',
  );
  @override
  late final GeneratedColumn<DateTime> reviewedAt = GeneratedColumn<DateTime>(
    'reviewed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _prevIntervalMinutesMeta =
      const VerificationMeta('prevIntervalMinutes');
  @override
  late final GeneratedColumn<int> prevIntervalMinutes = GeneratedColumn<int>(
    'prev_interval_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _correctMeta = const VerificationMeta(
    'correct',
  );
  @override
  late final GeneratedColumn<bool> correct = GeneratedColumn<bool>(
    'correct',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("correct" IN (0, 1))',
    ),
  );
  static const VerificationMeta _rarityMeta = const VerificationMeta('rarity');
  @override
  late final GeneratedColumn<int> rarity = GeneratedColumn<int>(
    'rarity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ReviewKind, int> kind =
      GeneratedColumn<int>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: Constant(ReviewKind.review.index),
      ).withConverter<ReviewKind>($ReviewLogTable.$converterkind);
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    reviewedAt,
    prevIntervalMinutes,
    correct,
    rarity,
    kind,
    durationMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'review_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReviewLogRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('reviewed_at')) {
      context.handle(
        _reviewedAtMeta,
        reviewedAt.isAcceptableOrUnknown(data['reviewed_at']!, _reviewedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_reviewedAtMeta);
    }
    if (data.containsKey('prev_interval_minutes')) {
      context.handle(
        _prevIntervalMinutesMeta,
        prevIntervalMinutes.isAcceptableOrUnknown(
          data['prev_interval_minutes']!,
          _prevIntervalMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_prevIntervalMinutesMeta);
    }
    if (data.containsKey('correct')) {
      context.handle(
        _correctMeta,
        correct.isAcceptableOrUnknown(data['correct']!, _correctMeta),
      );
    } else if (isInserting) {
      context.missing(_correctMeta);
    }
    if (data.containsKey('rarity')) {
      context.handle(
        _rarityMeta,
        rarity.isAcceptableOrUnknown(data['rarity']!, _rarityMeta),
      );
    } else if (isInserting) {
      context.missing(_rarityMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReviewLogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReviewLogRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      reviewedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}reviewed_at'],
      )!,
      prevIntervalMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}prev_interval_minutes'],
      )!,
      correct: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}correct'],
      )!,
      rarity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rarity'],
      )!,
      kind: $ReviewLogTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}kind'],
        )!,
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
    );
  }

  @override
  $ReviewLogTable createAlias(String alias) {
    return $ReviewLogTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ReviewKind, int, int> $converterkind =
      const EnumIndexConverter<ReviewKind>(ReviewKind.values);
}

class ReviewLogRow extends DataClass implements Insertable<ReviewLogRow> {
  final int id;
  final DateTime reviewedAt;

  /// Interval the card had *coming into* this review (minutes). 0 for
  /// the very first review of a card; subsequent rows record the gap
  /// since the previous review (in scheduler terms — not wall clock).
  final int prevIntervalMinutes;
  final bool correct;

  /// Denormalised so the retention curve can be sliced per-rarity
  /// without joining cards. Stored as the [Rarity] enum index.
  final int rarity;

  /// Whether this answer was a learn-phase, review-phase, or relearn-
  /// phase event. Stored as the [ReviewKind] enum index. Defaults to
  /// `review.index` so legacy rows (pre-v5) read as plain reviews; the
  /// migration backfills 0 for the (very few) rows that already exist.
  final ReviewKind kind;

  /// Wall-clock time the user spent on this card, in milliseconds —
  /// from the moment the front was shown to the swipe. Null when not
  /// known (Anki imports without a `time` value, or a swipe that fell
  /// through before the timer started).
  final int? durationMs;
  const ReviewLogRow({
    required this.id,
    required this.reviewedAt,
    required this.prevIntervalMinutes,
    required this.correct,
    required this.rarity,
    required this.kind,
    this.durationMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['reviewed_at'] = Variable<DateTime>(reviewedAt);
    map['prev_interval_minutes'] = Variable<int>(prevIntervalMinutes);
    map['correct'] = Variable<bool>(correct);
    map['rarity'] = Variable<int>(rarity);
    {
      map['kind'] = Variable<int>($ReviewLogTable.$converterkind.toSql(kind));
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    return map;
  }

  ReviewLogCompanion toCompanion(bool nullToAbsent) {
    return ReviewLogCompanion(
      id: Value(id),
      reviewedAt: Value(reviewedAt),
      prevIntervalMinutes: Value(prevIntervalMinutes),
      correct: Value(correct),
      rarity: Value(rarity),
      kind: Value(kind),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
    );
  }

  factory ReviewLogRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReviewLogRow(
      id: serializer.fromJson<int>(json['id']),
      reviewedAt: serializer.fromJson<DateTime>(json['reviewedAt']),
      prevIntervalMinutes: serializer.fromJson<int>(
        json['prevIntervalMinutes'],
      ),
      correct: serializer.fromJson<bool>(json['correct']),
      rarity: serializer.fromJson<int>(json['rarity']),
      kind: $ReviewLogTable.$converterkind.fromJson(
        serializer.fromJson<int>(json['kind']),
      ),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'reviewedAt': serializer.toJson<DateTime>(reviewedAt),
      'prevIntervalMinutes': serializer.toJson<int>(prevIntervalMinutes),
      'correct': serializer.toJson<bool>(correct),
      'rarity': serializer.toJson<int>(rarity),
      'kind': serializer.toJson<int>(
        $ReviewLogTable.$converterkind.toJson(kind),
      ),
      'durationMs': serializer.toJson<int?>(durationMs),
    };
  }

  ReviewLogRow copyWith({
    int? id,
    DateTime? reviewedAt,
    int? prevIntervalMinutes,
    bool? correct,
    int? rarity,
    ReviewKind? kind,
    Value<int?> durationMs = const Value.absent(),
  }) => ReviewLogRow(
    id: id ?? this.id,
    reviewedAt: reviewedAt ?? this.reviewedAt,
    prevIntervalMinutes: prevIntervalMinutes ?? this.prevIntervalMinutes,
    correct: correct ?? this.correct,
    rarity: rarity ?? this.rarity,
    kind: kind ?? this.kind,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
  );
  ReviewLogRow copyWithCompanion(ReviewLogCompanion data) {
    return ReviewLogRow(
      id: data.id.present ? data.id.value : this.id,
      reviewedAt: data.reviewedAt.present
          ? data.reviewedAt.value
          : this.reviewedAt,
      prevIntervalMinutes: data.prevIntervalMinutes.present
          ? data.prevIntervalMinutes.value
          : this.prevIntervalMinutes,
      correct: data.correct.present ? data.correct.value : this.correct,
      rarity: data.rarity.present ? data.rarity.value : this.rarity,
      kind: data.kind.present ? data.kind.value : this.kind,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReviewLogRow(')
          ..write('id: $id, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('prevIntervalMinutes: $prevIntervalMinutes, ')
          ..write('correct: $correct, ')
          ..write('rarity: $rarity, ')
          ..write('kind: $kind, ')
          ..write('durationMs: $durationMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    reviewedAt,
    prevIntervalMinutes,
    correct,
    rarity,
    kind,
    durationMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewLogRow &&
          other.id == this.id &&
          other.reviewedAt == this.reviewedAt &&
          other.prevIntervalMinutes == this.prevIntervalMinutes &&
          other.correct == this.correct &&
          other.rarity == this.rarity &&
          other.kind == this.kind &&
          other.durationMs == this.durationMs);
}

class ReviewLogCompanion extends UpdateCompanion<ReviewLogRow> {
  final Value<int> id;
  final Value<DateTime> reviewedAt;
  final Value<int> prevIntervalMinutes;
  final Value<bool> correct;
  final Value<int> rarity;
  final Value<ReviewKind> kind;
  final Value<int?> durationMs;
  const ReviewLogCompanion({
    this.id = const Value.absent(),
    this.reviewedAt = const Value.absent(),
    this.prevIntervalMinutes = const Value.absent(),
    this.correct = const Value.absent(),
    this.rarity = const Value.absent(),
    this.kind = const Value.absent(),
    this.durationMs = const Value.absent(),
  });
  ReviewLogCompanion.insert({
    this.id = const Value.absent(),
    required DateTime reviewedAt,
    required int prevIntervalMinutes,
    required bool correct,
    required int rarity,
    this.kind = const Value.absent(),
    this.durationMs = const Value.absent(),
  }) : reviewedAt = Value(reviewedAt),
       prevIntervalMinutes = Value(prevIntervalMinutes),
       correct = Value(correct),
       rarity = Value(rarity);
  static Insertable<ReviewLogRow> custom({
    Expression<int>? id,
    Expression<DateTime>? reviewedAt,
    Expression<int>? prevIntervalMinutes,
    Expression<bool>? correct,
    Expression<int>? rarity,
    Expression<int>? kind,
    Expression<int>? durationMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (reviewedAt != null) 'reviewed_at': reviewedAt,
      if (prevIntervalMinutes != null)
        'prev_interval_minutes': prevIntervalMinutes,
      if (correct != null) 'correct': correct,
      if (rarity != null) 'rarity': rarity,
      if (kind != null) 'kind': kind,
      if (durationMs != null) 'duration_ms': durationMs,
    });
  }

  ReviewLogCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? reviewedAt,
    Value<int>? prevIntervalMinutes,
    Value<bool>? correct,
    Value<int>? rarity,
    Value<ReviewKind>? kind,
    Value<int?>? durationMs,
  }) {
    return ReviewLogCompanion(
      id: id ?? this.id,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      prevIntervalMinutes: prevIntervalMinutes ?? this.prevIntervalMinutes,
      correct: correct ?? this.correct,
      rarity: rarity ?? this.rarity,
      kind: kind ?? this.kind,
      durationMs: durationMs ?? this.durationMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (reviewedAt.present) {
      map['reviewed_at'] = Variable<DateTime>(reviewedAt.value);
    }
    if (prevIntervalMinutes.present) {
      map['prev_interval_minutes'] = Variable<int>(prevIntervalMinutes.value);
    }
    if (correct.present) {
      map['correct'] = Variable<bool>(correct.value);
    }
    if (rarity.present) {
      map['rarity'] = Variable<int>(rarity.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(
        $ReviewLogTable.$converterkind.toSql(kind.value),
      );
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReviewLogCompanion(')
          ..write('id: $id, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('prevIntervalMinutes: $prevIntervalMinutes, ')
          ..write('correct: $correct, ')
          ..write('rarity: $rarity, ')
          ..write('kind: $kind, ')
          ..write('durationMs: $durationMs')
          ..write(')'))
        .toString();
  }
}

class $PacksTable extends Packs with TableInfo<$PacksTable, PackRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PacksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sourceTitleMeta = const VerificationMeta(
    'sourceTitle',
  );
  @override
  late final GeneratedColumn<String> sourceTitle = GeneratedColumn<String>(
    'source_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceAuthorMeta = const VerificationMeta(
    'sourceAuthor',
  );
  @override
  late final GeneratedColumn<String> sourceAuthor = GeneratedColumn<String>(
    'source_author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _licenseMeta = const VerificationMeta(
    'license',
  );
  @override
  late final GeneratedColumn<String> license = GeneratedColumn<String>(
    'license',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _cardCountMeta = const VerificationMeta(
    'cardCount',
  );
  @override
  late final GeneratedColumn<int> cardCount = GeneratedColumn<int>(
    'card_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
    name,
    label,
    description,
    sourceTitle,
    sourceUrl,
    sourceAuthor,
    license,
    version,
    cardCount,
    installedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'packs';
  @override
  VerificationContext validateIntegrity(
    Insertable<PackRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('source_title')) {
      context.handle(
        _sourceTitleMeta,
        sourceTitle.isAcceptableOrUnknown(
          data['source_title']!,
          _sourceTitleMeta,
        ),
      );
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    }
    if (data.containsKey('source_author')) {
      context.handle(
        _sourceAuthorMeta,
        sourceAuthor.isAcceptableOrUnknown(
          data['source_author']!,
          _sourceAuthorMeta,
        ),
      );
    }
    if (data.containsKey('license')) {
      context.handle(
        _licenseMeta,
        license.isAcceptableOrUnknown(data['license']!, _licenseMeta),
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
    if (data.containsKey('card_count')) {
      context.handle(
        _cardCountMeta,
        cardCount.isAcceptableOrUnknown(data['card_count']!, _cardCountMeta),
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
  Set<GeneratedColumn> get $primaryKey => {name};
  @override
  PackRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PackRow(
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      sourceTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_title'],
      ),
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      ),
      sourceAuthor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_author'],
      ),
      license: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}license'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
      cardCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}card_count'],
      )!,
      installedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}installed_at'],
      )!,
    );
  }

  @override
  $PacksTable createAlias(String alias) {
    return $PacksTable(attachedDatabase, alias);
  }
}

class PackRow extends DataClass implements Insertable<PackRow> {
  final String name;
  final String label;
  final String description;

  /// Attribution for the upstream deck. Absent fields stay null rather
  /// than being guessed at — an unknown licence is not "public domain".
  final String? sourceTitle;
  final String? sourceUrl;
  final String? sourceAuthor;
  final String? license;

  /// Truncated sha256 of the pack file this row was installed from.
  final String version;
  final int cardCount;
  final DateTime installedAt;
  const PackRow({
    required this.name,
    required this.label,
    required this.description,
    this.sourceTitle,
    this.sourceUrl,
    this.sourceAuthor,
    this.license,
    required this.version,
    required this.cardCount,
    required this.installedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['name'] = Variable<String>(name);
    map['label'] = Variable<String>(label);
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || sourceTitle != null) {
      map['source_title'] = Variable<String>(sourceTitle);
    }
    if (!nullToAbsent || sourceUrl != null) {
      map['source_url'] = Variable<String>(sourceUrl);
    }
    if (!nullToAbsent || sourceAuthor != null) {
      map['source_author'] = Variable<String>(sourceAuthor);
    }
    if (!nullToAbsent || license != null) {
      map['license'] = Variable<String>(license);
    }
    map['version'] = Variable<String>(version);
    map['card_count'] = Variable<int>(cardCount);
    map['installed_at'] = Variable<DateTime>(installedAt);
    return map;
  }

  PacksCompanion toCompanion(bool nullToAbsent) {
    return PacksCompanion(
      name: Value(name),
      label: Value(label),
      description: Value(description),
      sourceTitle: sourceTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceTitle),
      sourceUrl: sourceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUrl),
      sourceAuthor: sourceAuthor == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceAuthor),
      license: license == null && nullToAbsent
          ? const Value.absent()
          : Value(license),
      version: Value(version),
      cardCount: Value(cardCount),
      installedAt: Value(installedAt),
    );
  }

  factory PackRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PackRow(
      name: serializer.fromJson<String>(json['name']),
      label: serializer.fromJson<String>(json['label']),
      description: serializer.fromJson<String>(json['description']),
      sourceTitle: serializer.fromJson<String?>(json['sourceTitle']),
      sourceUrl: serializer.fromJson<String?>(json['sourceUrl']),
      sourceAuthor: serializer.fromJson<String?>(json['sourceAuthor']),
      license: serializer.fromJson<String?>(json['license']),
      version: serializer.fromJson<String>(json['version']),
      cardCount: serializer.fromJson<int>(json['cardCount']),
      installedAt: serializer.fromJson<DateTime>(json['installedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'name': serializer.toJson<String>(name),
      'label': serializer.toJson<String>(label),
      'description': serializer.toJson<String>(description),
      'sourceTitle': serializer.toJson<String?>(sourceTitle),
      'sourceUrl': serializer.toJson<String?>(sourceUrl),
      'sourceAuthor': serializer.toJson<String?>(sourceAuthor),
      'license': serializer.toJson<String?>(license),
      'version': serializer.toJson<String>(version),
      'cardCount': serializer.toJson<int>(cardCount),
      'installedAt': serializer.toJson<DateTime>(installedAt),
    };
  }

  PackRow copyWith({
    String? name,
    String? label,
    String? description,
    Value<String?> sourceTitle = const Value.absent(),
    Value<String?> sourceUrl = const Value.absent(),
    Value<String?> sourceAuthor = const Value.absent(),
    Value<String?> license = const Value.absent(),
    String? version,
    int? cardCount,
    DateTime? installedAt,
  }) => PackRow(
    name: name ?? this.name,
    label: label ?? this.label,
    description: description ?? this.description,
    sourceTitle: sourceTitle.present ? sourceTitle.value : this.sourceTitle,
    sourceUrl: sourceUrl.present ? sourceUrl.value : this.sourceUrl,
    sourceAuthor: sourceAuthor.present ? sourceAuthor.value : this.sourceAuthor,
    license: license.present ? license.value : this.license,
    version: version ?? this.version,
    cardCount: cardCount ?? this.cardCount,
    installedAt: installedAt ?? this.installedAt,
  );
  PackRow copyWithCompanion(PacksCompanion data) {
    return PackRow(
      name: data.name.present ? data.name.value : this.name,
      label: data.label.present ? data.label.value : this.label,
      description: data.description.present
          ? data.description.value
          : this.description,
      sourceTitle: data.sourceTitle.present
          ? data.sourceTitle.value
          : this.sourceTitle,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      sourceAuthor: data.sourceAuthor.present
          ? data.sourceAuthor.value
          : this.sourceAuthor,
      license: data.license.present ? data.license.value : this.license,
      version: data.version.present ? data.version.value : this.version,
      cardCount: data.cardCount.present ? data.cardCount.value : this.cardCount,
      installedAt: data.installedAt.present
          ? data.installedAt.value
          : this.installedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PackRow(')
          ..write('name: $name, ')
          ..write('label: $label, ')
          ..write('description: $description, ')
          ..write('sourceTitle: $sourceTitle, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('sourceAuthor: $sourceAuthor, ')
          ..write('license: $license, ')
          ..write('version: $version, ')
          ..write('cardCount: $cardCount, ')
          ..write('installedAt: $installedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    name,
    label,
    description,
    sourceTitle,
    sourceUrl,
    sourceAuthor,
    license,
    version,
    cardCount,
    installedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PackRow &&
          other.name == this.name &&
          other.label == this.label &&
          other.description == this.description &&
          other.sourceTitle == this.sourceTitle &&
          other.sourceUrl == this.sourceUrl &&
          other.sourceAuthor == this.sourceAuthor &&
          other.license == this.license &&
          other.version == this.version &&
          other.cardCount == this.cardCount &&
          other.installedAt == this.installedAt);
}

class PacksCompanion extends UpdateCompanion<PackRow> {
  final Value<String> name;
  final Value<String> label;
  final Value<String> description;
  final Value<String?> sourceTitle;
  final Value<String?> sourceUrl;
  final Value<String?> sourceAuthor;
  final Value<String?> license;
  final Value<String> version;
  final Value<int> cardCount;
  final Value<DateTime> installedAt;
  final Value<int> rowid;
  const PacksCompanion({
    this.name = const Value.absent(),
    this.label = const Value.absent(),
    this.description = const Value.absent(),
    this.sourceTitle = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.sourceAuthor = const Value.absent(),
    this.license = const Value.absent(),
    this.version = const Value.absent(),
    this.cardCount = const Value.absent(),
    this.installedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PacksCompanion.insert({
    required String name,
    required String label,
    this.description = const Value.absent(),
    this.sourceTitle = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.sourceAuthor = const Value.absent(),
    this.license = const Value.absent(),
    required String version,
    this.cardCount = const Value.absent(),
    required DateTime installedAt,
    this.rowid = const Value.absent(),
  }) : name = Value(name),
       label = Value(label),
       version = Value(version),
       installedAt = Value(installedAt);
  static Insertable<PackRow> custom({
    Expression<String>? name,
    Expression<String>? label,
    Expression<String>? description,
    Expression<String>? sourceTitle,
    Expression<String>? sourceUrl,
    Expression<String>? sourceAuthor,
    Expression<String>? license,
    Expression<String>? version,
    Expression<int>? cardCount,
    Expression<DateTime>? installedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (name != null) 'name': name,
      if (label != null) 'label': label,
      if (description != null) 'description': description,
      if (sourceTitle != null) 'source_title': sourceTitle,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (sourceAuthor != null) 'source_author': sourceAuthor,
      if (license != null) 'license': license,
      if (version != null) 'version': version,
      if (cardCount != null) 'card_count': cardCount,
      if (installedAt != null) 'installed_at': installedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PacksCompanion copyWith({
    Value<String>? name,
    Value<String>? label,
    Value<String>? description,
    Value<String?>? sourceTitle,
    Value<String?>? sourceUrl,
    Value<String?>? sourceAuthor,
    Value<String?>? license,
    Value<String>? version,
    Value<int>? cardCount,
    Value<DateTime>? installedAt,
    Value<int>? rowid,
  }) {
    return PacksCompanion(
      name: name ?? this.name,
      label: label ?? this.label,
      description: description ?? this.description,
      sourceTitle: sourceTitle ?? this.sourceTitle,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sourceAuthor: sourceAuthor ?? this.sourceAuthor,
      license: license ?? this.license,
      version: version ?? this.version,
      cardCount: cardCount ?? this.cardCount,
      installedAt: installedAt ?? this.installedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (sourceTitle.present) {
      map['source_title'] = Variable<String>(sourceTitle.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (sourceAuthor.present) {
      map['source_author'] = Variable<String>(sourceAuthor.value);
    }
    if (license.present) {
      map['license'] = Variable<String>(license.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (cardCount.present) {
      map['card_count'] = Variable<int>(cardCount.value);
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
    return (StringBuffer('PacksCompanion(')
          ..write('name: $name, ')
          ..write('label: $label, ')
          ..write('description: $description, ')
          ..write('sourceTitle: $sourceTitle, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('sourceAuthor: $sourceAuthor, ')
          ..write('license: $license, ')
          ..write('version: $version, ')
          ..write('cardCount: $cardCount, ')
          ..write('installedAt: $installedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CardsTable cards = $CardsTable(this);
  late final $CardSensesTable cardSenses = $CardSensesTable(this);
  late final $ExamplesTable examples = $ExamplesTable(this);
  late final $CardExamplesTable cardExamples = $CardExamplesTable(this);
  late final $UserCardsTable userCards = $UserCardsTable(this);
  late final $MetaTable meta = $MetaTable(this);
  late final $WishlistTable wishlist = $WishlistTable(this);
  late final $DailyStatsTable dailyStats = $DailyStatsTable(this);
  late final $ReviewLogTable reviewLog = $ReviewLogTable(this);
  late final $PacksTable packs = $PacksTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cards,
    cardSenses,
    examples,
    cardExamples,
    userCards,
    meta,
    wishlist,
    dailyStats,
    reviewLog,
    packs,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'cards',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('card_senses', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'cards',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('card_examples', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'examples',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('card_examples', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'cards',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('user_cards', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'cards',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('wishlist', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$CardsTableCreateCompanionBuilder =
    CardsCompanion Function({
      Value<int> id,
      required String kanji,
      required String kana,
      Value<String?> furigana,
      required String meaning,
      Value<Rarity> rarity,
      Value<int?> jlptLevel,
      Value<String?> audioPath,
      Value<String?> imagePath,
      Value<CardSource> source,
      Value<String?> pack,
    });
typedef $$CardsTableUpdateCompanionBuilder =
    CardsCompanion Function({
      Value<int> id,
      Value<String> kanji,
      Value<String> kana,
      Value<String?> furigana,
      Value<String> meaning,
      Value<Rarity> rarity,
      Value<int?> jlptLevel,
      Value<String?> audioPath,
      Value<String?> imagePath,
      Value<CardSource> source,
      Value<String?> pack,
    });

final class $$CardsTableReferences
    extends BaseReferences<_$AppDatabase, $CardsTable, CardRow> {
  $$CardsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CardSensesTable, List<CardSenseRow>>
  _cardSensesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.cardSenses,
    aliasName: $_aliasNameGenerator(db.cards.id, db.cardSenses.cardId),
  );

  $$CardSensesTableProcessedTableManager get cardSensesRefs {
    final manager = $$CardSensesTableTableManager(
      $_db,
      $_db.cardSenses,
    ).filter((f) => f.cardId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_cardSensesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CardExamplesTable, List<CardExampleRow>>
  _cardExamplesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.cardExamples,
    aliasName: $_aliasNameGenerator(db.cards.id, db.cardExamples.cardId),
  );

  $$CardExamplesTableProcessedTableManager get cardExamplesRefs {
    final manager = $$CardExamplesTableTableManager(
      $_db,
      $_db.cardExamples,
    ).filter((f) => f.cardId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_cardExamplesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$UserCardsTable, List<UserCardRow>>
  _userCardsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.userCards,
    aliasName: $_aliasNameGenerator(db.cards.id, db.userCards.cardId),
  );

  $$UserCardsTableProcessedTableManager get userCardsRefs {
    final manager = $$UserCardsTableTableManager(
      $_db,
      $_db.userCards,
    ).filter((f) => f.cardId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_userCardsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$WishlistTable, List<WishlistRow>>
  _wishlistRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.wishlist,
    aliasName: $_aliasNameGenerator(db.cards.id, db.wishlist.cardId),
  );

  $$WishlistTableProcessedTableManager get wishlistRefs {
    final manager = $$WishlistTableTableManager(
      $_db,
      $_db.wishlist,
    ).filter((f) => f.cardId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_wishlistRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CardsTableFilterComposer extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableFilterComposer({
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

  ColumnFilters<String> get kanji => $composableBuilder(
    column: $table.kanji,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kana => $composableBuilder(
    column: $table.kana,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get furigana => $composableBuilder(
    column: $table.furigana,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get meaning => $composableBuilder(
    column: $table.meaning,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Rarity, Rarity, int> get rarity =>
      $composableBuilder(
        column: $table.rarity,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get jlptLevel => $composableBuilder(
    column: $table.jlptLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CardSource, CardSource, int> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get pack => $composableBuilder(
    column: $table.pack,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> cardSensesRefs(
    Expression<bool> Function($$CardSensesTableFilterComposer f) f,
  ) {
    final $$CardSensesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cardSenses,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardSensesTableFilterComposer(
            $db: $db,
            $table: $db.cardSenses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cardExamplesRefs(
    Expression<bool> Function($$CardExamplesTableFilterComposer f) f,
  ) {
    final $$CardExamplesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cardExamples,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardExamplesTableFilterComposer(
            $db: $db,
            $table: $db.cardExamples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> userCardsRefs(
    Expression<bool> Function($$UserCardsTableFilterComposer f) f,
  ) {
    final $$UserCardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.userCards,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserCardsTableFilterComposer(
            $db: $db,
            $table: $db.userCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> wishlistRefs(
    Expression<bool> Function($$WishlistTableFilterComposer f) f,
  ) {
    final $$WishlistTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wishlist,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WishlistTableFilterComposer(
            $db: $db,
            $table: $db.wishlist,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CardsTableOrderingComposer
    extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableOrderingComposer({
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

  ColumnOrderings<String> get kanji => $composableBuilder(
    column: $table.kanji,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kana => $composableBuilder(
    column: $table.kana,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get furigana => $composableBuilder(
    column: $table.furigana,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meaning => $composableBuilder(
    column: $table.meaning,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rarity => $composableBuilder(
    column: $table.rarity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get jlptLevel => $composableBuilder(
    column: $table.jlptLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pack => $composableBuilder(
    column: $table.pack,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kanji =>
      $composableBuilder(column: $table.kanji, builder: (column) => column);

  GeneratedColumn<String> get kana =>
      $composableBuilder(column: $table.kana, builder: (column) => column);

  GeneratedColumn<String> get furigana =>
      $composableBuilder(column: $table.furigana, builder: (column) => column);

  GeneratedColumn<String> get meaning =>
      $composableBuilder(column: $table.meaning, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Rarity, int> get rarity =>
      $composableBuilder(column: $table.rarity, builder: (column) => column);

  GeneratedColumn<int> get jlptLevel =>
      $composableBuilder(column: $table.jlptLevel, builder: (column) => column);

  GeneratedColumn<String> get audioPath =>
      $composableBuilder(column: $table.audioPath, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CardSource, int> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get pack =>
      $composableBuilder(column: $table.pack, builder: (column) => column);

  Expression<T> cardSensesRefs<T extends Object>(
    Expression<T> Function($$CardSensesTableAnnotationComposer a) f,
  ) {
    final $$CardSensesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cardSenses,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardSensesTableAnnotationComposer(
            $db: $db,
            $table: $db.cardSenses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> cardExamplesRefs<T extends Object>(
    Expression<T> Function($$CardExamplesTableAnnotationComposer a) f,
  ) {
    final $$CardExamplesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cardExamples,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardExamplesTableAnnotationComposer(
            $db: $db,
            $table: $db.cardExamples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> userCardsRefs<T extends Object>(
    Expression<T> Function($$UserCardsTableAnnotationComposer a) f,
  ) {
    final $$UserCardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.userCards,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserCardsTableAnnotationComposer(
            $db: $db,
            $table: $db.userCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> wishlistRefs<T extends Object>(
    Expression<T> Function($$WishlistTableAnnotationComposer a) f,
  ) {
    final $$WishlistTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wishlist,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WishlistTableAnnotationComposer(
            $db: $db,
            $table: $db.wishlist,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CardsTable,
          CardRow,
          $$CardsTableFilterComposer,
          $$CardsTableOrderingComposer,
          $$CardsTableAnnotationComposer,
          $$CardsTableCreateCompanionBuilder,
          $$CardsTableUpdateCompanionBuilder,
          (CardRow, $$CardsTableReferences),
          CardRow,
          PrefetchHooks Function({
            bool cardSensesRefs,
            bool cardExamplesRefs,
            bool userCardsRefs,
            bool wishlistRefs,
          })
        > {
  $$CardsTableTableManager(_$AppDatabase db, $CardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> kanji = const Value.absent(),
                Value<String> kana = const Value.absent(),
                Value<String?> furigana = const Value.absent(),
                Value<String> meaning = const Value.absent(),
                Value<Rarity> rarity = const Value.absent(),
                Value<int?> jlptLevel = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<CardSource> source = const Value.absent(),
                Value<String?> pack = const Value.absent(),
              }) => CardsCompanion(
                id: id,
                kanji: kanji,
                kana: kana,
                furigana: furigana,
                meaning: meaning,
                rarity: rarity,
                jlptLevel: jlptLevel,
                audioPath: audioPath,
                imagePath: imagePath,
                source: source,
                pack: pack,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String kanji,
                required String kana,
                Value<String?> furigana = const Value.absent(),
                required String meaning,
                Value<Rarity> rarity = const Value.absent(),
                Value<int?> jlptLevel = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<CardSource> source = const Value.absent(),
                Value<String?> pack = const Value.absent(),
              }) => CardsCompanion.insert(
                id: id,
                kanji: kanji,
                kana: kana,
                furigana: furigana,
                meaning: meaning,
                rarity: rarity,
                jlptLevel: jlptLevel,
                audioPath: audioPath,
                imagePath: imagePath,
                source: source,
                pack: pack,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$CardsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                cardSensesRefs = false,
                cardExamplesRefs = false,
                userCardsRefs = false,
                wishlistRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (cardSensesRefs) db.cardSenses,
                    if (cardExamplesRefs) db.cardExamples,
                    if (userCardsRefs) db.userCards,
                    if (wishlistRefs) db.wishlist,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (cardSensesRefs)
                        await $_getPrefetchedData<
                          CardRow,
                          $CardsTable,
                          CardSenseRow
                        >(
                          currentTable: table,
                          referencedTable: $$CardsTableReferences
                              ._cardSensesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CardsTableReferences(
                                db,
                                table,
                                p0,
                              ).cardSensesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.cardId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (cardExamplesRefs)
                        await $_getPrefetchedData<
                          CardRow,
                          $CardsTable,
                          CardExampleRow
                        >(
                          currentTable: table,
                          referencedTable: $$CardsTableReferences
                              ._cardExamplesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CardsTableReferences(
                                db,
                                table,
                                p0,
                              ).cardExamplesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.cardId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (userCardsRefs)
                        await $_getPrefetchedData<
                          CardRow,
                          $CardsTable,
                          UserCardRow
                        >(
                          currentTable: table,
                          referencedTable: $$CardsTableReferences
                              ._userCardsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CardsTableReferences(
                                db,
                                table,
                                p0,
                              ).userCardsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.cardId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (wishlistRefs)
                        await $_getPrefetchedData<
                          CardRow,
                          $CardsTable,
                          WishlistRow
                        >(
                          currentTable: table,
                          referencedTable: $$CardsTableReferences
                              ._wishlistRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CardsTableReferences(
                                db,
                                table,
                                p0,
                              ).wishlistRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.cardId == item.id,
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

typedef $$CardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CardsTable,
      CardRow,
      $$CardsTableFilterComposer,
      $$CardsTableOrderingComposer,
      $$CardsTableAnnotationComposer,
      $$CardsTableCreateCompanionBuilder,
      $$CardsTableUpdateCompanionBuilder,
      (CardRow, $$CardsTableReferences),
      CardRow,
      PrefetchHooks Function({
        bool cardSensesRefs,
        bool cardExamplesRefs,
        bool userCardsRefs,
        bool wishlistRefs,
      })
    >;
typedef $$CardSensesTableCreateCompanionBuilder =
    CardSensesCompanion Function({
      Value<int> id,
      required int cardId,
      required int ordinal,
      Value<String> pos,
      required String gloss,
      Value<String> definition,
    });
typedef $$CardSensesTableUpdateCompanionBuilder =
    CardSensesCompanion Function({
      Value<int> id,
      Value<int> cardId,
      Value<int> ordinal,
      Value<String> pos,
      Value<String> gloss,
      Value<String> definition,
    });

final class $$CardSensesTableReferences
    extends BaseReferences<_$AppDatabase, $CardSensesTable, CardSenseRow> {
  $$CardSensesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CardsTable _cardIdTable(_$AppDatabase db) => db.cards.createAlias(
    $_aliasNameGenerator(db.cardSenses.cardId, db.cards.id),
  );

  $$CardsTableProcessedTableManager get cardId {
    final $_column = $_itemColumn<int>('card_id')!;

    final manager = $$CardsTableTableManager(
      $_db,
      $_db.cards,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cardIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CardSensesTableFilterComposer
    extends Composer<_$AppDatabase, $CardSensesTable> {
  $$CardSensesTableFilterComposer({
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

  ColumnFilters<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pos => $composableBuilder(
    column: $table.pos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gloss => $composableBuilder(
    column: $table.gloss,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get definition => $composableBuilder(
    column: $table.definition,
    builder: (column) => ColumnFilters(column),
  );

  $$CardsTableFilterComposer get cardId {
    final $$CardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableFilterComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardSensesTableOrderingComposer
    extends Composer<_$AppDatabase, $CardSensesTable> {
  $$CardSensesTableOrderingComposer({
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

  ColumnOrderings<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pos => $composableBuilder(
    column: $table.pos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gloss => $composableBuilder(
    column: $table.gloss,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get definition => $composableBuilder(
    column: $table.definition,
    builder: (column) => ColumnOrderings(column),
  );

  $$CardsTableOrderingComposer get cardId {
    final $$CardsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableOrderingComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardSensesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CardSensesTable> {
  $$CardSensesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get ordinal =>
      $composableBuilder(column: $table.ordinal, builder: (column) => column);

  GeneratedColumn<String> get pos =>
      $composableBuilder(column: $table.pos, builder: (column) => column);

  GeneratedColumn<String> get gloss =>
      $composableBuilder(column: $table.gloss, builder: (column) => column);

  GeneratedColumn<String> get definition => $composableBuilder(
    column: $table.definition,
    builder: (column) => column,
  );

  $$CardsTableAnnotationComposer get cardId {
    final $$CardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableAnnotationComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardSensesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CardSensesTable,
          CardSenseRow,
          $$CardSensesTableFilterComposer,
          $$CardSensesTableOrderingComposer,
          $$CardSensesTableAnnotationComposer,
          $$CardSensesTableCreateCompanionBuilder,
          $$CardSensesTableUpdateCompanionBuilder,
          (CardSenseRow, $$CardSensesTableReferences),
          CardSenseRow,
          PrefetchHooks Function({bool cardId})
        > {
  $$CardSensesTableTableManager(_$AppDatabase db, $CardSensesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardSensesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardSensesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardSensesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> cardId = const Value.absent(),
                Value<int> ordinal = const Value.absent(),
                Value<String> pos = const Value.absent(),
                Value<String> gloss = const Value.absent(),
                Value<String> definition = const Value.absent(),
              }) => CardSensesCompanion(
                id: id,
                cardId: cardId,
                ordinal: ordinal,
                pos: pos,
                gloss: gloss,
                definition: definition,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int cardId,
                required int ordinal,
                Value<String> pos = const Value.absent(),
                required String gloss,
                Value<String> definition = const Value.absent(),
              }) => CardSensesCompanion.insert(
                id: id,
                cardId: cardId,
                ordinal: ordinal,
                pos: pos,
                gloss: gloss,
                definition: definition,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CardSensesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cardId = false}) {
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
                    if (cardId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.cardId,
                                referencedTable: $$CardSensesTableReferences
                                    ._cardIdTable(db),
                                referencedColumn: $$CardSensesTableReferences
                                    ._cardIdTable(db)
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

typedef $$CardSensesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CardSensesTable,
      CardSenseRow,
      $$CardSensesTableFilterComposer,
      $$CardSensesTableOrderingComposer,
      $$CardSensesTableAnnotationComposer,
      $$CardSensesTableCreateCompanionBuilder,
      $$CardSensesTableUpdateCompanionBuilder,
      (CardSenseRow, $$CardSensesTableReferences),
      CardSenseRow,
      PrefetchHooks Function({bool cardId})
    >;
typedef $$ExamplesTableCreateCompanionBuilder =
    ExamplesCompanion Function({
      Value<int> id,
      required String sentence,
      Value<String?> sourceTitle,
    });
typedef $$ExamplesTableUpdateCompanionBuilder =
    ExamplesCompanion Function({
      Value<int> id,
      Value<String> sentence,
      Value<String?> sourceTitle,
    });

final class $$ExamplesTableReferences
    extends BaseReferences<_$AppDatabase, $ExamplesTable, ExampleRow> {
  $$ExamplesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CardExamplesTable, List<CardExampleRow>>
  _cardExamplesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.cardExamples,
    aliasName: $_aliasNameGenerator(db.examples.id, db.cardExamples.exampleId),
  );

  $$CardExamplesTableProcessedTableManager get cardExamplesRefs {
    final manager = $$CardExamplesTableTableManager(
      $_db,
      $_db.cardExamples,
    ).filter((f) => f.exampleId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_cardExamplesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ExamplesTableFilterComposer
    extends Composer<_$AppDatabase, $ExamplesTable> {
  $$ExamplesTableFilterComposer({
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

  ColumnFilters<String> get sentence => $composableBuilder(
    column: $table.sentence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceTitle => $composableBuilder(
    column: $table.sourceTitle,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> cardExamplesRefs(
    Expression<bool> Function($$CardExamplesTableFilterComposer f) f,
  ) {
    final $$CardExamplesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cardExamples,
      getReferencedColumn: (t) => t.exampleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardExamplesTableFilterComposer(
            $db: $db,
            $table: $db.cardExamples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ExamplesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExamplesTable> {
  $$ExamplesTableOrderingComposer({
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

  ColumnOrderings<String> get sentence => $composableBuilder(
    column: $table.sentence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceTitle => $composableBuilder(
    column: $table.sourceTitle,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExamplesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExamplesTable> {
  $$ExamplesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sentence =>
      $composableBuilder(column: $table.sentence, builder: (column) => column);

  GeneratedColumn<String> get sourceTitle => $composableBuilder(
    column: $table.sourceTitle,
    builder: (column) => column,
  );

  Expression<T> cardExamplesRefs<T extends Object>(
    Expression<T> Function($$CardExamplesTableAnnotationComposer a) f,
  ) {
    final $$CardExamplesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cardExamples,
      getReferencedColumn: (t) => t.exampleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardExamplesTableAnnotationComposer(
            $db: $db,
            $table: $db.cardExamples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ExamplesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExamplesTable,
          ExampleRow,
          $$ExamplesTableFilterComposer,
          $$ExamplesTableOrderingComposer,
          $$ExamplesTableAnnotationComposer,
          $$ExamplesTableCreateCompanionBuilder,
          $$ExamplesTableUpdateCompanionBuilder,
          (ExampleRow, $$ExamplesTableReferences),
          ExampleRow,
          PrefetchHooks Function({bool cardExamplesRefs})
        > {
  $$ExamplesTableTableManager(_$AppDatabase db, $ExamplesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExamplesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExamplesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExamplesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sentence = const Value.absent(),
                Value<String?> sourceTitle = const Value.absent(),
              }) => ExamplesCompanion(
                id: id,
                sentence: sentence,
                sourceTitle: sourceTitle,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sentence,
                Value<String?> sourceTitle = const Value.absent(),
              }) => ExamplesCompanion.insert(
                id: id,
                sentence: sentence,
                sourceTitle: sourceTitle,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ExamplesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cardExamplesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (cardExamplesRefs) db.cardExamples],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (cardExamplesRefs)
                    await $_getPrefetchedData<
                      ExampleRow,
                      $ExamplesTable,
                      CardExampleRow
                    >(
                      currentTable: table,
                      referencedTable: $$ExamplesTableReferences
                          ._cardExamplesRefsTable(db),
                      managerFromTypedResult: (p0) => $$ExamplesTableReferences(
                        db,
                        table,
                        p0,
                      ).cardExamplesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.exampleId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ExamplesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExamplesTable,
      ExampleRow,
      $$ExamplesTableFilterComposer,
      $$ExamplesTableOrderingComposer,
      $$ExamplesTableAnnotationComposer,
      $$ExamplesTableCreateCompanionBuilder,
      $$ExamplesTableUpdateCompanionBuilder,
      (ExampleRow, $$ExamplesTableReferences),
      ExampleRow,
      PrefetchHooks Function({bool cardExamplesRefs})
    >;
typedef $$CardExamplesTableCreateCompanionBuilder =
    CardExamplesCompanion Function({
      required int cardId,
      required int exampleId,
      Value<int> rowid,
    });
typedef $$CardExamplesTableUpdateCompanionBuilder =
    CardExamplesCompanion Function({
      Value<int> cardId,
      Value<int> exampleId,
      Value<int> rowid,
    });

final class $$CardExamplesTableReferences
    extends BaseReferences<_$AppDatabase, $CardExamplesTable, CardExampleRow> {
  $$CardExamplesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CardsTable _cardIdTable(_$AppDatabase db) => db.cards.createAlias(
    $_aliasNameGenerator(db.cardExamples.cardId, db.cards.id),
  );

  $$CardsTableProcessedTableManager get cardId {
    final $_column = $_itemColumn<int>('card_id')!;

    final manager = $$CardsTableTableManager(
      $_db,
      $_db.cards,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cardIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ExamplesTable _exampleIdTable(_$AppDatabase db) =>
      db.examples.createAlias(
        $_aliasNameGenerator(db.cardExamples.exampleId, db.examples.id),
      );

  $$ExamplesTableProcessedTableManager get exampleId {
    final $_column = $_itemColumn<int>('example_id')!;

    final manager = $$ExamplesTableTableManager(
      $_db,
      $_db.examples,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_exampleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CardExamplesTableFilterComposer
    extends Composer<_$AppDatabase, $CardExamplesTable> {
  $$CardExamplesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$CardsTableFilterComposer get cardId {
    final $$CardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableFilterComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExamplesTableFilterComposer get exampleId {
    final $$ExamplesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exampleId,
      referencedTable: $db.examples,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExamplesTableFilterComposer(
            $db: $db,
            $table: $db.examples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardExamplesTableOrderingComposer
    extends Composer<_$AppDatabase, $CardExamplesTable> {
  $$CardExamplesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$CardsTableOrderingComposer get cardId {
    final $$CardsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableOrderingComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExamplesTableOrderingComposer get exampleId {
    final $$ExamplesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exampleId,
      referencedTable: $db.examples,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExamplesTableOrderingComposer(
            $db: $db,
            $table: $db.examples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardExamplesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CardExamplesTable> {
  $$CardExamplesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$CardsTableAnnotationComposer get cardId {
    final $$CardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableAnnotationComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExamplesTableAnnotationComposer get exampleId {
    final $$ExamplesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exampleId,
      referencedTable: $db.examples,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExamplesTableAnnotationComposer(
            $db: $db,
            $table: $db.examples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardExamplesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CardExamplesTable,
          CardExampleRow,
          $$CardExamplesTableFilterComposer,
          $$CardExamplesTableOrderingComposer,
          $$CardExamplesTableAnnotationComposer,
          $$CardExamplesTableCreateCompanionBuilder,
          $$CardExamplesTableUpdateCompanionBuilder,
          (CardExampleRow, $$CardExamplesTableReferences),
          CardExampleRow,
          PrefetchHooks Function({bool cardId, bool exampleId})
        > {
  $$CardExamplesTableTableManager(_$AppDatabase db, $CardExamplesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardExamplesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardExamplesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardExamplesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> cardId = const Value.absent(),
                Value<int> exampleId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CardExamplesCompanion(
                cardId: cardId,
                exampleId: exampleId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int cardId,
                required int exampleId,
                Value<int> rowid = const Value.absent(),
              }) => CardExamplesCompanion.insert(
                cardId: cardId,
                exampleId: exampleId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CardExamplesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cardId = false, exampleId = false}) {
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
                    if (cardId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.cardId,
                                referencedTable: $$CardExamplesTableReferences
                                    ._cardIdTable(db),
                                referencedColumn: $$CardExamplesTableReferences
                                    ._cardIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (exampleId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.exampleId,
                                referencedTable: $$CardExamplesTableReferences
                                    ._exampleIdTable(db),
                                referencedColumn: $$CardExamplesTableReferences
                                    ._exampleIdTable(db)
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

typedef $$CardExamplesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CardExamplesTable,
      CardExampleRow,
      $$CardExamplesTableFilterComposer,
      $$CardExamplesTableOrderingComposer,
      $$CardExamplesTableAnnotationComposer,
      $$CardExamplesTableCreateCompanionBuilder,
      $$CardExamplesTableUpdateCompanionBuilder,
      (CardExampleRow, $$CardExamplesTableReferences),
      CardExampleRow,
      PrefetchHooks Function({bool cardId, bool exampleId})
    >;
typedef $$UserCardsTableCreateCompanionBuilder =
    UserCardsCompanion Function({
      Value<int> cardId,
      Value<int> level,
      Value<double> ease,
      Value<int> intervalMinutes,
      Value<DateTime?> lastReviewed,
      required DateTime nextDue,
      required DateTime obtainedAt,
      Value<bool> isNew,
      Value<int> failCount,
      Value<bool> suspended,
    });
typedef $$UserCardsTableUpdateCompanionBuilder =
    UserCardsCompanion Function({
      Value<int> cardId,
      Value<int> level,
      Value<double> ease,
      Value<int> intervalMinutes,
      Value<DateTime?> lastReviewed,
      Value<DateTime> nextDue,
      Value<DateTime> obtainedAt,
      Value<bool> isNew,
      Value<int> failCount,
      Value<bool> suspended,
    });

final class $$UserCardsTableReferences
    extends BaseReferences<_$AppDatabase, $UserCardsTable, UserCardRow> {
  $$UserCardsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CardsTable _cardIdTable(_$AppDatabase db) => db.cards.createAlias(
    $_aliasNameGenerator(db.userCards.cardId, db.cards.id),
  );

  $$CardsTableProcessedTableManager get cardId {
    final $_column = $_itemColumn<int>('card_id')!;

    final manager = $$CardsTableTableManager(
      $_db,
      $_db.cards,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cardIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$UserCardsTableFilterComposer
    extends Composer<_$AppDatabase, $UserCardsTable> {
  $$UserCardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ease => $composableBuilder(
    column: $table.ease,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get intervalMinutes => $composableBuilder(
    column: $table.intervalMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastReviewed => $composableBuilder(
    column: $table.lastReviewed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextDue => $composableBuilder(
    column: $table.nextDue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get obtainedAt => $composableBuilder(
    column: $table.obtainedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isNew => $composableBuilder(
    column: $table.isNew,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get failCount => $composableBuilder(
    column: $table.failCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get suspended => $composableBuilder(
    column: $table.suspended,
    builder: (column) => ColumnFilters(column),
  );

  $$CardsTableFilterComposer get cardId {
    final $$CardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableFilterComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UserCardsTableOrderingComposer
    extends Composer<_$AppDatabase, $UserCardsTable> {
  $$UserCardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ease => $composableBuilder(
    column: $table.ease,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intervalMinutes => $composableBuilder(
    column: $table.intervalMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastReviewed => $composableBuilder(
    column: $table.lastReviewed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextDue => $composableBuilder(
    column: $table.nextDue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get obtainedAt => $composableBuilder(
    column: $table.obtainedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isNew => $composableBuilder(
    column: $table.isNew,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get failCount => $composableBuilder(
    column: $table.failCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get suspended => $composableBuilder(
    column: $table.suspended,
    builder: (column) => ColumnOrderings(column),
  );

  $$CardsTableOrderingComposer get cardId {
    final $$CardsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableOrderingComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UserCardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserCardsTable> {
  $$UserCardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<double> get ease =>
      $composableBuilder(column: $table.ease, builder: (column) => column);

  GeneratedColumn<int> get intervalMinutes => $composableBuilder(
    column: $table.intervalMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastReviewed => $composableBuilder(
    column: $table.lastReviewed,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextDue =>
      $composableBuilder(column: $table.nextDue, builder: (column) => column);

  GeneratedColumn<DateTime> get obtainedAt => $composableBuilder(
    column: $table.obtainedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isNew =>
      $composableBuilder(column: $table.isNew, builder: (column) => column);

  GeneratedColumn<int> get failCount =>
      $composableBuilder(column: $table.failCount, builder: (column) => column);

  GeneratedColumn<bool> get suspended =>
      $composableBuilder(column: $table.suspended, builder: (column) => column);

  $$CardsTableAnnotationComposer get cardId {
    final $$CardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableAnnotationComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UserCardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserCardsTable,
          UserCardRow,
          $$UserCardsTableFilterComposer,
          $$UserCardsTableOrderingComposer,
          $$UserCardsTableAnnotationComposer,
          $$UserCardsTableCreateCompanionBuilder,
          $$UserCardsTableUpdateCompanionBuilder,
          (UserCardRow, $$UserCardsTableReferences),
          UserCardRow,
          PrefetchHooks Function({bool cardId})
        > {
  $$UserCardsTableTableManager(_$AppDatabase db, $UserCardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserCardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserCardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserCardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> cardId = const Value.absent(),
                Value<int> level = const Value.absent(),
                Value<double> ease = const Value.absent(),
                Value<int> intervalMinutes = const Value.absent(),
                Value<DateTime?> lastReviewed = const Value.absent(),
                Value<DateTime> nextDue = const Value.absent(),
                Value<DateTime> obtainedAt = const Value.absent(),
                Value<bool> isNew = const Value.absent(),
                Value<int> failCount = const Value.absent(),
                Value<bool> suspended = const Value.absent(),
              }) => UserCardsCompanion(
                cardId: cardId,
                level: level,
                ease: ease,
                intervalMinutes: intervalMinutes,
                lastReviewed: lastReviewed,
                nextDue: nextDue,
                obtainedAt: obtainedAt,
                isNew: isNew,
                failCount: failCount,
                suspended: suspended,
              ),
          createCompanionCallback:
              ({
                Value<int> cardId = const Value.absent(),
                Value<int> level = const Value.absent(),
                Value<double> ease = const Value.absent(),
                Value<int> intervalMinutes = const Value.absent(),
                Value<DateTime?> lastReviewed = const Value.absent(),
                required DateTime nextDue,
                required DateTime obtainedAt,
                Value<bool> isNew = const Value.absent(),
                Value<int> failCount = const Value.absent(),
                Value<bool> suspended = const Value.absent(),
              }) => UserCardsCompanion.insert(
                cardId: cardId,
                level: level,
                ease: ease,
                intervalMinutes: intervalMinutes,
                lastReviewed: lastReviewed,
                nextDue: nextDue,
                obtainedAt: obtainedAt,
                isNew: isNew,
                failCount: failCount,
                suspended: suspended,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$UserCardsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cardId = false}) {
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
                    if (cardId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.cardId,
                                referencedTable: $$UserCardsTableReferences
                                    ._cardIdTable(db),
                                referencedColumn: $$UserCardsTableReferences
                                    ._cardIdTable(db)
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

typedef $$UserCardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserCardsTable,
      UserCardRow,
      $$UserCardsTableFilterComposer,
      $$UserCardsTableOrderingComposer,
      $$UserCardsTableAnnotationComposer,
      $$UserCardsTableCreateCompanionBuilder,
      $$UserCardsTableUpdateCompanionBuilder,
      (UserCardRow, $$UserCardsTableReferences),
      UserCardRow,
      PrefetchHooks Function({bool cardId})
    >;
typedef $$MetaTableCreateCompanionBuilder =
    MetaCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$MetaTableUpdateCompanionBuilder =
    MetaCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$MetaTableFilterComposer extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MetaTableOrderingComposer extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$MetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MetaTable,
          MetaRow,
          $$MetaTableFilterComposer,
          $$MetaTableOrderingComposer,
          $$MetaTableAnnotationComposer,
          $$MetaTableCreateCompanionBuilder,
          $$MetaTableUpdateCompanionBuilder,
          (MetaRow, BaseReferences<_$AppDatabase, $MetaTable, MetaRow>),
          MetaRow,
          PrefetchHooks Function()
        > {
  $$MetaTableTableManager(_$AppDatabase db, $MetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => MetaCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MetaTable,
      MetaRow,
      $$MetaTableFilterComposer,
      $$MetaTableOrderingComposer,
      $$MetaTableAnnotationComposer,
      $$MetaTableCreateCompanionBuilder,
      $$MetaTableUpdateCompanionBuilder,
      (MetaRow, BaseReferences<_$AppDatabase, $MetaTable, MetaRow>),
      MetaRow,
      PrefetchHooks Function()
    >;
typedef $$WishlistTableCreateCompanionBuilder =
    WishlistCompanion Function({Value<int> cardId, required DateTime addedAt});
typedef $$WishlistTableUpdateCompanionBuilder =
    WishlistCompanion Function({Value<int> cardId, Value<DateTime> addedAt});

final class $$WishlistTableReferences
    extends BaseReferences<_$AppDatabase, $WishlistTable, WishlistRow> {
  $$WishlistTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CardsTable _cardIdTable(_$AppDatabase db) => db.cards.createAlias(
    $_aliasNameGenerator(db.wishlist.cardId, db.cards.id),
  );

  $$CardsTableProcessedTableManager get cardId {
    final $_column = $_itemColumn<int>('card_id')!;

    final manager = $$CardsTableTableManager(
      $_db,
      $_db.cards,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cardIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WishlistTableFilterComposer
    extends Composer<_$AppDatabase, $WishlistTable> {
  $$WishlistTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CardsTableFilterComposer get cardId {
    final $$CardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableFilterComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WishlistTableOrderingComposer
    extends Composer<_$AppDatabase, $WishlistTable> {
  $$WishlistTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CardsTableOrderingComposer get cardId {
    final $$CardsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableOrderingComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WishlistTableAnnotationComposer
    extends Composer<_$AppDatabase, $WishlistTable> {
  $$WishlistTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$CardsTableAnnotationComposer get cardId {
    final $$CardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableAnnotationComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WishlistTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WishlistTable,
          WishlistRow,
          $$WishlistTableFilterComposer,
          $$WishlistTableOrderingComposer,
          $$WishlistTableAnnotationComposer,
          $$WishlistTableCreateCompanionBuilder,
          $$WishlistTableUpdateCompanionBuilder,
          (WishlistRow, $$WishlistTableReferences),
          WishlistRow,
          PrefetchHooks Function({bool cardId})
        > {
  $$WishlistTableTableManager(_$AppDatabase db, $WishlistTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WishlistTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WishlistTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WishlistTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> cardId = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
              }) => WishlistCompanion(cardId: cardId, addedAt: addedAt),
          createCompanionCallback:
              ({
                Value<int> cardId = const Value.absent(),
                required DateTime addedAt,
              }) => WishlistCompanion.insert(cardId: cardId, addedAt: addedAt),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WishlistTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cardId = false}) {
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
                    if (cardId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.cardId,
                                referencedTable: $$WishlistTableReferences
                                    ._cardIdTable(db),
                                referencedColumn: $$WishlistTableReferences
                                    ._cardIdTable(db)
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

typedef $$WishlistTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WishlistTable,
      WishlistRow,
      $$WishlistTableFilterComposer,
      $$WishlistTableOrderingComposer,
      $$WishlistTableAnnotationComposer,
      $$WishlistTableCreateCompanionBuilder,
      $$WishlistTableUpdateCompanionBuilder,
      (WishlistRow, $$WishlistTableReferences),
      WishlistRow,
      PrefetchHooks Function({bool cardId})
    >;
typedef $$DailyStatsTableCreateCompanionBuilder =
    DailyStatsCompanion Function({
      required String date,
      Value<int> cTotal,
      Value<int> cCorrect,
      Value<int> rTotal,
      Value<int> rCorrect,
      Value<int> srTotal,
      Value<int> srCorrect,
      Value<int> ssrTotal,
      Value<int> ssrCorrect,
      Value<int> urTotal,
      Value<int> urCorrect,
      Value<int> newCards,
      Value<int> rowid,
    });
typedef $$DailyStatsTableUpdateCompanionBuilder =
    DailyStatsCompanion Function({
      Value<String> date,
      Value<int> cTotal,
      Value<int> cCorrect,
      Value<int> rTotal,
      Value<int> rCorrect,
      Value<int> srTotal,
      Value<int> srCorrect,
      Value<int> ssrTotal,
      Value<int> ssrCorrect,
      Value<int> urTotal,
      Value<int> urCorrect,
      Value<int> newCards,
      Value<int> rowid,
    });

class $$DailyStatsTableFilterComposer
    extends Composer<_$AppDatabase, $DailyStatsTable> {
  $$DailyStatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cTotal => $composableBuilder(
    column: $table.cTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cCorrect => $composableBuilder(
    column: $table.cCorrect,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rTotal => $composableBuilder(
    column: $table.rTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rCorrect => $composableBuilder(
    column: $table.rCorrect,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get srTotal => $composableBuilder(
    column: $table.srTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get srCorrect => $composableBuilder(
    column: $table.srCorrect,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ssrTotal => $composableBuilder(
    column: $table.ssrTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ssrCorrect => $composableBuilder(
    column: $table.ssrCorrect,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get urTotal => $composableBuilder(
    column: $table.urTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get urCorrect => $composableBuilder(
    column: $table.urCorrect,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get newCards => $composableBuilder(
    column: $table.newCards,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DailyStatsTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyStatsTable> {
  $$DailyStatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cTotal => $composableBuilder(
    column: $table.cTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cCorrect => $composableBuilder(
    column: $table.cCorrect,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rTotal => $composableBuilder(
    column: $table.rTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rCorrect => $composableBuilder(
    column: $table.rCorrect,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get srTotal => $composableBuilder(
    column: $table.srTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get srCorrect => $composableBuilder(
    column: $table.srCorrect,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ssrTotal => $composableBuilder(
    column: $table.ssrTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ssrCorrect => $composableBuilder(
    column: $table.ssrCorrect,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get urTotal => $composableBuilder(
    column: $table.urTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get urCorrect => $composableBuilder(
    column: $table.urCorrect,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get newCards => $composableBuilder(
    column: $table.newCards,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DailyStatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyStatsTable> {
  $$DailyStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get cTotal =>
      $composableBuilder(column: $table.cTotal, builder: (column) => column);

  GeneratedColumn<int> get cCorrect =>
      $composableBuilder(column: $table.cCorrect, builder: (column) => column);

  GeneratedColumn<int> get rTotal =>
      $composableBuilder(column: $table.rTotal, builder: (column) => column);

  GeneratedColumn<int> get rCorrect =>
      $composableBuilder(column: $table.rCorrect, builder: (column) => column);

  GeneratedColumn<int> get srTotal =>
      $composableBuilder(column: $table.srTotal, builder: (column) => column);

  GeneratedColumn<int> get srCorrect =>
      $composableBuilder(column: $table.srCorrect, builder: (column) => column);

  GeneratedColumn<int> get ssrTotal =>
      $composableBuilder(column: $table.ssrTotal, builder: (column) => column);

  GeneratedColumn<int> get ssrCorrect => $composableBuilder(
    column: $table.ssrCorrect,
    builder: (column) => column,
  );

  GeneratedColumn<int> get urTotal =>
      $composableBuilder(column: $table.urTotal, builder: (column) => column);

  GeneratedColumn<int> get urCorrect =>
      $composableBuilder(column: $table.urCorrect, builder: (column) => column);

  GeneratedColumn<int> get newCards =>
      $composableBuilder(column: $table.newCards, builder: (column) => column);
}

class $$DailyStatsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailyStatsTable,
          DailyStatRow,
          $$DailyStatsTableFilterComposer,
          $$DailyStatsTableOrderingComposer,
          $$DailyStatsTableAnnotationComposer,
          $$DailyStatsTableCreateCompanionBuilder,
          $$DailyStatsTableUpdateCompanionBuilder,
          (
            DailyStatRow,
            BaseReferences<_$AppDatabase, $DailyStatsTable, DailyStatRow>,
          ),
          DailyStatRow,
          PrefetchHooks Function()
        > {
  $$DailyStatsTableTableManager(_$AppDatabase db, $DailyStatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyStatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> date = const Value.absent(),
                Value<int> cTotal = const Value.absent(),
                Value<int> cCorrect = const Value.absent(),
                Value<int> rTotal = const Value.absent(),
                Value<int> rCorrect = const Value.absent(),
                Value<int> srTotal = const Value.absent(),
                Value<int> srCorrect = const Value.absent(),
                Value<int> ssrTotal = const Value.absent(),
                Value<int> ssrCorrect = const Value.absent(),
                Value<int> urTotal = const Value.absent(),
                Value<int> urCorrect = const Value.absent(),
                Value<int> newCards = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyStatsCompanion(
                date: date,
                cTotal: cTotal,
                cCorrect: cCorrect,
                rTotal: rTotal,
                rCorrect: rCorrect,
                srTotal: srTotal,
                srCorrect: srCorrect,
                ssrTotal: ssrTotal,
                ssrCorrect: ssrCorrect,
                urTotal: urTotal,
                urCorrect: urCorrect,
                newCards: newCards,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String date,
                Value<int> cTotal = const Value.absent(),
                Value<int> cCorrect = const Value.absent(),
                Value<int> rTotal = const Value.absent(),
                Value<int> rCorrect = const Value.absent(),
                Value<int> srTotal = const Value.absent(),
                Value<int> srCorrect = const Value.absent(),
                Value<int> ssrTotal = const Value.absent(),
                Value<int> ssrCorrect = const Value.absent(),
                Value<int> urTotal = const Value.absent(),
                Value<int> urCorrect = const Value.absent(),
                Value<int> newCards = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyStatsCompanion.insert(
                date: date,
                cTotal: cTotal,
                cCorrect: cCorrect,
                rTotal: rTotal,
                rCorrect: rCorrect,
                srTotal: srTotal,
                srCorrect: srCorrect,
                ssrTotal: ssrTotal,
                ssrCorrect: ssrCorrect,
                urTotal: urTotal,
                urCorrect: urCorrect,
                newCards: newCards,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DailyStatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailyStatsTable,
      DailyStatRow,
      $$DailyStatsTableFilterComposer,
      $$DailyStatsTableOrderingComposer,
      $$DailyStatsTableAnnotationComposer,
      $$DailyStatsTableCreateCompanionBuilder,
      $$DailyStatsTableUpdateCompanionBuilder,
      (
        DailyStatRow,
        BaseReferences<_$AppDatabase, $DailyStatsTable, DailyStatRow>,
      ),
      DailyStatRow,
      PrefetchHooks Function()
    >;
typedef $$ReviewLogTableCreateCompanionBuilder =
    ReviewLogCompanion Function({
      Value<int> id,
      required DateTime reviewedAt,
      required int prevIntervalMinutes,
      required bool correct,
      required int rarity,
      Value<ReviewKind> kind,
      Value<int?> durationMs,
    });
typedef $$ReviewLogTableUpdateCompanionBuilder =
    ReviewLogCompanion Function({
      Value<int> id,
      Value<DateTime> reviewedAt,
      Value<int> prevIntervalMinutes,
      Value<bool> correct,
      Value<int> rarity,
      Value<ReviewKind> kind,
      Value<int?> durationMs,
    });

class $$ReviewLogTableFilterComposer
    extends Composer<_$AppDatabase, $ReviewLogTable> {
  $$ReviewLogTableFilterComposer({
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

  ColumnFilters<DateTime> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get prevIntervalMinutes => $composableBuilder(
    column: $table.prevIntervalMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rarity => $composableBuilder(
    column: $table.rarity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ReviewKind, ReviewKind, int> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReviewLogTableOrderingComposer
    extends Composer<_$AppDatabase, $ReviewLogTable> {
  $$ReviewLogTableOrderingComposer({
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

  ColumnOrderings<DateTime> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get prevIntervalMinutes => $composableBuilder(
    column: $table.prevIntervalMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rarity => $composableBuilder(
    column: $table.rarity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReviewLogTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReviewLogTable> {
  $$ReviewLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get prevIntervalMinutes => $composableBuilder(
    column: $table.prevIntervalMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get correct =>
      $composableBuilder(column: $table.correct, builder: (column) => column);

  GeneratedColumn<int> get rarity =>
      $composableBuilder(column: $table.rarity, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ReviewKind, int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );
}

class $$ReviewLogTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReviewLogTable,
          ReviewLogRow,
          $$ReviewLogTableFilterComposer,
          $$ReviewLogTableOrderingComposer,
          $$ReviewLogTableAnnotationComposer,
          $$ReviewLogTableCreateCompanionBuilder,
          $$ReviewLogTableUpdateCompanionBuilder,
          (
            ReviewLogRow,
            BaseReferences<_$AppDatabase, $ReviewLogTable, ReviewLogRow>,
          ),
          ReviewLogRow,
          PrefetchHooks Function()
        > {
  $$ReviewLogTableTableManager(_$AppDatabase db, $ReviewLogTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReviewLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReviewLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReviewLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> reviewedAt = const Value.absent(),
                Value<int> prevIntervalMinutes = const Value.absent(),
                Value<bool> correct = const Value.absent(),
                Value<int> rarity = const Value.absent(),
                Value<ReviewKind> kind = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
              }) => ReviewLogCompanion(
                id: id,
                reviewedAt: reviewedAt,
                prevIntervalMinutes: prevIntervalMinutes,
                correct: correct,
                rarity: rarity,
                kind: kind,
                durationMs: durationMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime reviewedAt,
                required int prevIntervalMinutes,
                required bool correct,
                required int rarity,
                Value<ReviewKind> kind = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
              }) => ReviewLogCompanion.insert(
                id: id,
                reviewedAt: reviewedAt,
                prevIntervalMinutes: prevIntervalMinutes,
                correct: correct,
                rarity: rarity,
                kind: kind,
                durationMs: durationMs,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReviewLogTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReviewLogTable,
      ReviewLogRow,
      $$ReviewLogTableFilterComposer,
      $$ReviewLogTableOrderingComposer,
      $$ReviewLogTableAnnotationComposer,
      $$ReviewLogTableCreateCompanionBuilder,
      $$ReviewLogTableUpdateCompanionBuilder,
      (
        ReviewLogRow,
        BaseReferences<_$AppDatabase, $ReviewLogTable, ReviewLogRow>,
      ),
      ReviewLogRow,
      PrefetchHooks Function()
    >;
typedef $$PacksTableCreateCompanionBuilder =
    PacksCompanion Function({
      required String name,
      required String label,
      Value<String> description,
      Value<String?> sourceTitle,
      Value<String?> sourceUrl,
      Value<String?> sourceAuthor,
      Value<String?> license,
      required String version,
      Value<int> cardCount,
      required DateTime installedAt,
      Value<int> rowid,
    });
typedef $$PacksTableUpdateCompanionBuilder =
    PacksCompanion Function({
      Value<String> name,
      Value<String> label,
      Value<String> description,
      Value<String?> sourceTitle,
      Value<String?> sourceUrl,
      Value<String?> sourceAuthor,
      Value<String?> license,
      Value<String> version,
      Value<int> cardCount,
      Value<DateTime> installedAt,
      Value<int> rowid,
    });

class $$PacksTableFilterComposer extends Composer<_$AppDatabase, $PacksTable> {
  $$PacksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceTitle => $composableBuilder(
    column: $table.sourceTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceAuthor => $composableBuilder(
    column: $table.sourceAuthor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get license => $composableBuilder(
    column: $table.license,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cardCount => $composableBuilder(
    column: $table.cardCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PacksTableOrderingComposer
    extends Composer<_$AppDatabase, $PacksTable> {
  $$PacksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceTitle => $composableBuilder(
    column: $table.sourceTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceAuthor => $composableBuilder(
    column: $table.sourceAuthor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get license => $composableBuilder(
    column: $table.license,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cardCount => $composableBuilder(
    column: $table.cardCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PacksTableAnnotationComposer
    extends Composer<_$AppDatabase, $PacksTable> {
  $$PacksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceTitle => $composableBuilder(
    column: $table.sourceTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get sourceAuthor => $composableBuilder(
    column: $table.sourceAuthor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get license =>
      $composableBuilder(column: $table.license, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get cardCount =>
      $composableBuilder(column: $table.cardCount, builder: (column) => column);

  GeneratedColumn<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => column,
  );
}

class $$PacksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PacksTable,
          PackRow,
          $$PacksTableFilterComposer,
          $$PacksTableOrderingComposer,
          $$PacksTableAnnotationComposer,
          $$PacksTableCreateCompanionBuilder,
          $$PacksTableUpdateCompanionBuilder,
          (PackRow, BaseReferences<_$AppDatabase, $PacksTable, PackRow>),
          PackRow,
          PrefetchHooks Function()
        > {
  $$PacksTableTableManager(_$AppDatabase db, $PacksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PacksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PacksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PacksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> name = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String?> sourceTitle = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<String?> sourceAuthor = const Value.absent(),
                Value<String?> license = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<int> cardCount = const Value.absent(),
                Value<DateTime> installedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PacksCompanion(
                name: name,
                label: label,
                description: description,
                sourceTitle: sourceTitle,
                sourceUrl: sourceUrl,
                sourceAuthor: sourceAuthor,
                license: license,
                version: version,
                cardCount: cardCount,
                installedAt: installedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String name,
                required String label,
                Value<String> description = const Value.absent(),
                Value<String?> sourceTitle = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<String?> sourceAuthor = const Value.absent(),
                Value<String?> license = const Value.absent(),
                required String version,
                Value<int> cardCount = const Value.absent(),
                required DateTime installedAt,
                Value<int> rowid = const Value.absent(),
              }) => PacksCompanion.insert(
                name: name,
                label: label,
                description: description,
                sourceTitle: sourceTitle,
                sourceUrl: sourceUrl,
                sourceAuthor: sourceAuthor,
                license: license,
                version: version,
                cardCount: cardCount,
                installedAt: installedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PacksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PacksTable,
      PackRow,
      $$PacksTableFilterComposer,
      $$PacksTableOrderingComposer,
      $$PacksTableAnnotationComposer,
      $$PacksTableCreateCompanionBuilder,
      $$PacksTableUpdateCompanionBuilder,
      (PackRow, BaseReferences<_$AppDatabase, $PacksTable, PackRow>),
      PackRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CardsTableTableManager get cards =>
      $$CardsTableTableManager(_db, _db.cards);
  $$CardSensesTableTableManager get cardSenses =>
      $$CardSensesTableTableManager(_db, _db.cardSenses);
  $$ExamplesTableTableManager get examples =>
      $$ExamplesTableTableManager(_db, _db.examples);
  $$CardExamplesTableTableManager get cardExamples =>
      $$CardExamplesTableTableManager(_db, _db.cardExamples);
  $$UserCardsTableTableManager get userCards =>
      $$UserCardsTableTableManager(_db, _db.userCards);
  $$MetaTableTableManager get meta => $$MetaTableTableManager(_db, _db.meta);
  $$WishlistTableTableManager get wishlist =>
      $$WishlistTableTableManager(_db, _db.wishlist);
  $$DailyStatsTableTableManager get dailyStats =>
      $$DailyStatsTableTableManager(_db, _db.dailyStats);
  $$ReviewLogTableTableManager get reviewLog =>
      $$ReviewLogTableTableManager(_db, _db.reviewLog);
  $$PacksTableTableManager get packs =>
      $$PacksTableTableManager(_db, _db.packs);
}
