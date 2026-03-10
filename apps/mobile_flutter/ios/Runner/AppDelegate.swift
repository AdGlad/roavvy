import CoreLocation
import Flutter
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {

    // Stored as a property so ARC doesn't release the channel after setup returns.
    private var photoScanChannel: FlutterMethodChannel?

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
                let limit = (call.arguments as? [String: Any])?["limit"] as? Int ?? 100
                self?.scanPhotos(limit: limit, result: result)
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

    private func scanPhotos(limit: Int, result: @escaping FlutterResult) {
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
            options.predicate = NSPredicate(
                format: "mediaType = %d", PHAssetMediaType.image.rawValue
            )

            let assets = PHAsset.fetchAssets(with: options)

            // Bucket coordinates into a 0.5° grid (≈ 55 km) before geocoding
            // to minimise CLGeocoder calls.
            var buckets: [String: (CLLocation, Int)] = [:]
            var withLocation = 0
            var inspected = 0

            assets.enumerateObjects { asset, _, stop in
                guard inspected < limit else { stop.pointee = true; return }
                inspected += 1
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
    // CLGeocoder only allows one in-flight request at a time.
    // Recurse through buckets with a small delay between each call.

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

        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self else { return }
            var updated = countryMap
            var successes = geocodeSuccesses

            if let error {
                print("[PhotoScan] Geocode error [\(index)]: \(error.localizedDescription)")
            } else if let placemark = placemarks?.first,
                      let code = placemark.isoCountryCode,
                      let name = placemark.country {
                let existing = updated[code]
                updated[code] = (name: name, count: (existing?.count ?? 0) + count)
                successes += 1
                print("[PhotoScan] [\(index)/\(buckets.count)] → \(code) (\(name))")
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
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
