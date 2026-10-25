import Foundation
import Security
import ServiceManagement

struct SettingsManager {
    private static let KEYCHAIN_SERVICE = Bundle.main.bundleIdentifier ?? "harentius.GrammifyAI"
    private static let SETTING_AI_API_TOKEN = "OPENAI_TOKEN"
    private static let SETTING_AI_API_URL = "API_URL"
    private static let SETTING_AI_MODEL = "AI_MODEL"
    private static let SETTING_LAUNCH_AT_LOGIN = "LAUNCH_AT_LOGIN"

    private static var cachedApiToken: String?

    private static var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    static public func setAIApiToken(token: String) {
        cachedApiToken = token
        UserDefaults.standard.removeObject(forKey: SettingsManager.SETTING_AI_API_TOKEN)

        guard !isRunningInPreview else { return }

        if token.isEmpty {
            deleteTokenFromKeychain()
        } else {
            _ = saveTokenToKeychain(token: token)
        }
    }

    static public func getAIApiToken() -> String {
        if let cached = cachedApiToken {
            return cached
        }

        guard !isRunningInPreview else {
            return ""
        }

        // Migrate legacy plaintext token from UserDefaults if present
        if let legacyToken = UserDefaults.standard.string(forKey: SettingsManager.SETTING_AI_API_TOKEN) {
            if !legacyToken.isEmpty {
                if saveTokenToKeychain(token: legacyToken) {
                    UserDefaults.standard.removeObject(forKey: SettingsManager.SETTING_AI_API_TOKEN)
                }
                cachedApiToken = legacyToken
                return legacyToken
            } else {
                UserDefaults.standard.removeObject(forKey: SettingsManager.SETTING_AI_API_TOKEN)
            }
        }

        if let keychainToken = readTokenFromKeychain() {
            cachedApiToken = keychainToken
            return keychainToken
        }

        return ""
    }

    @discardableResult
    private static func saveTokenToKeychain(token: String) -> Bool {
        guard let data = token.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KEYCHAIN_SERVICE,
            kSecAttrAccount as String: SETTING_AI_API_TOKEN
        ]

        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }

        if updateStatus != errSecItemNotFound {
            // If an existing item could not be updated (e.g. stale ACL), remove and re-create it
            SecItemDelete(query as CFDictionary)
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus != errSecSuccess {
            NSLog("Keychain save failed with status: \(addStatus)")
            return false
        }
        return true
    }

    private static func readTokenFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KEYCHAIN_SERVICE,
            kSecAttrAccount as String: SETTING_AI_API_TOKEN,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecSuccess,
           let data = item as? Data,
           let token = String(data: data, encoding: .utf8) {
            return token
        }

        if status == errSecItemNotFound {
            return ""
        }

        NSLog("Keychain read failed with status: \(status)")
        return nil
    }

    private static func deleteTokenFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KEYCHAIN_SERVICE,
            kSecAttrAccount as String: SETTING_AI_API_TOKEN
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            NSLog("Keychain delete failed with status: \(status)")
        }
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
