//
//  BilibiliConstants.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import Foundation

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
