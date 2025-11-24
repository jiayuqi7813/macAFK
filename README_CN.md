# MacAfk - macOS 防休眠工具

![image](./assets/image.png)

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS-blue" alt="Platform">
  <img src="https://img.shields.io/badge/swift-5.0-orange" alt="Swift">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
</p>

>由于大多数企业电脑的 macOS 存在通过 MDM 管控禁止用户修改锁屏时间的情况，并且现在很多人都习惯将任务分配给 LLM Agent，然后自己去~~摸鱼~~。而此时电脑锁屏会影响大模型任务失败，所以开发了这款程序。

>你可以安心地打开它,它会通过鼠标细微（根本无法察觉）的抖动来防止系统进入休眠状态。

---


## ✨ 主要特性

### 🖱️ 防休眠功能
- **自动鼠标抖动** - 防止系统进入休眠状态
- **可调节间隔** - 10秒到10分钟，6个档位可选
- **无感操作** - 1像素移动，完全不影响工作

### 🌙 智能亮度控制
- **双模式支持**
  - **Pro 版**：真实硬件亮度控制（DisplayServices API）
  - **Lite 版**：软件调光（Gamma 表，App Store 兼容）
- **自动检测** - 根据运行环境自动选择最佳模式
- **低亮度模式** - 一键降低屏幕亮度，省电延长续航

### ⌨️ 强大的快捷键系统
- **全局快捷键** - 后台运行也能快速控制
- **完全自定义** - 可视化编辑器，实时录制新快捷键
- **自动保存** - 配置持久化，重启后保留

### 🎨 现代化界面
- **SwiftUI 构建** - 原生 macOS 体验
- **状态栏集成** - 轻量化，不占用 Dock 空间
- **直观操作** - 一目了然的状态显示

---

## 📦 双版本说明

| 版本 | MacAfk Pro | MacAfk Lite |
|------|-----------|-------------|
| **亮度控制** | DisplayServices（真实硬件）| Gamma 调光（软件模拟）|
| **省电效果** | ✅ 真实降低功耗 | ❌ 屏幕背光不变 |
| **沙盒** | ❌ 禁用 | ✅ 启用 |
| **App Store** | ❌ 不可上架 | ✅ 可上架 |
| **用户体验** | ⭐️⭐️⭐️⭐️⭐️ | ⭐️⭐️⭐️⭐️ |
| **发布渠道** | GitHub/网站 | App Store |
| **推荐人群** | 追求最佳体验 | 需要 App Store 版本 |

---

## 🚀 快速开始

### 下载安装

#### Pro 版（推荐）
```bash
# GitHub Releases 下载
https://github.com/jiayuqi7813/macAFK-Pro/releases
```

#### Lite 版
- App Store: [搜索 "MacAfk Lite"](#)

### 首次运行

1. **授予辅助功能权限**
   - 打开「系统设置」→「隐私与安全性」→「辅助功能」
   - 添加 MacAfk 并启用

2. **启动应用**
   - 点击状态栏图标
   - 或使用快捷键 `⌘ ⌃ S`

3. **开始使用**
   - 开启防休眠：点击按钮或按 `⌘ ⌃ S`
   - 启用低亮度：勾选开关或按 `⌘ ⌃ B`

---

## ⌨️ 默认快捷键

| 快捷键 | 功能 |
|--------|------|
| `⌘ ⌃ S` | 切换防休眠 |
| `⌘ ⌃ B` | 切换低亮度模式 |
| `⌘ ⌃ ↑` | 增加抖动间隔 |
| `⌘ ⌃ ↓` | 减少抖动间隔 |

**自定义快捷键**：点击主界面的「自定义所有快捷键」按钮

---

## 🔧 从源码构建

### 环境要求
- macOS 10.15+
- Xcode 14.0+
- Swift 5.0+

### 构建步骤

#### 快速构建
```bash
cd MacAfk
xcodebuild -scheme MacAfk -configuration Debug build
```

#### 构建双版本
```bash
# 使用自动化脚本
./build.sh

# 或手动构建
# Pro 版（真实亮度）
xcodebuild -scheme MacAfk -configuration Release build

# Lite 版（Gamma 调光）
xcodebuild -scheme MacAfk -configuration Release-AppStore build
```

---

## 📖 使用场景

### 场景1：ai agent自动挂起
```
问题：企业管控5分钟自动锁定，ai agent会被锁屏网络影响导致任务失败
解决：⌘ ⌃ S 启动防休眠，设置较长间隔（5-10分钟）
```

### 场景2：下载/处理任务 ⏬
```
问题：长时间任务但不想屏幕一直亮着
解决：⌘ ⌃ S + ⌘ ⌃ B（低亮度模式省电）
```

### 场景3：远程工作 💻
```
问题：需要保持连接但暂时离开
解决：⌘ ⌃ S 保持活跃状态，避免断开连接
```

### 场景4：视频播放 🎬
```
问题：看视频时系统自动休眠
解决：启动防休眠，享受不间断的观影体验
```

---


## 🛠️ 技术架构

```
MacAfk
├── AppModel.swift              # 应用状态管理
├── BrightnessControl.swift     # 双模式亮度控制
├── Jiggler.swift               # 鼠标抖动引擎
├── ShortcutManager.swift       # 快捷键管理系统
├── ShortcutEditorView.swift    # 快捷键编辑器
├── ContentView.swift           # 主界面
├── SettingsView.swift          # 设置界面
└── AppDelegate.swift           # 状态栏集成
```
---

## 🤝 贡献指南

欢迎贡献代码、报告问题或提出建议！

### 开发流程
1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

### 代码规范
- 遵循 Swift 官方代码风格
- 添加必要的注释
- 更新相关文档

---

## ❓ 常见问题

### Q: 快捷键不工作？
A: 请确保已在「系统设置」→「隐私与安全性」→「辅助功能」中授予 MacAfk 权限。

### Q: 支持外接显示器吗？
A: 是的，Pro 版支持多显示器；Lite 版主要针对主显示器。以实际效果为准，暂未测试多台显示器以上。

---

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

---

## 🙏 致谢

- [MonitorControl](https://github.com/MonitorControl/MonitorControl) - 亮度控制实现参考
- SwiftUI 社区 - 技术支持

---

<p align="center">
  <strong>⭐️ 如果这个项目对你有帮助，请给个 Star！</strong>
</p>

<p align="center">
  Made with ❤️ by Sn1waR
</p>

