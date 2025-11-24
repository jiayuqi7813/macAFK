import Foundation
import ServiceManagement

/// 管理应用开机自启动功能
class LaunchAtLoginHelper {
    
    /// 设置开机自启动
    /// - Parameter enabled: true 表示启用，false 表示禁用
    static func setLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            // macOS 13+ 使用新的 API
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                    print("✅ [LaunchAtLogin] 已启用开机自启动 (macOS 13+)")
                } else {
                    try SMAppService.mainApp.unregister()
                    print("✅ [LaunchAtLogin] 已禁用开机自启动 (macOS 13+)")
                }
            } catch {
                print("❌ [LaunchAtLogin] 设置失败: \(error.localizedDescription)")
            }
        } else {
            // macOS 13 以下使用旧的 API
            let success = SMLoginItemSetEnabled("com.macafk.pro" as CFString, enabled)
            if success {
                print("✅ [LaunchAtLogin] 已\(enabled ? "启用" : "禁用")开机自启动 (macOS 12-)")
            } else {
                print("❌ [LaunchAtLogin] 设置失败 (macOS 12-)")
            }
        }
    }
    
    /// 检查当前是否已设置开机自启动
    /// - Returns: true 表示已启用，false 表示未启用
    static func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            // macOS 13 以下版本，无法直接查询状态
            // 返回 UserDefaults 中保存的值
            return UserDefaults.standard.bool(forKey: "app.launchAtLogin")
        }
    }
}

