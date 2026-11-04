//
//  StreamInfoViewModel.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import Combine
import Foundation

/// 「推流信息」页：停止直播与错误展示。
@MainActor
final class StreamInfoViewModel: ObservableObject {
    
    private let api: APIClient
    
    init(api: APIClient = .shared) {
        self.api = api
    }
    
    @Published var isStopping = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    /// 返回 true 表示已经停播成功，由视图决定怎么提示
    func stopLive() async -> Bool {
        isStopping = true
        defer { isStopping = false }
        
        do {
            try await api.stopLive()
            return true
        } catch {
            presentError(error)
            return false
        }
    }
    
    func presentError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}
