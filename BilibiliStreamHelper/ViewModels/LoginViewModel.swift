//
//  LoginViewModel.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import AppKit
import Combine
import Foundation
import os

/// 「登录」页的流程状态与操作：扫码、轮询、手动登录、自动登录。
///
/// 视图只负责画界面和转发点击。
@MainActor
final class LoginViewModel: ObservableObject {
    
    // MARK: - 登录状态
    
    enum LoginStatus {
        case idle
        case waitingForScan
        case scanned
        case success
        case failed
        case expired
    }
    
    private let api: APIClient
    private var pollingTask: Task<Void, Never>?
    
    init(api: APIClient = .shared) {
        self.api = api
    }
    
    deinit {
        pollingTask?.cancel()
    }
    
    // MARK: - 状态
    
    @Published var qrCodeInfo: QRCodeInfo?
    @Published var qrCodeImage: NSImage?
    @Published var isPolling = false
    @Published var statusMessage = "请扫描二维码登录"
    @Published var loginStatus: LoginStatus = .idle
    
    @Published var showError = false
    @Published var errorMessage = ""
    
    // 手动输入
    @Published var showManualLogin = false
    @Published var manualRoomId = ""
    @Published var manualCookies = ""
    @Published var manualCSRF = ""
    @Published var isSavingManualLogin = false
    
    /// 强制展示登录界面（自动登录失败、或用户在已登录状态下主动换号时置位）
    @Published var forceShowLoginInterface = false
    
    // MARK: - 扫码登录
    
    /// 获取二维码并开始轮询
    func generateQRCode() async {
        // 已有保存的登录信息且未强制换号时，不需要二维码
        if let saved = api.getSavedLoginInfoFull(),
           !saved.userName.isEmpty,
           !forceShowLoginInterface {
            return
        }
        
        stopPolling()
        loginStatus = .idle
        
        do {
            let info = try await api.getQRCode()
            qrCodeInfo = info
            qrCodeImage = QRCodeGenerator.image(from: info.url)
            statusMessage = "请使用B站客户端扫描二维码"
            startPolling()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func startPolling() {
        guard let qrInfo = qrCodeInfo, pollingTask == nil else { return }
        
        isPolling = true
        loginStatus = .waitingForScan
        statusMessage = "请使用B站客户端扫描二维码"
        
        pollingTask = Task { [weak self] in
            guard let self else { return }
            await self.poll(qrcodeKey: qrInfo.qrcodeKey)
        }
    }
    
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        isPolling = false
        loginStatus = .idle
        statusMessage = "已停止扫描"
    }
    
    private func poll(qrcodeKey: String) async {
        while !Task.isCancelled, isPolling {
            do {
                let success = try await api.checkQRLogin(qrcodeKey: qrcodeKey)
                if success {
                    loginStatus = .success
                    statusMessage = "登录成功！"
                    isPolling = false
                    break
                }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            } catch {
                if handlePollingError(error) { break }
            }
        }
        pollingTask = nil
    }
    
    /// 返回 true 表示轮询应当结束
    private func handlePollingError(_ error: Error) -> Bool {
        guard let apiError = error as? BilibiliAPIError else {
            loginStatus = .failed
            errorMessage = error.localizedDescription
            showError = true
            isPolling = false
            return true
        }
        
        switch apiError {
        case .qrCodeExpired:
            loginStatus = .expired
            statusMessage = "二维码已失效，请点击刷新"
            isPolling = false
            return true
        case .qrCodeScanned:
            // 已扫描但还没确认，不是错误，继续等
            loginStatus = .scanned
            statusMessage = "已扫描，请在手机上确认登录"
            return false
        default:
            loginStatus = .failed
            errorMessage = error.localizedDescription
            showError = true
            isPolling = false
            return true
        }
    }
    
    // MARK: - 手动登录
    
    func saveManualLogin() async {
        stopPolling()
        isSavingManualLogin = true
        defer { isSavingManualLogin = false }
        
        guard !manualRoomId.isEmpty else {
            errorMessage = "请输入直播间ID"
            showError = true
            return
        }
        guard !manualCookies.isEmpty else {
            errorMessage = "请输入Cookies信息"
            showError = true
            return
        }
        guard !manualCSRF.isEmpty else {
            errorMessage = "请输入CSRF Token"
            showError = true
            return
        }
        
        do {
            try await api.saveManualLogin(roomId: manualRoomId, cookies: manualCookies, csrf: manualCSRF)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    /// 把已保存的登录信息回填到手动登录表单
    func fillManualFieldsFromSaved() {
        guard let saved = api.getSavedLoginInfo() else {
            errorMessage = "没有找到已保存的登录信息"
            showError = true
            return
        }
        manualRoomId = saved.roomId
        manualCookies = saved.cookies
        manualCSRF = saved.csrf
    }
    
    // MARK: - 自动登录
    
    func autoLogin() async {
        stopPolling()
        
        do {
            try await api.loadSavedLogin()
        } catch {
            if let apiError = error as? BilibiliAPIError, case .authenticationRequired = apiError {
                // 保存的凭据已失效：清掉并回到登录界面
                api.logout()
                errorMessage = "登录信息已过期，请重新登录"
                showError = true
                forceShowLoginInterface = true
                showManualLogin = false
                await generateQRCode()
            } else {
                errorMessage = "自动登录失败: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}
