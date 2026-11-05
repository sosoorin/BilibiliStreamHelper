//
//  BilibiliAPI.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import Foundation

/// 直播接口的抽象。
///
/// ViewModel 只依赖这一层，不直接依赖 `APIClient`，
/// 这样测试时可以塞一个假的实现进去，不用真的发请求。
@MainActor
protocol BilibiliAPI: AnyObject {
    
    // MARK: - 状态
    
    var partitions: [LivePartition] { get }
    var liveInfo: LiveInfo? { get set }
    var userInfo: UserInfo? { get }
    var currentRoomId: String { get }
    var hasLoadedInitialLiveInfo: Bool { get set }
    var isLiveActive: Bool { get }
    var isLoggedIn: Bool { get }
    
    // MARK: - 登录
    
    func getQRCode() async throws -> QRCodeInfo
    func checkQRLogin(qrcodeKey: String) async throws -> Bool
    func loadSavedLogin() async throws
    func saveManualLogin(roomId: String, cookies: String, csrf: String) async throws
    func getSavedLoginInfo() -> (roomId: String, cookies: String, csrf: String)?
    func getSavedLoginInfoFull() -> LoginInfo?
    func logout()
    
    // MARK: - 直播间
    
    func getPartitions() async throws -> [LivePartition]
    func getLiveRoomInfo() async throws -> LiveInfo
    /// 返回服务端确认后的标题（B站 会把新标题送审，回包里的 audit_title 才是生效值）
    func updateLiveTitle(_ title: String) async throws -> String
    func updateLiveArea(_ areaId: Int) async throws
    func startLive(areaId: Int) async throws -> StreamInfo
    func stopLive() async throws
    
    // MARK: - 弹幕
    
    func sendBullet(message: String) async throws
    /// 弹幕长连接的地址和 token。断线重连时调用方会复用缓存，不会每次都来取。
    func getDanmakuServerInfo(roomId: String) async throws -> DanmakuServerInfo
    /// 进直播间时先垫几条最近的弹幕，长连接只推实时消息。
    func getRecentDanmaku(roomId: String) async throws -> [DanmakuChatItem]
}
