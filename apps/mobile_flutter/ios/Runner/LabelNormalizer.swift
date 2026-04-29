import Foundation
import Vision

/// Maps Vision VNClassifyImageRequest identifier strings to the Roavvy label
/// vocabulary (M89, ADR-134).
///
/// Raw ML identifiers are never stored or sent to Dart — only normalised
/// Roavvy vocabulary values cross the MethodChannel boundary.
///
/// Unknown identifiers are silently discarded (not included in output).
struct LabelNormalizer {

    // MARK: - Normalisation entry point

    /// Normalises a list of Vision classification observations into a
    /// structured Roavvy label dict.
    ///
    /// Only observations with confidence >= [threshold] are considered.
    /// Returns a dict containing any of the keys:
    ///   primaryScene, secondaryScene, activity, mood, subjects,
    ///   labelConfidence
    static func normalise(
        _ observations: [VNClassificationObservation],
        threshold: Float = 0.35
    ) -> [String: Any] {
        let qualifying = observations
            .filter { $0.confidence >= threshold }
            .sorted { $0.confidence > $1.confidence }

        var primaryScene: String?
        var secondaryScene: String?
        var activity: [String] = []
        var mood: [String] = []
        var subjects: [String] = []
        var maxConfidence: Float = 0

        for obs in qualifying {
            let id = obs.identifier
            maxConfidence = max(maxConfidence, obs.confidence)

            if let scene = sceneMap[id] {
                if primaryScene == nil {
                    primaryScene = scene
                } else if secondaryScene == nil && scene != primaryScene {
                    secondaryScene = scene
                }
                continue
            }
            if let m = moodMap[id], !mood.contains(m) {
                mood.append(m)
                continue
            }
            if let a = activityMap[id], !activity.contains(a) {
                activity.append(a)
                continue
            }
            if let s = subjectMap[id], !subjects.contains(s) {
                subjects.append(s)
                continue
            }
            // Unknown identifier — discard.
        }

        var result: [String: Any] = [:]
        if let ps = primaryScene { result["primaryScene"] = ps }
        if let ss = secondaryScene { result["secondaryScene"] = ss }
        if !activity.isEmpty { result["activity"] = activity }
        if !mood.isEmpty { result["mood"] = mood }
        if !subjects.isEmpty { result["subjects"] = subjects }
        result["labelConfidence"] = Double(maxConfidence)
        return result
    }

    // MARK: - Scene map

    private static let sceneMap: [String: String] = [
        // beach / coast
        "seashore": "beach",
        "beach": "beach",
        "coast": "beach",
        "shore": "beach",
        "lakeside": "lake",
        "lake": "lake",
        "pond": "lake",
        "reservoir": "lake",
        // city
        "cityscape": "city",
        "street": "city",
        "downtown": "city",
        "town": "city",
        // mountain
        "mountain": "mountain",
        "alp": "mountain",
        "peak": "mountain",
        "cliff": "mountain",
        "mountainous_landforms": "mountain",
        // island
        "island": "island",
        // desert
        "desert": "desert",
        "sand_dune": "desert",
        "sandstone": "desert",
        // forest
        "forest": "forest",
        "jungle": "forest",
        "woodland": "forest",
        "rainforest": "forest",
        "tree": "forest",
        // snow
        "snowfield": "snow",
        "glacier": "snow",
        "ski_slope": "snow",
        "snow": "snow",
        "ice": "snow",
        // countryside
        "countryside": "countryside",
        "farmland": "countryside",
        "pasture": "countryside",
        "field": "countryside",
        "meadow": "countryside",
        // coast (distinct from beach — rocky)
        "coastal_and_oceanic_landforms": "coast",
        "headland": "coast",
        "cape": "coast",
    ]

    // MARK: - Mood map

    private static let moodMap: [String: String] = [
        "sunset": "sunset",
        "dusk": "sunset",
        "sunrise": "sunrise",
        "dawn": "sunrise",
        "golden_hour": "golden_hour",
        "night": "night",
        "nighttime": "night",
        "astronomical_object": "night",
    ]

    // MARK: - Activity map

    private static let activityMap: [String: String] = [
        "hiking": "hiking",
        "trekking": "hiking",
        "backpacking": "hiking",
        "skiing": "skiing",
        "snowboarding": "skiing",
        "boat": "boat",
        "ship": "boat",
        "yacht": "boat",
        "sailboat": "boat",
        "watercraft": "boat",
        "road": "roadtrip",
        "highway": "roadtrip",
        "asphalt": "roadtrip",
        "food": "food",
        "meal": "food",
        "restaurant": "food",
        "dish": "food",
    ]

    // MARK: - Subject map

    private static let subjectMap: [String: String] = [
        "person": "people",
        "people": "people",
        "crowd": "people",
        "group": "group",
        "party": "group",
        "selfie": "selfie",
        "portrait": "selfie",
        "landmark": "landmark",
        "monument": "landmark",
        "architecture": "architecture",
        "building": "architecture",
        "church": "architecture",
        "cathedral": "architecture",
        "temple": "architecture",
    ]
}
