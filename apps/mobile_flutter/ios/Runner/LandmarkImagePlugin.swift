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
    private weak var rootViewController: UIViewController?

    // MARK: - Registration

    public static func register(
        with messenger: FlutterBinaryMessenger,
        rootViewController: UIViewController
    ) -> LandmarkImagePlugin {
        let channel = FlutterMethodChannel(
            name: "roavvy/landmark_image",
            binaryMessenger: messenger
        )
        let instance = LandmarkImagePlugin(channel: channel, rootVC: rootViewController)
        channel.setMethodCallHandler(instance.handle)
        return instance
    }

    private init(channel: FlutterMethodChannel, rootVC: UIViewController) {
        self.channel = channel
        self.rootViewController = rootVC
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
            let landmarkName = args["landmarkName"] as? String
            presentPlayground(countryName: countryName, landmarkName: landmarkName, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Image Playground

    private func presentPlayground(
        countryName: String,
        landmarkName: String?,
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

        guard let vc = rootViewController else {
            result(FlutterError(
                code: "NO_VIEW_CONTROLLER",
                message: "Root view controller is not available",
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

            // Build concept list for the prompt.
            var concepts: [ImagePlaygroundConcept] = []
            if let landmark = landmarkName, !landmark.isEmpty {
                concepts.append(.text(landmark))
            } else {
                concepts.append(.text("\(countryName) landmark"))
            }
            concepts.append(.text("minimalist monochrome icon"))
            concepts.append(.text("bold silhouette"))
            concepts.append(.text("black on white"))
            playgroundVC.concepts = concepts

            vc.present(playgroundVC, animated: true)
        }
    }

    // MARK: - Helpers

    private func resolveTopVC(_ base: UIViewController) -> UIViewController {
        if let presented = base.presentedViewController {
            return resolveTopVC(presented)
        }
        if let nav = base as? UINavigationController, let top = nav.topViewController {
            return resolveTopVC(top)
        }
        if let tab = base as? UITabBarController, let sel = tab.selectedViewController {
            return resolveTopVC(sel)
        }
        return base
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
