import Foundation

struct SettingsManager {
    private static let SETTING_OPENAI_TOKEN = "OPENAI_TOKEN"

    static public func setOpenAIToken(token: String) {
        UserDefaults.standard.set(token, forKey: SettingsManager.SETTING_OPENAI_TOKEN)
    }

    static public func getOpenAIToken() -> String? {
        UserDefaults.standard.string(forKey: SettingsManager.SETTING_OPENAI_TOKEN)
    }
}
