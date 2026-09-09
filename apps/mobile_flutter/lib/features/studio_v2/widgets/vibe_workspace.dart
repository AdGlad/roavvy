import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';

import '../studio_v2_theme.dart';
import 'shirt_preview.dart';

/// **Vibe** — the look and feel, over the same design.
///
/// Thirteen styles, each shown as the shirt it would actually produce: the
/// design on screen, restyled. A named list would make Vintage and Grunge
/// indistinguishable, and the whole point of this step is that they are not.
///
/// The previews are real, and cheap enough to be: [StudioController
/// .vibeStyleOptions] builds thirteen RECIPES (a splice each, no rendering),
/// the grid is lazy so only the cards on screen are ever built, and each one
/// renders small through the render cache the rest of the Studio shares.
class VibeWorkspace extends StatelessWidget {
  const VibeWorkspace({super.key, required this.controller});

  final StudioController controller;

  /// One line per Vibe, in the engine's own order. Named here rather than on
  /// the engine because they are shop copy, not generator behaviour.
  static const Map<LabStyle, String> blurbs = {
    LabStyle.showcase: 'Clean and modern',
    LabStyle.extreme: 'Loud and daring',
    LabStyle.maximal: 'Every inch filled',
    LabStyle.beachwear: 'Sun and salt',
    LabStyle.surf: 'Easy and sun-bleached',
    LabStyle.grunge: 'Rough and torn',
    LabStyle.minimalist: 'Simple and refined',
    LabStyle.streetwear: 'Graphic and urban',
    LabStyle.vintage: 'Worn and timeless',
    LabStyle.retro: 'Seventies warmth',
    LabStyle.outdoor: 'Rugged and authentic',
    LabStyle.premium: 'Quiet and considered',
    LabStyle.typography: 'Led by the lettering',
  };

  @override
  Widget build(BuildContext context) {
    final options = controller.vibeStyleOptions();
    final current = controller.currentStyle;
    return CustomScrollView(
      key: const Key('v2-vibe-scroll'),
      slivers: [
        SliverToBoxAdapter(child: _heading()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.78,
            ),
            itemCount: options.length,
            itemBuilder: (context, i) {
              final (style, styled) = options[i];
              return _VibeCard(
                style: style,
                styled: styled,
                service: controller.service,
                selected: style == current,
                onTap: () => controller.onStyleTap(style, styled),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _heading() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: StudioV2Theme.accent,
                shape: BoxShape.circle,
              ),
              child: const Text(
                '4',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Vibe',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'What style vibe do you prefer?',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose the overall look and feel for your design. '
          'You can refine this later.',
          style: TextStyle(fontSize: 13, color: Colors.white54, height: 1.35),
        ),
      ],
    ),
  );
}

class _VibeCard extends StatelessWidget {
  const _VibeCard({
    required this.style,
    required this.styled,
    required this.service,
    required this.selected,
    required this.onTap,
  });

  final LabStyle style;
  final DesignRecipe styled;
  final RenderService service;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: Key('v2-vibe-${style.name}'),
    onTap: onTap,
    child: Semantics(
      button: true,
      selected: selected,
      label: '${style.label} — ${VibeWorkspace.blurbs[style] ?? ''}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: StudioV2Theme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? StudioV2Theme.accent : StudioV2Theme.subtleBorder,
            width: selected ? 2 : 1,
          ),
          boxShadow:
              selected
                  ? [
                    BoxShadow(
                      color: StudioV2Theme.accent.withValues(alpha: 0.28),
                      blurRadius: 14,
                    ),
                  ]
                  : null,
        ),
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
        child: Column(
          children: [
            Expanded(
              child: ShirtPreview(
                key: ValueKey('v2-vibe-shirt-${style.name}'),
                service: service,
                recipe: styled,
                front: false,
                // A thumbnail among thirteen, not the hero: small enough that
                // scrolling the grid does not cost full-size renders.
                longSide: 256,
                // Never a spinner here — thirteen of them flickering past says
                // nothing. The name is the honest stand-in until it arrives.
                placeholder: Center(
                  child: Text(
                    style.label,
                    style: const TextStyle(fontSize: 13, color: Colors.white24),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              style.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              VibeWorkspace.blurbs[style] ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
      ),
    ),
  );
}
