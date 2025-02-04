import Foundation

struct SettingsManager {
    private static let SETTING_AI_API_TOKEN = "OPENAI_TOKEN"
    private static let SETTING_AI_API_HOST = "API_HOST"
    private static let SETTING_AI_API_SCHEME = "API_SCHEME"
    private static let SETTING_AI_API_PORT = "API_PORT"
    private static let SETTING_AI_API_URL = "API_URL"
    private static let SETTING_AI_MODEL = "AI_MODEL"

    static public func setAIApiToken(token: String) {
        UserDefaults.standard.set(token, forKey: SettingsManager.SETTING_AI_API_TOKEN)
    }

    static public func getAIApiToken() -> String {
        let token = UserDefaults.standard.string(forKey: SettingsManager.SETTING_AI_API_TOKEN)

        return token ?? ""
    }

    static public func getAIUrl() -> String {
        let endpoint = UserDefaults.standard.string(forKey: SettingsManager.SETTING_AI_API_URL)

        if ((endpoint == nil) || endpoint!.isEmpty) {
            return "https://api.openai.com"
        }

        return endpoint!
    }

    static public func setAIUrl(url: String) {
        UserDefaults.standard.set(url, forKey: SettingsManager.SETTING_AI_API_URL)
    }

    static public func setAIModel(model: String) {
        UserDefaults.standard.set(model, forKey: SettingsManager.SETTING_AI_MODEL)
    }

    static public func getAIModel() -> String {
        let model = UserDefaults.standard.string(forKey: SettingsManager.SETTING_AI_MODEL)

        if ((model == nil) || model!.isEmpty) {
            return  "gpt-4o-mini"
        }

        return model!
    }
}
