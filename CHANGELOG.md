# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### ✨ 改进（进行中）
- 侧边栏合并为「直播」「弹幕」两项，直播页变成单页滚动
- 开播/停播提到工具栏，状态由按钮本身表达，只在条件不足时提示缺什么
- 处理中改为按钮内联转圈；操作成功不再弹窗，只有失败提示
- 使用说明收进菜单栏 Help，内容压到三条；OBS 说明并入其中
- 视觉细节：卡片配色区分、按钮命中区按 HIG 补到 44x44

### 🐛 修复
- 回填房间信息时子分区被误清空
- 分区列表未就绪就回填，导致下拉框显示「请选择分区」

### 🔧 内部
- developmentRegion 改为 zh-Hans，新增 Localizable.xcstrings（已抽取 83 条文案）


## [1.1.2] - 2026-11-04

### ✨ 改进
- 分区下拉里给受限分区标注「需权限」（团播 / 男声电台 / 虚拟男V / 时政 / 游戏赛事），
  这几个分区需要额外资质，选了也开不了，现在能提前看出来

### 🐛 修复
- 开播前修改标题失败不再阻塞开播：标题是附带操作，失败只记日志

### 🔧 内部
- 代码按 Models / Services / ViewModels / Views 分层重构，业务逻辑从视图移出
- 网络日志统一走 os.Logger，并对推流码、Cookie、CSRF 等敏感字段脱敏
- 补上单元测试 target 与 13 个用例，接入 CI

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