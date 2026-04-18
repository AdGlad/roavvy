import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/title_generation/ios_title_channel.dart';
import 'package:mobile_flutter/features/cards/title_generation/rule_based_title_generator.dart';
import 'package:mobile_flutter/features/cards/title_generation/title_generation_models.dart';
import 'package:shared_models/shared_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('roavvy/ai_title');

  // Year fields intentionally absent from request (ADR-125).
  final request = TitleGenerationRequest(
    countryCodes: const ['JP'],
    countryNames: const ['Japan'],
    regionNames: const ['Asia'],
    cardType: CardTemplateType.grid,
  );

  late IosOnDeviceTitleGenerator generator;
  MethodCall? capturedCall;

  setUp(() {
    capturedCall = null;
    generator = IosOnDeviceTitleGenerator(fallback: RuleBasedTitleGenerator());
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  void setHandler(Future<Object?> Function(MethodCall) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      capturedCall = call;
      return handler(call);
    });
  }

  // ── Channel args contract (ADR-125) ───────────────────────────────────────

  test('channel args do not contain startYear', () async {
    setHandler((_) async => 'Land of the Rising Sun');
    await generator.generate(request);
    final args = capturedCall!.arguments as Map;
    expect(args.containsKey('startYear'), isFalse,
        reason: 'startYear must not be sent to AI (ADR-125)');
  });

  test('channel args do not contain endYear', () async {
    setHandler((_) async => 'Cherry Blossom Road');
    await generator.generate(request);
    final args = capturedCall!.arguments as Map;
    expect(args.containsKey('endYear'), isFalse,
        reason: 'endYear must not be sent to AI (ADR-125)');
  });

  test('channel args contain regionNames', () async {
    setHandler((_) async => 'Asian Escape');
    await generator.generate(request);
    final args = capturedCall!.arguments as Map;
    expect(args.containsKey('regionNames'), isTrue);
    expect(args['regionNames'], contains('Asia'));
  });

  // ── Fallback behaviour ────────────────────────────────────────────────────

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

  // ── Success path ──────────────────────────────────────────────────────────

  test('non-empty response → TitleSource.ai with trimmed title', () async {
    setHandler((_) async => '  Rising Sun  ');
    final result = await generator.generate(request);
    expect(result.source, TitleSource.ai);
    expect(result.title, 'Rising Sun');
  });
}
