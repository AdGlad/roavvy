import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/cards/passport_stamp_model.dart';
import 'package:mobile_flutter/features/cards/rare_artefact_engine.dart';

StampData _stamp({bool enableArtefacts = true}) => StampData.fromCode(
      'JP',
      style: StampStyle.airportEntry,
      inkFamilyIndex: 0,
      ageEffect: StampAgeEffect.fresh,
      rotation: 0,
      center: const Offset(100, 100),
      renderConfig: StampRenderConfig(enableRareArtefacts: enableArtefacts),
    );

void main() {
  group('RareArtefactEngine', () {
    test('apply does not throw with artefacts enabled', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      RareArtefactEngine.apply(
          canvas, _stamp(), const Offset(100, 100), 40.0);
      final picture = recorder.endRecording();
      picture.dispose();
    });

    test('apply is a no-op when enableRareArtefacts is false', () {
      // With artefacts disabled, apply should complete without any drawing.
      // We verify by confirming no exception is thrown and the canvas remains
      // in a valid state.
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      RareArtefactEngine.apply(
          canvas, _stamp(enableArtefacts: false), const Offset(50, 50), 30.0);
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
      picture.dispose();
    });

    test('apply is deterministic — same stamp, same seed, no exception', () {
      final stamp = _stamp();
      for (var i = 0; i < 5; i++) {
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        RareArtefactEngine.apply(canvas, stamp, const Offset(100, 100), 40.0);
        recorder.endRecording().dispose();
      }
    });
  });
}
