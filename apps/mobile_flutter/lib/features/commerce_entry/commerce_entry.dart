import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/commerce/commerce_flag.dart';
import '../../core/providers.dart' show tripListProvider;
import '../cards/journey_card.dart' show JourneyStyle;
import '../memory/memory_anniversary_photo.dart';
import '../merch/achievement_merch_option_screen.dart';
import '../merch/local_mockup_preview_screen.dart';
import '../merch/merch_country_selection_screen.dart';
import '../merch/merch_orders_screen.dart';
import '../merch/merch_shop_screen.dart';
import '../merch/pulse_merch_option_screen.dart';
import '../studio_v2_commerce/studio_v2_entry.dart';
import '../studio_v2_commerce/signature_tees/my_tees_screen.dart';
import '../studio_v2_commerce/signature_tees/pair_tees_screen.dart';
import '../studio_v2_commerce/signature_tees/signature_tee_screen.dart';
import '../studio_v2_commerce/signature_tees/signature_tee_widgets.dart';
import '../studio_v2_commerce/signature_tees/signature_tees.dart'
    show TeePair, journeyPairFor;

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

  /// The signature tee product page for [countryCode] (M200), opened on
  /// design [packId] (null: the country's default design).
  static Future<void> openSignatureTee(
    BuildContext context,
    String countryCode, {
    String? packId,
  }) => _push(
    context,
    (_) => SignatureTeeScreen(
      countryCode: countryCode.toUpperCase(),
      packId: packId,
    ),
  );

  /// "My tees": signature tees for every visited country (M200), with the
  /// "Two countries" row on top when a two-country design exists (M213).
  static Future<void> openMyTees(BuildContext context) => _push(
    context,
    (_) => const MyTeesScreen(
      onOpenTee: openSignatureTee,
      onOpenPairs: openPairTees,
    ),
  );

  /// The tee page for two countries (M213): [pair].a prints on the left.
  /// Opened on design [packId] (null: the pair's first design).
  static Future<void> openPairTee(
    BuildContext context,
    TeePair pair, {
    String? packId,
  }) => _push(
    context,
    (_) => SignatureTeeScreen(
      countryCode: pair.a,
      pairWith: pair.b,
      packId: packId,
    ),
  );

  /// "Two countries": suggested pairs and pick-any-two (M213).
  static Future<void> openPairTees(BuildContext context) => _push(
    context,
    (_) => PairTeesScreen(onOpenPair: (c, p) => openPairTee(c, p)),
  );

  /// The trip sheet's two-country tee: [trip]'s country with its neighbour
  /// on the same journey. Hidden when commerce is off, when the journey has
  /// one country, or when there is no two-country design. [onOpen] replaces
  /// the default tap (e.g. to close a sheet first).
  static Widget tripPairTeeCard(TripRecord trip, {OpenPairTee? onOpen}) =>
      CommerceGate(
        child: Consumer(
          builder: (context, ref, _) {
            final trips = ref.watch(tripListProvider).valueOrNull ?? const [];
            return TripPairTeeCard(
              pair: journeyPairFor(trips, trip),
              onOpen: onOpen ?? (c, p) => openPairTee(c, p),
            );
          },
        ),
      );

  /// The "Your (country) tees" card for a visited country (country page,
  /// trip sheet): every signature design, in a row. Hidden when commerce is
  /// off or there is no tee for the country. [onOpen] replaces the default
  /// tap (e.g. to close a sheet first); it should still open the tee through
  /// [openSignatureTee].
  static Widget signatureTeeCard(String countryCode, {OpenTee? onOpen}) =>
      CommerceGate(
        child: SignatureTeeCard(
          countryCode: countryCode,
          onOpen:
              onOpen ?? (c, id) => openSignatureTee(c, countryCode, packId: id),
        ),
      );

  /// The tee strip with "Get this tee" on a new-country celebration.
  static Widget celebrationTee(String countryCode) => CommerceGate(
    child: CelebrationTee(
      countryCode: countryCode,
      onOpen: (c, id) => openSignatureTee(c, countryCode, packId: id),
    ),
  );

  /// The Stats card that opens "My tees".
  static Widget myTeesCard() =>
      const CommerceGate(child: MyTeesCard(onOpen: openMyTees));

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
