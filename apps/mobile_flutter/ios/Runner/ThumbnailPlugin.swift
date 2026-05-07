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

    // size == 0 → download full-quality image, including from iCloud if needed.
    // isNetworkAccessAllowed = true is safe: photos download to the device and
    // never leave it; this is purely PHImageManager fetching the user's own
    // photo from Apple's servers (extends ADR-002 — Roavvy servers untouched).
    // Thumbnails (size > 0) stay network-disallowed for fast offline display.
    let isFullRes = (size == 0)
    // High-quality requests (size ≥ 1000) need .highQualityFormat so iOS
    // actually decodes the source photo rather than returning a cached
    // low-res thumbnail that looks blurry when stretched to fill the card.
    // Grid/picker thumbnails (< 1000) keep .fastFormat — firing many
    // concurrent highQuality requests causes PHImageManager to drop most.
    let isHighQuality = isFullRes || size >= 1000
    let targetSize = isFullRes
      ? PHImageManagerMaximumSize
      : CGSize(width: size, height: size)
    let options = PHImageRequestOptions()
    options.isNetworkAccessAllowed = isFullRes
    options.deliveryMode = isHighQuality ? .highQualityFormat : .fastFormat
    options.isSynchronous = false

    PHImageManager.default().requestImage(
      for: asset,
      targetSize: targetSize,
      contentMode: PHImageContentMode.aspectFill,
      options: options
    ) { [weak self] image, info in
      // Degrade gracefully: iCloud-only assets return nil here.
      guard let image = image else {
        DispatchQueue.main.async { result(nil) }
        return
      }
      // PHImageManager returns images backed by a premultiplied-alpha bitmap
      // even for opaque photos, which doubles memory and triggers an iOS
      // warning when encoding to JPEG. Redraw into an opaque renderer first.
      let quality: CGFloat = isHighQuality ? 0.92 : 0.82
      let fmt = UIGraphicsImageRendererFormat()
      fmt.opaque = true
      fmt.scale = image.scale
      let renderer = UIGraphicsImageRenderer(size: image.size, format: fmt)
      let jpeg = renderer.jpegData(withCompressionQuality: quality) { _ in
        image.draw(in: CGRect(origin: .zero, size: image.size))
      }
      let data = jpeg as NSData
      self?.cache.setObject(data, forKey: cacheKey)
      DispatchQueue.main.async {
        result(FlutterStandardTypedData(bytes: jpeg))
      }
    }
  }
}
