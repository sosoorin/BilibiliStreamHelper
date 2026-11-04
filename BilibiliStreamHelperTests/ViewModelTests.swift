import Foundation
import Testing
@testable import BilibiliStreamHelper

// MARK: - 直播设置

@Suite("开播流程")
@MainActor
struct LiveSettingsViewModelTests {
    
    private func makeVM() -> (LiveSettingsViewModel, FakeAPI) {
        let api = FakeAPI()
        return (LiveSettingsViewModel(api: api), api)
    }
    
    @Test func successSetsNavigationConfirm() async {
        let (vm, api) = makeVM()
        
        await vm.startLive(title: "标题", areaId: 86)
        
        #expect(api.startLiveCalls == [86])
        #expect(vm.showNavigationConfirm)
        #expect(!vm.showError)
    }
    
    /// 开播前会先改标题，但标题失败不该拦住开播
    @Test func titleFailureDoesNotBlockStartLive() async {
        let (vm, api) = makeVM()
        api.updateTitleError = BilibiliAPIError.invalidResponse
        
        await vm.startLive(title: "标题", areaId: 86)
        
        #expect(api.startLiveCalls == [86])
        #expect(vm.showNavigationConfirm)
    }
    
    /// 60024 带认证链接：应该弹二维码，而不是错误弹窗
    @Test func faceAuthWithQRShowsQRCode() async {
        let (vm, api) = makeVM()
        api.startLiveResult = .failure(
            BilibiliAPIError.faceAuthRequired(
                code: 60024,
                qrURL: "https://www.bilibili.com/blackboard/live/face-auth-middle.html?mid=1",
                message: "需要人脸认证"
            )
        )
        
        await vm.startLive(title: "标题", areaId: 86)
        
        #expect(vm.showFaceVerification)
        #expect(vm.faceVerificationQRImage != nil)
        #expect(!vm.showError)
    }
    
    /// 60043 拿不到 mid（qrURL 为 nil）：退回错误弹窗，且标题带错误码
    @Test func faceAuthWithoutQRFallsBackToError() async {
        let (vm, api) = makeVM()
        api.startLiveResult = .failure(
            BilibiliAPIError.faceAuthRequired(
                code: 60043,
                qrURL: nil,
                message: "本次开播需要身份验证"
            )
        )
        
        await vm.startLive(title: "标题", areaId: 86)
        
        #expect(!vm.showFaceVerification)
        #expect(vm.showError)
        #expect(vm.errorTitle.contains("60043"))
        #expect(vm.errorMessage == "本次开播需要身份验证")
    }
    
    /// 普通接口错误：标题带码，正文是 B站 原文
    @Test func apiErrorShowsCodeAndMessage() async {
        let (vm, api) = makeVM()
        api.stopLiveError = BilibiliAPIError.apiError(60034, "系统维护仅支持直播姬开播")
        
        await vm.stopLive()
        
        #expect(vm.showError)
        #expect(vm.errorTitle.contains("60034"))
        #expect(vm.errorMessage == "系统维护仅支持直播姬开播")
    }
    
    /// Cookie 失效要清掉登录态
    @Test func authenticationFailureLogsOut() async {
        let (vm, api) = makeVM()
        api.stopLiveError = BilibiliAPIError.authenticationRequired
        
        await vm.stopLive()
        
        #expect(api.logoutCount == 1)
        #expect(vm.showError)
    }
    
    @Test func stopLiveSuccessShowsToastMessage() async {
        let (vm, _) = makeVM()
        
        await vm.stopLive()
        
        #expect(vm.successMessage == "直播已停止")
        #expect(vm.showSuccess)
    }
}

// MARK: - 登录

@Suite("登录流程")
@MainActor
struct LoginViewModelTests {
    
    private func makeVM() -> (LoginViewModel, FakeAPI) {
        let api = FakeAPI()
        return (LoginViewModel(api: api), api)
    }
    
    private func sampleLoginInfo() -> LoginInfo {
        LoginInfo(
            roomId: "123",
            cookies: "SESSDATA=abc",
            csrf: "csrf",
            userName: "已登录用户",
            userAvatar: "",
            userId: "456"
        )
    }
    
    /// 已有保存的登录信息、且没强制换号时，不该再去拉二维码
    @Test func skipsQRCodeWhenSavedLoginExists() async {
        let (vm, api) = makeVM()
        api.savedLoginInfo = sampleLoginInfo()
        vm.forceShowLoginInterface = false
        
        await vm.generateQRCode()
        
        #expect(api.getQRCodeCount == 0)
        #expect(!vm.isPolling)
    }
    
    /// 强制换号时必须重新拉
    @Test func fetchesQRCodeWhenForced() async {
        let (vm, api) = makeVM()
        api.savedLoginInfo = sampleLoginInfo()
        api.qrCodeResult = .success(QRCodeInfo(url: "https://qr", qrcodeKey: "key"))
        vm.forceShowLoginInterface = true
        
        await vm.generateQRCode()
        
        #expect(api.getQRCodeCount == 1)
        #expect(vm.qrCodeImage != nil)
    }
    
    /// 保存的凭据失效：清登录态、提示、回到登录界面
    @Test func expiredCredentialsResetToLoginUI() async {
        let (vm, api) = makeVM()
        api.loadSavedLoginError = BilibiliAPIError.authenticationRequired
        api.qrCodeResult = .success(QRCodeInfo(url: "https://qr", qrcodeKey: "key"))
        
        await vm.autoLogin()
        
        #expect(api.logoutCount >= 1)
        #expect(vm.forceShowLoginInterface)
        #expect(vm.showError)
    }
}
