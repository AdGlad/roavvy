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
    /// Local (on-device) assets are analysed first. iCloud-only assets are
    /// only fetched and analysed if the local results are fewer than the
    /// number of requested assetIds — i.e. local photos always take priority
    /// as hero candidates (ADR-134 extended).
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

            var allAssets: [PHAsset] = []
            fetchResult.enumerateObjects { asset, _, _ in
                allAssets.append(asset)
            }

            // Partition into local and iCloud-only groups.
            let (localAssets, iCloudAssets) = self.partitionByAvailability(allAssets)

            // Analyse local assets first — no network required.
            var results: [[String: Any]] = []
            let localGroup = DispatchGroup()

            for asset in localAssets {
                localGroup.enter()
                self.analyseAsset(asset, tripId: tripId, allowNetwork: false) { result in
                    if let r = result { results.append(r) }
                    localGroup.leave()
                }
            }
            localGroup.wait()

            // Fall back to iCloud assets only if we still need more candidates.
            let needed = assetIds.count - results.count
            if needed > 0 && !iCloudAssets.isEmpty {
                let iCloudGroup = DispatchGroup()
                for asset in iCloudAssets.prefix(needed) {
                    iCloudGroup.enter()
                    self.analyseAsset(asset, tripId: tripId, allowNetwork: true) { result in
                        if let r = result { results.append(r) }
                        iCloudGroup.leave()
                    }
                }
                iCloudGroup.wait()
            }

            completion(results)
        }
    }

    // MARK: - Local availability check

    /// Returns assets split into (local, iCloud-only) by probing each with a
    /// 1×1 synchronous fetch. A nil result with isNetworkAccessAllowed=false
    /// means the asset is not cached on-device.
    private func partitionByAvailability(_ assets: [PHAsset]) -> (local: [PHAsset], iCloud: [PHAsset]) {
        var local: [PHAsset] = []
        var iCloud: [PHAsset] = []

        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .fastFormat

        for asset in assets {
            var isLocal = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 1, height: 1),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                isLocal = (image != nil)
            }
            if isLocal { local.append(asset) } else { iCloud.append(asset) }
        }

        return (local, iCloud)
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
        allowNetwork: Bool,
        completion: @escaping ([String: Any]?) -> Void
    ) {
        let options = PHImageRequestOptions()
        options.deliveryMode = allowNetwork ? .highQualityFormat : .fastFormat
        options.isNetworkAccessAllowed = allowNetwork
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
