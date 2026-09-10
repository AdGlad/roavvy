import 'package:design_studio/design_studio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;

import '../studio_v2_theme.dart';
import 'fine_tune_panel.dart';

/// **Words & Title** (M20) — the words on the shirt, and the treatment the
/// renderer gives them.
///
/// The title STRING is not part of the reproducible genome: it lives in
/// `content.meta['title']`, and `TypographyStage` reads it at render time. This
/// screen edits that string and the [Typography] group beside it — face, place
/// and case — through [StudioController]. Nothing about the rest of the design
/// is touched, and nothing is regenerated: editing words must not re-roll the
/// artwork underneath them.
///
/// Typing is live but costs ONE undo step: [StudioController.beginEdit] on the
/// first keystroke, [StudioController.setTitle] per character (no history), and
/// [StudioController.endEdit] when the field is done — the same shape a slider
/// drag uses, for the same reason.
///
/// The typography controls come from [StudioController.wordChoices] and are
/// rendered by the shared [FineTunePanel]; they appear only once there is a
/// title for them to treat.
class WordsWorkspace extends StatefulWidget {
  const WordsWorkspace({super.key, required this.controller});

  final StudioController controller;

  @override
  State<WordsWorkspace> createState() => _WordsWorkspaceState();
}

class _WordsWorkspaceState extends State<WordsWorkspace> {
  late final TextEditingController _field;
  final FocusNode _focus = FocusNode();
  bool _typing = false;

  StudioController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _field = TextEditingController(text: _c.currentTitle);
    _c.addListener(_syncField);
    _focus.addListener(_onFocusChange);
  }

  /// Reflect changes made elsewhere (a suggestion, Undo, Reset) — but never
  /// while the field has focus, which would fight the person typing.
  void _syncField() {
    if (!mounted || _focus.hasFocus) return;
    if (_field.text != _c.currentTitle) _field.text = _c.currentTitle;
    setState(() {});
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) _endTyping();
  }

  @override
  void dispose() {
    // Detach FIRST. endEdit() notifies, and a notification that reaches
    // _syncField after this element is defunct asserts inside setState —
    // which is exactly what leaving Words mid-typing would have done.
    _c.removeListener(_syncField);
    _focus.removeListener(_onFocusChange);
    _endTyping();
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// One keystroke is not one undo step. The whole visit to the field is.
  void _onChanged(String v) {
    if (!_typing) {
      _c.beginEdit();
      _typing = true;
    }
    _c.setTitle(v);
    setState(() {});
  }

  void _endTyping() {
    if (!_typing) return;
    _typing = false;
    _c.endEdit();
  }

  /// A title applied at a boundary — a suggestion, Clear, or submit — is one
  /// decision, so it is its own undo step.
  void _apply(String v) {
    _endTyping();
    _c.commitTitle(v);
    _field.text = _c.currentTitle;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ideas = _c.titleIdeas;
    final title = _c.currentTitle;
    final hasTitle = title.trim().isNotEmpty;

    return ListView(
      key: const Key('v2-words-scroll'),
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        // Keep the field clear of the keyboard rather than under it.
        28 + MediaQuery.of(context).viewInsets.bottom,
      ),
      children: [
        _card(
          icon: Icons.title_rounded,
          title: 'Title text',
          helper: 'Add a title to your design (optional).',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TextField(
                key: const Key('v2-title-field'),
                controller: _field,
                focusNode: _focus,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.characters,
                // The renderer shrinks a long title to fit the band; past this
                // it is too small to read on a printed garment.
                inputFormatters: [
                  LengthLimitingTextInputFormatter(
                    StudioController.maxTitleLength,
                  ),
                ],
                onChanged: _onChanged,
                onSubmitted: _apply,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Your title',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: StudioV2Theme.control,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  suffixIcon:
                      hasTitle
                          ? IconButton(
                            key: const Key('v2-title-remove'),
                            tooltip: 'Remove title',
                            icon: const Icon(
                              Icons.cancel,
                              size: 19,
                              color: Colors.white38,
                            ),
                            onPressed: () => _apply(''),
                          )
                          : null,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: StudioV2Theme.subtleBorder,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: StudioV2Theme.accent),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${title.characters.length}/${StudioController.maxTitleLength}',
                key: const Key('v2-title-count'),
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ],
          ),
        ),
        _card(
          icon: Icons.auto_awesome_outlined,
          title: 'Suggestions',
          helper: 'Ideas from your own travels — no network needed.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (ideas.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Tap Suggest for titles built from where you have been.',
                    style: TextStyle(fontSize: 12, color: Colors.white38),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < ideas.length; i++)
                      _IdeaChip(
                        key: Key('v2-title-idea-$i'),
                        label: ideas[i],
                        selected: ideas[i] == title,
                        onTap: () => _apply(ideas[i]),
                      ),
                  ],
                ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('v2-title-suggest'),
                  onPressed: _c.suggestTitles,
                  style: TextButton.styleFrom(
                    foregroundColor: StudioV2Theme.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(
                    ideas.isEmpty ? 'Suggest titles' : 'More ideas',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Face, place and case — present only once there is a title to treat.
        // The panel renders whatever the controller hands it and carries the
        // group-scoped Reset, so nothing about type is written twice.
        FineTunePanel(
          controller: _c,
          only: FineTuneGroup.words,
          shrinkWrap: true,
        ),
      ],
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required String helper,
    required Widget child,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      color: StudioV2Theme.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: StudioV2Theme.subtleBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: StudioV2Theme.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    helper,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
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
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:
            selected
                ? StudioV2Theme.accent.withValues(alpha: 0.14)
                : StudioV2Theme.control,
        border: Border.all(
          color: selected ? StudioV2Theme.accent : StudioV2Theme.subtleBorder,
          width: selected ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: selected ? StudioV2Theme.accent : Colors.white,
        ),
      ),
    ),
  );
}
