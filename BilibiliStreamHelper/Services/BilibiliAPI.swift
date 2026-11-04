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
    func updateLiveTitle(_ title: String) async throws
    func updateLiveArea(_ areaId: Int) async throws
    func startLive(areaId: Int) async throws -> StreamInfo
    func stopLive() async throws
    
    // MARK: - 弹幕
    
    func sendBullet(message: String) async throws
}
