import Foundation
import Photos
import UIKit
import Vision

/// Analyses hero image candidates for a single trip using on-device Vision
/// framework (M89, ADR-134).
///
/// Fetches 200×200 px thumbnails via PHImageManager
/// (isNetworkAccessAllowed = false) and runs VNClassifyImageRequest.
/// Never accesses the network.
final class HeroImageAnalyzer {

    // MARK: - Public API

    /// Analyses [assetIds] and returns one result dict per successfully
    /// analysed asset.
    ///
    /// [tripId] is echoed into each result so Dart can correlate results
    /// back to the originating trip.
    ///
    /// Assets that are iCloud-only, deleted, or unavailable are silently
    /// skipped — the returned array may be shorter than [assetIds].
    ///
    /// Must NOT be called on the main thread.
    func analyse(
        assetIds: [String],
        tripId: String,
        completion: @escaping ([[String: Any]]) -> Void
    ) {
        guard !assetIds.isEmpty else {
            completion([])
            return
        }

        DispatchQueue.global(qos: .utility).async {
            let fetchResult = PHAsset.fetchAssets(
                withLocalIdentifiers: assetIds,
                options: nil
            )

            var results: [[String: Any]] = []
            let group = DispatchGroup()

            fetchResult.enumerateObjects { asset, _, _ in
                group.enter()
                self.analyseAsset(asset, tripId: tripId) { result in
                    if let r = result {
                        results.append(r)
                    }
                    group.leave()
                }
            }

            group.notify(queue: .global(qos: .utility)) {
                completion(results)
            }
        }
    }

    /// Returns the subset of [assetIds] that still exist in the photo library.
    func checkExistence(assetIds: [String]) -> [String] {
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: assetIds,
            options: nil
        )
        var existing: [String] = []
        fetchResult.enumerateObjects { asset, _, _ in
            existing.append(asset.localIdentifier)
        }
        return existing
    }

    // MARK: - Per-asset analysis

    private func analyseAsset(
        _ asset: PHAsset,
        tripId: String,
        completion: @escaping ([String: Any]?) -> Void
    ) {
        let options = PHImageRequestOptions()
        options.deliveryMode = PHImageRequestOptionsDeliveryMode.fastFormat
        options.isNetworkAccessAllowed = false   // ADR-002: no iCloud fetch
        options.isSynchronous = false
        options.resizeMode = PHImageRequestOptionsResizeMode.fast

        let targetSize = CGSize(width: 200, height: 200)

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: PHImageContentMode.aspectFill,
            options: options,
            resultHandler: { image, _ in
                // Degrade gracefully for unavailable / iCloud-only assets.
                guard let uiImage = image, let cgImage = uiImage.cgImage else {
                    completion(nil)
                    return
                }

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                let request = VNClassifyImageRequest()

                do {
                    try handler.perform([request])
                } catch {
                    // Vision failure — return metadata-only result.
                    let result = self.buildResult(
                        asset: asset,
                        tripId: tripId,
                        labelDict: [:],
                        qualityScore: 0.0
                    )
                    completion(result)
                    return
                }

                let observations = (request.results as? [VNClassificationObservation]) ?? []
                let labelDict = LabelNormalizer.normalise(observations)
                let quality = self.computeQualityScore(asset: asset)

                let result = self.buildResult(
                    asset: asset,
                    tripId: tripId,
                    labelDict: labelDict,
                    qualityScore: quality
                )
                completion(result)
            }
        )
    }

    // MARK: - Quality score

    /// Computes a normalised quality score 0.0–1.0 from pixel dimensions.
    ///
    /// A future milestone can add aperture score via VNImageAestheticsScoresObservation
    /// (iOS 17+). For now we use the dimension-based sub-score only.
    private func computeQualityScore(asset: PHAsset) -> Double {
        let shorter = min(asset.pixelWidth, asset.pixelHeight)
        if shorter >= 2000 { return 1.0 }
        if shorter >= 1080 { return 0.65 }
        return 0.3
    }

    // MARK: - Result builder

    private func buildResult(
        asset: PHAsset,
        tripId: String,
        labelDict: [String: Any],
        qualityScore: Double
    ) -> [String: Any] {
        let isoFormatter = ISO8601DateFormatter()
        let capturedAt = asset.creationDate.map { isoFormatter.string(from: $0) } ?? ""

        var result: [String: Any] = [
            "assetId": asset.localIdentifier,
            "tripId": tripId,
            "capturedAt": capturedAt,
            "pixelWidth": asset.pixelWidth,
            "pixelHeight": asset.pixelHeight,
            "hasGps": asset.location != nil,
            "qualityScore": qualityScore,
            "labels": labelDict,
        ]
        // Flatten label fields into top-level for Dart convenience.
        for (key, value) in labelDict {
            result[key] = value
        }
        return result
    }
}
