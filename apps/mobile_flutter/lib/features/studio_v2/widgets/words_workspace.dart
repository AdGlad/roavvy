import 'package:design_forge/design_forge.dart';
import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';

import '../studio_v2_theme.dart';
import 'axis_controls.dart';

/// **Words** workspace (M5) — a title EDITOR, not a generic generator. Wraps the
/// existing [StudioController] title APIs: [StudioController.currentTitle] shows
/// what's on the shirt, the field commits a manual edit ([StudioController.commitTitle],
/// undoable), Remove clears it, and "Suggest titles"
/// ([StudioController.suggestTitles] / [StudioController.titleIdeas]) offers local,
/// deterministic ideas — no network, no AI artwork. Tapping a suggestion applies
/// it immediately; the button re-rolls a fresh set each press.
class WordsWorkspace extends StatefulWidget {
  const WordsWorkspace({super.key, required this.controller});

  final StudioController controller;

  @override
  State<WordsWorkspace> createState() => _WordsWorkspaceState();
}

class _WordsWorkspaceState extends State<WordsWorkspace> {
  late final TextEditingController _field;
  final FocusNode _focus = FocusNode();

  StudioController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _field = TextEditingController(text: _c.currentTitle);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _c.focusWords();
    });
    _c.addListener(_syncField);
  }

  void _syncField() {
    if (!mounted || _focus.hasFocus) return;
    if (_field.text != _c.currentTitle) _field.text = _c.currentTitle;
  }

  @override
  void dispose() {
    _c.removeListener(_syncField);
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _apply(String v) {
    _c.commitTitle(v);
    _field.text = _c.currentTitle;
  }

  @override
  Widget build(BuildContext context) {
    final ideas = _c.titleIdeas;
    final hasTitle = _c.currentTitle.trim().isNotEmpty;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            const Expanded(
              child: Text('WORDS',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.4,
                      color: StudioV2Theme.accent)),
            ),
            AxisLockChip(controller: _c, axis: DesignAxis.words),
            const SizedBox(width: 8),
            RemixButton(controller: _c),
          ]),
          const SizedBox(height: 4),
          const Text('Add a title to your design — type your own or tap a '
              'suggestion.',
              style: TextStyle(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                key: const Key('v2-title-field'),
                controller: _field,
                focusNode: _focus,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                textInputAction: TextInputAction.done,
                onSubmitted: _apply,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Your title',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: StudioV2Theme.card,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: StudioV2Theme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: StudioV2Theme.accent),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              key: const Key('v2-title-remove'),
              onPressed: hasTitle ? () => _apply('') : null,
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              child: const Text('Remove'),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Text(ideas.isEmpty ? 'SUGGESTIONS' : 'TAP TO APPLY',
                  style: const TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      color: StudioV2Theme.accent)),
            ),
            TextButton.icon(
              key: const Key('v2-title-suggest'),
              onPressed: _c.suggestTitles,
              style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
              icon: const Icon(Icons.refresh, size: 15),
              label: Text(ideas.isEmpty ? 'Suggest titles' : 'More',
                  style: const TextStyle(fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 8),
          if (ideas.isEmpty)
            const Text('Tap “Suggest titles” for ideas from your travels.',
                style: TextStyle(fontSize: 12, color: Colors.white38))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < ideas.length; i++)
                  _IdeaChip(
                    key: Key('v2-title-idea-$i'),
                    label: ideas[i],
                    selected: ideas[i] == _c.currentTitle,
                    onTap: () => _apply(ideas[i]),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _IdeaChip extends StatelessWidget {
  const _IdeaChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? StudioV2Theme.accent.withValues(alpha: 0.14)
              : StudioV2Theme.card,
          border: Border.all(
              color: selected ? StudioV2Theme.accent : StudioV2Theme.border,
              width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                color: selected ? StudioV2Theme.accent : Colors.white)),
      ),
    );
  }
}
