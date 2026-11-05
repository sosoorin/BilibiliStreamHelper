//
//  DanmakuViewModel.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import Combine
import Foundation

/// 「弹幕」页的发送流程。
///
/// 收弹幕不在这里——连接挂在 `DanmakuCenter` 上，切页也不会断。
/// 发送成功后不本地插一条，靠服务器把 `DANMU_MSG` 推回来，免得自己发的出现两条。
@MainActor
final class DanmakuViewModel: ObservableObject {
    
    private let api: any BilibiliAPI
    
    init(api: any BilibiliAPI = APIClient.shared) {
        self.api = api
    }
    
    @Published var danmakuText = ""
    @Published var isSending = false
    
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
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
