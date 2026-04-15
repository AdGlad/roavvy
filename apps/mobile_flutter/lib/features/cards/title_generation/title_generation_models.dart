import 'package:shared_models/shared_models.dart';

/// Supported source labels reported in [TitleGenerationResult].
enum TitleSource { ai, fallback }

/// Input to [TitleGenerationService.generate].
class TitleGenerationRequest {
  const TitleGenerationRequest({
    required this.countryCodes,
    required this.countryNames,
    required this.regionNames,
    this.startYear,
    this.endYear,
    required this.cardType,
  });

  final List<String> countryCodes; // ISO 3166-1 alpha-2
  final List<String> countryNames; // human-readable, same order
  final List<String> regionNames; // e.g. ["Europe", "Asia"]
  final int? startYear;
  final int? endYear;
  final CardTemplateType cardType;
}

/// Output of [TitleGenerationService.generate].
class TitleGenerationResult {
  const TitleGenerationResult({
    required this.title,
    required this.source,
  });

  final String title;
  final TitleSource source;
}
