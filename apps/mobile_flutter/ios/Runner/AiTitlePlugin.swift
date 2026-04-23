import Flutter
import UIKit
import FoundationModels

@available(iOS 26.0, *)
public class AiTitlePlugin: NSObject {

    public static func register(with messenger: FlutterBinaryMessenger) -> AiTitlePlugin {
        let channel = FlutterMethodChannel(name: "roavvy/ai_title", binaryMessenger: messenger)
        let instance = AiTitlePlugin()
        channel.setMethodCallHandler(instance.handle)
        return instance
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "generateTitle" else {
            result(FlutterMethodNotImplemented)
            return
        }
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
            return
        }

        let countryNames = args["countryNames"] as? [String] ?? []
        let regionNames  = args["regionNames"]  as? [String] ?? []

        Task {
            await generateTitle(
                countries: countryNames,
                regions:   regionNames,
                result:    result
            )
        }
    }

    private func generateTitle(
        countries: [String],
        regions:   [String],
        result:    @escaping FlutterResult
    ) async {
        // Check model availability before allocating a session.
        let availability = SystemLanguageModel.default.availability
        guard availability == .available else {
            DispatchQueue.main.async {
                result(FlutterError(
                    code: "AI_UNAVAILABLE",
                    message: "On-device model not available: \(availability)",
                    details: nil
                ))
            }
            return
        }

        do {
            // Build region hint (e.g. "Europe, Asia") — max 3 regions to keep
            // the prompt short and focused (ADR-125).
            let regionHint = regions.prefix(3).joined(separator: ", ")
            let multipleCountries = countries.count > 1

            var prompt = "Write a short, playful, human-sounding travel title."
            if !countries.isEmpty {
                let listed = countries.prefix(8).joined(separator: ", ")
                prompt += " Countries visited: \(listed)."
            }
            if !regionHint.isEmpty {
                prompt += " Region: \(regionHint)."
            }
            if multipleCountries {
                prompt += " Do NOT use a single country name or region name as the title — create a thematic phrase."
            }
            prompt += " Rules: 2 to 4 words only. No year. No colon. No numbered list. No preamble. Output ONLY the title."

            let session = LanguageModelSession(
                instructions: "You generate short, witty travel card titles. Output ONLY the title — 2 to 4 words, nothing else. No numbered lists. No preamble like 'Sure' or 'Here is'. Never include a year, a colon, or quotation marks. Never use clichés like 'My Travels'. Sound playful and human."
            )   

            let response = try await session.respond(to: prompt)

            // Post-process: take only the first non-empty line, strip list
            // prefixes and preamble artefacts, then collapse whitespace.
            let firstLine = response.content
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .first { !$0.isEmpty } ?? ""

            // Strip numbered/bulleted prefixes: "1. ", "1) ", "- ", "* "
            let prefixPattern = try? NSRegularExpression(pattern: #"^[\d]+[.)]\s*|^[-*]\s+"#)
            let withoutPrefix: String
            if let re = prefixPattern {
                let range = NSRange(firstLine.startIndex..., in: firstLine)
                withoutPrefix = re.stringByReplacingMatches(
                    in: firstLine, range: range, withTemplate: "")
            } else {
                withoutPrefix = firstLine
            }

            // Strip preamble phrases (case-insensitive).
            let preambles = ["Sure, ", "Sure! ", "Here is ", "Here's ", "Title: ", "Title:"]
            var stripped = withoutPrefix
            for p in preambles {
                if stripped.lowercased().hasPrefix(p.lowercased()) {
                    stripped = String(stripped.dropFirst(p.count))
                }
            }

            let title = stripped
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "'", with: "")
                .replacingOccurrences(of: ":", with: "")
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            DispatchQueue.main.async {
                result(title.isEmpty
                    ? FlutterError(code: "EMPTY_RESPONSE",
                                   message: "Model returned empty string",
                                   details: nil)
                    : title)
            }
        } catch {
            DispatchQueue.main.async {
                result(FlutterError(
                    code: "GENERATION_FAILED",
                    message: error.localizedDescription,
                    details: nil
                ))
            }
        }
    }
}
