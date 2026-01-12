import Foundation
import ServiceManagement

struct SettingsManager {
    private static let SETTING_AI_API_TOKEN = "OPENAI_TOKEN"
    private static let SETTING_AI_API_URL = "API_URL"
    private static let SETTING_AI_MODEL = "AI_MODEL"
    private static let SETTING_LAUNCH_AT_LOGIN = "LAUNCH_AT_LOGIN"

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

    static public func getLaunchAtLogin() -> Bool {
        return UserDefaults.standard.bool(forKey: SettingsManager.SETTING_LAUNCH_AT_LOGIN)
    }

    static public func setLaunchAtLogin(enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: SettingsManager.SETTING_LAUNCH_AT_LOGIN)

        // Attempt to register/unregister app for launch at login where supported
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Persist preference anyway; log failure for diagnostics
                NSLog("LaunchAtLogin toggle failed: \(error.localizedDescription)")
            }
        } else {
            // Older macOS versions require a helper login item; not implemented here
            NSLog("LaunchAtLogin requires macOS 13+ or a helper login item on older systems.")
        }
    }
}
