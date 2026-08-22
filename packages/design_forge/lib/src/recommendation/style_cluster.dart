/// Six style clusters that group [LabStyle] values into preference buckets.
///
/// Each cluster maps to 1–3 Lab styles that share an aesthetic DNA.
/// The mapping is intentionally coarse — we want users to express broad
/// taste, not micromanage 13 knobs.
enum StyleCluster {
  clean('Clean & Minimal'),
  vintage('Vintage & Retro'),
  bold('Bold & Street'),
  relaxed('Relaxed & Beachy'),
  artistic('Artistic & Maximal'),
  typographic('Type-Forward');

  const StyleCluster(this.label);
  final String label;

  /// Default weight when the user has expressed no preference.
  static const double neutralWeight = 1.0;
}

/// Maps each cluster to the Lab-style names it draws from.
///
/// The keys are [StyleCluster] values; the values are Lab-style name strings
/// that match [LabStyle.name] (e.g. 'minimalist', 'vintage').
const Map<StyleCluster, List<String>> kClusterToLabStyles = {
  StyleCluster.clean: ['minimalist', 'premium'],
  StyleCluster.vintage: ['vintage', 'retro'],
  StyleCluster.bold: ['streetwear', 'grunge', 'extreme'],
  StyleCluster.relaxed: ['beachwear', 'surf', 'outdoor'],
  StyleCluster.artistic: ['showcase', 'maximal'],
  StyleCluster.typographic: ['typography'],
};
