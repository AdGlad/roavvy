import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

/// Uploads processed print/mockup images to Firebase Storage.
class MerchStorageUploader {
  final FirebaseStorage _storage;

  MerchStorageUploader({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  /// Uploads [bytes] to [storagePath] with content-type image/png.
  ///
  /// Returns [storagePath] on success.
  Future<String> upload(Uint8List bytes, String storagePath) async {
    final ref = _storage.ref(storagePath);
    await ref.putData(bytes, SettableMetadata(contentType: 'image/png'));
    return storagePath;
  }
}
