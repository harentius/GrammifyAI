import Foundation
import Security
import ServiceManagement
import CryptoKit
import IOKit

struct SettingsManager {
    private static let KEYCHAIN_SERVICE = Bundle.main.bundleIdentifier ?? "harentius.GrammifyAI"
    private static let SETTING_AI_API_TOKEN = "OPENAI_TOKEN"
    private static let SETTING_AI_API_URL = "API_URL"
    private static let SETTING_AI_MODEL = "AI_MODEL"
    private static let SETTING_LAUNCH_AT_LOGIN = "LAUNCH_AT_LOGIN"
    private static let SETTING_OPEN_NEAR_SELECTION = "OPEN_NEAR_SELECTION"
    private static let CREDENTIALS_FILENAME = "credentials.enc"

    private static var cachedApiToken: String?

    private static var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    static public func setAIApiToken(token: String) {
        cachedApiToken = token
        UserDefaults.standard.removeObject(forKey: SettingsManager.SETTING_AI_API_TOKEN)

        guard !isRunningInPreview else { return }

        if token.isEmpty {
            deleteEncryptedTokenFile()
        } else {
            _ = saveEncryptedToken(token: token)
        }
    }

    static public func getAIApiToken() -> String {
        if let cached = cachedApiToken {
            return cached
        }

        guard !isRunningInPreview else {
            return ""
        }

        // 1. Migrate legacy plaintext token from UserDefaults if present
        if let legacyToken = UserDefaults.standard.string(forKey: SettingsManager.SETTING_AI_API_TOKEN) {
            if !legacyToken.isEmpty {
                if saveEncryptedToken(token: legacyToken) {
                    UserDefaults.standard.removeObject(forKey: SettingsManager.SETTING_AI_API_TOKEN)
                }
                cachedApiToken = legacyToken
                return legacyToken
            } else {
                UserDefaults.standard.removeObject(forKey: SettingsManager.SETTING_AI_API_TOKEN)
            }
        }

        // 2. Read from app-specific AES-GCM encrypted credentials file
        if let storedToken = readEncryptedToken() {
            cachedApiToken = storedToken
            return storedToken
        }

        // 3. One-time migration from legacy cdhash-locked Keychain item
        if let keychainToken = readTokenFromKeychain() {
            if !keychainToken.isEmpty {
                _ = saveEncryptedToken(token: keychainToken)
            }
            cachedApiToken = keychainToken
            return keychainToken
        }

        return ""
    }

    private static func credentialsFileURL() -> URL? {
        let fileManager = FileManager.default
        guard let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let appDirectory = appSupportDir.appendingPathComponent(KEYCHAIN_SERVICE, isDirectory: true)
        do {
            try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        } catch {
            NSLog("Failed to create application support directory: \(error.localizedDescription)")
            return nil
        }
        return appDirectory.appendingPathComponent(CREDENTIALS_FILENAME)
    }

    private static func machineEncryptionKey() -> SymmetricKey {
        var machineSecret = KEYCHAIN_SERVICE
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        if service != 0 {
            defer { IOObjectRelease(service) }
            if let uuid = IORegistryEntryCreateCFProperty(service, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String,
               !uuid.isEmpty {
                machineSecret = uuid
            }
        }
        let ikm = SymmetricKey(data: Data(machineSecret.utf8))
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: ikm,
            salt: Data(KEYCHAIN_SERVICE.utf8),
            info: Data("GrammifyAI.APIToken.v1".utf8),
            outputByteCount: 32
        )
    }

    @discardableResult
    private static func saveEncryptedToken(token: String) -> Bool {
        guard let fileURL = credentialsFileURL(),
              let plaintext = token.data(using: .utf8) else {
            return false
        }

        do {
            let key = machineEncryptionKey()
            let sealedBox = try AES.GCM.seal(plaintext, using: key)
            guard let combined = sealedBox.combined else { return false }
            try combined.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
            return true
        } catch {
            NSLog("Encrypted token save failed: \(error.localizedDescription)")
            return false
        }
    }

    private static func readEncryptedToken() -> String? {
        guard let fileURL = credentialsFileURL(),
              FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let combined = try Data(contentsOf: fileURL)
            let sealedBox = try AES.GCM.SealedBox(combined: combined)
            let plaintext = try AES.GCM.open(sealedBox, using: machineEncryptionKey())
            return String(data: plaintext, encoding: .utf8)
        } catch {
            NSLog("Encrypted token read failed: \(error.localizedDescription)")
            return nil
        }
    }

    private static func deleteEncryptedTokenFile() {
        guard let fileURL = credentialsFileURL(),
              FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        try? FileManager.default.removeItem(at: fileURL)
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

    static public func getOpenNearSelection() -> Bool {
        return UserDefaults.standard.bool(forKey: SettingsManager.SETTING_OPEN_NEAR_SELECTION)
    }

    static public func setOpenNearSelection(enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: SettingsManager.SETTING_OPEN_NEAR_SELECTION)
    }
}
