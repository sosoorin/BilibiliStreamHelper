//
//  SecureStorageManager.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import Foundation
import Security

// MARK: - Secure Storage Manager

class SecureStorageManager {
    private static let serviceName = "com.sosoorin.bili.livestream"
    private static let accountName = "login_info"
    private static let roomIdKey = "room_id"
    
    // MARK: - Keychain Operations for Sensitive Data
    
    static func saveToKeychain(cookies: String, csrf: String) throws {
        let sensitiveData = ["cookies": cookies, "csrf": csrf]
        let data = try JSONEncoder().encode(sensitiveData)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecValueData as String: data
        ]
        
        // 删除已存在的项目
        SecItemDelete(query as CFDictionary)
        
        // 添加新项目
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw BilibiliAPIError.storageError("保存到Keychain失败")
        }
    }
    
    static func loadFromKeychain() -> (cookies: String, csrf: String)? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let sensitiveData = try? JSONDecoder().decode([String: String].self, from: data),
              let cookies = sensitiveData["cookies"],
              let csrf = sensitiveData["csrf"] else {
            return nil
        }
        
        return (cookies: cookies, csrf: csrf)
    }
    
    static func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - UserDefaults Operations for Non-sensitive Data
    
    static func saveRoomId(_ roomId: String) {
        UserDefaults.standard.set(roomId, forKey: roomIdKey)
    }
    
    static func loadRoomId() -> String? {
        return UserDefaults.standard.string(forKey: roomIdKey)
    }
    
    static func deleteRoomId() {
        UserDefaults.standard.removeObject(forKey: roomIdKey)
    }
    
    // MARK: - Unified Operations
    
    static func saveLoginInfo(_ loginInfo: LoginInfo) throws {
        // 保存敏感信息到Keychain
        try saveToKeychain(cookies: loginInfo.cookies, csrf: loginInfo.csrf)
        
        // 保存核心用户信息到UserDefaults
        let userDefaults = UserDefaults.standard
        userDefaults.set(loginInfo.roomId, forKey: roomIdKey)
        userDefaults.set(loginInfo.userName, forKey: "user_name")
        userDefaults.set(loginInfo.userAvatar, forKey: "user_avatar")
        userDefaults.set(loginInfo.userId, forKey: "user_id")
        userDefaults.set(loginInfo.savedDate, forKey: "saved_date")
    }
    
    static func loadLoginInfo() -> LoginInfo? {
        guard let roomId = loadRoomId(),
              let keychainData = loadFromKeychain() else {
            return nil
        }
        
        let userDefaults = UserDefaults.standard
        let userName = userDefaults.string(forKey: "user_name") ?? ""
        let userAvatar = userDefaults.string(forKey: "user_avatar") ?? ""
        let userId = userDefaults.string(forKey: "user_id") ?? ""
        
        return LoginInfo(
            roomId: roomId,
            cookies: keychainData.cookies,
            csrf: keychainData.csrf,
            userName: userName,
            userAvatar: userAvatar,
            userId: userId
        )
    }
    
    static func deleteLoginInfo() {
        deleteFromKeychain()
        deleteRoomId()
        
        // 删除核心用户信息
        let userDefaults = UserDefaults.standard
        userDefaults.removeObject(forKey: "user_name")
        userDefaults.removeObject(forKey: "user_avatar")
        userDefaults.removeObject(forKey: "user_id")
        userDefaults.removeObject(forKey: "saved_date")
    }
    
}
