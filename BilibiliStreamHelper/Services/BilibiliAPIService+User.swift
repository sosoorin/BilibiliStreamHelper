//
//  BilibiliAPIService+User.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import Foundation
import CryptoKit
import SwiftyJSON
import Combine

extension BilibiliAPIService {

    
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

}
