# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### 🔧 构建
- CI 切换到 Xcode 27 runner 镜像（`xcode-27`），删除多余的 setup-xcode 步骤
- GitHub Actions 全部升级到 Node 24 运行时版本
- 本地与 CI 工具链统一为 Xcode 27，部署目标仍为 macOS 13.0


## [1.1.1] - 2026-11-04

### 🐛 Fixes
- **修复人脸认证无法继续的问题**:B站 在部分分区/账号下返回 `60043` 而不是 `60024`,且不再提供 `data.qr`。
  现在按官方直播姬客户端的做法，自行拼接 `face-auth-middle` 认证中间页并生成二维码，原有扫码流程可继续使用。
- **错误提示改成说人话**:`60009` / `60013` / `60034` / `60037` / `65530` / `-400` 等错误码不再直接抛原始文案，
  改为给出具体原因和下一步该怎么做，同时保留错误码方便反馈。
- 移除会把人脸认证链接打印到控制台的调试输出。

## [1.1.0] - 2025-09-28

### 🚀 Major Features
- **完整的CI/CD流程**: 基于GitHub Actions的自动化构建和发布
- **使用Xcode 26.0构建**
- **多架构支持**: 同时支持Apple Silicon (arm64) 和 Intel (x86_64)
- **自动化包管理**: 自动生成DMG和ZIP安装包

## [1.0.0] - 2025-09-24

### 🎉 Initial Release
- **双重登录方式**: 扫码登录 / 手动Cookie登录
- **直播管理**: 设置标题、选择分区、开启/关闭直播  
- **推流信息获取**: 自动获取RTMP服务器地址和推流码
- **弹幕发送**: 应用内直接发送弹幕
- **便捷操作**: 一键复制、配置导出
- **安全存储**: 使用Keychain安全存储敏感信息
- **SwiftUI界面**: 现代化的macOS原生界面
- **Swift 6支持**: 使用最新的Swift语言特性