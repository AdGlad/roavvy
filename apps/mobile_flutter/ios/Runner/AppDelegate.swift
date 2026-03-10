import CoreLocation
import Flutter
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {

    // Stored as a property so ARC doesn't release the channel after setup returns.
    private var photoScanChannel: FlutterMethodChannel?

    // Single CLGeocoder instance reused for every call.
    // Creating a new instance per call is wasteful; CLGeocoder is designed to be reused.
    private let geocoder = CLGeocoder()

    // Dedicated serial queue for scheduling geocoder calls.
    // Keeps geocoding off the global pool and makes the one-at-a-time constraint explicit.
    private let geocodeQueue = DispatchQueue(label: "com.roavvy.geocode", qos: .utility)

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        setupPhotoScanChannel()
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - Channel setup

    private func setupPhotoScanChannel() {
        // Use registrar(forPlugin:) to get the engine-level binary messenger.
        // This is available before super.application() and works in both
        // debug and release builds.
        guard let registrar = registrar(forPlugin: "PhotoScan") else { return }

        let channel = FlutterMethodChannel(
            name: "roavvy/photo_scan",
            binaryMessenger: registrar.messenger()
        )
        channel.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "requestPermission":
                self?.requestPermission(result: result)
            case "scanPhotos":
                let args = call.arguments as? [String: Any]
                let limit = args?["limit"] as? Int ?? 100
                // sinceDate: ISO 8601 string. nil = full scan; non-nil = incremental rescan.
                let sinceDate: Date? = (args?["sinceDate"] as? String)
                    .flatMap { ISO8601DateFormatter().date(from: $0) }
                self?.scanPhotos(limit: limit, sinceDate: sinceDate, result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        photoScanChannel = channel
    }

    // MARK: - Permission

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

    // MARK: - Scan

    /// Scans up to [limit] photo assets and reverse-geocodes unique coordinate buckets.
    ///
    /// [sinceDate]: when non-nil, only assets created after this date are fetched —
    /// this is the hook for incremental rescans (see mobile_scan_flow.md §Incremental Scans).
    private func scanPhotos(limit: Int, sinceDate: Date?, result: @escaping FlutterResult) {
        let status = PHPhotoLibrary.authorizationStatus()
        guard status == .authorized || status == .limited else {
            result(FlutterError(
                code: "PERMISSION_DENIED",
                message: "Photo library access not granted (status \(status.rawValue))",
                details: nil
            ))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.includeHiddenAssets = false
            // fetchLimit stops PhotoKit reading beyond [limit] rows from disk.
            // Far more efficient than enumerating the full library and stopping
            // inside the enumeration block.
            options.fetchLimit = limit

            // Compound predicate adds a date gate for incremental rescans.
            // PhotoKit evaluates this in the database query — assets older than
            // sinceDate are never loaded into memory at all.
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
            // count is O(1) — stored in the PHFetchResult from the database query.
            let inspected = assets.count

            // Bucket coordinates into a 0.5° grid (≈ 55 km) before geocoding
            // to minimise CLGeocoder calls.
            // Assets without location hit the guard and return immediately —
            // no dictionary lookup, no allocation.
            var buckets: [String: (CLLocation, Int)] = [:]
            var withLocation = 0

            assets.enumerateObjects { asset, _, _ in
                guard let loc = asset.location else { return }
                withLocation += 1

                let lat = (loc.coordinate.latitude  * 2).rounded() / 2
                let lng = (loc.coordinate.longitude * 2).rounded() / 2
                let key = "\(lat),\(lng)"

                if let existing = buckets[key] {
                    buckets[key] = (existing.0, existing.1 + 1)
                } else {
                    buckets[key] = (loc, 1)
                }
            }

            print("[PhotoScan] Inspected: \(inspected), withLocation: \(withLocation), buckets: \(buckets.count)")

            guard !buckets.isEmpty else {
                let payload: [String: Any] = [
                    "inspected": inspected,
                    "withLocation": withLocation,
                    "geocodeSuccesses": 0,
                    "countries": [[String: Any]](),
                ]
                DispatchQueue.main.async { result(payload) }
                return
            }

            self.geocodeSerially(
                buckets: Array(buckets.values),
                index: 0,
                inspected: inspected,
                withLocation: withLocation,
                geocodeSuccesses: 0,
                countryMap: [:],
                result: result
            )
        }
    }

    // MARK: - Serial geocoding
    //
    // CLGeocoder enforces one in-flight request per process.
    // We schedule calls on geocodeQueue (serial) with an adaptive inter-call delay:
    //
    //   Success or no-result (ocean/poles): 0.2 s  — normal cadence
    //   Network / rate-limit error:         1.0 s  — back off before the next attempt
    //
    // The adaptive delay matters when the library has many open-water buckets:
    // those complete quickly with a no-result and don't need the full back-off.

    private func geocodeSerially(
        buckets: [(CLLocation, Int)],
        index: Int,
        inspected: Int,
        withLocation: Int,
        geocodeSuccesses: Int,
        countryMap: [String: (name: String, count: Int)],
        result: @escaping FlutterResult
    ) {
        guard index < buckets.count else {
            let countries: [[String: Any]] = countryMap
                .map { code, value in ["code": code, "name": value.name, "photoCount": value.count] }
                .sorted { ($0["photoCount"] as! Int) > ($1["photoCount"] as! Int) }
            let payload: [String: Any] = [
                "inspected": inspected,
                "withLocation": withLocation,
                "geocodeSuccesses": geocodeSuccesses,
                "countries": countries,
            ]
            print("[PhotoScan] Done. Countries: \(countries.count), geocodeSuccesses: \(geocodeSuccesses)/\(buckets.count)")
            DispatchQueue.main.async { result(payload) }
            return
        }

        let (location, count) = buckets[index]

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self else { return }
            var updated = countryMap
            var successes = geocodeSuccesses
            var delay = 0.2

            if let clError = error as? CLError {
                switch clError.code {
                case .network:
                    // Rate-limited or offline — back off before the next bucket.
                    delay = 1.0
                    print("[PhotoScan] Geocode rate-limit/network [\(index)]: \(clError.localizedDescription)")
                default:
                    // No result — open ocean, poles, unrecognised region. Skip silently.
                    print("[PhotoScan] Geocode no-result [\(index)]: \(clError.localizedDescription)")
                }
            } else if let error {
                print("[PhotoScan] Geocode error [\(index)]: \(error.localizedDescription)")
            } else if let placemark = placemarks?.first,
                      let code = placemark.isoCountryCode,
                      let name = placemark.country {
                let existing = updated[code]
                updated[code] = (name: name, count: (existing?.count ?? 0) + count)
                successes += 1
                print("[PhotoScan] [\(index)/\(buckets.count)] → \(code) (\(name))")
            }

            self.geocodeQueue.asyncAfter(deadline: .now() + delay) {
                self.geocodeSerially(
                    buckets: buckets,
                    index: index + 1,
                    inspected: inspected,
                    withLocation: withLocation,
                    geocodeSuccesses: successes,
                    countryMap: updated,
                    result: result
                )
            }
        }
    }
}
