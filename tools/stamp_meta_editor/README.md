# Stamp Meta Editor

A local Flutter desktop tool for adjusting passport stamp metadata.

## Prerequisites
- Flutter SDK installed.
- macOS (tested) or Windows/Linux.

## Running the Tool
From the root of the repository:
```bash
cd tools/stamp_meta_editor
flutter pub get
flutter run -d macos
```

## Architecture
- **State Management:** Riverpod for handling asset lists, selection, and metadata updates.
- **Persistence:** Direct file I/O using `dart:io` against absolute paths in the Roavvy repository.
- **Preview:** A layered `Stack` that places the PNG base image and overlays a `Text` widget. The text is transformed using `Positioned` and `Transform.rotate` to match the JSON metadata.
- **Editor:** Reactive numeric controls for quick adjustments and a read-only JSON view for inspection.

## Key Shortcuts
- **Arrow Up / Down:** Navigate through assets.
- **Cmd + S / Ctrl + S:** Save changes to disk.
- **Zoom Slider:** Scale the preview for pixel-perfect adjustments.

## Notes
- The tool currently uses 'monospace' as a placeholder for the actual font rendering.
- It loads from and saves to the hardcoded paths in `main.dart`. Update `basePath` if your repo location differs.
