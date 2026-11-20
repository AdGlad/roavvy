import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/commerce/commerce_flag.dart';
import '../cards/journey_card.dart' show JourneyStyle;
import '../memory/memory_anniversary_photo.dart';
import '../merch/achievement_merch_option_screen.dart';
import '../merch/local_mockup_preview_screen.dart';
import '../merch/merch_country_selection_screen.dart';
import '../merch/merch_orders_screen.dart';
import '../merch/merch_shop_screen.dart';
import '../merch/pulse_merch_option_screen.dart';
import '../studio_v2_commerce/studio_v2_entry.dart';

export '../merch/merch_cart_screen.dart' show merchCartCountProvider;

/// The only way into commerce (t-shirt design, print, shop, cart, orders)
/// from outside `features/merch/` and `features/studio_v2*/`. ADR-180.
///
/// Every opener is a no-op when commerce is off, and every visible entry
/// point is wrapped in [CommerceGate] or checks [isAvailable] so it is
/// hidden, never disabled. `test/architecture/commerce_boundary_test.dart`
/// fails the build if a screen elsewhere imports a commerce screen directly.
abstract final class CommerceEntry {
  /// Whether commerce entry points should be shown. Rebuilds on change.
  static bool isAvailable(WidgetRef ref) => ref.watch(commerceEnabledProvider);

  static bool _on(BuildContext context) => ProviderScope.containerOf(
    context,
    listen: false,
  ).read(commerceEnabledProvider);

  static Future<void> _push(BuildContext context, WidgetBuilder builder) {
    if (!_on(context)) return Future<void>.value();
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: builder));
  }

  /// Merch options for an unlocked achievement.
  static Future<void> openAchievementMerch(
    BuildContext context,
    Achievement achievement,
  ) => _push(
    context,
    (_) => AchievementMerchOptionScreen(achievement: achievement),
  );

  /// Merch options for a memory-anniversary photo.
  static Future<void> openPulseMerch(
    BuildContext context, {
    required MemoryAnniversaryPhoto hero,
    required List<TripRecord> allTrips,
    required List<EffectiveVisitedCountry> allVisits,
  }) => _push(
    context,
    (_) => PulseMerchOptionScreen(
      hero: hero,
      allTrips: allTrips,
      allVisits: allVisits,
    ),
  );

  /// Country picker that leads into the product browser.
  static Future<void> openCountryMerch(
    BuildContext context, {
    List<String>? preSelectedCodes,
  }) => _push(
    context,
    (_) => MerchCountrySelectionScreen(preSelectedCodes: preSelectedCodes),
  );

  /// Print a confirmed travel card on a garment.
  static Future<void> openCardPrint(BuildContext context, CardPrintRequest r) =>
      _push(
        context,
        (_) => LocalMockupPreviewScreen(
          selectedCodes: r.selectedCodes,
          allCodes: r.allCodes,
          trips: r.trips,
          artworkImageBytes: r.artworkImageBytes,
          artworkConfirmationId: r.artworkConfirmationId,
          initialTemplate: r.initialTemplate,
          initialJourneyStyle: r.initialJourneyStyle,
          confirmedAspectRatio: r.confirmedAspectRatio,
          confirmedEntryOnly: r.confirmedEntryOnly,
          cardId: r.cardId,
          titleOverride: r.titleOverride,
          subtitleOverride: r.subtitleOverride,
          stampColor: r.stampColor,
          dateColor: r.dateColor,
          transparentBackground: r.transparentBackground,
          stampSizeMultiplier: r.stampSizeMultiplier,
          stampJitterFactor: r.stampJitterFactor,
          stampLayoutSeed: r.stampLayoutSeed,
        ),
      );

  /// The user's merch orders.
  static Future<void> openOrders(BuildContext context) =>
      _push(context, (_) => const MerchOrdersScreen());

  /// The T-Shirt Studio V2 app, for the dev `STUDIO_V2` boot path.
  static Widget studio() => const StudioV2Entry();

  /// The Shop tab body. The shell only builds it when commerce is on.
  static Widget shopTab() => const MerchShopScreen();
}

/// Everything a travel card hands to the garment preview when printed.
class CardPrintRequest {
  const CardPrintRequest({
    required this.selectedCodes,
    required this.allCodes,
    required this.trips,
    required this.artworkImageBytes,
    required this.artworkConfirmationId,
    required this.initialTemplate,
    required this.initialJourneyStyle,
    required this.confirmedAspectRatio,
    required this.confirmedEntryOnly,
    this.cardId,
    this.titleOverride,
    this.subtitleOverride,
    this.stampColor,
    this.dateColor,
    this.transparentBackground = false,
    this.stampSizeMultiplier = 1.0,
    this.stampJitterFactor = 0.4,
    this.stampLayoutSeed,
  });

  final List<String> selectedCodes;
  final List<String> allCodes;
  final List<TripRecord> trips;
  final Uint8List artworkImageBytes;
  final String? artworkConfirmationId;
  final CardTemplateType initialTemplate;
  final JourneyStyle initialJourneyStyle;
  final double confirmedAspectRatio;
  final bool confirmedEntryOnly;
  final String? cardId;
  final String? titleOverride;
  final String? subtitleOverride;
  final Color? stampColor;
  final Color? dateColor;
  final bool transparentBackground;
  final double stampSizeMultiplier;
  final double stampJitterFactor;
  final int? stampLayoutSeed;
}

/// Builds [child] only when commerce is on; otherwise nothing at all.
/// Hide, never disable (ADR-180).
class CommerceGate extends ConsumerWidget {
  const CommerceGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      CommerceEntry.isAvailable(ref) ? child : const SizedBox.shrink();
}
