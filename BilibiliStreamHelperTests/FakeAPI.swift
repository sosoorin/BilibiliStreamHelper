import Foundation
@testable import BilibiliStreamHelper

/// 测试用的假实现：不发任何网络请求，所有结果由测试自行设置。
@MainActor
final class FakeAPI: BilibiliAPI {
    
    // MARK: 状态
    
    var partitions: [LivePartition] = []
    var liveInfo: LiveInfo?
    var userInfo: UserInfo?
    var currentRoomId: String = ""
    var hasLoadedInitialLiveInfo = false
    var isLiveActive = false
    var isLoggedIn = false
    
    // MARK: 桩
    
    /// startLive 的返回结果，默认成功
    var startLiveResult: Result<StreamInfo, Error> = .success(
        StreamInfo(rtmpAddr: "rtmp://fake/live", rtmpCode: "?key=fake")
    )
    var stopLiveError: Error?
    var updateTitleError: Error?
    var getLiveRoomInfoResult: Result<LiveInfo, Error> = .failure(BilibiliAPIError.invalidResponse)
    var loadSavedLoginError: Error?
    var qrCodeResult: Result<QRCodeInfo, Error> = .failure(BilibiliAPIError.invalidResponse)
    var savedLoginInfo: LoginInfo?
    var danmakuServerInfoResult: Result<DanmakuServerInfo, Error> = .failure(BilibiliAPIError.invalidResponse)
    var recentDanmaku: [DanmakuChatItem] = []
    
    // MARK: 调用记录
    
    private(set) var logoutCount = 0
    private(set) var getQRCodeCount = 0
    private(set) var updateTitleCalls: [String] = []
    private(set) var startLiveCalls: [Int] = []
    private(set) var danmakuServerInfoCalls: [String] = []
    
    // MARK: - 登录
    
    func getQRCode() async throws -> QRCodeInfo {
        getQRCodeCount += 1
        return try qrCodeResult.get()
    }
    
    func checkQRLogin(qrcodeKey: String) async throws -> Bool { false }
    
    func loadSavedLogin() async throws {
        if let loadSavedLoginError { throw loadSavedLoginError }
    }
    
    func saveManualLogin(roomId: String, cookies: String, csrf: String) async throws {}
    
    func getSavedLoginInfo() -> (roomId: String, cookies: String, csrf: String)? {
        guard let savedLoginInfo else { return nil }
        return (savedLoginInfo.roomId, savedLoginInfo.cookies, savedLoginInfo.csrf)
    }
    
    func getSavedLoginInfoFull() -> LoginInfo? { savedLoginInfo }
    
    func logout() { logoutCount += 1 }
    
    // MARK: - 直播间
    
    func getPartitions() async throws -> [LivePartition] { partitions }
    
    func getLiveRoomInfo() async throws -> LiveInfo { try getLiveRoomInfoResult.get() }
    
    func updateLiveTitle(_ title: String) async throws -> String {
        updateTitleCalls.append(title)
        if let updateTitleError { throw updateTitleError }
        return title
    }
    
    func updateLiveArea(_ areaId: Int) async throws {
        // 模拟服务端：更新后重新拉取能拿到新的 areaId
        if let info = liveInfo {
            let updated = LiveInfo(
                roomId: info.roomId,
                title: info.title,
                areaId: areaId,
                areaName: info.areaName,
                parentAreaId: info.parentAreaId,
                parentAreaName: info.parentAreaName,
                liveStatus: info.liveStatus
            )
            liveInfo = updated
            getLiveRoomInfoResult = .success(updated)
        }
    }
    
    func startLive(areaId: Int) async throws -> StreamInfo {
        startLiveCalls.append(areaId)
        return try startLiveResult.get()
    }
    
    func stopLive() async throws {
        if let stopLiveError { throw stopLiveError }
    }
    
    // MARK: - 弹幕
    
    func sendBullet(message: String) async throws {}
    
    func getDanmakuServerInfo(roomId: String) async throws -> DanmakuServerInfo {
        danmakuServerInfoCalls.append(roomId)
        return try danmakuServerInfoResult.get()
    }
    
    func getRecentDanmaku(roomId: String) async throws -> [DanmakuChatItem] {
        recentDanmaku
    }
}
