//
//  DanmakuViewModel.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import Combine
import Foundation

/// 「弹幕」页的发送流程与历史记录。
@MainActor
final class DanmakuViewModel: ObservableObject {
    
    private let api: APIClient
    
    init(api: APIClient = .shared) {
        self.api = api
    }
    
    @Published var danmakuText = ""
    @Published var danmakuHistory: [DanmakuMessage] = []
    @Published var isSending = false
    
    @Published var showSuccess = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    func send() async {
        let text = danmakuText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        isSending = true
        defer { isSending = false }
        
        do {
            try await api.sendBullet(message: text)
            danmakuText = ""
            danmakuHistory.append(DanmakuMessage(content: text, timestamp: Date(), isSuccess: true))
            showSuccess = true
        } catch {
            danmakuHistory.append(
                DanmakuMessage(content: text, timestamp: Date(), isSuccess: false,
                               errorMessage: error.localizedDescription)
            )
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
