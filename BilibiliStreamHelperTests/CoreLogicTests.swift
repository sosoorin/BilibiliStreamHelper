import Foundation
import SwiftyJSON
import Testing
@testable import BilibiliStreamHelper

// MARK: - 签名

@Suite("签名算法")
@MainActor
struct SignerTests {
    
    /// 同样的参数必须得到同样的签名
    @Test func appSignIsDeterministic() {
        let params: [String: Any] = ["room_id": "123", "ts": 1700000000]
        let a = AppSigner.appSign(params: params, appKey: "k", appSec: "s")
        let b = AppSigner.appSign(params: params, appKey: "k", appSec: "s")
        
        #expect(a["sign"] as? String == b["sign"] as? String)
    }
    
    /// 签名会把 appkey 一起带上，且是 32 位小写十六进制
    @Test func appSignIncludesAppkeyAndIsMD5Hex() {
        let result = AppSigner.appSign(params: ["a": "1"], appKey: "mykey", appSec: "mysecret")
        
        #expect(result["appkey"] as? String == "mykey")
        
        guard let sign = result["sign"] as? String else {
            Issue.record("签名缺失")
            return
        }
        #expect(sign.count == 32)
        #expect(sign.allSatisfy { $0.isHexDigit })
    }
    
    /// 参数顺序不影响结果（内部会排序）
    @Test func appSignIgnoresParameterOrder() {
        let a = AppSigner.appSign(params: ["x": "1", "y": "2"], appKey: "k", appSec: "s")
        let b = AppSigner.appSign(params: ["y": "2", "x": "1"], appKey: "k", appSec: "s")
        
        #expect(a["sign"] as? String == b["sign"] as? String)
    }
    
    /// Wbi 签名要产出 w_rid / wts，并保留原始参数
    @Test func wbiSignProducesWridAndWts() {
        let result = WBISigner.encWbi(
            params: ["foo": "bar"],
            imgKey: "7cd084941338484aae1ad9425b84077c",
            subKey: "4932caff0ff746eab6f01bf08b70ac45"
        )
        
        #expect(result["w_rid"] as? String != nil)
        #expect(result["wts"] != nil)
        #expect(result["foo"] as? String == "bar")
        
        if let rid = result["w_rid"] as? String {
            #expect(rid.count == 32)
        }
    }
}

// MARK: - 日志脱敏

@Suite("日志脱敏")
@MainActor
struct LogMaskTests {
    
    @Test func masksSensitiveLeafValues() {
        let payload: [String: Any] = [
            "uid": 348892132,
            "csrf_token": "abcdefgh12345678",
            "rtmp": ["addr": "rtmp://live-push.example/", "code": "?key=supersecret"]
        ]
        
        let text = LogMask.describe(payload)
        
        #expect(!text.contains("supersecret"))
        #expect(!text.contains("348892132"))
        #expect(!text.contains("abcdefgh12345678"))
    }
    
    /// 顶层的 code 是业务状态码，必须留着，否则没法排错
    @Test func keepsTopLevelCode() {
        let text = LogMask.describe(["code": 60043, "message": "需要验证"] as [String: Any])
        
        #expect(text.contains("60043"))
        #expect(text.contains("需要验证"))
    }
    
    @Test func truncatesLongOutput() {
        let long = String(repeating: "x", count: 2_000)
        let text = LogMask.describe(["blob": long] as [String: Any])
        
        #expect(text.count <= 301)
    }
    
    @Test func masksCookieValuesButKeepsNames() {
        let masked = LogMask.maskCookies("SESSDATA=secret123456; bili_jct=csrf987654")
        
        #expect(masked.contains("SESSDATA"))
        #expect(masked.contains("bili_jct"))
        #expect(!masked.contains("secret123456"))
        #expect(!masked.contains("csrf987654"))
    }
}

// MARK: - 错误展示

@Suite("开播错误展示")
@MainActor
struct ErrorDisplayTests {
    
    /// 标题要带错误码，正文是 B站 原文
    @Test func showsCodeAndOriginalMessage() {
        let display = LiveErrorText.display(code: 60034, message: "系统维护仅支持直播姬开播")
        
        #expect(display.title.contains("60034"))
        #expect(display.message == "系统维护仅支持直播姬开播")
    }
    
    /// B站 没给文案时也要有个说法
    @Test func handlesEmptyMessage() {
        let display = LiveErrorText.display(code: 12345, message: "")
        
        #expect(display.title.contains("12345"))
        #expect(!display.message.isEmpty)
    }
}

// MARK: - 业务码错误文案

@Suite("接口错误文案")
@MainActor
struct APIErrorMessageTests {
    
    /// message 有值就用 message
    @Test func prefersMessageField() {
        let json = JSON(["code": 60034, "message": "系统维护", "msg": "另一个说法"])
        #expect(APIClient.errorMessage(from: json) == "系统维护")
    }
    
    /// B站 有的接口只填 msg
    @Test func fallsBackToMsgWhenMessageEmpty() {
        let json = JSON(["code": 60034, "message": "", "msg": "只填了 msg"])
        #expect(APIClient.errorMessage(from: json) == "只填了 msg")
    }
    
    /// 两个都空就返回空串，交给上层兜底
    @Test func returnsEmptyWhenBothMissing() {
        let json = JSON(["code": 1])
        #expect(APIClient.errorMessage(from: json).isEmpty)
    }
}
