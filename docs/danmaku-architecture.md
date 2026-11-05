# 弹幕接入架构（v1，已实现）

在原有"只能发"的基础上加一条 WebSocket 长连接，接住直播间的实时消息。
协议与消息处理对齐参考项目 ChaceQC/bilibili_live_stream_code（v2.3.17），分层按 Swift 6 的并发模型重做。

## 1. 数据流

```
DanmakuView ── 读 ──> DanmakuViewModel（发送）
        └──── 读 ──> DanmakuCenter（@MainActor 单例：聊天列表 + 连接状态）
                          │
                          ▼
                    DanmakuConnection（actor）
                    ├─ 取 token：APIClient.getDanmakuServerInfo()
                    ├─ 连 wss，发认证包（protover 2），30s 心跳
                    ├─ 收包 → DanmakuPacketCodec 拆帧 / DanmakuCompression 解 zlib
                    ├─ JSON → DanmakuCommandParser → DanmakuEvent
                    └─ 断线 → 指数退避重连
```

连接挂在 `DanmakuCenter` 上，不挂 View：切 tab 不断，退出登录才断。

## 2. 决策

| 决策 | 选择 | 理由 |
|---|---|---|
| 消息范围 | `DANMU_MSG`、`SEND_GIFT`、`COMBO_SEND`、`INTERACT_WORD`、`ENTRY_EFFECT`、`INTERACT_WORD_V2` | 对齐上游 |
| 压缩 | 认证包报 **protover 2**，只解 zlib | 实测：报 2 服务端回 protover=2 的 zlib 包，报 3 回 brotli。数据完全一样，省掉 brotli 依赖 |
| 解压实现 | 系统 `Compression` framework，剥掉 RFC1950 的 2 字节头和 4 字节 adler32 | 零依赖，不往仓库塞 C 源码 |
| Protobuf | 手写 varint / length-delimited 解析 | 只解 `InteractWordV2` 的 uid(1)/uname(2)/msg_type(5) 三个字段 |
| 发送 | 复用 `sendBullet` | 已跑通 |
| 回显 | 不本地插入，等服务器推回来 | 避免自己发的出现两条 |
| 重连 | 5 秒起指数退避，封顶 60 秒；认证失败不重连 | 认证失败重连只会一直转 |
| 连接宿主 | `DanmakuCenter.shared` | 与 `APIClient.shared` 同风格 |

### 实测记录（2026-11-05）

匿名连直播间 7734200：
- 认证包 `protover: 2` → 服务端回 `protover=2, op=5`，解压后是正常 JSON 命令
- 认证包 `protover: 3` → 服务端回 `protover=3, op=5`（brotli）

结论：protover 是压缩协商字段，报 2 就拿 zlib，不需要 brotli。

## 3. 模块

```
Models/DanmakuEvent.swift            事件、聊天行、连接状态、DanmakuServerInfo
Services/Danmaku/
  DanmakuCompression.swift           zlib（Compression framework）
  DanmakuPacket.swift                16 字节包头的编解码，压缩包递归拆
  DanmakuProtobuf.swift              InteractWordV2 最小解析
  DanmakuCommandParser.swift         六种命令 → DanmakuEvent
  DanmakuTransport.swift             传输协议 + URLSessionWebSocketTask 实现
  DanmakuConnection.swift            actor：握手、心跳、收包、重连
  DanmakuCenter.swift                @MainActor 单例：列表、状态、去重
Services/APIClient+Danmaku.swift     发送 + getDanmakuServerInfo
ViewModels/DanmakuViewModel.swift    只负责发送
Views/DanmakuView.swift              聊天流 + 输入框
```

项目开了 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`，所以模型和纯逻辑类型都显式标了 `nonisolated`，不然 actor 里调不到。

## 4. 连接状态机

```
idle ──connect()──> connecting ──成功──> connected
                        │ 失败/断开            │
                        └──> reconnecting(attempt) ──> connecting
认证回执 code≠0 ──> failed（不再重连）
disconnect()/退出登录 ──> idle
```

## 5. UI

顶部状态条（连接状态 / 人气 / 自动滚动开关 / 连接·断开），中间聊天流（最多 200 条，自动滚底可关），底部输入框。

## 6. 测试

`BilibiliStreamHelperTests/DanmakuCodecTests.swift`
- 包编解码往返、连续包拆分、坏长度不越界、zlib 解压、压缩帧递归拆
- 六种命令解析、未知命令丢弃
- InteractWordV2 protobuf

`BilibiliStreamHelperTests/DanmakuConnectionTests.swift`
- 连上后发认证包（检查 roomid / protover / token）
- 收到认证回执变 connected
- 收到 DANMU_MSG 进列表
- 认证失败停在 failed，不再重连
- 列表 200 条上限

## 7. 已知风险

- 同一房间可能推 `DANMU_MSG` 和带版本后缀的重复消息，用 (uid, text) 3 秒窗口兜底。
- 如果 B站哪天不再支持 protover 2，会收到 brotli 包；现在会在日志里打"收到 brotli 包，当前未支持"，届时再补解压。
- `INTERACT_WORD_V2` 的 pb 结构若变，只影响进场消息，不影响主流程。
