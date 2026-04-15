import 'package:flutter/services.dart';

import 'title_generation_models.dart';
import 'title_generation_service.dart';

/// iOS on-device AI title generator via [MethodChannel].
///
/// Calls the Swift [AiTitlePlugin] over `roavvy/ai_title`. Any
/// [PlatformException] or empty/null response falls back to [_fallback]
/// (ADR-124).
class IosOnDeviceTitleGenerator implements TitleGenerationService {
  IosOnDeviceTitleGenerator({required TitleGenerationService fallback})
      : _fallback = fallback;

  static const _channel = MethodChannel('roavvy/ai_title');
  final TitleGenerationService _fallback;

  @override
  Future<TitleGenerationResult> generate(TitleGenerationRequest request) async {
    try {
      final response = await _channel.invokeMethod<String>(
        'generateTitle',
        {
          'countryCodes': request.countryCodes,
          'countryNames': request.countryNames,
          'regionNames': request.regionNames,
          if (request.startYear != null) 'startYear': request.startYear,
          if (request.endYear != null) 'endYear': request.endYear,
          'cardType': request.cardType.name,
        },
      );

      final title = response?.trim() ?? '';
      if (title.isEmpty) return _fallback.generate(request);

      return TitleGenerationResult(title: title, source: TitleSource.ai);
    } on PlatformException {
      return _fallback.generate(request);
    }
  }
}
