import Foundation
import SwiftUI

struct OpenAIHelper {
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

        let prompt = "Correct the writing of provided text. Response only with updated version, without any additional explanations. The text:"
        let userMessage = prompt + text

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
                    return Result.success(output: msg)
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
