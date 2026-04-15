import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/title_generation/ios_title_channel.dart';
import 'package:mobile_flutter/features/cards/title_generation/rule_based_title_generator.dart';
import 'package:mobile_flutter/features/cards/title_generation/title_generation_models.dart';
import 'package:shared_models/shared_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('roavvy/ai_title');

  final request = TitleGenerationRequest(
    countryCodes: const ['JP'],
    countryNames: const ['Japan'],
    regionNames: const ['Asia'],
    startYear: 2024,
    cardType: CardTemplateType.grid,
  );

  late IosOnDeviceTitleGenerator generator;

  setUp(() {
    generator = IosOnDeviceTitleGenerator(fallback: RuleBasedTitleGenerator());
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  void setHandler(Future<Object?> Function(MethodCall) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  test('PlatformException → TitleSource.fallback', () async {
    setHandler((_) async => throw PlatformException(code: 'AI_UNAVAILABLE'));
    final result = await generator.generate(request);
    expect(result.source, TitleSource.fallback);
    expect(result.title, isNotEmpty);
  });

  test('null response → TitleSource.fallback', () async {
    setHandler((_) async => null);
    final result = await generator.generate(request);
    expect(result.source, TitleSource.fallback);
    expect(result.title, isNotEmpty);
  });

  test('empty string response → TitleSource.fallback', () async {
    setHandler((_) async => '   ');
    final result = await generator.generate(request);
    expect(result.source, TitleSource.fallback);
  });

  test('non-empty response → TitleSource.ai with trimmed title', () async {
    setHandler((_) async => '  Japan 2024  ');
    final result = await generator.generate(request);
    expect(result.source, TitleSource.ai);
    expect(result.title, 'Japan 2024');
  });
}
