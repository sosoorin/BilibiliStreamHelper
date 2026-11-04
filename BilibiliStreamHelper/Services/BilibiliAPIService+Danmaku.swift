//
//  BilibiliAPIService+Danmaku.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import Foundation
import CryptoKit
import SwiftyJSON
import Combine

extension BilibiliAPIService {

    
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

}
