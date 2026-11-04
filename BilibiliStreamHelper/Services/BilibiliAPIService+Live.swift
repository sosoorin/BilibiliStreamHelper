//
//  BilibiliAPIService+Live.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import Foundation
import CryptoKit
import SwiftyJSON
import Combine

extension BilibiliAPIService {

    
    // MARK: - Live Stream APIs
    
    /// 获取直播间信息
    func getLiveRoomInfo() async throws -> LiveInfo {
        guard let userInfo = userInfo else {
            throw BilibiliAPIError.authenticationRequired
        }
        
        // 构建带查询参数的URL
        let roomIdParam = roomId.isEmpty ? String(userInfo.uid) : roomId
        let url = "https://api.live.bilibili.com/room/v1/Room/get_info?room_id=\(roomIdParam)"
        
        let json = try await requestAPI(
            url: url,
            method: .GET,
            cookies: cookies
        )
        
        let code = json["code"].intValue
        guard code == 0 else {
            throw BilibiliAPIError.apiError(code, json["message"].stringValue)
        }
        
        let data = json["data"]
        let liveInfo = LiveInfo(
            roomId: data["room_id"].intValue,
            title: data["title"].stringValue,
            areaId: data["area_id"].intValue,
            areaName: data["area_name"].stringValue,
            parentAreaId: data["parent_area_id"].intValue,
            parentAreaName: data["parent_area_name"].stringValue,
            liveStatus: data["live_status"].intValue
        )
        
        await MainActor.run {
            self.liveInfo = liveInfo
            self.hasLoadedInitialLiveInfo = true
        }
        
        return liveInfo
    }

    
    func startLive(title: String, areaId: Int) async throws -> StreamInfo {
        guard !roomId.isEmpty, !csrfToken.isEmpty else {
            throw BilibiliAPIError.authenticationRequired
        }
        
        // 1. 获取时间戳
        let timestampJson = try await requestAPI(
            url: "https://api.bilibili.com/x/report/click/now",
            method: .GET,
            headers: BilibiliConstants.header
        )
        
        guard timestampJson["code"].intValue == 0 else {
            throw BilibiliAPIError.apiError(timestampJson["code"].intValue, timestampJson["message"].stringValue)
        }
        
        let timestamp = timestampJson["data"]["now"].intValue
        
        // 2. 获取直播姬版本信息
        var versionData = BilibiliConstants.versionData
        versionData["ts"] = timestamp
        let signedVersionData = AppSignManager.appSign(params: versionData, appKey: appKey, appSec: appSec)
        
        let queryParts = signedVersionData.map { "\($0.key)=\($0.value)" }
        let query = queryParts.joined(separator: "&")
        
        let versionJson = try await requestAPI(
            url: "https://api.live.bilibili.com/xlive/app-blink/v1/liveVersionInfo/getHomePageLiveVersion?\(query)",
            method: .GET,
            headers: BilibiliConstants.header,
            cookies: cookies
        )
        
        guard versionJson["code"].intValue == 0 else {
            throw BilibiliAPIError.apiError(versionJson["code"].intValue, versionJson["message"].stringValue)
        }
        
        // 3. 设置直播标题
        var titleData = BilibiliConstants.titleData
        titleData["room_id"] = roomId
        titleData["csrf_token"] = csrfToken
        titleData["csrf"] = csrfToken
        titleData["title"] = title
        
        let titleResponse = try await requestAPI(
            url: "https://api.live.bilibili.com/room/v1/Room/update",
            method: .POST,
            headers: BilibiliConstants.header,
            data: titleData,
            cookies: cookies
        )
        
        guard titleResponse["code"].intValue == 0 else {
            throw BilibiliAPIError.apiError(titleResponse["code"].intValue, titleResponse["message"].stringValue)
        }
        
        // 4. 开始直播
        var startData = BilibiliConstants.startData
        startData["room_id"] = roomId
        startData["csrf_token"] = csrfToken
        startData["csrf"] = csrfToken
        startData["area_v2"] = areaId
        startData["build"] = versionJson["data"]["build"].stringValue
        startData["version"] = versionJson["data"]["curr_version"].stringValue
        startData["ts"] = timestamp
        
        let signedStartData = AppSignManager.appSign(params: startData, appKey: appKey, appSec: appSec)
        
        let startResponse = try await requestAPI(
            url: "https://api.live.bilibili.com/room/v1/Room/startLive",
            method: .POST,
            headers: BilibiliConstants.header,
            data: signedStartData,
            cookies: cookies
        )
        
        let startCode = startResponse["code"].intValue
        
        if startCode == 60024 {
            // 需要人脸认证，接口直接给出认证链接
            let qrUrl = startResponse["data"]["qr"].stringValue
            throw BilibiliAPIError.faceAuthRequired(
                code: 60024,
                qrURL: qrUrl.isEmpty ? nil : qrUrl,
                message: startResponse["message"].stringValue
            )
        }
        
        if startCode == 60043 {
            // 需要人脸认证，但接口不返回 qr，由客户端自行拼接认证中间页
            let mid = userInfo?.mid ?? 0
            let qrUrl = "https://www.bilibili.com/blackboard/live/face-auth-middle.html?source_event=400&mid=\(mid)"
            throw BilibiliAPIError.faceAuthRequired(
                code: 60043,
                qrURL: mid == 0 ? nil : qrUrl,
                message: startResponse["message"].stringValue
            )
        }
        
        guard startResponse["code"].intValue == 0 else {
            throw BilibiliAPIError.apiError(startResponse["code"].intValue, startResponse["message"].stringValue)
        }
        
        // 解析推流信息
        let rtmpData = startResponse["data"]["rtmp"]
        let streamInfo = StreamInfo(
            rtmpAddr: rtmpData["addr"].stringValue,
            rtmpCode: rtmpData["code"].stringValue
        )
        
        // 在主线程更新UI状态
        await MainActor.run {
            self.streamInfo = streamInfo
            self.isLiveActive = true
        }
        
        return streamInfo
    }

    
    func stopLive() async throws {
        guard !roomId.isEmpty, !csrfToken.isEmpty else {
            throw BilibiliAPIError.authenticationRequired
        }
        
        var stopData = BilibiliConstants.stopData
        stopData["room_id"] = roomId
        stopData["csrf_token"] = csrfToken
        stopData["csrf"] = csrfToken
        
        let response = try await requestAPI(
            url: "https://api.live.bilibili.com/room/v1/Room/stopLive",
            method: .POST,
            headers: BilibiliConstants.header,
            data: stopData,
            cookies: cookies
        )
        
        guard response["code"].intValue == 0 else {
            throw BilibiliAPIError.apiError(response["code"].intValue, response["message"].stringValue)
        }
        
        // 在主线程更新UI状态
        await MainActor.run {
            self.streamInfo = nil
            self.isLiveActive = false
        }
    }

    
    func updateTitle(_ title: String) async throws {
        guard !roomId.isEmpty, !csrfToken.isEmpty else {
            throw BilibiliAPIError.authenticationRequired
        }
        
        var titleData = BilibiliConstants.titleData
        titleData["room_id"] = roomId
        titleData["csrf_token"] = csrfToken
        titleData["csrf"] = csrfToken
        titleData["title"] = title
        
        let response = try await requestAPI(
            url: "https://api.live.bilibili.com/room/v1/Room/update",
            method: .POST,
            headers: BilibiliConstants.header,
            data: titleData,
            cookies: cookies
        )
        
        guard response["code"].intValue == 0 else {
            throw BilibiliAPIError.apiError(response["code"].intValue, response["message"].stringValue)
        }
    }

    
    func updatePartition(_ areaId: Int) async throws {
        guard !roomId.isEmpty, !csrfToken.isEmpty else {
            throw BilibiliAPIError.authenticationRequired
        }
        
        var idData = BilibiliConstants.idData
        idData["room_id"] = roomId
        idData["csrf_token"] = csrfToken
        idData["csrf"] = csrfToken
        idData["area_id"] = areaId
        
        let response = try await requestAPI(
            url: "https://api.live.bilibili.com/room/v1/Room/update",
            method: .POST,
            headers: BilibiliConstants.header,
            data: idData,
            cookies: cookies
        )
        
        guard response["code"].intValue == 0 else {
            throw BilibiliAPIError.apiError(response["code"].intValue, response["message"].stringValue)
        }
    }

    
    // MARK: - Partition API
    
    @MainActor
    func getPartitions() async throws -> [LivePartition] {
        let response = try await requestAPI(
            url: "https://api.live.bilibili.com/room/v1/Area/getList?show_pinyin=1",
            method: .GET,
            headers: BilibiliConstants.header,
            cookies: cookies
        )
        
        guard response["code"].intValue == 0 else {
            throw BilibiliAPIError.apiError(response["code"].intValue, response["message"].stringValue)
        }
        
        let partitionsData = response["data"]
        var partitions: [LivePartition] = []
        
        for partitionJson in partitionsData.arrayValue {
            let subPartitions = partitionJson["list"].arrayValue.map { subJson in
                LiveSubPartition(
                    id: subJson["id"].intValue,
                    name: subJson["name"].stringValue
                )
            }
            
            let partition = LivePartition(
                id: partitionJson["id"].intValue,
                name: partitionJson["name"].stringValue,
                list: subPartitions
            )
            partitions.append(partition)
        }
        
        self.partitions = partitions
        return partitions
    }

    
    // MARK: - Live Settings API
    
    /// 更新直播间标题
    func updateLiveTitle(_ title: String) async throws {
        guard !roomId.isEmpty, !csrfToken.isEmpty else {
            throw BilibiliAPIError.authenticationRequired
        }
        
        var updateData = BilibiliConstants.titleData
        updateData["room_id"] = roomId
        updateData["title"] = title
        updateData["csrf_token"] = csrfToken
        updateData["csrf"] = csrfToken
        
        let response = try await requestAPI(
            url: "https://api.live.bilibili.com/room/v1/Room/update",
            method: .POST,
            headers: BilibiliConstants.header,
            data: updateData,
            cookies: cookies
        )
        
        guard response["code"].intValue == 0 else {
            throw BilibiliAPIError.apiError(response["code"].intValue, response["message"].stringValue)
        }
    }

    
    /// 更新直播分区
    func updateLiveArea(_ areaId: Int) async throws {
        guard !roomId.isEmpty, !csrfToken.isEmpty else {
            throw BilibiliAPIError.authenticationRequired
        }
        
        var updateData = BilibiliConstants.idData
        updateData["room_id"] = roomId
        updateData["area_id"] = String(areaId)
        updateData["csrf_token"] = csrfToken
        updateData["csrf"] = csrfToken
        
        let response = try await requestAPI(
            url: "https://api.live.bilibili.com/room/v1/Room/update",
            method: .POST,
            headers: BilibiliConstants.header,
            data: updateData,
            cookies: cookies
        )
        
        guard response["code"].intValue == 0 else {
            throw BilibiliAPIError.apiError(response["code"].intValue, response["message"].stringValue)
        }
    }

}
