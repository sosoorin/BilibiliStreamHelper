//
//  BilibiliConstants.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import Foundation

// MARK: - Constants and Data Structures

struct BilibiliConstants {
    /// 与参考项目（ChaceQC/bilibili_live_stream_code）保持一致：
    /// 只报 UA，不伪造 sec-ch-ua / sec-fetch 这类客户端提示，
    /// 避免出现「macOS 应用自称 Windows Edge 129」这种自相矛盾的指纹。
    static let userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    
    static let header: [String: String] = [
        "accept": "application/json, text/plain, */*",
        "accept-language": "zh-CN,zh;q=0.9",
        "content-type": "application/x-www-form-urlencoded; charset=UTF-8",
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
