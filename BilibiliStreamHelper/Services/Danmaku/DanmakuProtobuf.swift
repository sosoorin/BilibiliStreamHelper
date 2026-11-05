//
//  DanmakuProtobuf.swift
//  BilibiliStreamHelper
//

import Foundation

/// 只够解 `INTERACT_WORD_V2` 的最小 protobuf 解析。
///
/// 这条命令把用户信息塞在 `data.pb`（base64）里，需要按 dm.proto 反序列化。
/// 只取 uid(1) / uname(2) / msg_type(5) 三个字段，其余字段按 wire type 跳过，
/// 没必要为了 30 行逻辑引 SwiftProtobuf。
nonisolated enum DanmakuProtobuf {

    struct InteractWordV2: Sendable {
        var uid: UInt64 = 0
        var uname: String = ""
        var msgType: UInt32 = 0
    }

    static func decodeInteractWordV2(_ data: Data) -> InteractWordV2? {
        var result = InteractWordV2()
        var index = data.startIndex

        while index < data.endIndex {
            guard let tag = readVarint(data, &index) else { return nil }
            let field = Int(tag >> 3)
            let wireType = Int(tag & 0x07)

            switch wireType {
            case 0: // varint
                guard let value = readVarint(data, &index) else { return nil }
                switch field {
                case 1: result.uid = value
                case 5: result.msgType = UInt32(truncatingIfNeeded: value)
                default: break
                }
            case 2: // length-delimited
                guard let length = readVarint(data, &index),
                      index + Int(length) <= data.endIndex else { return nil }
                let start = index
                let end = index + Int(length)
                index = end
                if field == 2 {
                    result.uname = String(decoding: data[start..<end], as: UTF8.self)
                }
            case 1: // 64-bit
                index += 8
            case 5: // 32-bit
                index += 4
            default:
                return nil
            }
        }
        return result
    }

    private static func readVarint(_ data: Data, _ index: inout Data.Index) -> UInt64? {
        var value: UInt64 = 0
        var shift: UInt64 = 0
        while index < data.endIndex {
            let byte = data[index]
            index = data.index(after: index)
            value |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 { return value }
            shift += 7
            if shift > 63 { return nil }
        }
        return nil
    }
}
