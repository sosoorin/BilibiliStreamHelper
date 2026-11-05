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
    
    /// 正在进行的是哪件事——按钮各自显示自己的转圈，而不是整页蒙一层
    enum Activity {
        case refresh
        case startLive
        case stopLive
        case updateTitle
        case updateArea
    }
    
    @Published private(set) var activity: Activity?
    @Published var isLoadingInitialData = false
    
    var isLoading: Bool { activity != nil }
    
    @Published var errorTitle = "操作失败"
    @Published var errorMessage = ""
    @Published var showError = false
    
    @Published var showNavigationConfirm = false
    @Published var showFaceVerification = false
    @Published var faceVerificationQRImage: NSImage?
    
    // MARK: - 表单是否有改动
    
    /// 标题和已经保存在服务端的值不一样（没加载过时算有改动）
    var titleChanged: Bool {
        guard let saved = api.liveInfo?.title else { return !liveTitle.isEmpty }
        return liveTitle != saved
    }
    
    /// 选中的分区和已经保存在服务端的值不一样
    var areaChanged: Bool {
        guard let savedArea = api.liveInfo?.areaId else { return selectedSubArea != nil }
        return selectedSubArea?.id != savedArea
    }
    
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
    
    // MARK: - 读取
    
    /// 首次进入时加载分区和房间信息。
    /// 返回房间信息，由视图负责把 areaId 映射回下拉框里的选中项。
    func loadInitialLiveInfo() async -> LiveInfo? {
        isLoadingInitialData = true
        defer { isLoadingInitialData = false }
        
        do {
            if api.partitions.isEmpty {
                _ = try await api.getPartitions()
            }
            return try await api.getLiveRoomInfo()
        } catch {
            present(error)
            return nil
        }
    }
    
    // MARK: - 操作
    
    /// 一次刷新：分区列表 + 房间信息，并把结果回填到表单。
    /// 分区会增删，房间信息可能在别处（手机端）改过，分开刷容易只刷到一半。
    func refreshAll() async {
        activity = .refresh
        defer { activity = nil }
        
        do {
            _ = try await api.getPartitions()
            let info = try await api.getLiveRoomInfo()
            applyLiveInfo(info)
        } catch {
            present(error)
        }
    }
    
    func updateTitle(_ title: String) async {
        await perform(.updateTitle) {
            let applied = try await api.updateLiveTitle(title)
            updateLocalLiveInfo(title: applied)
        }
    }
    
    func updateArea(areaId: Int) async {
        await perform(.updateArea) {
            try await api.updateLiveArea(areaId)
            updateLocalLiveInfo(areaId: areaId)
        }
    }
    
    func startLive(title: String, areaId: Int) async {
        activity = .startLive
        defer { activity = nil }
        
        // 标题是附带操作：失败只记日志，不阻塞开播
        do {
            _ = try await api.updateLiveTitle(title)
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
        await perform(.stopLive) {
            try await api.stopLive()
        }
    }
    
    // MARK: - 私有
    
    /// 统一的「忙 → 执行 → 失败提示」包装。
    /// 成功不弹窗：界面本身会变（标题回填、状态切换），再弹一次是噪音。
    private func perform(_ kind: Activity, _ work: () async throws -> Void) async {
        activity = kind
        defer { activity = nil }
        
        do {
            try await work()

        } catch {
            present(error)
        }
    }
    
    /// 提交成功后只在本地改这一项，不立刻重拉。
    /// 房间信息接口有缓存，刚提交完马上拉大概率还是旧值，反而把界面改回去。
    private func updateLocalLiveInfo(title: String? = nil, areaId: Int? = nil) {
        guard let info = api.liveInfo else { return }
        let main = selectedMainArea
        let sub = selectedSubArea
        api.liveInfo = LiveInfo(
            roomId: info.roomId,
            title: title ?? info.title,
            areaId: areaId ?? info.areaId,
            areaName: areaId != nil ? (sub?.name ?? info.areaName) : info.areaName,
            parentAreaId: areaId != nil ? (main?.id ?? info.parentAreaId) : info.parentAreaId,
            parentAreaName: areaId != nil ? (main?.name ?? info.parentAreaName) : info.parentAreaName,
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
