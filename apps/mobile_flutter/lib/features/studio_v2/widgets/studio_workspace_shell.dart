import 'package:flutter/material.dart';

import '../studio_v2_theme.dart';

/// The Studio V2 customisation frame, shared by every editing step (M12–M21).
///
/// One screen with two positions, not two screens: a compact garment above a
/// sheet of controls, or the garment at full height with the controls tucked
/// away. Dragging the sheet moves between them and nothing else happens — no
/// design is regenerated, no selection changes, no history is touched. The
/// preview simply gets more or less room.
///
/// The shell owns the drag, the snap and the space allocation; a step's
/// workspace supplies only its own controls and never implements dragging
/// itself. That is what lets every later step inherit this behaviour by
/// passing content in.
class StudioWorkspaceShell extends StatefulWidget {
  const StudioWorkspaceShell({
    super.key,
    required this.preview,
    required this.controls,
    this.header,
    this.initiallyExpanded = true,
    this.onPositionChanged,
  });

  /// The live garment. Built once and kept alive across drags — it must not be
  /// rebuilt frame by frame while the sheet moves.
  final Widget preview;

  /// The step's controls, scrolled inside the sheet.
  final Widget controls;

  /// Optional row pinned above the garment (the step's navigation).
  final Widget? header;

  /// True = controls expanded (the default for an editing step, where the
  /// controls are the reason you are here).
  final bool initiallyExpanded;

  /// Fired when the sheet settles, with the fraction of the screen the
  /// CONTROLS occupy.
  final ValueChanged<double>? onPositionChanged;

  /// Controls-expanded: the sheet takes most of the screen and the garment is
  /// a compact reminder of what is being edited.
  static const double expanded = 0.72;

  /// Garment-expanded: the shirt gets ~80% and the sheet becomes a handle.
  static const double collapsed = 0.16;

  @override
  State<StudioWorkspaceShell> createState() => _StudioWorkspaceShellState();
}

class _StudioWorkspaceShellState extends State<StudioWorkspaceShell> {
  late final DraggableScrollableController _sheet =
      DraggableScrollableController();
  late double _extent =
      widget.initiallyExpanded
          ? StudioWorkspaceShell.expanded
          : StudioWorkspaceShell.collapsed;

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  /// Which position we are in, for anything that needs to know.
  bool get _isExpanded =>
      _extent >
      (StudioWorkspaceShell.expanded + StudioWorkspaceShell.collapsed) / 2;

  void _snapTo(double extent) {
    if (!_sheet.isAttached) return;
    _sheet.animateTo(
      extent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      // The garment sits under the sheet and is laid out for the FULL height,
      // so sliding the sheet reveals more of the same widget rather than
      // resizing and re-rendering it. Dragging costs a translation, not a
      // render.
      Positioned.fill(
        child: Column(
          children: [
            if (widget.header != null) widget.header!,
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  // Leave the garment the room the sheet is not using, with a
                  // floor so it never collapses to nothing.
                  final free = (1 - _extent).clamp(0.2, 1.0);
                  return Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      height: box.maxHeight * free,
                      child: widget.preview,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      NotificationListener<DraggableScrollableNotification>(
        onNotification: (n) {
          if (n.extent != _extent) setState(() => _extent = n.extent);
          widget.onPositionChanged?.call(n.extent);
          return false;
        },
        child: DraggableScrollableSheet(
          key: const Key('v2-workspace-sheet'),
          controller: _sheet,
          initialChildSize:
              widget.initiallyExpanded
                  ? StudioWorkspaceShell.expanded
                  : StudioWorkspaceShell.collapsed,
          minChildSize: StudioWorkspaceShell.collapsed,
          maxChildSize: StudioWorkspaceShell.expanded,
          // Two positions, nothing in between: a sheet left halfway shows a
          // cramped shirt above cramped controls and serves neither.
          snap: true,
          snapSizes: const [
            StudioWorkspaceShell.collapsed,
            StudioWorkspaceShell.expanded,
          ],
          builder:
              (context, scrollController) => DecoratedBox(
                decoration: const BoxDecoration(
                  color: StudioV2Theme.card,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Column(
                  children: [
                    _handle(),
                    // The controls scroll with the sheet's own controller, so
                    // a flick that starts on the list can carry the sheet and
                    // a drag that starts on the handle never fights the list.
                    Expanded(
                      child: MediaQuery.removePadding(
                        context: context,
                        removeTop: true,
                        child: PrimaryScrollController(
                          controller: scrollController,
                          child: widget.controls,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ),
      ),
    ],
  );

  /// The grab handle, and a tap target for anyone who would rather not drag.
  Widget _handle() => GestureDetector(
    key: const Key('v2-workspace-handle'),
    behavior: HitTestBehavior.opaque,
    onTap:
        () => _snapTo(
          _isExpanded
              ? StudioWorkspaceShell.collapsed
              : StudioWorkspaceShell.expanded,
        ),
    child: SizedBox(
      height: 30,
      width: double.infinity,
      child: Center(
        child: Icon(
          _isExpanded
              ? Icons.keyboard_arrow_down_rounded
              : Icons.keyboard_arrow_up_rounded,
          size: 26,
          color: Colors.white38,
        ),
      ),
    ),
  );
}
