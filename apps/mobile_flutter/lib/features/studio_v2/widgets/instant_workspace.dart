import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

import '../commerce/garment_cart_request.dart';
import '../studio_v2_theme.dart';

/// **Instant** — the opening offer: a finished shirt, chosen for this traveller,
/// that can be bought without touching the workflow at all.
///
/// The persistent hero above already shows the garment, both faces and the
/// live colour, so this panel is the three things the hero cannot be: the deck
/// you swipe, the colour you switch, and the decision you make.
///
/// The decision is deliberately three-way, in ascending order of effort:
///   * **Buy it** — straight to the cart with what is on screen.
///   * **Configure** — keep this design and open the steps that change how it
///     looks (Vibe onwards); nothing is regenerated.
///   * **Start custom** — abandon the pick and build from Direction.
///
/// Swiping is browsing, not choosing: it never enters the undo history and
/// never teaches the preference model (see [StudioController.showInstant]), so
/// flicking through the deck cannot bury the design you started on.
class InstantWorkspace extends StatefulWidget {
  const InstantWorkspace({
    super.key,
    required this.controller,
    required this.onConfigure,
    required this.onCustom,
    this.onAddToCart,
  });

  final StudioController controller;

  /// Keep this design and open the editing steps.
  final VoidCallback onConfigure;

  /// Discard the pick and start the full flow at Direction.
  final VoidCallback onCustom;

  /// Injected by the host; null in dev builds with no commerce wired.
  final AddToCartCallback? onAddToCart;

  @override
  State<InstantWorkspace> createState() => _InstantWorkspaceState();
}

class _InstantWorkspaceState extends State<InstantWorkspace> {
  StudioController get _c => widget.controller;
  late final PageController _pages = PageController(
    initialPage: _c.instantIndex,
  );
  bool _busy = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _buy() async {
    final cb = widget.onAddToCart;
    if (cb == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is not available in this build')),
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

  void _configure() {
    _c.takeInstant();
    widget.onConfigure();
  }

  @override
  Widget build(BuildContext context) {
    final deck = _c.instantPicks;
    final index = _c.instantIndex;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'READY TO WEAR',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.4,
              color: StudioV2Theme.accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            deck.length > 1
                ? 'Made from your travels. Swipe for ${deck.length - 1} more.'
                : 'Made from your travels.',
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 12),

          // The deck. The pages carry the name and index rather than a second
          // copy of the shirt — the hero above is already showing it, and two
          // previews of the same design would only disagree.
          Row(
            children: [
              _arrow('v2-instant-prev', Icons.chevron_left_rounded, -1),
              Expanded(
                child: SizedBox(
                  height: 48,
                  // A PageView will not drag with a MOUSE under the default
                  // desktop scroll behaviour, so the deck simply would not
                  // swipe on macOS. Accept every pointer that can express the
                  // gesture.
                  child: ScrollConfiguration(
                    behavior: const _AnyPointerScroll(),
                    child: PageView.builder(
                      key: const Key('v2-instant-deck'),
                      controller: _pages,
                      itemCount: deck.length,
                      onPageChanged: (i) => setState(() => _c.showInstant(i)),
                      itemBuilder: (context, i) => _card(deck[i], i),
                    ),
                  ),
                ),
              ),
              _arrow('v2-instant-next', Icons.chevron_right_rounded, 1),
            ],
          ),
          const SizedBox(height: 10),
          if (deck.length > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < deck.length; i++)
                  Container(
                    width: i == index ? 18 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == index ? StudioV2Theme.accent : Colors.white24,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 16),

          const _MiniLabel('Shirt colour'),
          const SizedBox(height: 6),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (hex, name) in StudioController.garments)
                  _swatch(hex, name),
              ],
            ),
          ),
          const SizedBox(height: 20),

          FilledButton.icon(
            key: const Key('v2-instant-buy'),
            onPressed: _busy ? null : _buy,
            icon:
                _busy
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.shopping_bag_outlined, size: 18),
            label: Text(_busy ? 'Adding…' : 'Buy this one'),
            style: FilledButton.styleFrom(
              backgroundColor: StudioV2Theme.accent,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(46),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('v2-instant-configure'),
                  onPressed: _busy ? null : _configure,
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Configure'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: StudioV2Theme.border),
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('v2-instant-custom'),
                  onPressed: _busy ? null : widget.onCustom,
                  icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                  label: const Text('Start custom'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: StudioV2Theme.subtleBorder),
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Configure keeps this design. Start custom builds a new one.',
            style: TextStyle(fontSize: 11, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  /// One page of the deck: what this design is, and where it sits in the set.
  ///
  /// Deliberately a single row. Stacked text overflowed the moment the
  /// workspace panel got short — a phone in landscape, a small window — and an
  /// overflow here is a striped bar across the first thing anyone sees.
  Widget _card(DesignRecipe r, int i) => Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: StudioV2Theme.card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: StudioV2Theme.subtleBorder),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            _c.instantName(r),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${i + 1}/${_c.instantPicks.length}',
          style: const TextStyle(fontSize: 11, color: Colors.white38),
        ),
      ],
    ),
  );

  /// Step the deck by [delta]. The arrows exist because a mouse cannot swipe
  /// comfortably even once the drag is accepted.
  Widget _arrow(String key, IconData icon, int delta) {
    final deck = _c.instantPicks;
    return IconButton(
      key: Key(key),
      visualDensity: VisualDensity.compact,
      iconSize: 22,
      color: Colors.white54,
      onPressed:
          deck.length < 2
              ? null
              : () {
                final next = (_c.instantIndex + delta) % deck.length;
                _pages.animateToPage(
                  next < 0 ? next + deck.length : next,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                );
              },
      icon: Icon(icon),
    );
  }

  Widget _swatch(String hex, String name) {
    final selected = _c.current.palette?.garmentColour == hex;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: selected,
        label: name,
        child: GestureDetector(
          key: Key('v2-instant-garment-$name'),
          onTap: () => setState(() => _c.setGarment(hex)),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Color(int.parse('FF${hex.substring(1)}', radix: 16)),
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? StudioV2Theme.accent : Colors.white24,
                width: selected ? 2.5 : 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniLabel extends StatelessWidget {
  const _MiniLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 10,
      letterSpacing: 1.2,
      color: Colors.white38,
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
