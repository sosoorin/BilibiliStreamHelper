<div align="center">
<h1 align="center" style="margin-top: 0">BilibiliStreamHelper for macOS</h1>

![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![Platform](https://img.shields.io/badge/macOS-14.0+-green)
![License](https://img.shields.io/badge/License-Apache%202.0-red)
![Version](https://img.shields.io/badge/Version-v1.1.2-brightgreen)
![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF)

使用 Swift 6 + SwiftUI 开发的哔哩哔哩直播推流码获取工具。

</div>

> 不能获取推流码后，官方提供的Mac开播方法实在是太难用了！！

## ✨ 主要功能

- 🔐 **双重登录方式**：扫码登录 / 手动Cookie登录
- 📺 **直播管理**：设置标题、选择分区、开启/关闭直播
- 🔄 **推流信息获取**：自动获取RTMP服务器地址和推流码
- 💬 **弹幕发送**：应用内直接发送弹幕
- 📋 **便捷操作**：一键复制、配置导出
- 🔒 **安全存储**：使用Keychain安全存储敏感信息

## ⚠️ 重要提醒

- 本程序仅获取推流信息，使用官方API接口，**理论上**正常使用不会影响账号安全。
- 使用前请确保遵守B站相关条款，使用风险由用户自行承担。
- **请务必使用本程序停止直播**（OBS停止推流≠B站下播）。
- 推流码一次性使用，每次直播需重新获取。

## 🚀 快速开始

### 📦 下载使用

#### 方式一：下载预编译版本（推荐）
1. 访问 [Releases 页面](https://github.com/sosoorin/BilibiliStreamHelper/releases)
2. 下载最新的 `BilibiliStreamHelper-vX.X.X-macos.dmg`
3. 双击安装，拖拽到应用程序文件夹

#### 方式二：从源码构建
```bash
# 克隆仓库
git clone https://github.com/sosoorin/BilibiliStreamHelper.git
cd BilibiliStreamHelper

# 安装依赖并构建
make dev-setup
make build

# 或直接用 Xcode 打开
make open
```

### 系统要求
- **运行**: macOS 14.0+
- **开发**: macOS 14.0+ + Xcode 27.0+

### 使用流程
1. **登录** → 扫码或手动输入Cookie
2. **设置** → 输入标题，选择分区
3. **开播** → 获取推流信息
4. **OBS** → 配置服务器地址和推流码

## 🏗️ 技术栈

### 核心技术
- **Swift 6** + **SwiftUI** - 现代化界面
- **Keychain** - 安全存储

### 开发工具链
- **Xcode 27.0** - 最新开发环境
- **GitHub Actions** - 自动化CI/CD流程
- **SwiftyJSON** - JSON数据解析
- **语义化版本管理** - 规范的版本控制

## 🛠️ 开发者指南

<details>
<summary><strong>🚀 快速开始</strong></summary>

```bash
# 克隆项目
git clone https://github.com/your-username/BilibiliLiveStremCodeSwift.git
cd BilibiliLiveStremCodeSwift

# 环境设置
make dev-setup

# 构建运行
make build
```

</details>

<details>
<summary><strong>📦 发布流程</strong></summary>

```bash
# 版本管理
make bump-patch   # 1.0.0 → 1.0.1
make bump-minor   # 1.0.0 → 1.1.0  
make bump-major   # 1.0.0 → 2.0.0

# 自动发布
make release      # 创建 GitHub Release
```

**自动化特性**：推送标签后自动构建 DMG/ZIP 安装包

</details>

<details>
<summary><strong>🤝 参与贡献</strong></summary>

1. **Fork** 本仓库
2. **创建分支**: `git checkout -b feature/new-feature`
3. **提交代码**: `git commit -m "Add new feature"`
4. **推送分支**: `git push origin feature/new-feature`
5. **提交 PR**: 创建 Pull Request

**文档参考**: [CI/CD 指南](CICD_QUICKSTART.md) | [详细文档](docs/CI_CD_SETUP.md)

</details>

## 🐛 常见问题

- **二维码过期** → 重新生成
- **Cookie失效** → 重新登录
- **开播失败** → 检查分区设置
- **人脸认证** → 用手机客户端扫码
- **构建失败** → 检查Xcode版本和依赖

## 🤖 AI辅助开发声明

本项目在开发过程中使用了AI工具辅助，包括但不限于代码/文档生成、优化建议和问题解决。


## 贡献者

![cr](https://contrib.rocks/image?repo=sosoorin/BilibiliStreamHelper)

## 📄 许可证

 [Apache License 2.0](./LICENSE)

## 🙏 致谢

**功能思路参考**
- [ChaceQC/bilibili_live_stream_code](https://github.com/ChaceQC/bilibili_live_stream_code)

**技术依赖**
- [SwiftyJSON](https://github.com/SwiftyJSON/SwiftyJSON) - JSON解析
- [Apple CryptoKit](https://developer.apple.com/documentation/cryptokit) - 加密算法
- [SocialSisterYi/bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect) - API文档参考

---

<div align="center">

**如果有帮助请给个 ⭐️ Star！**

[问题反馈](https://github.com/sosoorin/BilibiliStreamHelper/issues) • [功能建议](https://github.com/sosoorin/BilibiliStreamHelper/issues)

</div>