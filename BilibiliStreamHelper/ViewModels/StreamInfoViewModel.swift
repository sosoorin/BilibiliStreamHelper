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
    
    private let api: any BilibiliAPI
    
    init(api: any BilibiliAPI = APIClient.shared) {
        self.api = api
    }
    
    @Published var showError = false
    @Published var errorMessage = ""
    
    func presentError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}
