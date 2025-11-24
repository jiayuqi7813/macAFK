import Foundation
import SwiftUI
import Combine

class AppModel: ObservableObject {
    @Published var isJiggling = false
    @Published var isLowBrightness = false {
        didSet {
            if !isLoading {
                saveLowBrightnessMode()
            }
        }
    }
    @Published var lowBrightnessLevel: Float = 0.0 {  // 低亮度模式的亮度值（0.0 - 1.0）
        didSet {
            if !isLoading {
                saveLowBrightnessLevel()
            }
        }
    }
    @Published var testBrightness: Float = 0.5  // 测试用的亮度值（0.0 - 1.0）
    @Published var launchAtLogin = false {
        didSet {
            if !isLoading {
                saveLaunchAtLogin()
                LaunchAtLoginHelper.setLaunchAtLogin(enabled: launchAtLogin)
            }
        }
    }
    
    // 子对象：使用普通属性 + Combine 订阅
    let jiggler = Jiggler()
    let brightnessControl = BrightnessControl()
    let shortcutManager = ShortcutManager()
    
    // Combine 订阅
    private var cancellables = Set<AnyCancellable>()
    
    // 持久化相关
    private let lowBrightnessKey = "app.lowBrightnessMode"
    private let lowBrightnessLevelKey = "app.lowBrightnessLevel"
    private let launchAtLoginKey = "app.launchAtLogin"
    private var isLoading = false
    
    init() {
        loadLowBrightnessMode()
        loadLowBrightnessLevel()
        loadLaunchAtLogin()
        // 订阅 jiggler 的变化，转发给 AppModel
        jiggler.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        
        // 订阅 shortcutManager 的变化，转发给 AppModel
        shortcutManager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        
        // 设置快捷键回调
        shortcutManager.onAction = { [weak self] action in
            DispatchQueue.main.async {
                self?.handleShortcutAction(action)
            }
        }
        shortcutManager.startListening()
    }
    
    // MARK: - 快捷键动作处理
    
    /// 处理快捷键动作
    private func handleShortcutAction(_ action: ShortcutAction) {
        switch action {
        case .toggleJiggle:
            toggleJiggle()
            
        case .toggleBrightness:
            toggleBrightnessMode()
            
        case .increaseJiggleInterval:
            jiggler.increaseInterval()
            
        case .decreaseJiggleInterval:
            jiggler.decreaseInterval()
        }
    }
    
    func toggleJiggle() {
        isJiggling.toggle()
        if isJiggling {
            jiggler.start()
            if isLowBrightness {
                brightnessControl.setLowestBrightness(level: lowBrightnessLevel)
            }
        } else {
            jiggler.stop()
            if isLowBrightness {
                brightnessControl.restoreBrightness()
            }
        }
        
        // 通知 AppDelegate 状态已改变
        NotificationCenter.default.post(name: NSNotification.Name("AppModelStateChanged"), object: nil)
    }
    
    func toggleBrightnessMode() {
        isLowBrightness.toggle()
        // 立即应用亮度变化（如果正在运行）
        if isJiggling {
            if isLowBrightness {
                brightnessControl.setLowestBrightness(level: lowBrightnessLevel)
            } else {
                brightnessControl.restoreBrightness()
            }
        }
        
        // 通知 AppDelegate 状态已改变
        NotificationCenter.default.post(name: NSNotification.Name("AppModelStateChanged"), object: nil)
    }
    
    // MARK: - 低亮度模式切换（支持快捷键）
    
    /// 切换低亮度模式（带通知）
    func toggleBrightnessModeWithNotification() {
        toggleBrightnessMode()
        
        // 可选：显示通知
        let message = isLowBrightness ? NSLocalizedString("message.low_brightness_enabled", comment: "") : NSLocalizedString("message.low_brightness_disabled", comment: "")
        print("ℹ️ \(message)")
    }
    
    /// 设置测试亮度（用于滑块测试）
    func setTestBrightness(_ value: Float) {
        testBrightness = value
        brightnessControl.setCustomBrightness(level: value)
    }
    
    /// 重置亮度为系统值
    func resetBrightness() {
        let currentBrightness = brightnessControl.getCurrentBrightness()
        testBrightness = currentBrightness
        print("🔄 [AppModel] 重置亮度为: \(currentBrightness)")
    }
    
    // MARK: - 持久化
    
    /// 保存低亮度模式状态到 UserDefaults
    private func saveLowBrightnessMode() {
        UserDefaults.standard.set(isLowBrightness, forKey: lowBrightnessKey)
        print("💾 [AppModel] 已保存低亮度模式状态: \(isLowBrightness)")
    }
    
    /// 从 UserDefaults 加载低亮度模式状态
    private func loadLowBrightnessMode() {
        isLoading = true
        defer { isLoading = false }
        
        let savedValue = UserDefaults.standard.bool(forKey: lowBrightnessKey)
        isLowBrightness = savedValue
        print("📖 [AppModel] 已加载低亮度模式状态: \(isLowBrightness)")
    }
    
    /// 保存低亮度级别到 UserDefaults
    private func saveLowBrightnessLevel() {
        UserDefaults.standard.set(lowBrightnessLevel, forKey: lowBrightnessLevelKey)
        print("💾 [AppModel] 已保存低亮度级别: \(Int(lowBrightnessLevel * 100))%")
    }
    
    /// 从 UserDefaults 加载低亮度级别
    private func loadLowBrightnessLevel() {
        isLoading = true
        defer { isLoading = false }
        
        let savedValue = UserDefaults.standard.float(forKey: lowBrightnessLevelKey)
        // 如果没有保存的值（首次启动），使用默认值 0.0
        lowBrightnessLevel = savedValue == 0 && !UserDefaults.standard.dictionaryRepresentation().keys.contains(lowBrightnessLevelKey) ? 0.0 : savedValue
        print("📖 [AppModel] 已加载低亮度级别: \(Int(lowBrightnessLevel * 100))%")
    }
    
    /// 保存开机自启动状态到 UserDefaults
    private func saveLaunchAtLogin() {
        UserDefaults.standard.set(launchAtLogin, forKey: launchAtLoginKey)
        print("💾 [AppModel] 已保存开机自启动状态: \(launchAtLogin)")
    }
    
    /// 从 UserDefaults 加载开机自启动状态
    private func loadLaunchAtLogin() {
        isLoading = true
        defer { isLoading = false }
        
        let savedValue = UserDefaults.standard.bool(forKey: launchAtLoginKey)
        launchAtLogin = savedValue
        print("📖 [AppModel] 已加载开机自启动状态: \(launchAtLogin)")
    }
}
