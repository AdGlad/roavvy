import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart' show kCountryContinent;

import '../commerce/garment_cart_request.dart';
import '../studio_v2_theme.dart';
import 'shirt_preview.dart';

/// **Instant** — Roavvy's front door: a finished shirt, made from these
/// travels, ready to buy.
///
/// This is a product screen, not step one of a wizard. It fills the viewport
/// itself rather than sitting in the Studio's hero/controls/workspace/footer
/// frame, because the promise being made is "here is your shirt" and a shirt
/// squeezed into the bottom third of a configuration screen does not make it.
/// There is exactly ONE representation of the design on screen — the garment
/// you swipe — so nothing on the page can disagree with anything else on it.
///
/// Three ways forward, in the order most people want them: buy it, customise
/// it, keep it. Customise carries the browsed design into the editing steps
/// untouched; there is no second path that throws it away and starts over.
///
/// Browsing is not choosing: swiping never enters undo history and never
/// teaches the preference model (see [StudioController.showInstant]).
class InstantWorkspace extends StatefulWidget {
  const InstantWorkspace({
    super.key,
    required this.controller,
    required this.onCustomise,
    this.onAddToCart,
    this.onExit,
    this.onOpenSaved,
  });

  final StudioController controller;

  /// Carry this exact design into the editing steps.
  final VoidCallback onCustomise;

  /// Injected by the host; null in dev builds with no commerce wired.
  final AddToCartCallback? onAddToCart;

  /// Leave the Studio. Null hides the affordance.
  final VoidCallback? onExit;

  /// Open the saved-designs wardrobe. Null hides the affordance.
  final VoidCallback? onOpenSaved;

  @override
  State<InstantWorkspace> createState() => _InstantWorkspaceState();
}

class _InstantWorkspaceState extends State<InstantWorkspace> {
  StudioController get _c => widget.controller;
  late final PageController _pages = PageController(
    initialPage: _c.instantIndex,
  );
  bool _busy = false;
  bool _saved = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _addToCart() async {
    final cb = widget.onAddToCart;
    if (cb == null) {
      _say('Cart is not available in this build');
      return;
    }
    if (!_c.canOrderCurrent) {
      _say(
        '${_c.garmentName} is not available to order yet — '
        'pick another shirt colour.',
      );
      return;
    }
    // Buying IS choosing — unlike swiping, this one counts.
    _c.takeInstant();
    setState(() => _busy = true);
    try {
      await cb(context, buildGarmentCartRequest(_c));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _customise() {
    _c.takeInstant();
    widget.onCustomise();
  }

  void _save() {
    _c.saveGarment();
    setState(() => _saved = true);
    _say('Saved to your designs');
  }

  void _say(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  void _step(int delta) {
    final deck = _c.instantPicks;
    if (deck.length < 2) return;
    final next = (_c.instantIndex + delta) % deck.length;
    _pages.animateToPage(
      next < 0 ? next + deck.length : next,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final deck = _c.instantPicks;
    return Column(
      children: [
        _topBar(),
        // The garment takes what is left after the copy and the actions, which
        // on any phone is most of the screen.
        Expanded(child: _garment(deck)),
        _identity(deck),
        _colours(),
        const SizedBox(height: 12),
        _actions(),
      ],
    );
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
    child: Row(
      children: [
        SizedBox(
          width: 44,
          child:
              widget.onExit == null
                  ? null
                  : IconButton(
                    key: const Key('v2-instant-exit'),
                    onPressed: widget.onExit,
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    color: Colors.white70,
                  ),
        ),
        const Expanded(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'roavvy',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                Icon(Icons.place, size: 17, color: StudioV2Theme.accent),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child:
              widget.onOpenSaved == null
                  ? null
                  : IconButton(
                    key: const Key('v2-instant-saved'),
                    tooltip: 'Your saved designs',
                    onPressed: widget.onOpenSaved,
                    icon: const Icon(Icons.favorite_border_rounded, size: 22),
                    color: Colors.white70,
                  ),
        ),
      ],
    ),
  );

  /// The shirt, and only the shirt.
  ///
  /// `PageView.builder` keeps this bounded: only the visible page and its
  /// immediate neighbours are ever built, so swiping renders a shirt or two,
  /// never the whole deck. Page changes fire when a swipe SETTLES, so nothing
  /// is generated or re-rendered mid-drag.
  Widget _garment(List<DesignRecipe> deck) => Stack(
    children: [
      Positioned.fill(
        child: ScrollConfiguration(
          // Flutter's desktop scroll behaviour omits the mouse, which leaves
          // the deck unswipeable on macOS.
          behavior: const _AnyPointerScroll(),
          child: PageView.builder(
            key: const Key('v2-instant-deck'),
            controller: _pages,
            itemCount: deck.length,
            onPageChanged: (i) => setState(() => _c.showInstant(i)),
            itemBuilder: (context, i) {
              final front = _c.onFront;
              return ShirtPreview(
                key: ValueKey('v2-instant-shirt-$i-${front ? 'f' : 'b'}'),
                service: _c.service,
                // The pick already wearing the chosen colour, so the shirt
                // does not change colour as the swipe lands.
                recipe: front ? _c.instantFrontAt(i) : _c.instantPreviewAt(i),
                front: front,
                printArea: front ? _c.frontPrintRect() : null,
                // A name, not a spinner: eight spinners flickering past is
                // worse than none.
                placeholder: Center(
                  child: Text(
                    _c.instantName(_c.instantPreviewAt(i)),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.white38),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      // Arrows for anyone who cannot swipe comfortably — a mouse, or a thumb
      // already holding the phone.
      if (deck.length > 1) ...[
        _arrow(Alignment.centerLeft, 'v2-instant-prev', Icons.chevron_left, -1),
        _arrow(
          Alignment.centerRight,
          'v2-instant-next',
          Icons.chevron_right,
          1,
        ),
      ],
      // Front/Back belongs to the garment, not to a toolbar somewhere else.
      Align(alignment: Alignment.bottomCenter, child: _faceSwitch()),
    ],
  );

  Widget _arrow(Alignment side, String key, IconData icon, int delta) => Align(
    alignment: side,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        child: InkWell(
          key: Key(key),
          customBorder: const CircleBorder(),
          onTap: () => _step(delta),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, size: 22, color: Colors.white70),
          ),
        ),
      ),
    ),
  );

  /// Back / Front. Switching faces shows the other side of the SAME design —
  /// it never rolls a new one.
  Widget _faceSwitch() {
    Widget half(String label, bool front) {
      final on = _c.onFront == front;
      return GestureDetector(
        key: Key('v2-instant-side-${front ? 'front' : 'back'}'),
        onTap: on ? null : () => setState(() => _c.setSide(front)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
          decoration: BoxDecoration(
            color: on ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: on ? Colors.black : Colors.white70,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [half('Back', false), half('Front', true)],
      ),
    );
  }

  /// What this shirt is, in the customer's words — never the engine's.
  Widget _identity(List<DesignRecipe> deck) {
    final codes = _c.selectedCountryCodes;
    final continents =
        {
          for (final c in codes)
            if (kCountryContinent[c.toUpperCase()] != null)
              kCountryContinent[c.toUpperCase()]!,
        }.length;
    final parts = [
      if (codes.isNotEmpty)
        '${codes.length} ${codes.length == 1 ? 'country' : 'countries'}',
      if (continents > 0)
        '$continents ${continents == 1 ? 'continent' : 'continents'}',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _c.instantName(_c.hero),
            key: const Key('v2-instant-title'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          if (parts.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              parts.join(' • '),
              style: const TextStyle(fontSize: 13, color: Colors.white54),
            ),
          ],
          if (deck.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < deck.length; i++)
                  Container(
                    width: i == _c.instantIndex ? 16 : 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 5),
                    decoration: BoxDecoration(
                      color:
                          i == _c.instantIndex
                              ? StudioV2Theme.accent
                              : Colors.white24,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Shirt colour. It dresses the design; it never redraws it.
  Widget _colours() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Shirt colour',
          style: TextStyle(fontSize: 13, color: Colors.white70),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final (hex, name) in StudioController.garments)
                _swatch(hex, name),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _swatch(String hex, String name) {
    final selected = _c.hero.palette?.garmentColour == hex;
    // A colour the store cannot make is dimmed and labelled, not hidden —
    // seeing the design on it is fine; being sold it is not.
    final orderable = _c.canOrderGarment(name);
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Semantics(
        button: true,
        selected: selected,
        label: orderable ? name : '$name — not available to order yet',
        child: GestureDetector(
          key: Key('v2-instant-garment-$name'),
          onTap: () => setState(() => _c.setGarment(hex)),
          child: Opacity(
            opacity: orderable ? 1.0 : 0.35,
            child: Container(
              width: 34,
              height: 34,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? StudioV2Theme.accent : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Color(int.parse('FF${hex.substring(1)}', radix: 16)),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actions() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
    child: Row(
      children: [
        _secondary(
          'v2-instant-save',
          _saved ? Icons.bookmark : Icons.bookmark_border,
          'Save',
          _busy ? null : _save,
        ),
        const SizedBox(width: 10),
        _secondary(
          'v2-instant-customise',
          Icons.tune_rounded,
          'Customise',
          _busy ? null : _customise,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            key: const Key('v2-instant-buy'),
            onPressed: _busy ? null : _addToCart,
            icon:
                _busy
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Icon(Icons.shopping_cart_outlined, size: 20),
            label: Text(_busy ? 'Adding…' : 'Add to Cart'),
            style: FilledButton.styleFrom(
              backgroundColor: StudioV2Theme.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(58),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _secondary(
    String key,
    IconData icon,
    String label,
    VoidCallback? onTap,
  ) => Material(
    color: StudioV2Theme.card,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      key: Key(key),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 58,
        constraints: const BoxConstraints(minWidth: 84),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: Colors.white),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Lets the deck be dragged by mouse and trackpad as well as by touch.
///
/// Flutter's desktop scroll behaviour deliberately omits the mouse, on the
/// reasoning that desktop users scroll with a wheel. A PageView has no wheel
/// affordance, so without this the deck cannot be swiped at all on macOS.
class _AnyPointerScroll extends MaterialScrollBehavior {
  const _AnyPointerScroll();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
  };
}
