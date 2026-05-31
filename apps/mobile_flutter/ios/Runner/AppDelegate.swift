import AVFoundation
import CoreLocation
import Firebase
import Flutter
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {

    // Stored as properties so ARC doesn't release channels after setup returns.
    private var photoMethodChannel: FlutterMethodChannel?
    private var photoEventChannel: FlutterEventChannel?
    private var aiTitlePlugin: AnyObject? // holds AiTitlePlugin on iOS 26+
    private var landmarkImagePlugin: AnyObject? // holds LandmarkImagePlugin on iOS 18.1+
    private var heroAnalysisChannel: FlutterMethodChannel?
    private let heroAnalyzer = HeroImageAnalyzer()
    private let thumbnailPlugin = ThumbnailPlugin()

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FirebaseApp.configure()
        GeneratedPluginRegistrant.register(with: self)
        configureAudioSession()
        setupChannels()
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    /// Fixes the touch-freeze that occurs after sharing via Messages.
    ///
    /// Sequence that causes the freeze:
    ///   1. Share sheet opens (UIActivityViewController).
    ///   2. User taps Messages → SHSheetRemoteCustomViewController (Messages share
    ///      extension) is presented as a form sheet inside the activity controller.
    ///   3. User taps Send → the extension starts its dismiss animation.
    ///   4. iOS opens the full Messages app mid-animation → our app backgrounds →
    ///      UIKit freezes the dismiss animation at that frame.
    ///   5. The Messages extension process terminates (XPC connection invalidated).
    ///   6. User returns → applicationDidBecomeActive fires.
    ///
    /// The _UIFormSheetPresentationController for the Messages extension is now
    /// permanently stuck "transitioning" (its process is gone). Any call to
    /// dismiss() on the parent UIActivityViewController is silently rejected with
    /// "Trying to dismiss while transitioning". The invisible ghost VC stays in
    /// the hierarchy and intercepts every touch → app appears frozen.
    ///
    /// Fix (two steps):
    ///   Step 1 — immediately set isUserInteractionEnabled = false on the stuck
    ///            VC's view so touch events fall through to Flutter. User can
    ///            interact with the app straight away.
    ///   Step 2 — retry dismiss() with back-off delays; the internal transitioning
    ///            flag may clear asynchronously as UIKit settles. If all retries
    ///            fail (remote process is gone and state is permanent), hide the
    ///            view as a last resort.
    override func applicationDidBecomeActive(_ application: UIApplication) {
        super.applicationDidBecomeActive(application)
        DispatchQueue.main.async { [weak self] in
            self?.cleanupStuckShareSheet()
        }
    }

    private func cleanupStuckShareSheet() {
        guard
            let rootVC = window?.rootViewController,
            let activityVC = rootVC.presentedViewController as? UIActivityViewController
        else { return }

        // Step 1: immediately restore Flutter touch input.
        activityVC.view.isUserInteractionEnabled = false

        // Step 2: retry proper VC dismissal with back-off.
        retryDismiss(activityVC, delays: [0.3, 0.6, 1.0, 2.0])
    }

    /// Attempts `dismiss(animated:false)` on `vc`, retrying after each delay if
    /// the VC is still in the hierarchy. Falls back to hiding the view if all
    /// delays are exhausted (permanent stuck state due to remote process death).
    private func retryDismiss(_ vc: UIActivityViewController, delays: [TimeInterval]) {
        guard !delays.isEmpty else {
            vc.view.isHidden = true // last resort — view gone, hierarchy stays
            return
        }
        let delay = delays[0]
        let remaining = Array(delays.dropFirst())
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak vc] in
            guard let vc else { return }
            guard vc.presentingViewController != nil, !vc.isBeingDismissed else { return }
            vc.dismiss(animated: false, completion: nil)
            // Schedule next retry in case this attempt was also silently rejected.
            self?.retryDismiss(vc, delays: remaining)
        }
    }

    // MARK: - Audio session

    /// Configures AVAudioSession so celebration sounds play even when the
    /// device ringer switch is off. `.playback` with `.mixWithOthers` lets
    /// our sounds layer over background music without interrupting it.
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: .mixWithOthers
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Non-critical — audio simply falls back to system defaults.
        }
    }

    // MARK: - Channel setup

    private func setupChannels() {
        guard let registrar = registrar(forPlugin: "PhotoScan") else { return }
        let messenger = registrar.messenger()

        // Method channel — permission only.
        let methodChannel = FlutterMethodChannel(
            name: "roavvy/photo_scan",
            binaryMessenger: messenger
        )
        methodChannel.setMethodCallHandler { [weak self] call, result in
            if call.method == "requestPermission" {
                self?.requestPermission(result: result)
            } else if call.method == "openSettings" {
                self?.openSettings(result: result)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
        photoMethodChannel = methodChannel

        // Event channel — streams per-photo GPS records during a scan.
        // Flutter subscribes via receiveBroadcastStream(args) which triggers onListen.
        let eventChannel = FlutterEventChannel(
            name: "roavvy/photo_scan/events",
            binaryMessenger: messenger
        )
        eventChannel.setStreamHandler(self)
        photoEventChannel = eventChannel

        // AI title generation channel (ADR-124).
        if #available(iOS 26.0, *) {
            aiTitlePlugin = AiTitlePlugin.register(with: messenger)
        }

        // Landmark image generation channel (M116).
        if #available(iOS 18.1, *) {
            landmarkImagePlugin = LandmarkImagePlugin.register(with: messenger)
        }

        // Hero image analysis channel (M89, ADR-134).
        let heroChannel = FlutterMethodChannel(
            name: "roavvy/hero_analysis",
            binaryMessenger: messenger
        )
        heroChannel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }
            switch call.method {
            case "analyseHeroCandidates":
                guard
                    let args = call.arguments as? [String: Any],
                    let tripId = args["tripId"] as? String,
                    let assetIds = args["assetIds"] as? [String]
                else {
                    result(FlutterError(
                        code: "INVALID_ARGS",
                        message: "analyseHeroCandidates requires tripId and assetIds",
                        details: nil
                    ))
                    return
                }
                self.heroAnalyzer.analyse(assetIds: assetIds, tripId: tripId) { results in
                    DispatchQueue.main.async { result(results) }
                }
            case "checkAssetsExist":
                guard
                    let args = call.arguments as? [String: Any],
                    let assetIds = args["assetIds"] as? [String]
                else {
                    result([])
                    return
                }
                let existing = self.heroAnalyzer.checkExistence(assetIds: assetIds)
                result(existing)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        heroAnalysisChannel = heroChannel

        // Thumbnail fetch channel (M90, ADR-135).
        thumbnailPlugin.register(with: messenger)
    }

    // MARK: - Permission

    private func openSettings(result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            guard let url = URL(string: UIApplication.openSettingsURLString) else {
                result(nil)
                return
            }
            UIApplication.shared.open(url)
            result(nil)
        }
    }

    private func requestPermission(result: @escaping FlutterResult) {
        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async { result(status.rawValue) }
            }
        } else {
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async { result(status.rawValue) }
            }
        }
    }
}

// MARK: - FlutterStreamHandler

extension AppDelegate: FlutterStreamHandler {
    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        let args = arguments as? [String: Any]
        let limit = args?["limit"] as? Int ?? 2000
        // sinceDate: ISO 8601 string from Dart's DateTime.toIso8601String().
        // Dart always emits microseconds (e.g. "2026-04-24T10:30:00.123456Z"),
        // so we must enable .withFractionalSeconds; without it the default
        // ISO8601DateFormatter returns nil and every scan falls back to full.
        let sinceDate: Date? = (args?["sinceDate"] as? String).flatMap { raw in
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return fmt.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        }
        startScan(limit: limit, sinceDate: sinceDate, sink: events)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil
    }
}

// MARK: - Scan

private extension AppDelegate {

    /// Enumerates PhotoKit assets and streams raw GPS records to [sink].
    ///
    /// Swift sends [batchSize] photos per 'batch' event, then a terminal 'done'
    /// event. No geocoding is performed — country resolution is the Dart layer's
    /// responsibility (see packages/country_lookup).
    ///
    /// [sinceDate]: when non-nil, only assets created after this date are fetched
    /// — the hook for incremental rescans (see mobile_scan_flow.md §Incremental Scans).
    func startScan(limit: Int, sinceDate: Date?, sink: @escaping FlutterEventSink) {
        let status = PHPhotoLibrary.authorizationStatus()
        guard status == .authorized || status == .limited else {
            DispatchQueue.main.async {
                sink(FlutterError(
                    code: "PERMISSION_DENIED",
                    message: "Photo library access not granted (status \(status.rawValue))",
                    details: nil
                ))
            }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            options.includeHiddenAssets = false
            // fetchLimit stops PhotoKit reading beyond [limit] rows from disk.
            options.fetchLimit = limit

            // Compound predicate adds a date gate for incremental rescans.
            if let sinceDate {
                options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue),
                    NSPredicate(format: "creationDate > %@", sinceDate as CVarArg),
                ])
            } else {
                options.predicate = NSPredicate(
                    format: "mediaType = %d", PHAssetMediaType.image.rawValue
                )
            }

            let assets = PHAsset.fetchAssets(with: options)
            let inspected = assets.count
            var withLocation = 0

            // Collect GPS records, flushing in batches to keep memory bounded.
            let batchSize = 50
            let isoFormatter = ISO8601DateFormatter()
            var batch: [[String: Any]] = []

            assets.enumerateObjects { asset, _, _ in
                guard let location = asset.location else { return }
                withLocation += 1

                var record: [String: Any] = [
                    "lat": location.coordinate.latitude,
                    "lng": location.coordinate.longitude,
                    "assetId": asset.localIdentifier,
                ]
                if let capturedAt = asset.creationDate {
                    record["capturedAt"] = isoFormatter.string(from: capturedAt)
                }
                batch.append(record)

                if batch.count >= batchSize {
                    let toSend = batch
                    batch = []
                    DispatchQueue.main.async {
                        sink(["type": "batch", "photos": toSend] as [String: Any])
                    }
                }
            }

            // Flush remainder and send the terminal done event.
            let remaining = batch
            let finalInspected = inspected
            let finalWithLocation = withLocation

            DispatchQueue.main.async {
                if !remaining.isEmpty {
                    sink(["type": "batch", "photos": remaining] as [String: Any])
                }
                sink([
                    "type": "done",
                    "inspected": finalInspected,
                    "withLocation": finalWithLocation,
                ] as [String: Any])
                sink(FlutterEndOfEventStream)
            }
        }
    }
}
