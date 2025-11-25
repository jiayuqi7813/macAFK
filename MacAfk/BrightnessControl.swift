import Foundation
import AppKit
import CoreGraphics
import Combine

/// 亮度控制类 - Pro 版本
/// 使用 DisplayServices API 控制内置屏幕，BetterDisplay API 控制外接屏幕
class BrightnessControl: ObservableObject {
    
    // 内置显示器的亮度缓存
    private var previousBrightnessMap: [CGDirectDisplayID: Float] = [:]
    private let displayQueue: DispatchQueue
    
    // DisplayServices 函数指针（用于内置屏幕）
    private var setDisplayBrightness: ((CGDirectDisplayID, Float) -> Int32)?
    private var getDisplayBrightness: ((CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32)?
    
    // BetterDisplay 管理器
    private let betterDisplayManager = BetterDisplayManager.shared
    
    // 用于映射 CGDirectDisplayID 到 BetterDisplay 显示器 UUID
    private var displayUUIDMapping: [CGDirectDisplayID: String] = [:]
    
    init() {
        self.displayQueue = DispatchQueue(label: "com.macafk.brightness")
        self.loadDisplayServices()
        self.updateDisplayMapping()
    }
    
    /// 加载 DisplayServices 框架
    private func loadDisplayServices() {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/Versions/A/DisplayServices"
        guard let handle = dlopen(path, RTLD_LAZY) else {
            print("❌ [亮度控制] 无法加载 DisplayServices 框架")
            return
        }
        
        if let setPtr = dlsym(handle, "DisplayServicesSetBrightness") {
            typealias SetBrightnessFunc = @convention(c) (CGDirectDisplayID, Float) -> Int32
            self.setDisplayBrightness = unsafeBitCast(setPtr, to: SetBrightnessFunc.self)
        }
        
        if let getPtr = dlsym(handle, "DisplayServicesGetBrightness") {
            typealias GetBrightnessFunc = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
            self.getDisplayBrightness = unsafeBitCast(getPtr, to: GetBrightnessFunc.self)
        }
        
        // 检测是否成功加载
        if self.setDisplayBrightness != nil && self.getDisplayBrightness != nil {
            print("✅ [亮度控制] DisplayServices 加载成功（硬件亮度控制）")
        } else {
            print("❌ [亮度控制] DisplayServices 加载失败")
        }
    }
    
    /// 更新显示器 UUID 映射（CGDirectDisplayID -> BetterDisplay UUID）- 异步版本
    func updateDisplayMapping() {
        displayUUIDMapping.removeAll()
        
        print("🔄 [亮度控制] 更新显示器映射...")
        print("   BetterDisplay 状态: 安装=\(betterDisplayManager.isInstalled), 运行=\(betterDisplayManager.isRunning), 启用=\(betterDisplayManager.isEnabled)")
        
        guard betterDisplayManager.isInstalled && betterDisplayManager.isRunning && betterDisplayManager.isEnabled else {
            print("⚠️ [亮度控制] BetterDisplay 未就绪，跳过映射")
            return
        }
        
        // 等待显示器列表刷新
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            let cgDisplays = self.getAllDisplays()
            let bdDisplays = self.betterDisplayManager.displays
            
            print("   CG 显示器数: \(cgDisplays.count), BD 显示器数: \(bdDisplays.count)")
            
            for cgDisplayID in cgDisplays {
                // BetterDisplay 的 displayID 是字符串形式的数字
                let cgDisplayIDString = String(cgDisplayID)
                
                if let bdDisplay = bdDisplays.first(where: { $0.displayID == cgDisplayIDString }),
                   let uuid = bdDisplay.UUID {
                    self.displayUUIDMapping[cgDisplayID] = uuid
                    print("🔗 [亮度控制] 映射显示器: CG=\(cgDisplayID) -> UUID=\(uuid) (\(bdDisplay.name))")
                } else {
                    print("⚠️ [亮度控制] CG 显示器 \(cgDisplayID) 未找到对应的 BD 显示器或 UUID")
                }
            }
        }
    }
    
    /// 更新显示器 UUID 映射 - 同步版本（用于需要立即使用映射的场景）
    private func updateDisplayMappingSync() {
        displayUUIDMapping.removeAll()
        
        guard betterDisplayManager.isInstalled && betterDisplayManager.isRunning && betterDisplayManager.isEnabled else {
            print("⚠️ [亮度控制] BetterDisplay 未就绪，无法建立映射")
            return
        }
        
        // 如果显示器列表为空，先刷新
        if betterDisplayManager.displays.isEmpty {
            print("🔄 [亮度控制] BetterDisplay 显示器列表为空，正在刷新...")
            betterDisplayManager.refreshDisplays()
            // 等待一小段时间让显示器列表更新
            Thread.sleep(forTimeInterval: 0.3)
        }
        
        let cgDisplays = getAllDisplays()
        let bdDisplays = betterDisplayManager.displays
        
        print("🔗 [亮度控制] 同步建立映射 - CG 显示器数: \(cgDisplays.count), BD 显示器数: \(bdDisplays.count)")
        
        for cgDisplayID in cgDisplays {
            let cgDisplayIDString = String(cgDisplayID)
            
            if let bdDisplay = bdDisplays.first(where: { $0.displayID == cgDisplayIDString }),
               let uuid = bdDisplay.UUID {
                displayUUIDMapping[cgDisplayID] = uuid
                print("   🔗 映射: CG=\(cgDisplayID) -> UUID=\(uuid) (\(bdDisplay.name))")
            } else {
                print("   ⚠️ CG 显示器 \(cgDisplayID) 未找到对应的 BD 显示器")
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// 开始抖动时调用：获取并保存当前亮度，成功后设置为指定亮度
    /// - Parameter level: 目标亮度值 (0.0 - 1.0)
    /// - Parameter completion: 完成回调
    func setLowestBrightness(level: Float = 0.0, completion: (() -> Void)? = nil) {
        print("🎯 [亮度控制] 开始设置亮度流程")
        
        // 0. 先检测所有显示器
        let displays = getAllDisplays()
        print("🖥️ [亮度控制] 检测到 \(displays.count) 个显示器: \(displays)")
        
        // 检查每个显示器的类型
        for displayID in displays {
            let isBuiltin = CGDisplayIsBuiltin(displayID) != 0
            print("   显示器 \(displayID): \(isBuiltin ? "内置" : "外接")")
        }
        
        // 对于外接显示器，先确保映射已建立
        let externalDisplays = displays.filter { CGDisplayIsBuiltin($0) == 0 }
        if !externalDisplays.isEmpty {
            print("🔍 [亮度控制] 发现 \(externalDisplays.count) 个外接显示器，检查 BetterDisplay 映射...")
            print("   当前映射表: \(displayUUIDMapping)")
            print("   BetterDisplay 状态: 安装=\(betterDisplayManager.isInstalled), 运行=\(betterDisplayManager.isRunning), 启用=\(betterDisplayManager.isEnabled)")
            print("   BetterDisplay 显示器列表: \(betterDisplayManager.displays.map { "\($0.name)[\($0.displayID ?? "?")]" })")
            
            // 如果映射为空或不完整，先建立映射
            if displayUUIDMapping.isEmpty || externalDisplays.contains(where: { displayUUIDMapping[$0] == nil }) {
                print("⚠️ [亮度控制] 映射不完整，正在建立映射...")
                updateDisplayMappingSync()
            }
        }
        
        let group = DispatchGroup()
        
        // 1. 先获取并保存所有显示器的当前亮度
        for displayID in displays {
            if CGDisplayIsBuiltin(displayID) != 0 {
                // 内置显示器：直接获取并保存
                let brightness = getBuiltinBrightness(displayID: displayID)
                previousBrightnessMap[displayID] = brightness
                print("💾 [亮度控制] 保存内置显示器 \(displayID) 的亮度: \(Int(brightness * 100))%")
            } else {
                // 外接显示器：通过 BetterDisplay 获取并保存
                if let uuid = displayUUIDMapping[displayID] {
                    print("🔍 [亮度控制] 外接显示器 \(displayID) 映射到 UUID: \(uuid)")
                    group.enter()
                    betterDisplayManager.cacheBrightnessByUUID(uuid: uuid) { brightness in
                        if let brightness = brightness {
                            print("💾 [亮度控制] BetterDisplay 保存显示器 \(displayID) (UUID:\(uuid)) 的亮度: \(Int(brightness * 100))%")
                        } else {
                            print("❌ [亮度控制] BetterDisplay 无法获取显示器 \(displayID) (UUID:\(uuid)) 的亮度")
                        }
                        group.leave()
                    }
                } else {
                    print("⚠️ [亮度控制] 外接显示器 \(displayID) 没有找到 UUID 映射，跳过")
                }
            }
        }
        
        // 2. 等待所有亮度获取完成后，再设置为目标亮度
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            print("✅ [亮度控制] 所有亮度已保存，开始设置为目标亮度 \(Int(level * 100))%")
            self.setAllDisplaysBrightness(value: level, completion: completion)
        }
    }
    
    /// 停止抖动时调用：恢复所有显示器的缓存亮度
    /// - Parameter completion: 完成回调
    func restoreBrightness(completion: (() -> Void)? = nil) {
        print("🔄 [亮度控制] 开始恢复亮度流程")
        
        let displays = getAllDisplays()
        let group = DispatchGroup()
        
        for displayID in displays {
            if CGDisplayIsBuiltin(displayID) != 0 {
                // 内置显示器：从缓存恢复
                if let brightness = previousBrightnessMap[displayID] {
                    setBuiltinBrightness(displayID: displayID, value: brightness)
                    print("✅ [亮度控制] 恢复内置显示器 \(displayID) 的亮度: \(Int(brightness * 100))%")
                }
            } else {
                // 外接显示器：通过 BetterDisplay 恢复
                if let uuid = displayUUIDMapping[displayID] {
                    group.enter()
                    betterDisplayManager.restoreCachedBrightnessByUUID(uuid: uuid) { success in
                        if success {
                            print("✅ [亮度控制] BetterDisplay 恢复显示器 \(displayID) (UUID:\(uuid)) 的亮度")
                        }
                        group.leave()
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            print("✅ [亮度控制] 所有显示器亮度已恢复")
            completion?()
        }
    }
    
    /// 直接设置亮度（用于测试和手动调节）
    func setCustomBrightness(level: Float) {
        setAllDisplaysBrightness(value: level, completion: nil)
    }
    
    /// 获取当前亮度（返回主显示器的亮度）
    func getCurrentBrightness() -> Float {
        return getBuiltinBrightness(displayID: CGMainDisplayID())
    }
    
    // MARK: - Private Methods
    
    /// 获取所有在线显示器
    private func getAllDisplays() -> [CGDirectDisplayID] {
        let maxDisplays: UInt32 = 32
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
        var displayCount: UInt32 = 0
        
        let result = CGGetOnlineDisplayList(maxDisplays, &displays, &displayCount)
        
        if result == .success {
            return Array(displays.prefix(Int(displayCount)))
        } else {
            return [CGMainDisplayID()]
        }
    }
    
    /// 设置所有显示器的亮度
    private func setAllDisplaysBrightness(value: Float, completion: (() -> Void)?) {
        let displays = getAllDisplays()
        let clampedValue = max(min(value, 1.0), 0.0)
        let group = DispatchGroup()
        
        print("🎯 [亮度控制] 准备将所有显示器设置为: \(Int(clampedValue * 100))%")
        print("   显示器列表: \(displays)")
        
        for displayID in displays {
            if CGDisplayIsBuiltin(displayID) != 0 {
                // 内置显示器：直接设置
                print("   ➡️ 设置内置显示器 \(displayID)")
                setBuiltinBrightness(displayID: displayID, value: clampedValue)
            } else {
                // 外接显示器：通过 BetterDisplay 设置
                if let uuid = displayUUIDMapping[displayID] {
                    print("   ➡️ 设置外接显示器 \(displayID) (UUID: \(uuid))")
                    group.enter()
                    betterDisplayManager.setBrightnessByUUID(uuid: uuid, brightness: clampedValue) { success in
                        if success {
                            print("   ✅ 外接显示器 \(displayID) 设置成功")
                        } else {
                            print("   ❌ 外接显示器 \(displayID) 设置失败")
                        }
                        group.leave()
                    }
                } else {
                    print("   ⚠️ 外接显示器 \(displayID) 没有 UUID 映射，跳过")
                }
            }
        }
        
        group.notify(queue: .main) {
            print("✅ [亮度控制] 所有显示器设置完成")
            completion?()
        }
    }
    
    /// 获取内置显示器的亮度
    private func getBuiltinBrightness(displayID: CGDirectDisplayID) -> Float {
        guard let getBrightness = self.getDisplayBrightness else {
            return 0.5
        }
        
        var brightness: Float = 0.5
        let result = getBrightness(displayID, &brightness)
        
        if result == 0 {
            return brightness
        } else {
            return 0.5
        }
    }
    
    /// 设置内置显示器的亮度
    private func setBuiltinBrightness(displayID: CGDirectDisplayID, value: Float) {
        guard let setBrightness = self.setDisplayBrightness else {
            print("❌ [亮度控制] DisplayServices 不可用")
            return
        }
        
        let clampedValue = max(min(value, 1.0), 0.0)
        
        displayQueue.sync {
            let result = setBrightness(displayID, clampedValue)
            
            if result == 0 {
                print("✅ [亮度控制] 内置显示器 \(displayID) 成功设置亮度: \(Int(clampedValue * 100))%")
            } else {
                print("❌ [亮度控制] 内置显示器 \(displayID) 设置亮度失败，错误码: \(result)")
            }
        }
    }
}
