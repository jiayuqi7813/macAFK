import Foundation
import Combine
import AppKit

/// BetterDisplay 通知请求数据结构
struct IntegrationNotificationRequestData: Codable {
    var uuid: String?
    var commands: [String] = []
    var parameters: [String: String?] = [:]
}

/// BetterDisplay 通知响应数据结构
struct IntegrationNotificationResponseData: Codable {
    var uuid: String?
    var result: Bool?
    var payload: String?
}

/// BetterDisplay 显示器信息
struct BetterDisplayInfo: Codable, Identifiable {
    let UUID: String?
    let alphanumericSerial: String?
    let deviceType: String
    let displayID: String?
    let model: String?
    let name: String
    let originalName: String?
    let productName: String?
    let registryLocation: String?
    let serial: String?
    let tagID: String
    let vendor: String?
    let weekOfManufacture: String?
    let yearOfManufacture: String?
    
    var id: String { UUID ?? tagID }
    
    /// 是否是显示器组
    var isDisplayGroup: Bool {
        deviceType == "DisplayGroup"
    }
    
    /// 是否是物理显示器
    var isPhysicalDisplay: Bool {
        deviceType == "Display"
    }
}

/// BetterDisplay 集成管理器
class BetterDisplayManager: ObservableObject {
    static let shared = BetterDisplayManager()
    
    @Published var isInstalled: Bool = false
    @Published var isRunning: Bool = false
    @Published var isEnabled: Bool = false
    @Published var displays: [BetterDisplayInfo] = []
    
    private let appPath = "/Applications/BetterDisplay.app"
    private let appBundleIdentifier = "me.waydabber.BetterDisplay"
    private let requestNotificationName = "com.betterdisplay.BetterDisplay.request"
    private let responseNotificationName = "com.betterdisplay.BetterDisplay.response"
    private let userDefaultsKey = "useBetterDisplay"
    
    private var responseObserver: Any?
    private var pendingRequests: [String: (Bool, String?) -> Void] = [:]
    
    // 缓存的亮度值（UUID -> 亮度）
    private var cachedBrightness: [String: Float] = [:]
    
    private init() {
        setupNotificationObserver()
        checkInstallation()
        checkIfRunning()
        loadEnabledState()
        
        if isInstalled && isRunning && isEnabled {
            refreshDisplays()
        }
    }
    
    deinit {
        if let observer = responseObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }
    
    // MARK: - Notification Observer
    
    /// 设置通知监听器
    private func setupNotificationObserver() {
        responseObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(responseNotificationName),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleResponse(notification)
        }
    }
    
    /// 处理 BetterDisplay 响应
    private func handleResponse(_ notification: Notification) {
        guard let jsonString = notification.object as? String,
              let jsonData = jsonString.data(using: .utf8) else {
            return
        }
        
        do {
            let response = try JSONDecoder().decode(IntegrationNotificationResponseData.self, from: jsonData)
            
            if let uuid = response.uuid, let completion = pendingRequests[uuid] {
                completion(response.result ?? false, response.payload)
                pendingRequests.removeValue(forKey: uuid)
            }
        } catch {
            print("❌ [BetterDisplay] JSON 解析失败: \(error)")
        }
    }
    
    // MARK: - Installation Detection
    
    /// 检查 BetterDisplay 是否已安装
    func checkInstallation() {
        let fileManager = FileManager.default
        isInstalled = fileManager.fileExists(atPath: appPath)
    }
    
    /// 检查 BetterDisplay 进程是否在运行
    func checkIfRunning() {
        let runningApps = NSWorkspace.shared.runningApplications
        
        for app in runningApps {
            if let bundleId = app.bundleIdentifier {
                if bundleId == appBundleIdentifier || 
                   bundleId.contains("BetterDisplay") ||
                   bundleId.hasPrefix("me.waydabber") {
                    isRunning = true
                    return
                }
            }
            
            if let appName = app.localizedName, appName.contains("BetterDisplay") {
                isRunning = true
                return
            }
            
            if let url = app.bundleURL, url.path.contains("BetterDisplay.app") {
                isRunning = true
                return
            }
        }
        
        isRunning = false
    }
    
    /// 测试与 BetterDisplay 的连通性
    func testConnection(completion: @escaping (Bool) -> Void) {
        checkInstallation()
        checkIfRunning()
        
        guard isInstalled else {
            completion(false)
            return
        }
        
        guard isRunning else {
            completion(false)
            return
        }
        
        let uuid = UUID().uuidString
        let requestData = IntegrationNotificationRequestData(
            uuid: uuid,
            commands: ["get"],
            parameters: ["identifiers": nil]
        )
        
        var hasResponded = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            if !hasResponded {
                self?.pendingRequests.removeValue(forKey: uuid)
                completion(false)
            }
        }
        
        pendingRequests[uuid] = { [weak self] success, _ in
            guard !hasResponded else { return }
            hasResponded = true
            
            if success {
                self?.isRunning = true
            }
            completion(success)
        }
        
        sendNotificationRequest(requestData)
    }
    
    // MARK: - Notification Request
    
    /// 发送通知请求到 BetterDisplay
    private func sendNotificationRequest(_ requestData: IntegrationNotificationRequestData) {
        do {
            let encodedData = try JSONEncoder().encode(requestData)
            if let jsonString = String(data: encodedData, encoding: .utf8) {
                DistributedNotificationCenter.default().postNotificationName(
                    NSNotification.Name(requestNotificationName),
                    object: jsonString,
                    userInfo: nil,
                    deliverImmediately: true
                )
            }
        } catch {
            print("❌ [BetterDisplay] 编码请求失败: \(error)")
        }
    }
    
    // MARK: - Enable/Disable
    
    /// 加载启用状态
    private func loadEnabledState() {
        isEnabled = UserDefaults.standard.bool(forKey: userDefaultsKey)
    }
    
    /// 设置启用状态
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: userDefaultsKey)
        
        if enabled && isInstalled {
            refreshDisplays()
        } else {
            displays = []
        }
    }
    
    // MARK: - Display List
    
    /// 刷新显示器列表
    func refreshDisplays() {
        guard isInstalled && isRunning else {
            return
        }
        
        let uuid = UUID().uuidString
        let requestData = IntegrationNotificationRequestData(
            uuid: uuid,
            commands: ["get"],
            parameters: ["identifiers": nil]
        )
        
        pendingRequests[uuid] = { [weak self] success, payload in
            if success, let payload = payload {
                self?.parseDisplaysJSON(payload)
            }
        }
        
        sendNotificationRequest(requestData)
    }
    
    /// 解析显示器 JSON 数据
    private func parseDisplaysJSON(_ jsonString: String) {
        let wrappedJSON = "[" + jsonString.replacingOccurrences(of: "}{", with: "},{") + "]"
        
        guard let wrappedData = wrappedJSON.data(using: .utf8) else {
            return
        }
        
        let decoder = JSONDecoder()
        do {
            let allDisplays = try decoder.decode([BetterDisplayInfo].self, from: wrappedData)
            DispatchQueue.main.async {
                self.displays = allDisplays.filter { $0.isPhysicalDisplay }
            }
        } catch {
            print("❌ [BetterDisplay] JSON 解析失败: \(error)")
        }
    }
    
    // MARK: - 亮度控制核心方法
    
    /// 获取显示器当前亮度并保存到缓存（通过 UUID）
    /// - Parameters:
    ///   - uuid: 显示器 UUID
    ///   - completion: 完成回调，返回获取到的亮度值（成功）或 nil（失败）
    func cacheBrightnessByUUID(uuid: String, completion: @escaping (Float?) -> Void) {
        guard isInstalled && isRunning && isEnabled else {
            print("⚠️ [BetterDisplay] 未就绪，无法获取亮度")
            completion(nil)
            return
        }
        
        let requestUUID = UUID().uuidString
        let requestData = IntegrationNotificationRequestData(
            uuid: requestUUID,
            commands: ["get"],
            parameters: [
                "uuid": uuid,
                "feature": "brightness"
            ]
        )
        
        pendingRequests[requestUUID] = { [weak self] result, payload in
            guard result, let payload = payload else {
                print("❌ [BetterDisplay] 获取显示器 UUID:\(uuid) 亮度失败")
                completion(nil)
                return
            }
            
            if let value = Float(payload.trimmingCharacters(in: .whitespacesAndNewlines)) {
                self?.cachedBrightness[uuid] = value
                print("💾 [BetterDisplay] 已缓存显示器 UUID:\(uuid) 亮度: \(Int(value * 100))%")
                completion(value)
            } else {
                print("❌ [BetterDisplay] 无法解析亮度值: \(payload)")
                completion(nil)
            }
        }
        
        sendNotificationRequest(requestData)
    }
    
    /// 设置显示器亮度（通过 UUID）
    /// - Parameters:
    ///   - uuid: 显示器 UUID
    ///   - brightness: 亮度值 (0.0 - 1.0)
    ///   - completion: 完成回调，返回是否成功
    func setBrightnessByUUID(uuid: String, brightness: Float, completion: @escaping (Bool) -> Void) {
        guard isInstalled && isRunning && isEnabled else {
            print("⚠️ [BetterDisplay] 未就绪，无法设置亮度")
            completion(false)
            return
        }
        
        let clampedBrightness = max(0.0, min(1.0, brightness))
        
        let requestUUID = UUID().uuidString
        let requestData = IntegrationNotificationRequestData(
            uuid: requestUUID,
            commands: ["set"],
            parameters: [
                "uuid": uuid,
                "brightness": String(format: "%.2f", clampedBrightness)
            ]
        )
        
        pendingRequests[requestUUID] = { result, _ in
            if result {
                print("✅ [BetterDisplay] 显示器 UUID:\(uuid) 亮度已设置为 \(Int(clampedBrightness * 100))%")
            } else {
                print("❌ [BetterDisplay] 显示器 UUID:\(uuid) 设置亮度失败")
            }
            completion(result)
        }
        
        sendNotificationRequest(requestData)
    }
    
    /// 恢复显示器缓存的亮度（通过 UUID）
    /// - Parameters:
    ///   - uuid: 显示器 UUID
    ///   - completion: 完成回调，返回是否成功
    func restoreCachedBrightnessByUUID(uuid: String, completion: @escaping (Bool) -> Void) {
        guard let cachedValue = cachedBrightness[uuid] else {
            print("⚠️ [BetterDisplay] 未找到显示器 UUID:\(uuid) 的缓存亮度")
            completion(false)
            return
        }
        
        print("🔄 [BetterDisplay] 恢复显示器 UUID:\(uuid) 的缓存亮度: \(Int(cachedValue * 100))%")
        setBrightnessByUUID(uuid: uuid, brightness: cachedValue, completion: completion)
    }
    
    /// 清除缓存的亮度值
    func clearCachedBrightness() {
        cachedBrightness.removeAll()
        print("🗑️ [BetterDisplay] 已清除所有缓存亮度")
    }
}
