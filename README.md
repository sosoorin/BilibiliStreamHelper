<div align="center">
<h1 align="center" style="margin-top: 0">BilibiliStreamHelper for macOS</h1>

![Swift](https://img.shields.io/badge/Swift-6.4-orange)
![Platform](https://img.shields.io/badge/macOS-14.0+-green)
![License](https://img.shields.io/badge/License-Apache%202.0-red)
![Version](https://img.shields.io/badge/Version-v1.3.1-brightgreen)

Swift 6 + SwiftUI 写的哔哩哔哩直播推流码工具。

</div>

> 不能获取推流码后，官方提供的Mac开播方法实在是太难用了！！

## 功能

- 🔐 **双重登录方式**：扫码登录 / 手动 Cookie 登录
- 📺 **直播管理**：设置标题、选择分区、开启 / 关闭直播
- 🔄 **推流信息获取**：自动获取 RTMP 服务器地址和推流码
- 💬 **弹幕收发**：进直播间自动连，收弹幕、礼物、进场，也能直接发
- 📋 **便捷操作**：一键复制、配置导出
- 🔒 **安全存储**：登录凭证存进 macOS Keychain，只留在本机；所有请求直连 B站 官方接口，不经过任何第三方服务器

## 声明

**本程序仅用于学习和交流，使用前请确保遵守 B站 相关条款，使用风险由用户自行承担。**

## 下载

去 [Releases](https://github.com/sosoorin/BilibiliStreamHelper/releases) 下 `BilibiliStreamHelper-vX.X.X-macos.dmg`，拖进「应用程序」。

系统要求 macOS 14+。

## 从源码构建

```bash
git clone https://github.com/sosoorin/BilibiliStreamHelper.git
cd BilibiliStreamHelper
make dev-setup
make build
```

需要 Xcode 27+，`make open` 直接用 Xcode 打开。推 `v*` 标签会自动构建 DMG / ZIP 发版。

## 使用

1. 登录（扫码或 Cookie）
2. 填标题、选分区
3. 开播，拿到推流码
4. 填进 OBS
5. 切到「弹幕」页看实时弹幕

## 注意

- **必须用本程序停播**，OBS 断流不等于 B站 下播
- 推流码是一次性的，每次开播都要重新取

## 常见问题

二维码过期就重新生成一张；登录状态失效，重新登一次就好。

开播失败多半是分区没选对，或者账号没有那个分区的开播资质。

遇到人脸认证按界面提示走，手机上用 B站 App 扫一下。

弹幕连不上、提示风控，是短时间内请求太多被限了，隔半分钟再点连接。

## AI 辅助开发声明

本项目在开发过程中使用了 AI 工具辅助，包括代码与文档的起草、界面方案讨论和问题排查。

## 致谢

功能思路参考 [ChaceQC/bilibili_live_stream_code](https://github.com/ChaceQC/bilibili_live_stream_code)。
依赖 [SwiftyJSON](https://github.com/SwiftyJSON/SwiftyJSON)、Apple CryptoKit 和系统 Compression。

## 许可

[Apache License 2.0](./LICENSE)

---
<div align="center">

**觉得有用就给个 ⭐️**

[问题反馈](https://github.com/sosoorin/BilibiliStreamHelper/issues) · [功能建议](https://github.com/sosoorin/BilibiliStreamHelper/issues)

</div>
