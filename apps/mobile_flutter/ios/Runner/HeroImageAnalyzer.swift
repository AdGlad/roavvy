import Foundation
import Photos
import UIKit
import Vision
import CoreImage

/// Analyses hero image candidates for a single trip using on-device Vision
/// framework (M89, ADR-134).
///
/// Fetches 800×800 px images via PHImageManager for quality analysis.
/// Runs VNClassifyImageRequest, VNGenerateAttentionBasedSaliencyImageRequest,
/// and VNDetectFaceRectanglesRequest in a single Vision pass.
/// Color richness is derived from a CIAreaAverage filter.
/// Never accesses the network for local assets.
final class HeroImageAnalyzer {

    // MARK: - CIContext (reused across calls)

    private let ciContext = CIContext(options: [.workingColorSpace: NSNull()])

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
        // Always request high quality — analysis accuracy depends on image detail.
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = allowNetwork
        options.isSynchronous = false
        options.resizeMode = PHImageRequestOptionsResizeMode.fast

        // 800×800 gives enough detail for Vision scene classification,
        // saliency mapping, face detection, and color richness analysis while
        // remaining performant on background threads.
        let targetSize = CGSize(width: 800, height: 800)

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

                // Track actual resolution returned (shorter edge in pixels).
                let analysisResolution = min(cgImage.width, cgImage.height)

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                let classifyRequest = VNClassifyImageRequest()
                let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()
                let faceRequest = VNDetectFaceRectanglesRequest()

                do {
                    try handler.perform([classifyRequest, saliencyRequest, faceRequest])
                } catch {
                    // Vision failure — return metadata-only result.
                    let result = self.buildResult(
                        asset: asset,
                        tripId: tripId,
                        labelDict: [:],
                        qualityScore: 0.0,
                        saliencyCenterScore: 0.5,
                        faceCount: 0,
                        colorRichnessScore: 0.5,
                        analysisResolution: analysisResolution
                    )
                    completion(result)
                    return
                }

                let observations = (classifyRequest.results as? [VNClassificationObservation]) ?? []
                let labelDict = LabelNormalizer.normalise(observations)
                let quality = self.computeQualityScore(asset: asset)
                let saliency = self.computeSaliencyCenterScore(request: saliencyRequest)
                let faceCount = (faceRequest.results as? [VNFaceObservation])?.count ?? 0
                let colorRichness = self.computeColorRichness(cgImage: cgImage)

                let result = self.buildResult(
                    asset: asset,
                    tripId: tripId,
                    labelDict: labelDict,
                    qualityScore: quality,
                    saliencyCenterScore: saliency,
                    faceCount: faceCount,
                    colorRichnessScore: colorRichness,
                    analysisResolution: analysisResolution
                )
                completion(result)
            }
        )
    }

    // MARK: - Quality score

    /// Computes a normalised quality score 0.0–1.0 from pixel dimensions.
    private func computeQualityScore(asset: PHAsset) -> Double {
        let shorter = min(asset.pixelWidth, asset.pixelHeight)
        if shorter >= 2000 { return 1.0 }
        if shorter >= 1080 { return 0.65 }
        return 0.3
    }

    // MARK: - Saliency center score

    /// Returns 0.0–1.0 indicating how centred the most salient region is.
    /// 1.0 = perfectly centred subject; 0.0 = subject at corner.
    /// Returns 0.5 (neutral) when no saliency data is available.
    private func computeSaliencyCenterScore(
        request: VNGenerateAttentionBasedSaliencyImageRequest
    ) -> Double {
        guard
            let observation = request.results?.first as? VNSaliencyImageObservation,
            let objects = observation.salientObjects,
            !objects.isEmpty
        else {
            return 0.5
        }

        // Weighted centre of mass of salient bounding boxes.
        var weightedX: Double = 0
        var weightedY: Double = 0
        var totalWeight: Double = 0

        for obj in objects {
            let cx = Double(obj.boundingBox.midX)
            // Vision coordinates have origin at bottom-left; flip Y for consistency.
            let cy = 1.0 - Double(obj.boundingBox.midY)
            let weight = Double(obj.confidence)
            weightedX += cx * weight
            weightedY += cy * weight
            totalWeight += weight
        }

        guard totalWeight > 0 else { return 0.5 }

        let cx = weightedX / totalWeight
        let cy = weightedY / totalWeight

        // Euclidean distance from image centre (0.5, 0.5).
        // Max distance from centre to corner ≈ 0.707.
        let dx = cx - 0.5
        let dy = cy - 0.5
        let dist = sqrt(dx * dx + dy * dy)

        // Map 0 (centred) → 1.0, 0.707 (corner) → ~0.0.
        let score = max(0.0, 1.0 - dist * 1.414)
        return score
    }

    // MARK: - Color richness

    /// Returns 0.0–1.0 representing the HSB saturation of the image's average
    /// colour. Low values indicate grey/flat scenes; high values indicate
    /// vibrant, colourful images (sunsets, tropical scenes, etc.).
    private func computeColorRichness(cgImage: CGImage) -> Double {
        let ciImage = CIImage(cgImage: cgImage)
        guard
            let filter = CIFilter(name: "CIAreaAverage", parameters: [
                kCIInputImageKey: ciImage,
                kCIInputExtentKey: CIVector(cgRect: ciImage.extent)
            ]),
            let output = filter.outputImage
        else {
            return 0.5
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        let r = Double(bitmap[0]) / 255.0
        let g = Double(bitmap[1]) / 255.0
        let b = Double(bitmap[2]) / 255.0

        let maxC = max(r, max(g, b))
        let minC = min(r, min(g, b))
        let saturation = maxC > 0 ? (maxC - minC) / maxC : 0.0
        return saturation
    }

    // MARK: - Result builder

    private func buildResult(
        asset: PHAsset,
        tripId: String,
        labelDict: [String: Any],
        qualityScore: Double,
        saliencyCenterScore: Double,
        faceCount: Int,
        colorRichnessScore: Double,
        analysisResolution: Int
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
            "saliencyCenterScore": saliencyCenterScore,
            "faceCount": faceCount,
            "colorRichnessScore": colorRichnessScore,
            "analysisResolution": analysisResolution,
        ]
        // Flatten label fields into top-level for Dart convenience.
        for (key, value) in labelDict {
            result[key] = value
        }
        return result
    }
}
