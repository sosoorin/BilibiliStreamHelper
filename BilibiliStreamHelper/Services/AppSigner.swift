//
//  AppSigner.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import Foundation
import CryptoKit

// MARK: - App Sign Algorithm

class AppSigner {
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
