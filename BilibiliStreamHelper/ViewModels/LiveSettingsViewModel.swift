//
//  LiveSettingsViewModel.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import AppKit
import Combine
import Foundation
import os

/// 「直播设置」页的流程状态与操作。
///
/// 视图只负责"用户当前填了什么"（标题、选中的分区），
/// 忙不忙、错没错、二维码出来了没有，都归这里。
@MainActor
final class LiveSettingsViewModel: ObservableObject {
    
    private let api: any BilibiliAPI
    
    init(api: any BilibiliAPI = APIClient.shared) {
        self.api = api
    }
    
    // MARK: - 表单状态（用户在填什么）
    
    @Published var liveTitle = "我的直播间"
    @Published var selectedMainArea: LivePartition?
    @Published var selectedSubArea: LiveSubPartition?
    
    // MARK: - 流程状态
    
    @Published var isLoading = false
    @Published var isLoadingInitialData = false
    
    @Published var errorTitle = "操作失败"
    @Published var errorMessage = ""
    @Published var showError = false
    
    @Published var successMessage = ""
    @Published var showSuccess = false
    
    @Published var showNavigationConfirm = false
    @Published var showFaceVerification = false
    @Published var faceVerificationQRImage: NSImage?
    
    // MARK: - 主操作
    
    /// 现在能不能开播；不能的话 reason 说明缺什么
    var startBlockedReason: String? {
        if api.isLiveActive { return nil }
        if liveTitle.trimmingCharacters(in: .whitespaces).isEmpty { return "请先填写直播标题" }
        if selectedSubArea == nil { return "请先选择直播分区" }
        return nil
    }
    
    var canStartLive: Bool {
        !api.isLiveActive && startBlockedReason == nil && !isLoading
    }
    
    /// 用当前表单里的标题和分区开播
    func startLiveWithCurrentSelection() async {
        guard let areaId = selectedSubArea?.id else { return }
        await startLive(title: liveTitle, areaId: areaId)
    }
    
    /// 把房间信息回填到表单（主分区由 areaId 反查）
    func applyLiveInfo(_ info: LiveInfo) {
        liveTitle = info.title
        
        guard let main = api.partitions.first(where: { partition in
            partition.list?.contains(where: { $0.id == info.areaId }) == true
        }), let sub = main.list?.first(where: { $0.id == info.areaId }) else {
            AppLog.live.debug("未找到匹配的分区，areaId: \(info.areaId, privacy: .public)")
            return
        }
        selectedMainArea = main
        selectedSubArea = sub
    }
    
    /// 第一次选中某个主分区时，把子分区清掉
    func clearSubSelection() {
        selectedSubArea = nil
    }
    
    // MARK: - 读取
    
    /// 首次进入时加载分区和房间信息。
    /// 返回房间信息，由视图负责把 areaId 映射回下拉框里的选中项。
    func loadInitialLiveInfo() async -> LiveInfo? {
        isLoadingInitialData = true
        defer { isLoadingInitialData = false }
        
        do {
            if api.partitions.isEmpty {
                try await api.getPartitions()
            }
            return try await api.getLiveRoomInfo()
        } catch {
            present(error)
            return nil
        }
    }
    
    // MARK: - 操作
    
    func refreshPartitions() async {
        await perform(success: "分区列表刷新成功") {
            try await api.getPartitions()
        }
    }
    
    func updateTitle(_ title: String) async {
        await perform(success: "直播标题更新成功") {
            try await api.updateLiveTitle(title)
            applyTitle(title)
        }
    }
    
    func updateArea(areaId: Int) async {
        await perform(success: "直播分区更新成功") {
            try await api.updateLiveArea(areaId)
        }
    }
    
    func startLive(title: String, areaId: Int) async {
        isLoading = true
        defer { isLoading = false }
        
        // 标题是附带操作：失败只记日志，不阻塞开播
        do {
            try await api.updateLiveTitle(title)
        } catch {
            AppLog.live.warning("开播前更新标题失败，继续开播: \(error.localizedDescription, privacy: .public)")
        }
        
        do {
            _ = try await api.startLive(areaId: areaId)
            showNavigationConfirm = true
        } catch {
            present(error)
        }
    }
    
    func stopLive() async {
        await perform(success: "直播已停止") {
            try await api.stopLive()
        }
    }
    
    // MARK: - 私有
    
    /// 统一的「忙 → 执行 → 成功/失败」包装，省掉每个操作重复的 isLoading 开关
    private func perform(success message: String, _ work: () async throws -> Void) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await work()
            successMessage = message
            showSuccess = true
        } catch {
            present(error)
        }
    }
    
    private func applyTitle(_ title: String) {
        guard let info = api.liveInfo else { return }
        api.liveInfo = LiveInfo(
            roomId: info.roomId,
            title: title,
            areaId: info.areaId,
            areaName: info.areaName,
            parentAreaId: info.parentAreaId,
            parentAreaName: info.parentAreaName,
            liveStatus: info.liveStatus
        )
    }
    
    private func present(_ error: Error) {
        guard let apiError = error as? BilibiliAPIError else {
            errorTitle = "操作失败"
            errorMessage = error.localizedDescription
            showError = true
            return
        }
        
        switch apiError {
        case .faceAuthRequired(let code, let qrURL, let message):
            presentFaceAuth(code: code, qrURL: qrURL, message: message)
            
        case .authenticationRequired:
            api.logout()
            errorTitle = "操作失败"
            errorMessage = "Cookie失效，请重新登录"
            showError = true
            
        case .apiError(let code, let message):
            if code == 3 {
                api.logout()
                errorTitle = "操作失败"
                errorMessage = "Cookie失效，请重新登录"
            } else {
                let display = LiveErrorText.display(code: code, message: message)
                errorTitle = display.title
                errorMessage = display.message
            }
            showError = true
            
        default:
            errorTitle = "操作失败"
            errorMessage = apiError.localizedDescription
            showError = true
        }
    }
    
    private func presentFaceAuth(code: Int, qrURL: String?, message: String) {
        if let qrURL, !qrURL.isEmpty {
            faceVerificationQRImage = QRCodeGenerator.image(from: qrURL)
            showFaceVerification = true
        } else {
            // B站 没给可用的认证链接，把它的话和错误码原样给用户
            let display = LiveErrorText.display(code: code, message: message)
            errorTitle = display.title
            errorMessage = display.message
            showError = true
        }
    }
}
