import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Exports a merch design artwork as a shareable PNG (ADR-155).
///
/// Writes [artworkBytes] to a temporary file then invokes [SharePlus] so
/// the user can share via AirDrop, Messages, Instagram, etc.
class MerchShareExporter {
  MerchShareExporter._();

  /// Shares [artworkBytes] as a PNG file with [title] as the share subject.
  ///
  /// Returns true if the share sheet was presented successfully.
  static Future<bool> share(Uint8List artworkBytes, {String title = 'My Travel Design'}) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/roavvy_design.png');
      await file.writeAsBytes(artworkBytes);

      final result = await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        subject: title,
      );

      return result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.dismissed;
    } catch (_) {
      return false;
    }
  }
}
