import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Exports a merch design artwork as a shareable PNG (ADR-155, ADR-175).
///
/// Writes [artworkBytes] to a temporary file then invokes [SharePlus] so
/// the user can share via AirDrop, Messages, Instagram, etc.
class MerchShareExporter {
  MerchShareExporter._();

  /// Shares [artworkBytes] as a PNG file with [title] as the share subject.
  ///
  /// [shareText] is shown as the main share body on platforms that support
  /// text+image sharing (e.g. Twitter, WhatsApp). Falls back gracefully when
  /// only image sharing is supported.
  ///
  /// Returns true if the share sheet was presented successfully.
  static Future<bool> share(
    Uint8List artworkBytes, {
    String title = 'My Travel Design',
    String? shareText,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/roavvy_design.png');
      await file.writeAsBytes(artworkBytes);

      final result = await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        subject: title,
        text: shareText,
      );

      return result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.dismissed;
    } catch (_) {
      return false;
    }
  }
}
