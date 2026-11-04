//
//  DanmakuMessage.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import Foundation

struct DanmakuMessage: Identifiable {
    let id = UUID()
    let content: String
    let timestamp: Date
    let isSuccess: Bool
    let errorMessage: String?
    
    init(content: String, timestamp: Date, isSuccess: Bool, errorMessage: String? = nil) {
        self.content = content
        self.timestamp = timestamp
        self.isSuccess = isSuccess
        self.errorMessage = errorMessage
    }
}
