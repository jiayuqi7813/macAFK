import Foundation
import Carbon
import AppKit
import Combine
import ApplicationServices

/// 快捷键动作类型
enum ShortcutAction: Hashable, Codable {
    case toggleJiggle           // 切换防休眠
    case toggleBrightness       // 切换低亮度模式
    case increaseJiggleInterval // 增加抖动间隔
    case decreaseJiggleInterval // 减少抖动间隔
}

/// 快捷键配置
struct ShortcutConfig: Codable {
    let action: ShortcutAction
    let keyCode: UInt16
    let modifiers: UInt
    let displayName: String
    
    init(action: ShortcutAction, keyCode: UInt16, modifiers: NSEvent.ModifierFlags, displayName: String) {
        self.action = action
        self.keyCode = keyCode
        self.modifiers = modifiers.rawValue
        self.displayName = displayName
    }
    
    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiers)
    }
    
    /// 获取快捷键显示字符串
    var displayString: String {
        var parts: [String] = []
        
        let flags = modifierFlags
        if flags.contains(.command) { parts.append("⌘") }
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        
        // 键码转字符
        let keyChar = Self.keyCodeToChar(keyCode)
        parts.append(keyChar)
        
        return parts.joined(separator: " ")
    }
    
    static func keyCodeToChar(_ code: UInt16) -> String {
        switch code {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 17: return "T"
        case 16: return "Y"
        case 32: return "U"
        case 34: return "I"
        case 31: return "O"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 40: return "K"
        case 45: return "N"
        case 46: return "M"
        case 49: return "Space"
        case 36: return "↩"
        case 51: return "⌫"
        case 53: return "⎋"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return "\(code)"
        }
    }
}

/// 快捷键管理器 - 支持多个自定义快捷键
class ShortcutManager: ObservableObject {
    
    // 快捷键回调
    var onAction: ((ShortcutAction) -> Void)?
    
    private var eventMonitor: Any?
    private var localEventMonitor: Any?
    private let userDefaultsKey = "customShortcuts"
    
    // 默认快捷键配置
    @Published var shortcuts: [ShortcutAction: ShortcutConfig] = [
        .toggleJiggle: ShortcutConfig(
            action: .toggleJiggle,
            keyCode: 1,  // S
            modifiers: [.command, .control],
            displayName: NSLocalizedString("shortcut.toggle_jiggle", comment: "")
        ),
        .toggleBrightness: ShortcutConfig(
            action: .toggleBrightness,
            keyCode: 11, // B
            modifiers: [.command, .control],
            displayName: NSLocalizedString("shortcut.toggle_brightness", comment: "")
        ),
        .increaseJiggleInterval: ShortcutConfig(
            action: .increaseJiggleInterval,
            keyCode: 126, // 上箭头
            modifiers: [.command, .control],
            displayName: NSLocalizedString("shortcut.increase_interval", comment: "")
        ),
        .decreaseJiggleInterval: ShortcutConfig(
            action: .decreaseJiggleInterval,
            keyCode: 125, // 下箭头
            modifiers: [.command, .control],
            displayName: NSLocalizedString("shortcut.decrease_interval", comment: "")
        )
    ]
    
    init() {
        loadCustomShortcuts()
    }
    
    func startListening() {
        // 停止现有监听器（如果有）
        stopListening()
        
        // 检查辅助功能权限
        let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [checkOptPrompt: false] as CFDictionary
        let hasPermission = AXIsProcessTrustedWithOptions(options)
        
        if !hasPermission {
            print("⚠️ [ShortcutManager] 没有辅助功能权限，全局快捷键将不可用")
            // 仍然创建本地监听器，至少在应用前台时可用
        } else {
            print("✅ [ShortcutManager] 辅助功能权限已授予")
        }
        
        // 使用全局事件监听器（在应用后台时也能工作，需要辅助功能权限）
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleEvent(event)
        }
        
        if eventMonitor != nil {
            print("✅ [ShortcutManager] 全局事件监听器已创建")
        } else {
            print("❌ [ShortcutManager] 全局事件监听器创建失败（可能缺少辅助功能权限）")
        }
        
        // 同时监听本地事件（当应用在前台时）
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleEvent(event)
            return event
        }
        
        if localEventMonitor != nil {
            print("✅ [ShortcutManager] 本地事件监听器已创建")
        }
        
        print("✅ [ShortcutManager] 快捷键监听已启动")
    }
    
    func stopListening() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        print("⏹️ [ShortcutManager] 快捷键监听已停止")
    }
    
    private func handleEvent(_ event: NSEvent) {
        // 提取事件的修饰键（只保留我们关心的）
        let eventModifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        
        // 调试日志
        // #if DEBUG
        // print("🔍 [ShortcutManager] 键盘事件: keyCode=\(event.keyCode), modifiers=\(eventModifiers.rawValue)")
        // #endif
        
        // 遍历所有快捷键配置，查找匹配的
        for (action, config) in shortcuts {
            // 提取配置的修饰键（只保留我们关心的）
            let configModifiers = config.modifierFlags.intersection([.command, .control, .option, .shift])
            
            if event.keyCode == config.keyCode && eventModifiers == configModifiers {
                print("🎯 [ShortcutManager] 快捷键触发: \(action)")
                onAction?(action)
                break
            }
        }
    }
    
    /// 获取快捷键显示字符串
    func getShortcutDisplay(for action: ShortcutAction) -> String {
        return shortcuts[action]?.displayString ?? NSLocalizedString("shortcut.editor.not_set", comment: "")
    }
    
    /// 更新快捷键配置
    func updateShortcut(for action: ShortcutAction, keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        if let existing = shortcuts[action] {
            shortcuts[action] = ShortcutConfig(
                action: action,
                keyCode: keyCode,
                modifiers: modifiers,
                displayName: existing.displayName
            )
            saveCustomShortcuts()
        }
    }
    
    /// 重置为默认快捷键
    func resetToDefaults() {
        shortcuts = [
            .toggleJiggle: ShortcutConfig(
                action: .toggleJiggle,
                keyCode: 1,
                modifiers: [.command, .control],
                displayName: NSLocalizedString("shortcut.toggle_jiggle", comment: "")
            ),
            .toggleBrightness: ShortcutConfig(
                action: .toggleBrightness,
                keyCode: 11,
                modifiers: [.command, .control],
                displayName: NSLocalizedString("shortcut.toggle_brightness", comment: "")
            ),
            .increaseJiggleInterval: ShortcutConfig(
                action: .increaseJiggleInterval,
                keyCode: 126,
                modifiers: [.command, .control],
                displayName: NSLocalizedString("shortcut.increase_interval", comment: "")
            ),
            .decreaseJiggleInterval: ShortcutConfig(
                action: .decreaseJiggleInterval,
                keyCode: 125,
                modifiers: [.command, .control],
                displayName: NSLocalizedString("shortcut.decrease_interval", comment: "")
            )
        ]
        saveCustomShortcuts()
    }
    
    // MARK: - 持久化
    
    /// 保存自定义快捷键到 UserDefaults
    private func saveCustomShortcuts() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(shortcuts) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
            print("💾 [ShortcutManager] 已保存自定义快捷键")
        }
    }
    
    /// 从 UserDefaults 加载自定义快捷键
    private func loadCustomShortcuts() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey) {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode([ShortcutAction: ShortcutConfig].self, from: data) {
                shortcuts = decoded
                print("📖 [ShortcutManager] 已加载自定义快捷键")
                return
            }
        }
        print("ℹ️ [ShortcutManager] 使用默认快捷键配置")
    }
}
