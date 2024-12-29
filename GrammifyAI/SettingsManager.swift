import Foundation

struct SettingsManager {
    private static let SETTING_AI_API_TOKEN = "OPENAI_TOKEN"
    private static let SETTING_AI_API_HOST = "API_HOST"
    private static let SETTING_AI_API_SCHEME = "API_SCHEME"
    private static let SETTING_AI_API_PORT = "API_PORT"
    private static let SETTING_AI_MODEL = "AI_MODEL"

    static public func setAIApiToken(token: String) {
        UserDefaults.standard.set(token, forKey: SettingsManager.SETTING_AI_API_TOKEN)
    }

    static public func getAIApiToken() -> String {
        let token = UserDefaults.standard.string(forKey: SettingsManager.SETTING_AI_API_TOKEN)

        return token ?? ""
    }

    static public func setAIEndpoint(endpoint: String) {
        UserDefaults.standard.set(endpoint, forKey: SettingsManager.SETTING_AI_API_HOST)
    }
    
    static public func getAIHost() -> String {
        let endpoint = UserDefaults.standard.string(forKey: SettingsManager.SETTING_AI_API_HOST)

        if ((endpoint == nil) || endpoint!.isEmpty) {
            return "api.openai.com"
        }

        return endpoint!
    }

    static public func setAIScheme(scheme: String) {
        UserDefaults.standard.set(scheme, forKey: SettingsManager.SETTING_AI_API_SCHEME)
    }

    static public func getAIScheme() -> String {
        let scheme = UserDefaults.standard.string(forKey: SettingsManager.SETTING_AI_API_SCHEME)
        
        if ((scheme == nil) || scheme!.isEmpty) {
            return "https"
        }
        
        return scheme!
    }

    static public func setAIPort(port: Int) {
        UserDefaults.standard.set(port, forKey: SettingsManager.SETTING_AI_API_PORT)
    }

    static public func getAIPort() -> Int {
        let port = UserDefaults.standard.integer(forKey: SettingsManager.SETTING_AI_API_PORT)
        
        if (port == 0) {
            return 443
        }
        
        return port
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
