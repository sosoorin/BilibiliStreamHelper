//
//  UserModels.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import Foundation

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
