import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ios_title_channel.dart';
import 'rule_based_title_generator.dart';
import 'title_generation_service.dart';

final titleGenerationServiceProvider = Provider<TitleGenerationService>((ref) {
  final fallback = RuleBasedTitleGenerator();
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return IosOnDeviceTitleGenerator(fallback: fallback);
  }
  // Future: TargetPlatform.android → AndroidOnDeviceTitleGenerator(fallback: fallback)
  return fallback;
});
