import Flutter
import UIKit
import ImagePlayground

// ── LandmarkImagePlugin (M116) ────────────────────────────────────────────────
//
// MethodChannel: roavvy/landmark_image
//
// Methods:
//   isAvailable()                        → Bool
//   generateLandmarkIcon({isoCode, countryName, landmarkName?}) → FlutterStandardTypedData (PNG)
//
// Uses ImagePlaygroundViewController (iOS 18.1+) to present Apple Intelligence
// image generation. On confirmation the generated image is returned as PNG bytes.
// The Dart layer is responsible for caching to disk.

@available(iOS 18.1, *)
public class LandmarkImagePlugin: NSObject {

    private let channel: FlutterMethodChannel
    private var pendingResult: FlutterResult?

    // MARK: - Registration

    public static func register(with messenger: FlutterBinaryMessenger) -> LandmarkImagePlugin {
        let channel = FlutterMethodChannel(
            name: "roavvy/landmark_image",
            binaryMessenger: messenger
        )
        let instance = LandmarkImagePlugin(channel: channel)
        channel.setMethodCallHandler(instance.handle)
        return instance
    }

    private init(channel: FlutterMethodChannel) {
        self.channel = channel
    }

    // MARK: - VC resolution

    /// Resolves the topmost presented view controller at call time, so we never
    /// hold a stale weak reference captured at app-launch.
    private func topViewController() -> UIViewController? {
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return nil }
        var top: UIViewController = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }

    // MARK: - Method handler

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
            result(ImagePlaygroundViewController.isAvailable)

        case "generateLandmarkIcon":
            guard
                let args = call.arguments as? [String: Any],
                let countryName = args["countryName"] as? String
            else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "generateLandmarkIcon requires countryName",
                    details: nil
                ))
                return
            }
            let description = args["description"] as? String
            presentPlayground(countryName: countryName, description: description, result: result)

        case "generateLandmarkCollage":
            guard
                let args = call.arguments as? [String: Any],
                let descriptions = args["descriptions"] as? [String],
                !descriptions.isEmpty
            else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "generateLandmarkCollage requires non-empty descriptions array",
                    details: nil
                ))
                return
            }
            presentCollagePlayground(descriptions: descriptions, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Image Playground

    private func presentPlayground(
        countryName: String,
        description: String?,
        result: @escaping FlutterResult
    ) {
        guard ImagePlaygroundViewController.isAvailable else {
            result(FlutterError(
                code: "UNAVAILABLE",
                message: "Image Playground is not available on this device or OS version",
                details: nil
            ))
            return
        }

        guard let vc = topViewController() else {
            result(FlutterError(
                code: "NO_VIEW_CONTROLLER",
                message: "Could not resolve a presenting view controller",
                details: nil
            ))
            return
        }

        // Only one generation at a time.
        if pendingResult != nil {
            result(FlutterError(
                code: "BUSY",
                message: "A generation is already in progress",
                details: nil
            ))
            return
        }

        pendingResult = result

        DispatchQueue.main.async {
            let playgroundVC = ImagePlaygroundViewController()
            playgroundVC.delegate = self

            // Build concept list.
            // Image Playground responds best to a specific subject description
            // followed by a concise style tag. Keep it to 2–3 concepts.
            var concepts: [ImagePlaygroundConcept] = []
            if let desc = description, !desc.isEmpty {
                concepts.append(.text(desc))
            } else {
                concepts.append(.text("iconic landmark of \(countryName)"))
            }
            concepts.append(.text("travel sticker illustration"))
            playgroundVC.concepts = concepts

            vc.present(playgroundVC, animated: true)
        }
    }

    // MARK: - Collage Playground

    /// Opens a single Image Playground session seeded with one concept per
    /// landmark (up to 6) plus a unifying style concept.
    private func presentCollagePlayground(
        descriptions: [String],
        result: @escaping FlutterResult
    ) {
        guard ImagePlaygroundViewController.isAvailable else {
            result(FlutterError(
                code: "UNAVAILABLE",
                message: "Image Playground is not available on this device or OS version",
                details: nil
            ))
            return
        }

        guard let vc = topViewController() else {
            result(FlutterError(
                code: "NO_VIEW_CONTROLLER",
                message: "Could not resolve a presenting view controller",
                details: nil
            ))
            return
        }

        if pendingResult != nil {
            result(FlutterError(
                code: "BUSY",
                message: "A generation is already in progress",
                details: nil
            ))
            return
        }

        pendingResult = result

        DispatchQueue.main.async {
            let playgroundVC = ImagePlaygroundViewController()
            playgroundVC.delegate = self

            // Seed up to 6 landmark subjects so the model composes a collage.
            // More than ~6 concepts tend to confuse the model.
            var concepts: [ImagePlaygroundConcept] = []
            for desc in descriptions.prefix(6) {
                concepts.append(.text(desc))
            }
            concepts.append(.text("world landmarks travel poster illustration"))
            playgroundVC.concepts = concepts

            vc.present(playgroundVC, animated: true)
        }
    }

}

// MARK: - ImagePlaygroundViewController.Delegate

@available(iOS 18.1, *)
extension LandmarkImagePlugin: ImagePlaygroundViewController.Delegate {

    public func imagePlaygroundViewController(
        _ imagePlaygroundViewController: ImagePlaygroundViewController,
        didCreateImageAt imageURL: URL
    ) {
        imagePlaygroundViewController.dismiss(animated: true)

        guard let data = try? Data(contentsOf: imageURL) else {
            DispatchQueue.main.async { [weak self] in
                self?.pendingResult?(FlutterError(
                    code: "READ_ERROR",
                    message: "Could not read generated image at \(imageURL)",
                    details: nil
                ))
                self?.pendingResult = nil
            }
            return
        }

        // Convert to PNG for consistent Dart-side handling.
        let pngData: Data
        if let uiImage = UIImage(data: data), let png = uiImage.pngData() {
            pngData = png
        } else {
            pngData = data
        }

        DispatchQueue.main.async { [weak self] in
            self?.pendingResult?(FlutterStandardTypedData(bytes: pngData))
            self?.pendingResult = nil
        }
    }

    public func imagePlaygroundViewControllerDidCancel(
        _ imagePlaygroundViewController: ImagePlaygroundViewController
    ) {
        imagePlaygroundViewController.dismiss(animated: true)
        DispatchQueue.main.async { [weak self] in
            // Dart side receives nil to indicate user cancelled.
            self?.pendingResult?(nil)
            self?.pendingResult = nil
        }
    }
}
