import Foundation
import AppKit
import CoreGraphics
import Combine

/// 亮度控制类 - Pro 版本
/// 使用 DisplayServices API 直接控制硬件亮度
/// 需要禁用 App Sandbox
class BrightnessControl: ObservableObject {
    
    private var previousBrightness: Float = 0.5
    private let displayQueue: DispatchQueue
    
    // DisplayServices 函数指针
    private var setDisplayBrightness: ((CGDirectDisplayID, Float) -> Int32)?
    private var getDisplayBrightness: ((CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32)?
    
    init() {
        self.displayQueue = DispatchQueue(label: "com.macafk.brightness")
        self.loadDisplayServices()
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
    
    // MARK: - Public Methods
    
    func setLowestBrightness() {
        previousBrightness = getAppleBrightness()
        setAppleBrightness(value: 0.01)
    }
    
    func restoreBrightness() {
        setAppleBrightness(value: previousBrightness)
    }
    
    /// 直接设置亮度（用于测试和手动调节）
    func setCustomBrightness(level: Float) {
        setAppleBrightness(value: level)
    }
    
    /// 获取当前亮度
    func getCurrentBrightness() -> Float {
        return getAppleBrightness()
    }
    
    // MARK: - Private Methods
    
    /// 获取 Apple 显示器亮度
    private func getAppleBrightness() -> Float {
        guard let getBrightness = self.getDisplayBrightness else {
            print("⚠️ [亮度控制] DisplayServices 不可用，返回默认值")
            return previousBrightness
        }
        
        var brightness: Float = 0.5
        let result = getBrightness(CGMainDisplayID(), &brightness)
        
        if result == 0 {
            return brightness
        } else {
            print("⚠️ [亮度控制] 获取亮度失败，错误码: \(result)")
            return previousBrightness
        }
    }
    
    /// 设置 Apple 显示器亮度
    private func setAppleBrightness(value: Float) {
        let clampedValue = max(min(value, 1.0), 0.0)
        
        self.displayQueue.sync {
            guard let setBrightness = self.setDisplayBrightness else {
                print("❌ [亮度控制] DisplayServices 不可用")
                return
            }
            
            let result = setBrightness(CGMainDisplayID(), clampedValue)
            
            if result == 0 {
                print("✅ [亮度控制] 设置亮度: \(Int(clampedValue * 100))%")
            } else {
                print("❌ [亮度控制] 设置亮度失败，错误码: \(result)")
            }
        }
    }
}
