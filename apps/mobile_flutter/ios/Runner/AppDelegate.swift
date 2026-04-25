import AVFoundation
import CoreLocation
import Flutter
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {

    // Stored as properties so ARC doesn't release channels after setup returns.
    private var photoMethodChannel: FlutterMethodChannel?
    private var photoEventChannel: FlutterEventChannel?
    private var aiTitlePlugin: AnyObject? // holds AiTitlePlugin on iOS 26+

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        configureAudioSession()
        setupChannels()
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
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
