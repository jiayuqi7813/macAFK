import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var showRestartAlert = false
    @State private var previewBrightness: Float = 0.0
    @State private var isPreviewing = false
    @StateObject private var updateManager = UpdateManager.shared
    @State private var showUpdateAlert = false
    @State private var latestRelease: GitHubRelease?
    
    var body: some View {
        VStack(spacing: 0) {
            titleBar
            Divider()
            contentScrollView
            Divider()
            bottomBar
        }
        .frame(width: 500, height: 550)
        .onDisappear {
            if isPreviewing {
                appModel.brightnessControl.restoreBrightness()
                isPreviewing = false
            }
        }
        .onAppear {
            previewBrightness = appModel.lowBrightnessLevel
        }
        .alert("menu.language.restart_required".localized, isPresented: $showRestartAlert) {
            Button("button.done".localized) {
                showRestartAlert = false
            }
        } message: {
            Text("menu.language.restart_required".localized)
        }
        .sheet(isPresented: $showUpdateAlert) {
            if let release = latestRelease {
                UpdateAlertView(updateManager: updateManager, isPresented: $showUpdateAlert, release: release)
            }
        }
        .onChange(of: updateManager.updateStatus) { _, newStatus in
            if case .available(let release) = newStatus {
                latestRelease = release
                showUpdateAlert = true
            }
        }
    }
    
    // MARK: - Title Bar
    
    private var titleBar: some View {
        HStack {
            Text("menu.preferences".localized)
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.title2)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - Content Scroll View
    
    private var contentScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                brightnessSection
                languageSection
                updateSection
            }
            .padding()
        }
    }
    
    // MARK: - Brightness Section
    
    private var brightnessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sun.max.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
                
                Text("settings.low_brightness".localized)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                brightnessLevelRow
                brightnessSlider
                brightnessPreviewButtons
                brightnessHint
            }
            .padding(.leading, 32)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
    
    private var brightnessLevelRow: some View {
        HStack {
            Text("settings.brightness_level".localized)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text("\(Int(appModel.lowBrightnessLevel * 100))%")
                .foregroundColor(.secondary)
                .font(.system(.body, design: .monospaced))
        }
    }
    
    private var brightnessSlider: some View {
        VStack(alignment: .leading, spacing: 8) {
            Slider(value: Binding(
                get: { appModel.lowBrightnessLevel },
                set: { newValue in
                    appModel.lowBrightnessLevel = newValue
                    if isPreviewing {
                        previewBrightness = newValue
                        appModel.brightnessControl.setCustomBrightness(level: newValue)
                    }
                }
            ), in: 0...1)
            .accentColor(.orange)
            
            HStack {
                Text("0%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("100%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var brightnessPreviewButtons: some View {
        HStack(spacing: 12) {
            Button {
                if isPreviewing {
                    appModel.brightnessControl.restoreBrightness()
                    isPreviewing = false
                } else {
                    previewBrightness = appModel.lowBrightnessLevel
                    appModel.brightnessControl.setLowestBrightness(level: appModel.lowBrightnessLevel)
                    isPreviewing = true
                }
            } label: {
                HStack {
                    Image(systemName: isPreviewing ? "eye.slash.fill" : "eye.fill")
                    Text(isPreviewing ? "settings.stop_preview".localized : "settings.preview_brightness".localized)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            
            if isPreviewing {
                Button {
                    appModel.brightnessControl.restoreBrightness()
                    isPreviewing = false
                } label: {
                    Text("settings.restore_brightness".localized)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
    }
    
    private var brightnessHint: some View {
        Text("settings.brightness_preview_hint".localized)
            .font(.caption)
            .foregroundColor(.secondary)
    }
    
    // MARK: - Language Section
    
    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.blue)
                    .font(.title3)
                
                Text("menu.language".localized)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    languageButton(for: language)
                }
            }
            .padding(.leading, 32)
            
            Text("menu.language.restart_required".localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 32)
                .padding(.top, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
    
    private func languageButton(for language: AppLanguage) -> some View {
        Button(action: {
            if languageManager.currentLanguage != language {
                languageManager.setLanguage(language)
                showRestartAlert = true
            }
        }) {
            HStack {
                Image(systemName: languageManager.currentLanguage == language ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(languageManager.currentLanguage == language ? .blue : .secondary)
                
                Text(language.localizedDisplayName)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(languageManager.currentLanguage == language ? Color.blue.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Update Section
    
    private var updateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(.green)
                    .font(.title3)
                
                Text("update.check_for_updates".localized)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                currentVersionRow
                updateStatusView
                checkUpdateButton
            }
            .padding(.leading, 32)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
    
    private var currentVersionRow: some View {
        HStack {
            Text("update.current_version".localized)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(getCurrentVersion())
                .foregroundColor(.secondary)
                .font(.system(.body, design: .monospaced))
        }
    }
    
    @ViewBuilder
    private var updateStatusView: some View {
        switch updateManager.updateStatus {
        case .checking:
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                    .controlSize(.small)
                Text("update.checking".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            
        case .upToDate:
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("update.up_to_date".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            
        case .available(let release):
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.blue)
                Text("update.new_version_available".localized + ": \(release.tagName)")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .padding(.vertical, 4)
            
        case .error(let message):
            HStack(alignment: .top) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            
        default:
            EmptyView()
        }
    }
    
    private var checkUpdateButton: some View {
        Button {
            updateManager.checkForUpdates(silent: false)
        } label: {
            HStack {
                Image(systemName: "arrow.clockwise")
                Text("update.check_now".localized)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .disabled(isCheckingUpdate)
    }
    
    // MARK: - Bottom Bar
    
    private var bottomBar: some View {
        HStack {
            Spacer()
            
            Button("button.done".localized) {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentVersion() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return "v\(version)"
        }
        return "v1.0.0"
    }
    
    private var isCheckingUpdate: Bool {
        if case .checking = updateManager.updateStatus {
            return true
        }
        return false
    }
}
