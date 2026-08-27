/// The V2 workflow stages (storyboard order). This is **workflow navigation
/// state only** — entirely separate from the design recipe and its undo/redo
/// history (which live in the shared `StudioController`). Later milestones fill
/// each stage's workspace; M1 only establishes the shell + navigation.
enum StudioStage {
  instant,
  travels,
  direction,
  detail,
  vibe,
  focus,
  colour,
  words,
  front,
  fineTune,
  review,
}

extension StudioStageLabel on StudioStage {
  String get label => switch (this) {
        StudioStage.instant => 'Instant',
        StudioStage.travels => 'Travels',
        StudioStage.direction => 'Direction',
        StudioStage.detail => 'Detail',
        StudioStage.vibe => 'Vibe',
        StudioStage.focus => 'Focus',
        StudioStage.colour => 'Colour',
        StudioStage.words => 'Words',
        StudioStage.front => 'Front',
        StudioStage.fineTune => 'Fine Tune',
        StudioStage.review => 'Review',
      };

  /// One-line placeholder describing what this stage will do (M1 shows this in
  /// the workspace; later milestones replace it with real controls).
  String get blurb => switch (this) {
        StudioStage.instant => 'An instant design from your travels.',
        StudioStage.travels => 'Choose countries or trips, map or list.',
        StudioStage.direction => 'Pick what your shirt is about.',
        StudioStage.detail => 'Choose the shape your flags fill.',
        StudioStage.vibe => 'Pick the overall style.',
        StudioStage.focus => 'Adjust the composition.',
        StudioStage.colour => 'Set the colour treatment.',
        StudioStage.words => 'Add your title.',
        StudioStage.front => 'Configure the shirt front.',
        StudioStage.fineTune => 'Go deeper with precise controls.',
        StudioStage.review => 'Review both sides and save.',
      };
}
