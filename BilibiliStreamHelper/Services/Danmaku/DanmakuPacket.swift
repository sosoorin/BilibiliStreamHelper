//
//  DanmakuPacket.swift
//  BilibiliStreamHelper
//

import Foundation
import os

/// 弹幕服务器的一个数据包（去掉 16 字节头之后）。
nonisolated struct DanmakuPacket: Sendable {
    let operation: UInt32
    let protover: UInt16
    let body: Data
}

/// 弹幕协议的包编解码。
///
/// 包头固定 16 字节，大端：
/// ```
/// 0-3   包总长（含头）
/// 4-5   头长（固定 16）
/// 6-7   协议版本 0/1 明文，2 zlib，3 brotli
/// 8-11  操作码 2 心跳 3 人气值 5 命令 7 认证 8 认证回执
/// 12-15 序号
/// ```
nonisolated enum DanmakuPacketCodec {

    static let headerSize = 16

    enum Operation: UInt32 {
        case heartbeat = 2
        case popularity = 3
        case command = 5
        case auth = 7
        case authReply = 8
    }

    // MARK: - 编码

    static func encode(operation: UInt32, body: Data) -> Data {
        var data = Data(capacity: headerSize + body.count)
        append(UInt32(headerSize + body.count).bigEndian, to: &data)
        append(UInt16(headerSize).bigEndian, to: &data)
        append(UInt16(1).bigEndian, to: &data)
        append(operation.bigEndian, to: &data)
        append(UInt32(1).bigEndian, to: &data)
        data.append(body)
        return data
    }

    private static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        withUnsafeBytes(of: value) { data.append(contentsOf: $0) }
    }

    // MARK: - 解码

    /// 把一帧拆成若干包。压缩包解开后递归拆，所以返回值里不会有 protover 2/3 的包。
    ///
    /// 不抛错：线上收到畸形包时丢掉这一帧比让整条连接崩掉划算。
    static func decode(_ raw: Data) -> [DanmakuPacket] {
        var packets: [DanmakuPacket] = []
        decodeInto(raw, packets: &packets, depth: 0)
        return packets
    }

    private static func decodeInto(_ raw: Data, packets: inout [DanmakuPacket], depth: Int) {
        guard depth < 4, raw.count >= headerSize else { return }

        var offset = 0
        raw.withUnsafeBytes { buffer in
            while offset + headerSize <= buffer.count {
                let packetLength = Int(buffer.loadUnaligned(fromByteOffset: offset, as: UInt32.self).bigEndian)
                let protover = buffer.loadUnaligned(fromByteOffset: offset + 6, as: UInt16.self).bigEndian
                let operation = buffer.loadUnaligned(fromByteOffset: offset + 8, as: UInt32.self).bigEndian

                // 长度不合法就停，避免拿错误的 offset 一路越界
                guard packetLength >= headerSize, offset + packetLength <= buffer.count else { return }

                let start = offset + headerSize
                let body = Data(buffer[start..<(offset + packetLength)])

                switch protover {
                case 2:
                    if let plain = DanmakuCompression.inflateZlib(body) {
                        decodeInto(plain, packets: &packets, depth: depth + 1)
                    } else {
                        AppLog.danmaku.error("zlib 解压失败，丢弃一个包")
                    }
                case 3:
                    // 认证包上报的是 2，正常不会收到 brotli；真收到就是协议变了，记一笔。
                    AppLog.danmaku.error("收到 brotli 包，当前未支持")
                default:
                    packets.append(DanmakuPacket(operation: operation, protover: protover, body: body))
                }

                offset += packetLength
            }
        }
    }
}
