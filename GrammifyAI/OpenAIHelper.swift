import Foundation
import SwiftUI
import OpenAI

struct OpenAIHelper {
    public func correctWritting(text: String) async -> Result {
        let openAIToken = SettingsManager.getOpenAIToken()

        if openAIToken == nil {
            return Result.error(error: "OpenAPI token is not set")
        }

        let openAI = OpenAI(apiToken: openAIToken!)
        let prompt = "Correct the writing of provided text. Response only with updated version, without any additional explanations. The text:"
        let query = ChatQuery(messages: [.init(role: .user, content: prompt + text)!], model: .gpt4_o_mini)

        do {
            let result = try await openAI.chats(query: query)
            let msg = result.choices[0].message.content?.string

            if (msg == nil) {
                return Result.error(error: "Can't process OpenAI response")
            }

            return Result.success(output: msg!)
        } catch {
            return Result.error(error: "Error connection to OpenAI API")
        }
    }
}
