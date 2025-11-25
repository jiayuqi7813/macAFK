# MacAfk - macOS Anti-Sleep Tool

![image](./assets/image.png)

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS-blue" alt="Platform">
  <img src="https://img.shields.io/badge/swift-5.0-orange" alt="Swift">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
</p>

<p align="center">
  <a href="README.md">English</a> | <a href="README_CN.md">中文</a>
</p>

> Most enterprise macOS computers are managed via MDM, which prevents users from modifying screen lock settings. Additionally, many people now delegate tasks to LLM Agents and then... take a break. However, screen lock can cause AI agent tasks to fail, which is why this tool was developed.

> You can safely run it, and it will prevent the system from entering sleep mode through subtle (imperceptible) mouse movements.

---

## ✨ Key Features

### 🖱️ Anti-Sleep Functionality
- **Automatic Mouse Jiggling** - Prevents system from entering sleep mode
- **Adjustable Intervals** - 6 levels from 10 seconds to 10 minutes
- **Imperceptible Operation** - 1-pixel movement, completely unobtrusive

### 🌙 Smart Brightness Control
- **Dual Mode Support**
  - **Pro Version**: Real hardware brightness control (DisplayServices API)
  - **Lite Version**: Software dimming (Gamma table, App Store compatible)
- **Auto Detection** - Automatically selects the best mode based on runtime environment
- **Low Brightness Mode** - One-click screen dimming to save power and extend battery life

### ⌨️ Powerful Shortcut System
- **Global Shortcuts** - Quick control even when running in background
- **Fully Customizable** - Visual editor with real-time shortcut recording
- **Auto Save** - Persistent configuration, retained after restart

### 🎨 Modern Interface
- **SwiftUI Built** - Native macOS experience
- **Menu Bar Integration** - Lightweight, doesn't occupy Dock space
- **Intuitive Operation** - Clear status display at a glance

---

## 📦 Dual Version Overview

| Version | MacAfk Pro | MacAfk Lite |
|---------|-----------|-------------|
| **Brightness Control** | DisplayServices (Real Hardware) | Gamma Dimming (Software Simulation) |
| **Power Saving** | ✅ Real power reduction | ❌ Screen backlight unchanged |
| **Sandbox** | ❌ Disabled | ✅ Enabled |
| **App Store** | ❌ Not available | ✅ Available |
| **User Experience** | ⭐️⭐️⭐️⭐️⭐️ | ⭐️⭐️⭐️⭐️ |
| **Distribution** | GitHub/Website | App Store |
| **Target Users** | Best experience seekers | App Store version needed |

---

## 🚀 Quick Start

### Download & Install

#### Pro Version (Recommended)
```bash
# Download from GitHub Releases
https://github.com/jiayuqi7813/macAFK-Pro/releases
```

#### Lite Version
- App Store: [Search "MacAfk Lite"](#)

### First Run

1. **Grant Accessibility Permission**
   - Open "System Settings" → "Privacy & Security" → "Accessibility"
   - Add MacAfk and enable it

2. **Launch Application**
   - Click the menu bar icon
   - Or use shortcut `⌘ ⌃ S`

3. **Start Using**
   - Enable anti-sleep: Click button or press `⌘ ⌃ S`
   - Enable low brightness: Toggle switch or press `⌘ ⌃ B`

---

## ⌨️ Default Shortcuts

| Shortcut | Function |
|----------|----------|
| `⌘ ⌃ S` | Toggle anti-sleep |
| `⌘ ⌃ B` | Toggle low brightness mode |
| `⌘ ⌃ ↑` | Increase jiggle interval |
| `⌘ ⌃ ↓` | Decrease jiggle interval |

**Custom Shortcuts**: Click "Customize All Shortcuts" button in the main interface

---

## 🔧 Build from Source

### Requirements
- macOS 10.15+
- Xcode 14.0+
- Swift 5.0+

### Build Steps

#### Quick Build
```bash
cd MacAfk
xcodebuild -scheme MacAfk -configuration Debug build
```

#### Build Both Versions
```bash
# Using automated script
./build.sh

# Or manual build
# Pro Version (Real brightness)
xcodebuild -scheme MacAfk -configuration Release build

# Lite Version (Gamma dimming)
xcodebuild -scheme MacAfk -configuration Release-AppStore build
```

---

## 📖 Use Cases

### Case 1: AI Agent Auto-Suspend
```
Problem: Enterprise policy auto-locks after 5 minutes, AI agent tasks fail due to screen lock network issues
Solution: Press ⌘ ⌃ S to enable anti-sleep, set longer interval (5-10 minutes)
```

### Case 2: Download/Processing Tasks ⏬
```
Problem: Long-running tasks but don't want screen always on
Solution: ⌘ ⌃ S + ⌘ ⌃ B (Low brightness mode saves power)
```

### Case 3: Remote Work 💻
```
Problem: Need to maintain connection but temporarily away
Solution: ⌘ ⌃ S to keep active, avoid disconnection
```

### Case 4: Video Playback 🎬
```
Problem: System auto-sleeps during video playback
Solution: Enable anti-sleep for uninterrupted viewing experience
```

---

## 🛠️ Technical Architecture

```
MacAfk
├── AppModel.swift              # Application state management
├── BrightnessControl.swift     # Dual-mode brightness control
├── Jiggler.swift               # Mouse jiggling engine
├── ShortcutManager.swift       # Shortcut management system
├── ShortcutEditorView.swift    # Shortcut editor
├── ContentView.swift           # Main interface
├── SettingsView.swift          # Settings interface
└── AppDelegate.swift           # Menu bar integration
```
---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!

### Development Workflow
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Code Style
- Follow Swift official code style guidelines
- Add necessary comments
- Update relevant documentation

---

## ❓ FAQ

### Q: "File is damaged" error when installing from GitHub Release?
A: This is a macOS Gatekeeper security feature. Since the app is not notarized (to comply with App Store guidelines), you need to remove the quarantine attribute. Run this command in Terminal:
```bash
xattr -cr /Applications/MacAfk\ Pro.app/
```
Then try opening the app again. Alternatively, you can right-click the app and select "Open" instead of double-clicking.

### Q: Shortcuts not working?
A: Please ensure MacAfk has been granted permission in "System Settings" → "Privacy & Security" → "Accessibility".

### Q: Does it support external displays?
A: Yes, Pro version supports brightness control for multiple displays.

**Technical Approach:**
- **Built-in Display**: Uses DisplayServices API (native hardware control)
- **External Displays**: Based on [BetterDisplay](https://github.com/waydabber/BetterDisplay) integration interface

Due to technical cost considerations, external display brightness control is implemented using BetterDisplay's [Integration API](https://github.com/waydabber/BetterDisplay/wiki/Integration-features,-CLI). This solution is mature, stable, and supports a wide range of external display models.

**Prerequisites:**
1. Install [BetterDisplay](https://github.com/waydabber/BetterDisplay) (free version works)
2. Enable "Integration features" in BetterDisplay settings
3. MacAfk will automatically detect and connect to BetterDisplay

**Note:** Lite version only supports the main display.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details

---

## 🙏 Acknowledgments

- [MonitorControl](https://github.com/MonitorControl/MonitorControl) - Brightness control implementation reference
- SwiftUI Community - Technical support

---

<p align="center">
  <strong>⭐️ If this project helps you, please give it a Star!</strong>
</p>

<p align="center">
  Made with ❤️ by Sn1waR
</p>

