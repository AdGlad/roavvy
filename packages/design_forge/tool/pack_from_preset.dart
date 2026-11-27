// Turns a Design Lab preset (`roavvy.design_preset`) into a draft Signature
// Recipe pack (ADR-181) templated on the preset's country.
//
//   dart run tool/pack_from_preset.dart <preset.json> <id> "<Title>" <out.pack.json>
import 'dart:convert';
import 'dart:io';

import 'package:design_forge/design_forge.dart';

void main(List<String> args) {
  if (args.length != 4) {
    stderr.writeln(
        'usage: dart run tool/pack_from_preset.dart <preset> <id> <title> <out>');
    exit(64);
  }
  final preset = TornFlagPreset.fromJson(
      (jsonDecode(File(args[0]).readAsStringSync()) as Map).cast());
  if (!preset.recipeIdMatchesFile) {
    stderr.writeln('warning: preset recipeId no longer matches the engine');
  }
  final pack = SignaturePackCodec.draftFromRecipe(
    id: args[1],
    title: args[2],
    recipe: preset.recipe,
    notes: 'Seeded from ${args[0].split('/').last} (${preset.name}). '
        '${preset.notes ?? ''}'.trim(),
  );
  File(args[3]).writeAsStringSync(SignaturePackCodec.encode(pack));
  stdout.writeln('wrote ${args[3]} (locks: ${pack.locks})');
}
