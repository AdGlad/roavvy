import 'title_generation_models.dart';

abstract class TitleGenerationService {
  /// Generates a short travel card title from [request].
  ///
  /// Must never throw — implementations return [TitleSource.fallback] when
  /// the primary provider is unavailable.
  Future<TitleGenerationResult> generate(TitleGenerationRequest request);
}
