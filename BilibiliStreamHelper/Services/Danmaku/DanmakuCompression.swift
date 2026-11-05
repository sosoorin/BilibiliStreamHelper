//
//  DanmakuCompression.swift
//  BilibiliStreamHelper
//

import Foundation
import Compression

/// 弹幕包的压缩解压。
///
/// 连接时认证包上报 `protover: 2`，服务端就只发 zlib 包（实测过：报 2 回 protover=2，
/// 报 3 回 protover=3）。所以这里只实现 zlib，不引 brotli 依赖。
nonisolated enum DanmakuCompression {

    /// 解 RFC 1950 的 zlib 流。
    ///
    /// 系统的 Compression framework 只吃裸 deflate 数据（RFC 1951），
    /// 所以先剥掉 2 字节头（CMF/FLG）和末尾 4 字节 adler32。
    /// B站不会带预设字典，断言 FDICT 没置位这条就够用。
    static func inflateZlib(_ data: Data) -> Data? {
        guard data.count > 6 else { return nil }
        // 头两个字节：CMF 的低 4 位是压缩方法，必须是 8（deflate）；
        // FLG 的 0x20 是 FDICT 标志。
        let cmf = data[data.startIndex]
        let flg = data[data.index(after: data.startIndex)]
        guard (cmf & 0x0F) == 8, (flg & 0x20) == 0 else { return nil }

        let body = data.dropFirst(2).dropLast(4)
        var capacity = max(4096, body.count * 16)
        let limit = 64 * 1024 * 1024

        while capacity <= limit {
            var out = [UInt8](repeating: 0, count: capacity)
            let written = body.withUnsafeBytes { source -> Int in
                guard let base = source.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(
                    &out, capacity,
                    base, body.count,
                    nil, COMPRESSION_ZLIB
                )
            }
            if written > 0 {
                return Data(out[0..<written])
            }
            capacity *= 4
        }
        return nil
    }
}
