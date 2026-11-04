# CI/CD 详细设置指南

> 💡 **快速开始**: 查看 [CI/CD 快速指南](../CICD_QUICKSTART.md)

## 📋 目录
- [版本管理](#-版本管理)
- [GitHub Actions](#-github-actions)
- [故障排除](#-故障排除)

## 🔧 GitHub Actions

### 触发方式
1. **自动**: 推送标签时触发 (`git push origin v1.0.0`)
2. **手动**: GitHub → Actions → Release macOS App → Run workflow

### 构建环境
- **Runner**: xcode-27（Xcode 27 单版本镜像，仅 Apple Silicon）
- **Xcode**: 27
- **架构**: arm64 + x86_64
- **目标**: macOS 13.0+

### 代码签名
开源项目使用无签名模式，生成的应用需用户手动信任

## 📋 版本管理

### 脚本命令
```bash
./scripts/version_manager.sh bump patch   # 1.0.0 → 1.0.1
./scripts/version_manager.sh bump minor   # 1.0.0 → 1.1.0
./scripts/version_manager.sh bump major   # 1.0.0 → 2.0.0
./scripts/version_manager.sh release      # 创建标签并推送
```

### 自动更新
- **VERSION文件**: 存储当前版本号
- **project.pbxproj**: 更新Xcode项目版本
- **CHANGELOG.md**: 自动添加新版本条目


## 🛠️ 故障排除

### 常见问题

**构建失败**
```bash
make clean && make build  # 清理重新构建
```

**标签冲突**
```bash
git tag -d v1.0.0                    # 删除本地标签
git push origin :refs/tags/v1.0.0    # 删除远程标签
```

**权限错误**
GitHub仓库 → Settings → Actions → General → Workflow permissions → "Read and write permissions"

### 调试
- 查看GitHub Actions日志
- 使用 `make status` 检查项目状态
- [提交Issue](https://github.com/sosoorin/BilibiliStreamHelper/issues)

---
📚 更多信息请查看 [快速指南](../CICD_QUICKSTART.md)
