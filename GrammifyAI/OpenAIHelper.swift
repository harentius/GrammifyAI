import Foundation
import SwiftUI
import OpenAI

struct OpenAIHelper {
    public func correctWritting(text: String) async -> Result {
        let openAIToken = SettingsManager.getAIApiToken()

        if openAIToken.isEmpty {
            return Result.error(error: "API token is not set")
        }

        let aiUrl = SettingsManager.getAIUrl()
        let aiModel = SettingsManager.getAIModel()

        let url = URL(string: aiUrl)
        let aiHost = url?.host() ?? ""
        let aiScheme = url?.scheme ?? "https"
        let aiPort = url?.port ?? 443
        let aiBasePath = url?.path() ?? "/"

        let configuration = OpenAI.Configuration(
            token: openAIToken,
            host: aiHost,
            port: aiPort,
            scheme: aiScheme,
            basePath: aiBasePath,
        )

        let openAI = OpenAI(configuration: configuration)
        let prompt = "Correct the writing of provided text. Response only with updated version, without any additional explanations. The text:"
        let query = ChatQuery(messages: [.init(role: .user, content: prompt + text)!], model: aiModel)

        do {
            let result = try await openAI.chats(query: query)
            let msg = result.choices[0].message.content
            if (msg == nil) {
                return Result.error(error: "Can't process API response")
            }

            return Result.success(output: msg!)
        } catch {
            // print ("Error: \(error)")
            return Result.error(error: "Error connection to API")
        }
    }
}
