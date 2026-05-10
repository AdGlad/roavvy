import 'package:shared_models/shared_models.dart';

/// A curated merch drop — a themed collection of templates surfaced with a
/// badge label in the merch gallery (ADR-155).
///
/// Active drops whose [templates] overlap with the ranked results receive
/// a [badge] prefix on their section header label, giving the gallery a
/// "curated drop" feel without changing the underlying merch pipeline.
class MerchDrop {
  const MerchDrop({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.templates,
    this.isActive = true,
  });

  /// Unique identifier.
  final String id;

  /// Display title, e.g. "Explorer Badge Collection".
  final String title;

  /// Supporting copy, e.g. "Circular badge designs for every explorer".
  final String subtitle;

  /// Short badge string prepended to section headers, e.g. "✦ Collection".
  final String badge;

  /// Template types this drop applies to.
  final List<CardTemplateType> templates;

  /// Whether this drop is currently active. Inactive drops are ignored.
  final bool isActive;

  /// Returns the first active drop whose [templates] include [t], or null.
  static MerchDrop? forTemplate(CardTemplateType t) {
    for (final drop in kCurrentMerchDrops) {
      if (drop.isActive && drop.templates.contains(t)) return drop;
    }
    return null;
  }
}

/// Currently active merch drops surfaced in the gallery.
const List<MerchDrop> kCurrentMerchDrops = [
  MerchDrop(
    id: 'explorer_badge_collection',
    title: 'Explorer Badge Collection',
    subtitle: 'Circular badge designs for every explorer',
    badge: '✦ Collection',
    templates: [CardTemplateType.badge],
  ),
  MerchDrop(
    id: 'passport_series',
    title: 'Passport Series',
    subtitle: 'Classic stamp designs, reimagined',
    badge: '📖 Classic',
    templates: [CardTemplateType.passport],
  ),
];
