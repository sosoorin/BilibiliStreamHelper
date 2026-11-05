//
//  DanmakuCodecTests.swift
//  BilibiliStreamHelperTests
//

import Foundation
import Testing
@testable import BilibiliStreamHelper

@Suite("弹幕包编解码")
struct DanmakuPacketCodecTests {

    @Test func encodeDecodeRoundTrip() {
        let body = Data(#"{"cmd":"TEST"}"#.utf8)
        let packet = DanmakuPacketCodec.encode(operation: 5, body: body)

        #expect(packet.count == 16 + body.count)

        let decoded = DanmakuPacketCodec.decode(packet)
        #expect(decoded.count == 1)
        #expect(decoded.first?.operation == 5)
        #expect(decoded.first?.protover == 1)
        #expect(decoded.first?.body == body)
    }

    @Test func splitsConsecutivePackets() {
        var data = Data()
        data.append(DanmakuPacketCodec.encode(operation: 5, body: Data("a".utf8)))
        data.append(DanmakuPacketCodec.encode(operation: 3, body: Data([1, 2, 3, 4])))

        let decoded = DanmakuPacketCodec.decode(data)
        #expect(decoded.count == 2)
        #expect(decoded[0].operation == 5)
        #expect(decoded[1].operation == 3)
        #expect(decoded[1].body == Data([1, 2, 3, 4]))
    }

    /// 长度字段说谎时不能一路越界往下读
    @Test func rejectsBrokenLength() {
        var data = DanmakuPacketCodec.encode(operation: 5, body: Data("abc".utf8))
        data[0] = 0xFF
        #expect(DanmakuPacketCodec.decode(data).isEmpty)
    }

    @Test func inflatesZlibBody() throws {
        // python 的 zlib.compress(b'{"cmd":"DANMU_MSG",...}')
        let base64 = "eJyrVkrOTVGyUnJx9PMNjfcNdlfSUcrMS8tXsoqONtAx1DEy1TE0Mzc3NzI0jdVRykjNyclX0om21FHKTVWKja0FACc+EUM="
        let body = try #require(Data(base64Encoded: base64))

        let plain = try #require(DanmakuCompression.inflateZlib(body))
        #expect(String(decoding: plain, as: UTF8.self).contains("DANMU_MSG"))
    }

    @Test func compressedFrameIsDecodedRecursively() throws {
        // zlib.compress(16 字节头 + JSON)，真实服务端就是这么套的
        let base64 = "eJxjYGDwZxBgYGRgYGAFYsZqpeTcFCUrJRdHP9/QeN9gdyUdpcy8tHwlq+hoAx1DHSNTHUMzc3NzI0PTWB2ljNScnHwlnWhLHaXcVKXY2FoART4RqQ=="
        let compressed = try #require(Data(base64Encoded: base64))

        var frame = Data()
        frame.append(uint32(UInt32(16 + compressed.count)))
        frame.append(uint16(16))
        frame.append(uint16(2))          // protover 2 = zlib
        frame.append(uint32(5))          // op 5
        frame.append(uint32(1))
        frame.append(compressed)

        let decoded = DanmakuPacketCodec.decode(frame)
        let packet = try #require(decoded.first)
        #expect(decoded.count == 1)
        #expect(String(decoding: packet.body, as: UTF8.self).contains("DANMU_MSG"))
    }

    private func uint16(_ value: UInt16) -> Data {
        withUnsafeBytes(of: value.bigEndian) { Data($0) }
    }

    private func uint32(_ value: UInt32) -> Data {
        withUnsafeBytes(of: value.bigEndian) { Data($0) }
    }
}

@Suite("弹幕命令解析")
struct DanmakuCommandParserTests {

    @Test func parsesDanmaku() throws {
        let json = try parse(#"""
        {"cmd":"DANMU_MSG:4:0:2:2:2:0","info":[[0,1,25,16777215], "晚上好", [12345,"小明",0,0], "", "", ""]}
        """#)

        let event = DanmakuCommandParser.parse(json, selfUID: 999)
        guard case .chat(let item) = try #require(event) else {
            Issue.record("应该是 chat 事件")
            return
        }
        #expect(item.kind == .danmaku)
        #expect(item.uid == 12345)
        #expect(item.uname == "小明")
        #expect(item.text == "晚上好")
        #expect(!item.isSelf)
    }

    @Test func marksSelfDanmaku() throws {
        let json = try parse(#"""
        {"cmd":"DANMU_MSG","info":[[0,1,25,0], "我自己", [999,"我"]]}
        """#)

        guard case .chat(let item) = try #require(DanmakuCommandParser.parse(json, selfUID: 999)) else {
            Issue.record("应该是 chat 事件")
            return
        }
        #expect(item.isSelf)
    }

    @Test func parsesGift() throws {
        let json = try parse(#"""
        {"cmd":"SEND_GIFT","data":{"uid":7,"uname":"打赏哥","giftName":"小心心","num":10,"action":"投喂"}}
        """#)

        guard case .chat(let item) = try #require(DanmakuCommandParser.parse(json, selfUID: 0)) else {
            Issue.record("应该是 chat 事件")
            return
        }
        #expect(item.kind == .gift)
        #expect(item.text.contains("小心心"))
        #expect(item.text.contains("10"))
    }

    @Test func parsesInteract() throws {
        let json = try parse(#"""
        {"cmd":"INTERACT_WORD","data":{"uid":8,"uname":"路人","msg_type":1}}
        """#)

        guard case .chat(let item) = try #require(DanmakuCommandParser.parse(json, selfUID: 0)) else {
            Issue.record("应该是 chat 事件")
            return
        }
        #expect(item.kind == .interact)
        #expect(item.text == "进入直播间")
    }

    @Test func stripsEntryEffectPlaceholders() throws {
        let json = try parse(#"""
        {"cmd":"ENTRY_EFFECT","data":{"uid":8,"copy_writing":"<%张三%> 进来了"}}
        """#)

        guard case .chat(let item) = try #require(DanmakuCommandParser.parse(json, selfUID: 0)) else {
            Issue.record("应该是 chat 事件")
            return
        }
        #expect(item.text == "张三 进来了")
    }

    /// 颜色在 info[0][3]，头像和表情在 info[0][15]；这里按真实抓包的结构摆一遍
    @Test func parsesColorFaceAndEmots() throws {
        let json = try parse(#"""
        {"cmd":"DANMU_MSG","info":[[0,1,25,16711680,0,0,0,"h",0,0,0,"",0,"{}",{},
        {"user":{"base":{"face":"https://example.com/a.jpg"}},"extra":"{\"emots\":{\"妙啊\":{\"url\":\"https://example.com/1.png\"}}}"},{},0],
        "红色弹幕",[123,"小明"]]}
        """#)

        guard case .chat(let item) = try #require(DanmakuCommandParser.parse(json, selfUID: 0)) else {
            Issue.record("应该是 chat 事件")
            return
        }
        #expect(item.color == 16711680)
        #expect(item.faceURL == "https://example.com/a.jpg")
        #expect(item.emots["妙啊"] == "https://example.com/1.png")
    }

    /// 粉丝牌、大航海、财富等级都在 info[0][15]["user"] 里，用户等级在 info[4][0]
    @Test func parsesMedalGuardAndLevels() throws {
        let json = try parse(#"""
        {"cmd":"DANMU_MSG","info":[[0,1,25,16777215,0,0,0,"h",0,0,0,"",0,"{}",{},
        {"user":{"base":{"face":"https://example.com/a.jpg"},"medal":{"name":"德云色","level":31,"color":2951253},"guard":{"level":1},"wealth":{"level":15}},"extra":"{}"},{},0],
        "hi",[1,"u"],[31,"德云色","主播",545068],[11,0,6406234,">50000",0],["",""],0,0,null,
        {"ct":"X"},0,0,null,null,0,260,[10],null]}
        """#)

        guard case .chat(let item) = try #require(DanmakuCommandParser.parse(json, selfUID: 0)) else {
            Issue.record("应该是 chat 事件")
            return
        }
        #expect(item.medal?.name == "德云色")
        #expect(item.medal?.level == 31)
        #expect(item.guardLevel == 1)
        #expect(item.wealthLevel == 10)
        #expect(item.userLevel == 11)
    }

    @Test func ignoresUnknownCommands() throws {
        let json = try parse(#"""
        {"cmd":"ONLINE_RANK_V2","data":{}}
        """#)
        #expect(DanmakuCommandParser.parse(json, selfUID: 0) == nil)
    }

    private func parse(_ raw: String) throws -> [String: Any] {
        let data = Data(raw.utf8)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

@Suite("InteractWordV2 protobuf")
struct DanmakuProtobufTests {

    /// 手拼一段 InteractWordV2：uid=42，uname="张三"，msg_type=1
    @Test func decodesUidNameAndType() throws {
        var data = Data()
        data.append(contentsOf: [0x08, 42])                    // field 1 varint
        data.append(contentsOf: [0x12, 6])                     // field 2 length 6
        data.append(Data("张三".utf8))
        data.append(contentsOf: [0x28, 1])                     // field 5 varint

        let decoded = try #require(DanmakuProtobuf.decodeInteractWordV2(data))
        #expect(decoded.uid == 42)
        #expect(decoded.uname == "张三")
        #expect(decoded.msgType == 1)
    }
}
