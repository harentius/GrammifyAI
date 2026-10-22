import Foundation
import SwiftUI

struct LlmClient {
    // Response structure expected from LLM
    struct CorrectionResponse: Codable {
        let detectedLanguage: String?
        let correctedText: String
        let errors: [ErrorInfo]?

        struct ErrorInfo: Codable {
            let category: String
            let originalFragment: String?
            let correctedFragment: String?
        }
    }

    private struct ChatMessage: Decodable {
        let role: String?
        let content: String?
    }

    private struct ChatChoice: Decodable {
        let index: Int?
        let message: ChatMessage?
    }

    private struct ChatResponse: Decodable {
        let choices: [ChatChoice]
    }

    // Helper method to parse LLM response as JSON
    private func parseCorrectionResponse(_ content: String) -> CorrectionResponse? {
        var jsonString = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Extract the outermost JSON object { ... } to handle markdown code fences
        // and conversational text without breaking on inner backticks
        if let firstBrace = jsonString.firstIndex(of: "{"),
           let lastBrace = jsonString.lastIndex(of: "}"),
           firstBrace < lastBrace {
            jsonString = String(jsonString[firstBrace...lastBrace])
        }

        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(CorrectionResponse.self, from: data)
        } catch {
            NSLog("Failed to parse correction response: \(error.localizedDescription)")
            return nil
        }
    }

    public func correctWritting(text: String) async -> Result {
        let openAIToken = SettingsManager.getAIApiToken()

        if openAIToken.isEmpty {
            return Result.error(error: "API token is not set")
        }

        let aiUrl = SettingsManager.getAIUrl()
        let aiModel = SettingsManager.getAIModel()

        let url = URL(string: aiUrl)
        let aiHost = url?.host ?? ""
        let aiScheme = url?.scheme ?? "https"
        let aiPort = url?.port ?? 443
        let aiBasePath = url?.path ?? "/"

        // Get language-specific error categories without repeating universal ones
        let universalCategories: [ErrorCategory] = [.SYN, .VOC, .PREP, .IDM, .REG, .ORT]
        let englishSpecificCategories: [ErrorCategory] = [.TNS, .ASP, .ART]
        let germanSpecificCategories: [ErrorCategory] = [.GEN, .CAS, .ADJ, .V_POS]

        let universalList = universalCategories.map { "\($0.rawValue) (\($0.description))" }.joined(separator: ", ")
        let englishList = englishSpecificCategories.map { "\($0.rawValue) (\($0.description))" }.joined(separator: ", ")
        let germanList = germanSpecificCategories.map { "\($0.rawValue) (\($0.description))" }.joined(separator: ", ")

        let prompt = """
        Detect the language of the provided text, correct its writing, and classify all detected errors.

        Return your response as a JSON object with this exact structure:
        {
          "detectedLanguage": "English", "German", or detected language name,
          "correctedText": "the corrected version of the text",
          "errors": [
            {
              "category": "ERROR_CODE",
              "originalFragment": "the incorrect fragment (optional)",
              "correctedFragment": "the corrected fragment (optional)"
            }
          ]
        }

        Available error categories by language:

        Universal (all languages): \(universalList)

        English-specific: \(englishList)

        German-specific: \(germanList)

        Instructions:
        1. Detect the language of the text automatically
        2. Correct the text according to that language's grammar rules
        3. Classify errors using appropriate categories for that language
        4. Use only the category codes (e.g., "SYN", "VOC", "PREP")
        5. If there are no errors, return an empty array for errors

        Text to analyze:
        """
        let userMessage = prompt + "\n" + text

        // Build URL
        var components = URLComponents()
        components.scheme = aiScheme
        components.host = aiHost
        components.port = aiPort
        let normalizedBase = aiBasePath.isEmpty ? "/" : (aiBasePath.hasPrefix("/") ? aiBasePath : "/" + aiBasePath)
        let trimmedBase = normalizedBase.hasSuffix("/") ? String(normalizedBase.dropLast()) : normalizedBase
        components.path = trimmedBase + "/chat/completions"
        guard let endpointURL = components.url else {
            return Result.error(error: "Invalid AI URL", errorDetails: "scheme=\(aiScheme) host=\(aiHost) port=\(aiPort) basePath=\(aiBasePath)")
        }

        // Build request
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(openAIToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": aiModel,
            "messages": [
                ["role": "user", "content": userMessage]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            return Result.error(error: "Failed to encode request body", errorDetails: error.localizedDescription)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let textBody = String(data: data, encoding: .utf8) ?? "Response not UTF-8 (bytes: \(data.count))"

            guard (200...299).contains(status) else {
                return Result.error(error: "HTTP error \(status)", errorDetails: textBody)
            }

            // Decode JSON
            do {
                let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
                if let msg = decoded.choices.first?.message?.content, !msg.isEmpty {
                    // Try to parse the LLM response as JSON with error classification
                    if let correctionResponse = parseCorrectionResponse(msg) {
                        let textUnchanged = correctionResponse.correctedText.trimmingCharacters(in: .whitespacesAndNewlines) ==
                            text.trimmingCharacters(in: .whitespacesAndNewlines)

                        let errors: [CorrectionError]
                        if textUnchanged {
                            errors = []
                        } else {
                            errors = (correctionResponse.errors ?? []).compactMap { errorInfo -> CorrectionError? in
                                guard let category = ErrorCategory.from(errorInfo.category) else {
                                    NSLog("Unrecognized error category: \(errorInfo.category)")
                                    return nil
                                }
                                // Skip false-positive error entries where original and corrected fragments are identical
                                if let orig = errorInfo.originalFragment?.trimmingCharacters(in: .whitespacesAndNewlines),
                                   let corr = errorInfo.correctedFragment?.trimmingCharacters(in: .whitespacesAndNewlines),
                                   !orig.isEmpty, orig == corr {
                                    return nil
                                }
                                return CorrectionError(
                                    category: category,
                                    originalFragment: errorInfo.originalFragment,
                                    correctedFragment: errorInfo.correctedFragment
                                )
                            }
                        }

                        let language = ErrorCategory.normalizeLanguage(correctionResponse.detectedLanguage ?? "unknown")
                        return Result.success(
                            output: correctionResponse.correctedText,
                            errors: errors,
                            detectedLanguage: language
                        )
                    } else {
                        // If response looks like broken JSON, report parse error rather than polluting clipboard & stats
                        let trimmedMsg = msg.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmedMsg.hasPrefix("{") || trimmedMsg.contains("\"correctedText\"") {
                            return Result.error(error: "Failed to parse correction response", errorDetails: msg)
                        }
                        // Fallback for plain-text models
                        return Result.success(output: msg, errors: [], detectedLanguage: "unknown")
                    }
                } else {
                    return Result.error(error: "Can't process API response", errorDetails: "Missing message content")
                }
            } catch {
                return Result.error(error: "Failed to parse server response", errorDetails: textBody)
            }
        } catch {
            return Result.error(error: "Network error", errorDetails: error.localizedDescription)
        }
    }
}

