//
//  APIClient+Danmaku.swift
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

    
    // MARK: - Danmaku API
    
    func sendBullet(message: String) async throws {
        guard !roomId.isEmpty, !csrfToken.isEmpty else {
            throw BilibiliAPIError.authenticationRequired
        }
        
        // 获取wbi签名
        let (_, query) = try await WBISigner.getWRidAndWts(otherData: ["web_location": 444.8])
        
        var bulletData = Constants.danmakuData
        bulletData["msg"] = message
        bulletData["csrf_token"] = csrfToken
        bulletData["csrf"] = csrfToken
        bulletData["roomid"] = Int(roomId) ?? 0
        bulletData["rnd"] = Int(Date().timeIntervalSince1970)
        
        let response = try await requestAPI(
            url: "https://api.live.bilibili.com/msg/send?\(query)",
            method: .POST,
            headers: Constants.header,
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
    
    // MARK: - 弹幕长连接
    
    /// 拿弹幕服务器的 host 列表和 token。
    ///
    /// 这个接口对风控很敏感：缺 buvid3 或短时间连发就会回 -352。
    /// 所以请求前保证带 buvid3，并且调用方要自己做 token 缓存、别每次重连都来要。
    func getDanmakuServerInfo(roomId: String) async throws -> DanmakuServerInfo {
        let (_, query) = try await WBISigner.getWRidAndWts(otherData: ["id": roomId, "type": 0])
        let requestCookies = try await cookiesWithBuvid3()
        
        var headers = Constants.header
        headers["Referer"] = "https://live.bilibili.com/"
        headers["Origin"] = "https://live.bilibili.com"
        
        let response = try await requestAPI(
            url: "https://api.live.bilibili.com/xlive/web-room/v1/index/getDanmuInfo?\(query)",
            method: .GET,
            headers: headers,
            cookies: requestCookies
        )
        try throwIfFailed(response)
        
        let token = response["data"]["token"].stringValue
        let hosts = response["data"]["host_list"].arrayValue.compactMap { item -> DanmakuServerInfo.Host? in
            let host = item["host"].stringValue
            guard !host.isEmpty else { return nil }
            return DanmakuServerInfo.Host(host: host, wssPort: item["wss_port"].intValue)
        }
        guard !token.isEmpty, !hosts.isEmpty else {
            throw BilibiliAPIError.invalidResponse
        }
        return DanmakuServerInfo(token: token, hosts: hosts)
    }
    
    /// 登录 cookie 里没有 buvid3（扫码登录给的那几个 cookie 不含它），补一个再发请求。
    private func cookiesWithBuvid3() async throws -> [HTTPCookie] {
        if cookies.contains(where: { $0.name == "buvid3" }) {
            return cookies
        }
        let buvid3: String?
        if let cachedBuvid3 {
            buvid3 = cachedBuvid3
        } else {
            buvid3 = try? await fetchBuvid3()
            cachedBuvid3 = buvid3
        }
        guard let buvid3, !buvid3.isEmpty else {
            return cookies
        }
        AppLog.danmaku.debug("补了一个 buvid3 再请求弹幕地址")
        let cookie = HTTPCookie(properties: [
            .name: "buvid3",
            .value: buvid3,
            .domain: ".bilibili.com",
            .path: "/",
            .expires: Date().addingTimeInterval(365 * 24 * 3600)
        ])
        if let cookie {
            cookies.append(cookie)
        }
        return cookies
    }
    
    private func fetchBuvid3() async throws -> String? {
        let response = try await requestAPI(
            url: "https://api.bilibili.com/x/frontend/finger/spi",
            method: .GET,
            headers: Constants.header,
            cookies: cookies
        )
        let value = response["data"]["b_3"].stringValue
        return value.isEmpty ? nil : value
    }
    
    /// 直播间最近的历史弹幕（一般就十来条）。
    ///
    /// 长连接只推实时消息，网页端刚进直播间能看见几行字，是另外调了这个接口垫的。
    /// 匿名请求返回空数组，要带登录 cookie 才有内容。
    func getRecentDanmaku(roomId: String) async throws -> [DanmakuChatItem] {
        var headers = Constants.header
        headers["Referer"] = "https://live.bilibili.com/\(roomId)"

        let response = try await requestAPI(
            url: "https://api.live.bilibili.com/xlive/web-room/v1/dM/gethistory?roomid=\(roomId)&room_type=0",
            method: .GET,
            headers: headers,
            cookies: try await cookiesWithBuvid3()
        )
        try throwIfFailed(response)

        return response["data"]["room"].arrayValue.compactMap { item -> DanmakuChatItem? in
            let text = item["text"].stringValue
            guard !text.isEmpty else { return nil }
            return DanmakuChatItem(
                kind: .danmaku,
                uid: UInt64(item["uid"].intValue),
                uname: item["nickname"].stringValue,
                text: text,
                timestamp: Self.historyFormatter.date(from: item["timeline"].stringValue) ?? Date()
            )
        }
    }

    private static let historyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    // MARK: - Utility Methods
    
    enum HTTPMethod {
        case GET
        case POST
    }

}
