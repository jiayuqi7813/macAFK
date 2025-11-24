import Foundation
import SwiftUI
import Combine

/// GitHub Release 信息
struct GitHubRelease: Codable, Equatable {
    let tagName: String
    let name: String
    let body: String?
    let htmlUrl: String
    let assets: [GitHubAsset]
    let publishedAt: String
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case assets
        case publishedAt = "published_at"
    }
}

/// GitHub Asset 信息
struct GitHubAsset: Codable, Equatable {
    let name: String
    let browserDownloadUrl: String
    let size: Int
    
    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
    }
}

/// 更新状态
enum UpdateStatus: Equatable {
    case idle
    case checking
    case available(GitHubRelease)
    case upToDate
    case downloading(Double) // 下载进度 0-1
    case installing
    case error(String)
    
    static func == (lhs: UpdateStatus, rhs: UpdateStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.checking, .checking),
             (.upToDate, .upToDate),
             (.installing, .installing):
            return true
        case (.available(let lRelease), .available(let rRelease)):
            return lRelease.tagName == rRelease.tagName
        case (.downloading(let lProgress), .downloading(let rProgress)):
            return lProgress == rProgress
        case (.error(let lMsg), .error(let rMsg)):
            return lMsg == rMsg
        default:
            return false
        }
    }
}

/// 更新管理器
class UpdateManager: ObservableObject {
    static let shared = UpdateManager()
    
    @Published var updateStatus: UpdateStatus = .idle
    @Published var showUpdateAlert = false
    
    // GitHub 仓库信息
    private let githubOwner = "jiayuqi7813"
    private let githubRepo = "macAFK-Pro"
    private let currentVersion: String
    
    private var downloadTask: URLSessionDownloadTask?
    
    init() {
        // 获取当前版本号
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            self.currentVersion = version
        } else {
            self.currentVersion = "1.0.0"
        }
    }
    
    /// 检查更新
    func checkForUpdates(silent: Bool = false) {
        updateStatus = .checking
        
        let urlString = "https://api.github.com/repos/\(githubOwner)/\(githubRepo)/releases/latest"
        guard let url = URL(string: urlString) else {
            updateStatus = .error("update.error.invalid_url".localized)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    self.updateStatus = .error("update.error.network".localized + ": \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    self.updateStatus = .error("update.error.no_data".localized)
                    return
                }
                
                do {
                    let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                    
                    // 比较版本号
                    if self.isNewerVersion(release.tagName, than: self.currentVersion) {
                        self.updateStatus = .available(release)
                        self.showUpdateAlert = true
                    } else {
                        self.updateStatus = .upToDate
                        if !silent {
                            // 非静默模式下显示已是最新版本的提示
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                self.updateStatus = .idle
                            }
                        }
                    }
                } catch {
                    self.updateStatus = .error("update.error.parse".localized + ": \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    /// 下载并安装更新
    func downloadAndInstall(release: GitHubRelease) {
        // 根据当前架构选择合适的安装包
        let architecture = self.getCurrentArchitecture()
        
        guard let asset = self.selectAsset(from: release.assets, for: architecture) else {
            updateStatus = .error("update.error.no_compatible_asset".localized)
            return
        }
        
        guard let url = URL(string: asset.browserDownloadUrl) else {
            updateStatus = .error("update.error.invalid_download_url".localized)
            return
        }
        
        updateStatus = .downloading(0)
        
        let session = URLSession(configuration: .default, delegate: DownloadDelegate(updateManager: self), delegateQueue: nil)
        downloadTask = session.downloadTask(with: url)
        downloadTask?.resume()
    }
    
    /// 取消下载
    func cancelDownload() {
        downloadTask?.cancel()
        updateStatus = .idle
    }
    
    /// 打开 GitHub Release 页面
    func openGitHubRelease(url: String) {
        if let url = URL(string: url) {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Private Methods
    
    /// 比较版本号
    private func isNewerVersion(_ newVersion: String, than currentVersion: String) -> Bool {
        let new = newVersion.replacingOccurrences(of: "v", with: "").split(separator: ".").compactMap { Int($0) }
        let current = currentVersion.split(separator: ".").compactMap { Int($0) }
        
        for i in 0..<max(new.count, current.count) {
            let newPart = i < new.count ? new[i] : 0
            let currentPart = i < current.count ? current[i] : 0
            
            if newPart > currentPart {
                return true
            } else if newPart < currentPart {
                return false
            }
        }
        
        return false
    }
    
    /// 获取当前系统架构
    private func getCurrentArchitecture() -> String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "universal"
        #endif
    }
    
    /// 从资源列表中选择合适的安装包
    private func selectAsset(from assets: [GitHubAsset], for architecture: String) -> GitHubAsset? {
        // 优先选择匹配当前架构的 DMG
        if let asset = assets.first(where: { $0.name.contains(architecture) && $0.name.hasSuffix(".dmg") }) {
            return asset
        }
        
        // 其次选择 Universal 版本
        if let asset = assets.first(where: { $0.name.contains("Universal") && $0.name.hasSuffix(".dmg") }) {
            return asset
        }
        
        // 最后选择任意 DMG
        return assets.first(where: { $0.name.hasSuffix(".dmg") })
    }
    
    /// 安装下载的 DMG
    fileprivate func installDMG(at localURL: URL) {
        updateStatus = .installing
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 在 Finder 中显示下载的文件
            DispatchQueue.main.async {
                NSWorkspace.shared.activateFileViewerSelecting([localURL])
                
                // 提示用户手动安装
                let alert = NSAlert()
                alert.messageText = "update.install.manual.title".localized
                alert.informativeText = "update.install.manual.message".localized
                alert.alertStyle = .informational
                alert.addButton(withTitle: "button.done".localized)
                alert.runModal()
                
                self.updateStatus = .idle
            }
        }
    }
}

// MARK: - Download Delegate

class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    weak var updateManager: UpdateManager?
    
    init(updateManager: UpdateManager) {
        self.updateManager = updateManager
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // 将文件移动到下载文件夹
        let fileManager = FileManager.default
        let downloadsURL = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let fileName = downloadTask.response?.suggestedFilename ?? "MacAfk-Pro.dmg"
        let destinationURL = downloadsURL.appendingPathComponent(fileName)
        
        do {
            // 如果文件已存在，先删除
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            try fileManager.moveItem(at: location, to: destinationURL)
            
            DispatchQueue.main.async {
                self.updateManager?.installDMG(at: destinationURL)
            }
        } catch {
            DispatchQueue.main.async {
                self.updateManager?.updateStatus = .error("update.error.save_file".localized + ": \(error.localizedDescription)")
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        DispatchQueue.main.async {
            self.updateManager?.updateStatus = .downloading(progress)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.updateManager?.updateStatus = .error("update.error.download".localized + ": \(error.localizedDescription)")
            }
        }
    }
}

