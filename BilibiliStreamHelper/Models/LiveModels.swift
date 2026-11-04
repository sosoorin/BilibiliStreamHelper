//
//  LiveModels.swift
//  BilibiliStreamHelper
//
//  Created by sosoorin on 2025/9/23.
//

import Foundation

struct StreamInfo: Codable {
    let rtmpAddr: String
    let rtmpCode: String
    
    enum CodingKeys: String, CodingKey {
        case rtmpAddr = "addr"
        case rtmpCode = "code"
    }
}

struct LivePartition: Codable, Hashable, Equatable {
    let id: Int
    let name: String
    let list: [LiveSubPartition]?
}

struct LiveSubPartition: Codable, Hashable, Equatable {
    let id: Int
    let name: String
}

struct LiveInfo: Codable {
    let roomId: Int
    let title: String
    let areaId: Int
    let areaName: String
    let parentAreaId: Int
    let parentAreaName: String
    let liveStatus: Int
    
    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case title
        case areaId = "area_id"
        case areaName = "area_name"
        case parentAreaId = "parent_area_id"
        case parentAreaName = "parent_area_name"
        case liveStatus = "live_status"
    }
}
