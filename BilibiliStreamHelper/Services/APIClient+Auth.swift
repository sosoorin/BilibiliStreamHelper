//
//  APIClient+Auth.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import Foundation
import os
import CryptoKit
import SwiftyJSON
import Combine

extension APIClient {

    
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
        _ = try await getUserStats()
        
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
        try SecureStorage.saveLoginInfo(loginInfo)
        
        // 每次登录都刷新缓存头像
        Task {
            await AvatarCache.cacheAvatar(from: userInfo.face, userId: String(userInfo.mid), forceRefresh: true)
        }
        
        await MainActor.run {
            self.isLoggedIn = true
            self.userInfo = userInfo
        }
    }

    
    func loadSavedLogin() async throws {
        guard let loginInfo = SecureStorage.loadLoginInfo() else {
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
            await AvatarCache.cacheAvatar(from: userInfo.face, userId: String(userInfo.mid), forceRefresh: true)
        }
        
        await MainActor.run {
            self.isLoggedIn = true
            self.userInfo = userInfo
        }
    }

    
    private func clearSavedLogin() {
        SecureStorage.deleteLoginInfo()
    }

    
    
    func getSavedLoginInfo() -> (roomId: String, cookies: String, csrf: String)? {
        guard let loginInfo = SecureStorage.loadLoginInfo() else {
            return nil
        }
        
        return (roomId: loginInfo.roomId, cookies: loginInfo.cookies, csrf: loginInfo.csrf)
    }

    
    func getSavedLoginInfoFull() -> LoginInfo? {
        return SecureStorage.loadLoginInfo()
    }

    
    // MARK: - Additional Storage Utilities
    
    func hasStoredLoginInfo() -> Bool {
        return SecureStorage.loadLoginInfo() != nil
    }

    
    func getLoginInfoSavedDate() -> Date? {
        return SecureStorage.loadLoginInfo()?.savedDate
    }

    
    func clearAllStoredData() {
        SecureStorage.deleteLoginInfo()
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
        request.setValue(Constants.userAgent, forHTTPHeaderField: "User-Agent")
        
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
            try throwIfFailed(json)
            
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
        request.setValue(Constants.userAgent, forHTTPHeaderField: "User-Agent")
        
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
            AppLog.auth.debug("登录成功，开始保存Cookies")
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
            AppLog.auth.debug("等待扫描，状态码: \(statusCode, privacy: .public)")
            return false
        }
    }

    
    @MainActor
    private func saveCookies(from response: HTTPURLResponse) async {
        // 从响应头中获取Set-Cookie
        if let httpFields = response.allHeaderFields as? [String: String] {
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: httpFields, for: response.url!)
            
            AppLog.auth.debug("从响应中获取到 \(cookies.count) 个 Cookie: \(cookies.map(\.name).joined(separator: ", "), privacy: .public)")
            for cookie in cookies {
                if cookie.name == "bili_jct" {
                    self.csrfToken = cookie.value
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
            _ = try await getUserStats()
            AppLog.auth.debug("用户信息获取成功，登录验证通过")
            
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
            try SecureStorage.saveLoginInfo(loginInfo)
            
            // 每次登录都刷新缓存头像
            Task {
                await AvatarCache.cacheAvatar(from: userInfo.face, userId: String(userInfo.mid), forceRefresh: true)
            }
            
            // 更新内存状态 - roomId已经在getUserInfo()中设置了
            self.isLoggedIn = true
            self.userInfo = userInfo
            
            AppLog.auth.debug("登录信息已保存到安全存储，房间ID: \(roomId, privacy: .public)")
            
        } catch BilibiliAPIError.authenticationRequired {
            AppLog.auth.debug("Cookie验证失败，用户未登录")
            self.isLoggedIn = false
            self.cookies.removeAll()
        } catch {
            AppLog.auth.debug("用户信息获取失败: \(error, privacy: .public)")
            // 其他错误，仍然认为是登录状态（可能是网络问题）
            if !cookies.isEmpty {
                self.isLoggedIn = true
                AppLog.auth.debug("Cookie存在，暂时设置为登录状态")
            }
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
            AvatarCache.clearAvatarCache(for: String(userId))
        }
        
        // 清除持久化存储的登录信息
        SecureStorage.deleteLoginInfo()
        
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
        
        // 退登后弹幕长连接必须断，否则还在用旧账号的凭证收消息
        DanmakuCenter.shared.disconnect()
        
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
