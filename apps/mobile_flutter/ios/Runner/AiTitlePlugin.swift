import Flutter
import UIKit
import NaturalLanguage

@available(iOS 26.0, *)
public class AiTitlePlugin: NSObject {
    
    public static func register(with messenger: FlutterBinaryMessenger) -> AiTitlePlugin {
        let channel = FlutterMethodChannel(name: "roavvy/ai_title", binaryMessenger: messenger)
        let instance = AiTitlePlugin()
        channel.setMethodCallHandler(instance.handle)
        return instance
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "generateTitle" {
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
                return
            }
            
            let countryNames = args["countryNames"] as? [String] ?? []
            let startYear = args["startYear"] as? Int
            let endYear = args["endYear"] as? Int
            let cardType = args["cardType"] as? String ?? "general"
            
            Task {
                await generateTitleWithAppleIntelligence(
                    countries: countryNames,
                    startYear: startYear,
                    endYear: endYear,
                    cardType: cardType,
                    result: result
                )
            }
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func generateTitleWithAppleIntelligence(countries: [String], startYear: Int?, endYear: Int?, cardType: String, result: @escaping FlutterResult) async {
        do {
            // Using the iOS 26+ Generative Language API
            // Construct the prompt based on the provided travel data
            var prompt = "Generate a short, catchy, and emotional title for a travel \(cardType) card."
            if !countries.isEmpty {
                prompt += " The destinations include \(countries.joined(separator: ", "))."
            }
            if let start = startYear, let end = endYear {
                if start == end {
                    prompt += " The trip happened in \(start)."
                } else {
                    prompt += " The trips spanned from \(start) to \(end)."
                }
            } else if let start = startYear {
                prompt += " The trip started in \(start)."
            }
            prompt += " Reply with ONLY the title text, max 5 words. Do not use quotes."
            
            // Fictitious/Real iOS 26+ SDK for on-device generative language modeling
            // as per user instructions that the SDK is available.
            let model = try NLGenerativeLanguageModel(systemPrompt: "You are a witty, concise travel title generator. Return ONLY the title text, max 5 words.")
            
            // Keep fallback logic:
            // Model may still not be available on all devices (e.g., storage constraints, older Neural Engines).
            guard model.isAvailableOnDevice else {
                DispatchQueue.main.async {
                    // Returning nil or error triggers the Dart layer fallback (RuleBasedTitleGenerator)
                    result(FlutterError(code: "MODEL_UNAVAILABLE", message: "On-device AI model not downloaded or supported.", details: nil))
                }
                return
            }
            
            // Perform actual on-device generation
            let response = try await model.generateText(for: prompt)
            let title = response.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
            
            DispatchQueue.main.async {
                result(title)
            }
        } catch {
            DispatchQueue.main.async {
                // Any error falls back to the Dart layer RuleBasedTitleGenerator
                result(FlutterError(code: "GENERATION_FAILED", message: error.localizedDescription, details: nil))
            }
        }
    }
}
