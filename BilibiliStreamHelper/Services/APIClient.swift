//
//  APIClient.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import Foundation
import os
import CryptoKit
import SwiftyJSON
import Combine

// MARK: - Main API Service

class APIClient: ObservableObject {
    static let shared = APIClient()
    
    @Published var isLoggedIn = false
    @Published var hasLoadedInitialLiveInfo = false
    @Published var userInfo: UserInfo?
    @Published var liveInfo: LiveInfo?
    @Published var partitions: [LivePartition] = []
    @Published var streamInfo: StreamInfo?
    @Published var isLiveActive = false
    
    var roomId: String = ""
    
    // 公开的roomId访问接口
    var currentRoomId: String {
        return roomId
    }
    var cookies: [HTTPCookie] = []
    var csrfToken: String = ""
    let session = URLSession.shared
    
    // App keys for signing
    let appKey = "aae92bc66f3edfab"
    let appSec = "af125a0d5279fd576c1b4418a3e8276d"
    
    private init() {
        // 初始化时不自动登录，只在用户主动操作时才登录
        // 这样用户可以看到登录界面并选择是否登录
    }

    
    // MARK: - Cookie Utilities
    
    func cookieStringToDict(_ cookieString: String) -> [String: String] {
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

    
    // MARK: - Room ID API
    
    func getRoomId() async throws {
        guard let uid = userInfo?.uid else { return }
        
        let url = URL(string: "https://api.live.bilibili.com/room/v2/Room/room_id_by_uid?uid=\(uid)")!
        var request = URLRequest(url: url)
        request.setValue(Constants.userAgent, forHTTPHeaderField: "User-Agent")
        
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

    
    func requestAPI(
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
        
        AppLog.network.debug("→ \(String(describing: method), privacy: .public) \(url, privacy: .public)")
        
        do {
            let (responseData, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw BilibiliAPIError.invalidResponse
            }
            
            let json = try JSON(data: responseData)
            // 响应体可能含推流码 / SESSDATA / 人脸认证链接，一律脱敏后再打
            AppLog.network.debug("← \(httpResponse.statusCode, privacy: .public) \(LogMask.describe(json.object), privacy: .public)")
            
            if httpResponse.statusCode == 200 {
                return json
            } else {
                throw BilibiliAPIError.invalidResponse
            }
        } catch {
            AppLog.network.error("请求失败 \(url, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw BilibiliAPIError.networkError(error)
        }
    }

}
