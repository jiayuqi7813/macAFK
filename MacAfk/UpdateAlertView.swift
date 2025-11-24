import SwiftUI

struct UpdateAlertView: View {
    @ObservedObject var updateManager: UpdateManager
    @Binding var isPresented: Bool
    let release: GitHubRelease
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("update.available.title".localized)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(release.tagName)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // 更新内容
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let body = release.body, !body.isEmpty {
                        Text("update.release_notes".localized)
                            .font(.headline)
                        
                        Text(body)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 200)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            
            // 下载状态
            if case .downloading(let progress) = updateManager.updateStatus {
                VStack(spacing: 8) {
                    HStack {
                        Text("update.downloading".localized)
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                )
            }
            
            // 错误信息
            if case .error(let message) = updateManager.updateStatus {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.1))
                )
            }
            
            Divider()
            
            // 按钮
            HStack(spacing: 12) {
                Button {
                    isPresented = false
                } label: {
                    Text("button.cancel".localized)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button {
                    updateManager.openGitHubRelease(url: release.htmlUrl)
                } label: {
                    HStack {
                        Image(systemName: "link")
                        Text("update.open_github".localized)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                if case .downloading = updateManager.updateStatus {
                    Button {
                        updateManager.cancelDownload()
                    } label: {
                        Text("update.cancel_download".localized)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else if case .error = updateManager.updateStatus {
                    Button {
                        updateManager.downloadAndInstall(release: release)
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("update.retry".localized)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        updateManager.downloadAndInstall(release: release)
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("update.download_install".localized)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(24)
        .frame(width: 550, height: 450)
    }
}

