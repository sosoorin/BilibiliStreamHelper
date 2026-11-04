//
//  WBIManager.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import Foundation
import CryptoKit
import SwiftyJSON

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
