//
//  BilibiliAPI.swift
//  BilibiliLiveStremCodeSwift
//
//  Created by sosoorin on 2025/9/23.
//

import Foundation
import CryptoKit
import SwiftyJSON
import Combine
import Security

// MARK: - Constants and Data Structures

struct BilibiliConstants {
    static let userAgent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36"
    
    static let header: [String: String] = [
        "accept": "application/json, text/plain, */*",
        "accept-language": "zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6",
        "content-type": "application/x-www-form-urlencoded; charset=UTF-8",
        "origin": "https://link.bilibili.com",
        "referer": "https://link.bilibili.com/p/center/index",
        "sec-ch-ua": "\"Microsoft Edge\";v=\"129\", \"Not=A?Brand\";v=\"8\", \"Chromium\";v=\"129\"",
        "sec-ch-ua-mobile": "?0",
        "sec-ch-ua-platform": "\"Windows\"",
        "sec-fetch-dest": "empty",
        "sec-fetch-mode": "cors",
        "sec-fetch-site": "same-site",
        "user-agent": userAgent
    ]
    
    static var startData: [String: Any] = [
        "room_id": "",
        "platform": "pc_link",
        "area_v2": "624",
        "backup_stream": "0",
        "csrf_token": "",
        "csrf": "",
        "build": "1234",
        "version": "1.0.0"
    ]
    
    static var stopData: [String: Any] = [
        "room_id": "",
        "platform": "pc_link",
        "csrf_token": "",
        "csrf": ""
    ]
    
    static var titleData: [String: Any] = [
        "room_id": "",
        "platform": "pc_link",
        "title": "",
        "csrf_token": "",
        "csrf": ""
    ]
    
    static var idData: [String: Any] = [
        "room_id": "",
        "area_id": 642,
        "activity_id": 0,
        "platform": "pc_link",
        "csrf_token": "",
        "csrf": ""
    ]
    
    static var danmakuData: [String: Any] = [
        "msg": "",
        "color": 16777215,
        "fontsize": 25,
        "rnd": 0,
        "roomid": 0,
        "csrf_token": "",
        "csrf": ""
    ]
    
    static var versionData: [String: Any] = [
        "system_version": 2,
        "ts": ""
    ]
}

// MARK: - WBI Algorithm Implementation

class WBIManager {
    private static let mixinKeyEncTab: [Int] = [
        46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, 5, 49,
        33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13, 37, 48, 7, 16, 24, 55, 40,
        61, 26, 17, 0, 1, 60, 51, 30, 4, 22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11,
        36, 20, 34, 44, 52
    ]
    
    private static func getMixinKey(_ orig: String) -> String {
        let chars = Array(orig)
        var result = ""
        for i in mixinKeyEncTab.prefix(32) {
            if i < chars.count {
                result += String(chars[i])
            }
        }
        return result
    }
    
    static func encWbi(params: [String: Any], imgKey: String, subKey: String) -> [String: Any] {
        let mixinKey = getMixinKey(imgKey + subKey)
        let currTime = Int(Date().timeIntervalSince1970)
        
        var newParams = params
        newParams["wts"] = currTime
        
        // 按key排序
        let sortedKeys = newParams.keys.sorted()
        
        // 过滤特殊字符
        var filteredParams: [String: String] = [:]
        for key in sortedKeys {
            let value = "\(newParams[key] ?? "")"
            let filteredValue = value.replacingOccurrences(of: "!", with: "")
                .replacingOccurrences(of: "'", with: "")
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")
                .replacingOccurrences(of: "*", with: "")
            filteredParams[key] = filteredValue
        }
        
        // 构建查询字符串
        let queryParts = filteredParams.map { "\($0.key)=\($0.value)" }
        let query = queryParts.joined(separator: "&")
        
        // 计算w_rid
        let signString = query + mixinKey
        let data = signString.data(using: .utf8)!
        let digest = Insecure.MD5.hash(data: data)
        let wRid = digest.map { String(format: "%02x", $0) }.joined()
        
        newParams["w_rid"] = wRid
        return newParams
    }
    
    static func getWbiKeys() async throws -> (String, String) {
        let headers = [
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3",
            "Referer": "https://www.bilibili.com/"
        ]
        
        var request = URLRequest(url: URL(string: "https://api.bilibili.com/x/web-interface/nav")!)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSON(data: data)
        
        let imgUrl = json["data"]["wbi_img"]["img_url"].stringValue
        let subUrl = json["data"]["wbi_img"]["sub_url"].stringValue
        
        let imgKey = imgUrl.components(separatedBy: "/").last?.components(separatedBy: ".").first ?? ""
        let subKey = subUrl.components(separatedBy: "/").last?.components(separatedBy: ".").first ?? ""
        
        return (imgKey, subKey)
    }
    
    static func getWRidAndWts(otherData: [String: Any]) async throws -> (params: [String: Any], query: String) {
        let (imgKey, subKey) = try await getWbiKeys()
        let signedParams = encWbi(params: otherData, imgKey: imgKey, subKey: subKey)
        
        let queryParts = signedParams.map { "\($0.key)=\($0.value)" }
        let query = queryParts.joined(separator: "&")
        
        return (signedParams, query)
    }
}

// MARK: - App Sign Algorithm

class AppSignManager {
    static func appSign(params: [String: Any], appKey: String, appSec: String) -> [String: Any] {
        var newParams = params
        newParams["appkey"] = appKey
        
        // 按key排序
        let sortedKeys = newParams.keys.sorted()
        let queryParts = sortedKeys.map { "\($0)=\(newParams[$0] ?? "")" }
        let query = queryParts.joined(separator: "&")
        
        // 计算签名
        let signString = query + appSec
        let data = signString.data(using: .utf8)!
        let digest = Insecure.MD5.hash(data: data)
        let sign = digest.map { String(format: "%02x", $0) }.joined()
        
        newParams["sign"] = sign
        return newParams
    }
}

// MARK: - Data Models

struct QRCodeInfo: Codable {
    let url: String
    let qrcodeKey: String
    
    enum CodingKeys: String, CodingKey {
        case url
        case qrcodeKey = "qrcode_key"
    }
}

struct UserInfo: Codable {
    let mid: Int
    let uname: String
    let face: String
    let money: Double
    let level: Int
    let follower: Int?
    let following: Int?
    let dynamicCount: Int?
    
    // B站接口使用mid作为用户ID，为兼容性提供uid属性
    var uid: Int {
        return mid
    }
    
    // 简化的初始化器，用于手动创建UserInfo
    init(mid: Int, uname: String, face: String, money: Double, level: Int, follower: Int? = nil, following: Int? = nil, dynamicCount: Int? = nil) {
        self.mid = mid
        self.uname = uname
        self.face = face
        self.money = money
        self.level = level
        self.follower = follower
        self.following = following
        self.dynamicCount = dynamicCount
    }
}

struct StreamInfo: Codable {
    let rtmpAddr: String
    let rtmpCode: String
    
    enum CodingKeys: String, CodingKey {
        case rtmpAddr = "addr"
        case rtmpCode = "code"
    }
}

struct LivePartition: Codable, Hashable, Equatable {
    let id: Int
    let name: String
    let list: [LiveSubPartition]?
}

struct LiveSubPartition: Codable, Hashable, Equatable {
    let id: Int
    let name: String
}

struct LiveInfo: Codable {
    let roomId: Int
    let title: String
    let areaId: Int
    let areaName: String
    let parentAreaId: Int
    let parentAreaName: String
    let liveStatus: Int
    
    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case title
        case areaId = "area_id"
        case areaName = "area_name"
        case parentAreaId = "parent_area_id"
        case parentAreaName = "parent_area_name"
        case liveStatus = "live_status"
    }
}

struct UserStats: Codable {
    let following: Int
    let follower: Int
    let dynamicCount: Int
    
    enum CodingKeys: String, CodingKey {
        case following
        case follower
        case dynamicCount = "dynamic_count"
    }
}

// MARK: - Login Info Storage

struct LoginInfo: Codable {
    let roomId: String
    let cookies: String
    let csrf: String
    let savedDate: Date
    
    // 核心用户信息（持久化保存）
    let userName: String
    let userAvatar: String  // 头像URL，图片会缓存到本地
    let userId: String      // 用户ID (uid)
    
    init(roomId: String, cookies: String, csrf: String, userName: String = "", userAvatar: String = "", userId: String = "") {
        self.roomId = roomId
        self.cookies = cookies
        self.csrf = csrf
        self.userName = userName
        self.userAvatar = userAvatar
        self.userId = userId
        self.savedDate = Date()
    }
}

// MARK: - Avatar Cache Manager

class AvatarCacheManager {
    private static let cacheDirectory: URL = {
        let urls = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheDir = urls[0].appendingPathComponent("AvatarCache")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        return cacheDir
    }()
    
    static func cacheAvatar(from url: String, userId: String, forceRefresh: Bool = false) async -> URL? {
        guard let imageURL = URL(string: url) else { return nil }
        
        let cacheFileName = "\(userId)_avatar.jpg"
        let cacheFileURL = cacheDirectory.appendingPathComponent(cacheFileName)
        
        // 如果不强制刷新且已经缓存了，直接返回
        if !forceRefresh && FileManager.default.fileExists(atPath: cacheFileURL.path) {
            print("使用已缓存的头像: \(cacheFileURL.path)")
            return cacheFileURL
        }
        
        do {
            // 下载新头像
            let (data, _) = try await URLSession.shared.data(from: imageURL)
            
            // 如果已存在旧文件，先删除
            if FileManager.default.fileExists(atPath: cacheFileURL.path) {
                try FileManager.default.removeItem(at: cacheFileURL)
                print("已删除旧的头像缓存")
            }
            
            // 保存新头像
            try data.write(to: cacheFileURL)
            print("头像已更新缓存到: \(cacheFileURL.path)")
            return cacheFileURL
        } catch {
            print("头像缓存失败: \(error)")
            return nil
        }
    }
    
    static func getCachedAvatarURL(for userId: String) -> URL? {
        let cacheFileName = "\(userId)_avatar.jpg"
        let cacheFileURL = cacheDirectory.appendingPathComponent(cacheFileName)
        
        return FileManager.default.fileExists(atPath: cacheFileURL.path) ? cacheFileURL : nil
    }
    
    static func clearAvatarCache(for userId: String) {
        let cacheFileName = "\(userId)_avatar.jpg"
        let cacheFileURL = cacheDirectory.appendingPathComponent(cacheFileName)
        try? FileManager.default.removeItem(at: cacheFileURL)
    }
}

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

// MARK: - Error Types

enum BilibiliAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError(Error)
    case apiError(Int, String)
    case authenticationRequired
    case networkError(Error)
    case qrCodeExpired
    case qrCodeScanned
    case invalidInput(String)
    case storageError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .invalidResponse:
            return "无效的响应"
        case .decodingError(let error):
            return "数据解析错误: \(error.localizedDescription)"
        case .apiError(let code, let message):
            return "API错误 (\(code)): \(message)"
        case .authenticationRequired:
            return "需要登录验证"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .qrCodeExpired:
            return "二维码已过期"
        case .qrCodeScanned:
            return "二维码已扫描，请确认"
        case .invalidInput(let message):
            return message
        case .storageError(let message):
            return message
        }
    }
}

// MARK: - Main API Service

class BilibiliAPIService: ObservableObject {
    static let shared = BilibiliAPIService()
    
    @Published var isLoggedIn = false
    @Published var hasLoadedInitialLiveInfo = false
    @Published var userInfo: UserInfo?
    @Published var liveInfo: LiveInfo?
    @Published var partitions: [LivePartition] = []
    @Published var streamInfo: StreamInfo?
    @Published var isLiveActive = false
    
    private var roomId: String = ""
    
    // 公开的roomId访问接口
    var currentRoomId: String {
        return roomId
    }
    private var cookies: [HTTPCookie] = []
    private var csrfToken: String = ""
    private let session = URLSession.shared
    
    // App keys for signing
    private let appKey = "aae92bc66f3edfab"
    private let appSec = "af125a0d5279fd576c1b4418a3e8276d"
    
    private init() {
        // 初始化时不自动登录，只在用户主动操作时才登录
        // 这样用户可以看到登录界面并选择是否登录
    }
    
    // MARK: - Cookie Utilities
    
    private func cookieStringToDict(_ cookieString: String) -> [String: String] {
        var cookies: [String: String] = [:]
        let pattern = #"(\w+)=([^;]+)(?:;|$)"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let matches = regex.matches(in: cookieString, range: NSRange(cookieString.startIndex..., in: cookieString))
        
        for match in matches {
            if let keyRange = Range(match.range(at: 1), in: cookieString),
               let valueRange = Range(match.range(at: 2), in: cookieString) {
                let key = String(cookieString[keyRange])
                let value = String(cookieString[valueRange]).removingPercentEncoding ?? String(cookieString[valueRange])
                cookies[key] = value
            }
        }
        return cookies
    }
    
    // MARK: - Manual Login
    
    func saveManualLogin(roomId: String, cookies: String, csrf: String) async throws {
        // 验证输入
        guard !roomId.isEmpty, !cookies.isEmpty, !csrf.isEmpty else {
            throw BilibiliAPIError.invalidInput("请填写所有字段")
        }
        
        // 更新内存状态
        self.csrfToken = csrf
        
        // 解析并设置cookies
        let cookieDict = cookieStringToDict(cookies)
        self.cookies = cookieDict.compactMap { key, value in
            HTTPCookie(properties: [
                .domain: ".bilibili.com",
                .path: "/",
                .name: key,
                .value: value
            ])
        }
        
        // 获取用户信息
        let userInfo = try await getUserInfo()
        let userStats = try await getUserStats()
        
        // 手动登录时，使用用户输入的roomId，不使用自动获取的
        self.roomId = roomId
        
        // 创建核心登录信息对象（只保存必要信息）
        let loginInfo = LoginInfo(
            roomId: roomId,
            cookies: cookies,
            csrf: csrf,
            userName: userInfo.uname,
            userAvatar: userInfo.face,
            userId: String(userInfo.mid)
        )
        
        // 保存到安全存储
        try SecureStorageManager.saveLoginInfo(loginInfo)
        
        // 每次登录都刷新缓存头像
        Task {
            await AvatarCacheManager.cacheAvatar(from: userInfo.face, userId: String(userInfo.mid), forceRefresh: true)
        }
        
        await MainActor.run {
            self.isLoggedIn = true
            self.userInfo = userInfo
        }
    }
    
    func loadSavedLogin() async throws {
        guard let loginInfo = SecureStorageManager.loadLoginInfo() else {
            return
        }
        
        // 设置基本登录信息
        self.roomId = loginInfo.roomId
        self.csrfToken = loginInfo.csrf
        
        // 解析并设置cookies
        let cookieDict = cookieStringToDict(loginInfo.cookies)
        self.cookies = cookieDict.compactMap { key, value in
            HTTPCookie(properties: [
                .domain: ".bilibili.com",
                .path: "/",
                .name: key,
                .value: value
            ])
        }
        
        // 每次登录都获取最新的用户信息
        let userInfo = try await getUserInfo()
        
        // 每次自动登录也刷新缓存头像
        Task {
            await AvatarCacheManager.cacheAvatar(from: userInfo.face, userId: String(userInfo.mid), forceRefresh: true)
        }
        
        await MainActor.run {
            self.isLoggedIn = true
            self.userInfo = userInfo
        }
    }
    
    private func clearSavedLogin() {
        SecureStorageManager.deleteLoginInfo()
    }
    
    private func validateLogin() async throws {
        // 验证登录状态，尝试获取用户信息
        try await getUserInfo()
    }
    
    func getSavedLoginInfo() -> (roomId: String, cookies: String, csrf: String)? {
        guard let loginInfo = SecureStorageManager.loadLoginInfo() else {
            return nil
        }
        
        return (roomId: loginInfo.roomId, cookies: loginInfo.cookies, csrf: loginInfo.csrf)
    }
    
    func getSavedLoginInfoFull() -> LoginInfo? {
        return SecureStorageManager.loadLoginInfo()
    }
    
    // MARK: - Additional Storage Utilities
    
    func hasStoredLoginInfo() -> Bool {
        return SecureStorageManager.loadLoginInfo() != nil
    }
    
    func getLoginInfoSavedDate() -> Date? {
        return SecureStorageManager.loadLoginInfo()?.savedDate
    }
    
    func clearAllStoredData() {
        SecureStorageManager.deleteLoginInfo()
        // 重置内存状态
        self.roomId = ""
        self.csrfToken = ""
        self.cookies = []
        self.isLoggedIn = false
        self.userInfo = nil
        self.liveInfo = nil
        self.streamInfo = nil
        self.isLiveActive = false
    }
    
    
    // MARK: - QR Code Login
    
    func getQRCode() async throws -> QRCodeInfo {
        let url = URL(string: "https://passport.bilibili.com/x/passport-login/web/qrcode/generate")!
        var request = URLRequest(url: url)
        request.setValue(BilibiliConstants.userAgent, forHTTPHeaderField: "User-Agent")
        
        // 重置登录状态
        self.isLoggedIn = false
        self.userInfo = nil
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw BilibiliAPIError.invalidResponse
            }
            
            let json = try JSON(data: data)
            guard json["code"].intValue == 0 else {
                throw BilibiliAPIError.apiError(json["code"].intValue, json["message"].stringValue)
            }
            
            let qrData = json["data"]
            return QRCodeInfo(
                url: qrData["url"].stringValue,
                qrcodeKey: qrData["qrcode_key"].stringValue
            )
        } catch {
            throw BilibiliAPIError.networkError(error)
        }
    }
    
    func checkQRLogin(qrcodeKey: String) async throws -> Bool {
        let url = URL(string: "https://passport.bilibili.com/x/passport-login/web/qrcode/poll")!
        var request = URLRequest(url: url)
        request.setValue(BilibiliConstants.userAgent, forHTTPHeaderField: "User-Agent")
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "qrcode_key", value: qrcodeKey)]
        request.url = components.url
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BilibiliAPIError.invalidResponse
        }
        
        let json = try JSON(data: data)
        let code = json["code"].intValue
        
        // 检查API调用是否成功
        guard code == 0 else {
            throw BilibiliAPIError.apiError(code, json["message"].stringValue)
        }
        
        let statusCode = json["data"]["code"].intValue
        
        // 检查登录状态
        if statusCode == 0 {
            // 登录成功，保存cookies
            print("登录成功，开始保存Cookies")
            await saveCookies(from: httpResponse)
            return true
        } else if statusCode == 86038 {
            // 二维码已失效
            throw BilibiliAPIError.qrCodeExpired
        } else if statusCode == 86090 {
            // 已扫描，等待确认
            throw BilibiliAPIError.qrCodeScanned
        } else {
            // 其他状态，继续等待
            print("等待扫描，状态码: \(statusCode)")
            return false
        }
    }
    
    @MainActor
    private func saveCookies(from response: HTTPURLResponse) async {
        // 从响应头中获取Set-Cookie
        if let httpFields = response.allHeaderFields as? [String: String] {
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: httpFields, for: response.url!)
            
            print("从响应中获取到 \(cookies.count) 个cookies")
            for cookie in cookies {
                print("Cookie: \(cookie.name) = \(cookie.value)")
                if cookie.name == "bili_jct" {
                    self.csrfToken = cookie.value
                    print("找到CSRF token: \(cookie.value)")
                }
            }
            
            // 保存所有cookies到session
            for cookie in cookies {
                session.configuration.httpCookieStorage?.setCookie(cookie)
            }
            
            // 保存到实例变量
            self.cookies = cookies
        }
        
        // 获取用户信息和统计信息
        do {
            let userInfo = try await getUserInfo()
            let userStats = try await getUserStats()
            print("用户信息获取成功，登录验证通过")
            
            // 构建cookie字符串
            let cookieString = self.cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            
            // 获取真正的直播间ID
            // 注意：getUserInfo()方法内部已经调用了getRoomId()，所以这里直接使用self.roomId
            let roomId = self.roomId.isEmpty ? String(userInfo.mid) : self.roomId
            
            // 创建核心登录信息对象（只保存必要信息）
            let loginInfo = LoginInfo(
                roomId: roomId,
                cookies: cookieString,
                csrf: self.csrfToken,
                userName: userInfo.uname,
                userAvatar: userInfo.face,
                userId: String(userInfo.mid)
            )
            
            // 保存到安全存储
            try SecureStorageManager.saveLoginInfo(loginInfo)
            
            // 每次登录都刷新缓存头像
            Task {
                await AvatarCacheManager.cacheAvatar(from: userInfo.face, userId: String(userInfo.mid), forceRefresh: true)
            }
            
            // 更新内存状态 - roomId已经在getUserInfo()中设置了
            self.isLoggedIn = true
            self.userInfo = userInfo
            
            print("登录信息已保存到安全存储，房间ID: \(roomId)")
            
        } catch BilibiliAPIError.authenticationRequired {
            print("Cookie验证失败，用户未登录")
            self.isLoggedIn = false
            self.cookies.removeAll()
        } catch {
            print("用户信息获取失败: \(error)")
            // 其他错误，仍然认为是登录状态（可能是网络问题）
            if !cookies.isEmpty {
                self.isLoggedIn = true
                print("Cookie存在，暂时设置为登录状态")
            }
        }
    }
    
    // MARK: - User Info API
    
    @MainActor
    func getUserInfo() async throws -> UserInfo {
        let url = URL(string: "https://api.bilibili.com/x/web-interface/nav")!
        var request = URLRequest(url: url)
        
        // 添加cookies
        if !cookies.isEmpty {
            let cookieString = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            request.setValue(cookieString, forHTTPHeaderField: "Cookie")
            print("发送Cookie: \(cookieString)")
        } else {
            print("警告：没有可用的Cookie")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BilibiliAPIError.invalidResponse
        }
        
        // 添加调试输出
        if let jsonString = String(data: data, encoding: .utf8) {
            print("用户信息API响应: \(jsonString)")
        }
        
        let json = try JSON(data: data)
        let code = json["code"].intValue
        
        // 如果是未登录状态，返回认证错误
        if code == -101 {
            print("API返回未登录状态，Cookie可能无效或已过期")
            throw BilibiliAPIError.authenticationRequired
        }
        
        // 检查是否有用户数据
        guard code == 0,
              let isLogin = json["data"]["isLogin"].bool,
              isLogin else {
            print("用户未登录或API返回错误: code=\(code)")
            throw BilibiliAPIError.apiError(code, json["message"].stringValue)
        }
        
        // 使用SwiftyJSON解析用户信息
        let userData = json["data"]
        var userInfo = UserInfo(
            mid: userData["mid"].intValue,
            uname: userData["uname"].stringValue,
            face: userData["face"].stringValue,
            money: userData["money"].doubleValue,
            level: userData["level_info"]["current_level"].intValue,
            follower: nil,
            following: nil,
            dynamicCount: nil
        )
        
        // 获取用户统计信息（关注、粉丝、动态）
        do {
            let statInfo = try await getUserStats()
            userInfo = UserInfo(
                mid: userInfo.mid,
                uname: userInfo.uname,
                face: userInfo.face,
                money: userInfo.money,
                level: userInfo.level,
                follower: statInfo.follower,
                following: statInfo.following,
                dynamicCount: statInfo.dynamicCount
            )
        } catch {
            print("获取用户统计信息失败: \(error)")
        }
        
        self.userInfo = userInfo
        self.isLoggedIn = true
        
        // 获取直播间ID
        try? await getRoomId()
        
        return userInfo
    }
    
    /// 获取用户统计信息（关注、粉丝、动态）
    func getUserStats() async throws -> UserStats {
        let url = URL(string: "https://api.bilibili.com/x/web-interface/nav/stat")!
        var request = URLRequest(url: url)
        
        // 添加cookies
        if !cookies.isEmpty {
            let cookieString = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            request.setValue(cookieString, forHTTPHeaderField: "Cookie")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BilibiliAPIError.invalidResponse
        }
        
        let json = try JSON(data: data)
        let code = json["code"].intValue
        
        guard code == 0 else {
            throw BilibiliAPIError.apiError(code, json["message"].stringValue)
        }
        
        let statData = json["data"]
        let stats = UserStats(
            following: statData["following"].intValue,
            follower: statData["follower"].intValue,
            dynamicCount: statData["dynamic_count"].intValue
        )
        
        print("用户统计信息: 关注=\(stats.following), 粉丝=\(stats.follower), 动态=\(stats.dynamicCount)")
        return stats
    }
    
    // MARK: - Room ID API
    
    private func getRoomId() async throws {
        guard let uid = userInfo?.uid else { return }
        
        let url = URL(string: "https://api.live.bilibili.com/room/v2/Room/room_id_by_uid?uid=\(uid)")!
        var request = URLRequest(url: url)
        request.setValue(BilibiliConstants.userAgent, forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BilibiliAPIError.invalidResponse
        }
        
        let json = try JSON(data: data)
        
        if json["code"].intValue == 0 {
            let roomId = json["data"]["room_id"].intValue
            self.roomId = "\(roomId)"
            print("获取到直播间ID: \(roomId)")
        }
    }
    
    // MARK: - Live Stream APIs
    
    /// 获取直播间信息
    func getLiveRoomInfo() async throws -> LiveInfo {
        guard let userInfo = userInfo else {
            throw BilibiliAPIError.authenticationRequired
        }
        
        // 构建带查询参数的URL
        let roomIdParam = roomId.isEmpty ? String(userInfo.uid) : roomId
        let url = "https://api.live.bilibili.com/room/v1/Room/get_info?room_id=\(roomIdParam)"
        
        let json = try await requestAPI(
            url: url,
            method: .GET,
            cookies: cookies
        )
        
        let code = json["code"].intValue
        guard code == 0 else {
            throw BilibiliAPIError.apiError(code, json["message"].stringValue)
        }
        
        let data = json["data"]
        let liveInfo = LiveInfo(
            roomId: data["room_id"].intValue,
            title: data["title"].stringValue,
            areaId: data["area_id"].intValue,
            areaName: data["area_name"].stringValue,
            parentAreaId: data["parent_area_id"].intValue,
            parentAreaName: data["parent_area_name"].stringValue,
            liveStatus: data["live_status"].intValue
        )
        
        await MainActor.run {
            self.liveInfo = liveInfo
            self.hasLoadedInitialLiveInfo = true
        }
        
        return liveInfo
    }
    
    func startLive(title: String, areaId: Int) async throws -> StreamInfo {
        guard !roomId.isEmpty, !csrfToken.isEmpty else {
            throw BilibiliAPIError.authenticationRequired
        }
        
        // 1. 获取时间戳
        let timestampJson = try await requestAPI(
            url: "https://api.bilibili.com/x/report/click/now",
            method: .GET,
            headers: BilibiliConstants.header
        )
        
        guard timestampJson["code"].intValue == 0 else {
            throw BilibiliAPIError.apiError(timestampJson["code"].intValue, timestampJson["message"].stringValue)
        }
        
        let timestamp = timestampJson["data"]["now"].intValue
        
        // 2. 获取直播姬版本信息
        var versionData = BilibiliConstants.versionData
        versionData["ts"] = timestamp
        let signedVersionData = AppSignManager.appSign(params: versionData, appKey: appKey, appSec: appSec)
        
        let queryParts = signedVersionData.map { "\($0.key)=\($0.value)" }
        let query = queryParts.joined(separator: "&")
        
        let versionJson = try await requestAPI(
            url: "https://api.live.bilibili.com/xlive/app-blink/v1/liveVersionInfo/getHomePageLiveVersion?\(query)",
            method: .GET,
            headers: BilibiliConstants.header,
            cookies: cookies
        )
        
        guard versionJson["code"].intValue == 0 else {
            throw BilibiliAPIError.apiError(versionJson["code"].intValue, versionJson["message"].stringValue)
        }
        
        // 3. 设置直播标题
        var titleData = BilibiliConstants.titleData
        titleData["room_id"] = roomId
        titleData["csrf_token"] = csrfToken
        titleData["csrf"] = csrfToken
        titleData["title"] = title
        
        let titleResponse = try await requestAPI(
            url: "https://api.live.bilibili.com/room/v1/Room/update",
            method: .POST,
            headers: BilibiliConstants.header,
            data: titleData,
            cookies: cookies
        )
        
        guard titleResponse["code"].intValue == 0 else {
            throw BilibiliAPIError.apiError(titleResponse["code"].intValue, titleResponse["message"].stringValue)
        }
        
        // 4. 开始直播
        var startData = BilibiliConstants.startData
        startData["room_id"] = roomId
        startData["csrf_token"] = csrfToken
        startData["csrf"] = csrfToken
        startData["area_v2"] = areaId
        startData["build"] = versionJson["data"]["build"].stringValue
        startData["version"] = versionJson["data"]["curr_version"].stringValue
        startData["ts"] = timestamp
        
        let signedStartData = AppSignManager.appSign(params: startData, appKey: appKey, appSec: appSec)
        
        let startResponse = try await requestAPI(
            url: "https://api.live.bilibili.com/room/v1/Room/startLive",
            method: .POST,
            headers: BilibiliConstants.header,
            data: signedStartData,
            cookies: cookies
        )
        
        if startResponse["code"].intValue == 60024 {
            // 需要人脸认证，接口直接给出认证链接
            let qrUrl = startResponse["data"]["qr"].stringValue
            throw BilibiliAPIError.apiError(60024, "需要进行人脸认证: \(qrUrl)")
        }
        
        if startResponse["code"].intValue == 60043 {
            // 需要人脸认证，但接口不返回 qr，由客户端自行拼接认证中间页
            let mid = userInfo?.mid ?? 0
            let qrUrl = "https://www.bilibili.com/blackboard/live/face-auth-middle.html?source_event=400&mid=\(mid)"
            throw BilibiliAPIError.apiError(60043, "需要进行人脸认证: \(qrUrl)")
        }
        
        guard startResponse["code"].intValue == 0 else {
            throw BilibiliAPIError.apiError(startResponse["code"].intValue, startResponse["message"].stringValue)
        }
        
        // 解析推流信息
        let rtmpData = startResponse["data"]["rtmp"]
        let streamInfo = StreamInfo(
            rtmpAddr: rtmpData["addr"].stringValue,
            rtmpCode: rtmpData["code"].stringValue
        )
        
        // 在主线程更新UI状态
        await MainActor.run {
            self.streamInfo = streamInfo
            self.isLiveActive = true
        }
        
        return streamInfo
    }
    
    func stopLive() async throws {
        guard !roomId.isEmpty, !csrfToken.isEmpty else {
            throw BilibiliAPIError.authenticationRequired
        }
        
        var stopData = BilibiliConstants.stopData
        stopData["room_id"] = roomId
        stopData["csrf_token"] = csrfToken
        stopData["csrf"] = csrfToken
        
        let response = try await requestAPI(
            url: "https://api.live.bilibili.com/room/v1/Room/stopLive",
            method: .POST,
            headers: BilibiliConstants.header,
            data: stopData,
            cookies: cookies
        )
        
        guard response["code"].intValue == 0 else {
            throw BilibiliAPIError.apiError(response["code"].intValue, response["message"].stringValue)
        }
        
        // 在主线程更新UI状态
        await MainActor.run {
            self.streamInfo = nil
            self.isLiveActive = false
        }
    }
    
    func updateTitle(_ title: String) async throws {
        guard !roomId.isEmpty, !csrfToken.isEmpty else {
            throw BilibiliAPIError.authenticationRequired
        }
        
        var titleData = BilibiliConstants.titleData
        titleData["room_id"] = roomId
        titleData["csrf_token"] = csrfToken
        titleData["csrf"] = csrfToken
        titleData["title"] = title
        
        let response = try await requestAPI(
            url: "https://api.live.bilibili.com/room/v1/Room/update",
            method: .POST,
            headers: BilibiliConstants.header,
            data: titleData,
            cookies: cookies
        )
        
        guard response["code"].intValue == 0 else {
            throw BilibiliAPIError.apiError(response["code"].intValue, response["message"].stringValue)
        }
    }
    
    func updatePartition(_ areaId: Int) async throws {
        guard !roomId.isEmpty, !csrfToken.isEmpty else {
            throw BilibiliAPIError.authenticationRequired
        }
        
        var idData = BilibiliConstants.idData
        idData["room_id"] = roomId
        idData["csrf_token"] = csrfToken
        idData["csrf"] = csrfToken
        idData["area_id"] = areaId
        
        let response = try await requestAPI(
            url: "https://api.live.bilibili.com/room/v1/Room/update",
            method: .POST,
            headers: BilibiliConstants.header,
            data: idData,
            cookies: cookies
        )
        
        guard response["code"].intValue == 0 else {
            throw BilibiliAPIError.apiError(response["code"].intValue, response["message"].stringValue)
        }
    }
    
    // MARK: - Partition API
    
    @MainActor
    func getPartitions() async throws -> [LivePartition] {
        let response = try await requestAPI(
            url: "https://api.live.bilibili.com/room/v1/Area/getList?show_pinyin=1",
            method: .GET,
            headers: BilibiliConstants.header,
            cookies: cookies
        )
        
        guard response["code"].intValue == 0 else {
            throw BilibiliAPIError.apiError(response["code"].intValue, response["message"].stringValue)
        }
        
        let partitionsData = response["data"]
        var partitions: [LivePartition] = []
        
        for partitionJson in partitionsData.arrayValue {
            let subPartitions = partitionJson["list"].arrayValue.map { subJson in
                LiveSubPartition(
                    id: subJson["id"].intValue,
                    name: subJson["name"].stringValue
                )
            }
            
            let partition = LivePartition(
                id: partitionJson["id"].intValue,
                name: partitionJson["name"].stringValue,
                list: subPartitions
            )
            partitions.append(partition)
        }
        
        self.partitions = partitions
        return partitions
    }
    
    // MARK: - Danmaku API
    
    func sendBullet(message: String) async throws {
        guard !roomId.isEmpty, !csrfToken.isEmpty else {
            throw BilibiliAPIError.authenticationRequired
        }
        
        // 获取wbi签名
        let (_, query) = try await WBIManager.getWRidAndWts(otherData: ["web_location": 444.8])
        
        var bulletData = BilibiliConstants.danmakuData
        bulletData["msg"] = message
        bulletData["csrf_token"] = csrfToken
        bulletData["csrf"] = csrfToken
        bulletData["roomid"] = Int(roomId) ?? 0
        bulletData["rnd"] = Int(Date().timeIntervalSince1970)
        
        let response = try await requestAPI(
            url: "https://api.live.bilibili.com/msg/send?\(query)",
            method: .POST,
            headers: BilibiliConstants.header,
            data: bulletData,
            cookies: cookies
        )
        
        let code = response["code"].intValue
        switch code {
        case 0:
            break // 成功
        case 1003212:
            throw BilibiliAPIError.apiError(code, "超出限制长度")
        case -101:
            throw BilibiliAPIError.apiError(code, "未登录")
        case -400:
            throw BilibiliAPIError.apiError(code, "参数错误")
        case 10031:
            throw BilibiliAPIError.apiError(code, "发送频率过高")
        default:
            throw BilibiliAPIError.apiError(code, "未知错误")
        }
    }
    
    // MARK: - Utility Methods
    
    enum HTTPMethod {
        case GET
        case POST
    }
    
    private func requestAPI(
        url: String,
        method: HTTPMethod = .POST,
        headers: [String: String]? = nil,
        data: [String: Any]? = nil,
        cookies: [HTTPCookie]? = nil
    ) async throws -> JSON {
        guard let requestURL = URL(string: url) else {
            throw BilibiliAPIError.invalidURL
        }
        
        var request = URLRequest(url: requestURL)
        request.timeoutInterval = 10
        
        // 设置请求方法
        switch method {
        case .GET:
            request.httpMethod = "GET"
        case .POST:
            request.httpMethod = "POST"
        }
        
        // 设置请求头
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        // 设置cookies
        if let cookies = cookies, !cookies.isEmpty {
            let cookieString = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            request.setValue(cookieString, forHTTPHeaderField: "Cookie")
        }
        
        // 设置请求体
        if let data = data {
            let bodyParts = data.map { "\($0.key)=\($0.value)" }
            let bodyString = bodyParts.joined(separator: "&")
            request.httpBody = bodyString.data(using: .utf8)
        }
        
        do {
            let (responseData, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw BilibiliAPIError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                return try JSON(data: responseData)
            } else {
                throw BilibiliAPIError.invalidResponse
            }
        } catch {
            throw BilibiliAPIError.networkError(error)
        }
    }
    
    // MARK: - Live Settings API
    
    /// 更新直播间标题
    func updateLiveTitle(_ title: String) async throws {
        guard !roomId.isEmpty, !csrfToken.isEmpty else {
            throw BilibiliAPIError.authenticationRequired
        }
        
        var updateData = BilibiliConstants.titleData
        updateData["room_id"] = roomId
        updateData["title"] = title
        updateData["csrf_token"] = csrfToken
        updateData["csrf"] = csrfToken
        
        let response = try await requestAPI(
            url: "https://api.live.bilibili.com/room/v1/Room/update",
            method: .POST,
            headers: BilibiliConstants.header,
            data: updateData,
            cookies: cookies
        )
        
        guard response["code"].intValue == 0 else {
            throw BilibiliAPIError.apiError(response["code"].intValue, response["message"].stringValue)
        }
    }
    
    /// 更新直播分区
    func updateLiveArea(_ areaId: Int) async throws {
        guard !roomId.isEmpty, !csrfToken.isEmpty else {
            throw BilibiliAPIError.authenticationRequired
        }
        
        var updateData = BilibiliConstants.idData
        updateData["room_id"] = roomId
        updateData["area_id"] = String(areaId)
        updateData["csrf_token"] = csrfToken
        updateData["csrf"] = csrfToken
        
        let response = try await requestAPI(
            url: "https://api.live.bilibili.com/room/v1/Room/update",
            method: .POST,
            headers: BilibiliConstants.header,
            data: updateData,
            cookies: cookies
        )
        
        guard response["code"].intValue == 0 else {
            throw BilibiliAPIError.apiError(response["code"].intValue, response["message"].stringValue)
        }
    }
    
    // MARK: - Manual Login Support
    
    @MainActor
    func setManualLogin(roomId: String, cookies: String, csrf: String) {
        self.roomId = roomId
        self.csrfToken = csrf
        
        // 解析cookie字符串并设置
        let cookieDict = cookieStringToDict(cookies)
        var httpCookies: [HTTPCookie] = []
        
        for (name, value) in cookieDict {
            if let cookie = HTTPCookie(properties: [
                .name: name,
                .value: value,
                .domain: ".bilibili.com",
                .path: "/"
            ]) {
                httpCookies.append(cookie)
                session.configuration.httpCookieStorage?.setCookie(cookie)
            }
        }
        
        self.cookies = httpCookies
        self.isLoggedIn = true
        
        // 尝试获取用户信息
        Task {
            try? await getUserInfo()
        }
    }
    
    // MARK: - Logout
    
    /// 退出登录
    @MainActor
    func logout() {
        // 清除头像缓存
        if let userId = userInfo?.uid {
            AvatarCacheManager.clearAvatarCache(for: String(userId))
        }
        
        // 清除持久化存储的登录信息
        SecureStorageManager.deleteLoginInfo()
        
        // 重置内存状态
        isLoggedIn = false
        userInfo = nil
        cookies = []
        roomId = ""
        csrfToken = ""
        streamInfo = nil
        isLiveActive = false
        partitions = []
        hasLoadedInitialLiveInfo = false
        liveInfo = nil
        
        // 清除系统Cookie存储
        if let cookieStorage = session.configuration.httpCookieStorage {
            for cookie in cookieStorage.cookies ?? [] {
                if cookie.domain.contains("bilibili.com") {
                    cookieStorage.deleteCookie(cookie)
                }
            }
        }
    }
}
