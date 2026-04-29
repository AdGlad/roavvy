import Flutter
import Photos
import UIKit

/// Provides on-demand JPEG thumbnails for local PHAsset identifiers.
///
/// Channel: `roavvy/thumbnail`
/// Method:  `getThumbnail({assetId: String, size: Int}) → FlutterStandardTypedData? (JPEG)`
///
/// - Results are cached per session in `NSCache` keyed by `"<assetId>@<size>"`.
/// - `isNetworkAccessAllowed = false` — iCloud-only assets return nil.
/// - Photo bytes never leave the device (extends ADR-002, ADR-135).
class ThumbnailPlugin: NSObject {

  private let cache = NSCache<NSString, NSData>()

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "roavvy/thumbnail",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "getThumbnail" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let args = call.arguments as? [String: Any],
        let assetId = args["assetId"] as? String,
        let size = args["size"] as? Int
      else {
        result(FlutterError(code: "INVALID_ARGS", message: "assetId and size required", details: nil))
        return
      }
      self?.fetchThumbnail(assetId: assetId, size: size, result: result)
    }
  }

  private func fetchThumbnail(assetId: String, size: Int, result: @escaping FlutterResult) {
    let cacheKey = "\(assetId)@\(size)" as NSString

    if let cached = cache.object(forKey: cacheKey) {
      result(FlutterStandardTypedData(bytes: cached as Data))
      return
    }

    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
    guard let asset = fetchResult.firstObject else {
      result(nil)
      return
    }

    let targetSize = CGSize(width: size, height: size)
    let options = PHImageRequestOptions()
    options.isNetworkAccessAllowed = false
    options.deliveryMode = .fastFormat
    options.isSynchronous = false

    PHImageManager.default().requestImage(
      for: asset,
      targetSize: targetSize,
      contentMode: PHImageContentMode.aspectFill,
      options: options
    ) { [weak self] image, info in
      // Degrade gracefully: iCloud-only assets return nil here.
      guard let image = image,
            let jpeg = image.jpegData(compressionQuality: 0.82) else {
        DispatchQueue.main.async { result(nil) }
        return
      }
      let data = jpeg as NSData
      self?.cache.setObject(data, forKey: cacheKey)
      DispatchQueue.main.async {
        result(FlutterStandardTypedData(bytes: jpeg))
      }
    }
  }
}
