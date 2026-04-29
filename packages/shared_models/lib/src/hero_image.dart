/// On-device hero image metadata for a trip (M89, ADR-134).
///
/// A hero image is the single best representative photo per trip as determined
/// by the on-device Vision labelling pipeline. Original photo bytes are never
/// stored — only metadata and normalised labels.
///
/// [assetId] is a PHAsset.localIdentifier. It is stored in local SQLite only
/// and must never appear in Firestore (extends ADR-002, ADR-060).
library;

/// Structured labels derived from Vision VNClassifyImageRequest.
///
/// All fields are nullable because labelling may not have run yet, or a
/// candidate may not have received a confident-enough classification.
/// Raw ML identifiers are never stored — all values use the Roavvy vocabulary
/// (normalised by LabelNormalizer.swift before crossing the MethodChannel).
class HeroLabels {
  const HeroLabels({
    this.primaryScene,
    this.secondaryScene,
    this.activity = const [],
    this.mood = const [],
    this.subjects = const [],
    this.landmark,
    this.confidence = 0.0,
  });

  /// Primary scene: beach, city, mountain, island, desert, forest, snow,
  /// lake, coast, countryside.
  final String? primaryScene;

  /// Secondary scene (same vocabulary as primaryScene).
  final String? secondaryScene;

  /// Activity labels: hiking, skiing, boat, roadtrip, food.
  final List<String> activity;

  /// Mood/lighting labels: sunset, sunrise, golden_hour, night.
  final List<String> mood;

  /// Subject labels: people, group, selfie, landmark, architecture, food.
  final List<String> subjects;

  /// Named landmark (reserved for future milestone; always null in M89).
  final String? landmark;

  /// Highest raw confidence score observed across all labels for this image.
  final double confidence;

  /// Constructs from a JSON map returned by the MethodChannel.
  factory HeroLabels.fromJson(Map<Object?, Object?> json) {
    List<String> parseList(Object? value) {
      if (value == null) return const [];
      if (value is List) return value.whereType<String>().toList();
      return const [];
    }

    return HeroLabels(
      primaryScene: json['primaryScene'] as String?,
      secondaryScene: json['secondaryScene'] as String?,
      activity: parseList(json['activity']),
      mood: parseList(json['mood']),
      subjects: parseList(json['subjects']),
      landmark: json['landmark'] as String?,
      confidence: (json['labelConfidence'] as num? ?? 0.0).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeroLabels &&
          runtimeType == other.runtimeType &&
          primaryScene == other.primaryScene &&
          secondaryScene == other.secondaryScene &&
          _listEq(activity, other.activity) &&
          _listEq(mood, other.mood) &&
          _listEq(subjects, other.subjects) &&
          landmark == other.landmark &&
          confidence == other.confidence;

  @override
  int get hashCode => Object.hash(
        primaryScene,
        secondaryScene,
        Object.hashAll(activity),
        Object.hashAll(mood),
        Object.hashAll(subjects),
        landmark,
        confidence,
      );

  static bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'HeroLabels(primaryScene: $primaryScene, mood: $mood, confidence: $confidence)';
}

/// Raw analysis result returned from the Swift MethodChannel per candidate
/// image before scoring and ranking.
///
/// The [qualityScore] and [hasGps] fields come from the Swift side's quality
/// analysis; [pixelWidth] and [pixelHeight] are photo metadata.
class HeroAnalysisResult {
  const HeroAnalysisResult({
    required this.assetId,
    required this.capturedAt,
    required this.labels,
    required this.qualityScore,
    required this.pixelWidth,
    required this.pixelHeight,
    required this.hasGps,
    required this.tripId,
  });

  /// PHAsset.localIdentifier — device-local only (ADR-060).
  final String assetId;
  final DateTime capturedAt;
  final HeroLabels labels;

  /// Normalised quality score 0.0–1.0 from Swift-side apertureScore / dimensions.
  final double qualityScore;
  final int pixelWidth;
  final int pixelHeight;
  final bool hasGps;

  /// Trip ID this candidate belongs to (passed in by Dart side, echoed back).
  final String tripId;

  /// Constructs from a JSON map returned by the MethodChannel.
  factory HeroAnalysisResult.fromJson(Map<Object?, Object?> json) {
    return HeroAnalysisResult(
      assetId: json['assetId'] as String,
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      labels: HeroLabels.fromJson(
        (json['labels'] as Map<Object?, Object?>?) ?? {},
      ),
      qualityScore: (json['qualityScore'] as num? ?? 0.0).toDouble(),
      pixelWidth: (json['pixelWidth'] as int? ?? 0),
      pixelHeight: (json['pixelHeight'] as int? ?? 0),
      hasGps: (json['hasGps'] as bool? ?? false),
      tripId: json['tripId'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeroAnalysisResult &&
          runtimeType == other.runtimeType &&
          assetId == other.assetId &&
          tripId == other.tripId;

  @override
  int get hashCode => Object.hash(assetId, tripId);

  @override
  String toString() =>
      'HeroAnalysisResult(assetId: $assetId, tripId: $tripId, '
      'qualityScore: $qualityScore)';
}

/// A persisted hero image record: the selected (or candidate) representative
/// photo for a trip.
///
/// [rank] == 1 is the active hero; rank 2-3 are stored candidates.
/// rank == -1 is a tombstone (assetId no longer available on device).
///
/// [isUserSelected] == true means the user explicitly chose this image; it is
/// never overwritten by automatic re-scanning.
class HeroImage {
  const HeroImage({
    required this.id,
    required this.assetId,
    required this.tripId,
    required this.countryCode,
    required this.capturedAt,
    required this.heroScore,
    required this.rank,
    required this.isUserSelected,
    this.primaryScene,
    this.secondaryScene,
    this.activity = const [],
    this.mood = const [],
    this.subjects = const [],
    this.landmark,
    this.labelConfidence = 0.0,
    this.qualityScore = 0.0,
    this.thumbnailLocalPath,
    required this.createdAt,
    required this.updatedAt,
  });

  /// `"hero_{tripId}"` for rank-1; `"hero_{tripId}_2"` / `"_3"` for candidates.
  final String id;

  /// PHAsset.localIdentifier — device-local only (ADR-060).
  final String assetId;
  final String tripId;
  final String countryCode;
  final DateTime capturedAt;
  final double heroScore;

  /// 1 = selected hero, 2-3 = candidates, -1 = tombstone.
  final int rank;

  /// When true, this row is never overwritten by automatic analysis.
  final bool isUserSelected;

  final String? primaryScene;
  final String? secondaryScene;
  final List<String> activity;
  final List<String> mood;
  final List<String> subjects;
  final String? landmark;
  final double labelConfidence;
  final double qualityScore;

  /// Device-local cache path for a persisted thumbnail; never synced (ADR-002).
  final String? thumbnailLocalPath;

  final DateTime createdAt;
  final DateTime updatedAt;

  HeroImage copyWith({
    String? id,
    String? assetId,
    String? tripId,
    String? countryCode,
    DateTime? capturedAt,
    double? heroScore,
    int? rank,
    bool? isUserSelected,
    String? primaryScene,
    String? secondaryScene,
    List<String>? activity,
    List<String>? mood,
    List<String>? subjects,
    String? landmark,
    double? labelConfidence,
    double? qualityScore,
    String? thumbnailLocalPath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HeroImage(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      tripId: tripId ?? this.tripId,
      countryCode: countryCode ?? this.countryCode,
      capturedAt: capturedAt ?? this.capturedAt,
      heroScore: heroScore ?? this.heroScore,
      rank: rank ?? this.rank,
      isUserSelected: isUserSelected ?? this.isUserSelected,
      primaryScene: primaryScene ?? this.primaryScene,
      secondaryScene: secondaryScene ?? this.secondaryScene,
      activity: activity ?? this.activity,
      mood: mood ?? this.mood,
      subjects: subjects ?? this.subjects,
      landmark: landmark ?? this.landmark,
      labelConfidence: labelConfidence ?? this.labelConfidence,
      qualityScore: qualityScore ?? this.qualityScore,
      thumbnailLocalPath: thumbnailLocalPath ?? this.thumbnailLocalPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// True if this record is a tombstone (asset no longer available on device).
  bool get isTombstone => rank == -1;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeroImage &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          assetId == other.assetId &&
          tripId == other.tripId;

  @override
  int get hashCode => Object.hash(id, assetId, tripId);

  @override
  String toString() =>
      'HeroImage(id: $id, tripId: $tripId, rank: $rank, '
      'primaryScene: $primaryScene, heroScore: $heroScore)';
}
