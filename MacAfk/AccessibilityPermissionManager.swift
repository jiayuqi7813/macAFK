import Foundation
import AppKit

/// 辅助功能权限管理器
class AccessibilityPermissionManager {
    
    static let shared = AccessibilityPermissionManager()
    
    private init() {}
    
    /// 检查是否已授予辅助功能权限
    func checkAccessibilityPermission() -> Bool {
        let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [checkOptPrompt: false] as CFDictionary
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if accessEnabled {
            print("✅ [权限检查] 辅助功能权限已授予")
        } else {
            print("⚠️ [权限检查] 辅助功能权限未授予")
        }
        
        return accessEnabled
    }
    
    /// 请求辅助功能权限（会弹出系统提示）
    func requestAccessibilityPermission() {
        let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [checkOptPrompt: true] as CFDictionary
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessEnabled {
            print("🔔 [权限请求] 正在请求辅助功能权限...")
            
            // 显示提示对话框
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = NSLocalizedString("permission.accessibility.title", comment: "需要辅助功能权限")
                alert.informativeText = NSLocalizedString("permission.accessibility.message", comment: "MacAfk Pro 需要辅助功能权限来监听全局快捷键和模拟鼠标移动。\n\n请在系统设置中授予权限后重启应用。")
                alert.alertStyle = .warning
                alert.addButton(withTitle: NSLocalizedString("permission.open_settings", comment: "打开系统设置"))
                alert.addButton(withTitle: NSLocalizedString("button.cancel", comment: "取消"))
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    // 打开系统设置 - 隐私与安全性 - 辅助功能
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        } else {
            print("✅ [权限请求] 辅助功能权限已授予")
        }
    }
    
    /// 监控权限状态变化（轮询方式）
    func startMonitoringPermission(onChange: @escaping (Bool) -> Void) {
        var lastStatus = checkAccessibilityPermission()
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            let currentStatus = self.checkAccessibilityPermission()
            if currentStatus != lastStatus {
                print("🔄 [权限监控] 辅助功能权限状态变化: \(lastStatus) -> \(currentStatus)")
                lastStatus = currentStatus
                onChange(currentStatus)
            }
        }
    }
}

