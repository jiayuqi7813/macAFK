import SwiftUI
import AppKit

enum SettingsTab: String, CaseIterable, Identifiable {
    case displays = "显示设置"
    case general = "常规设置"
    case language = "语言"
    case update = "更新"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .displays: return "display.2"
        case .general: return "gearshape.fill"
        case .language: return "globe"
        case .update: return "arrow.down.circle"
        }
    }
    
    var localizedKey: String {
        switch self {
        case .displays: return "settings.displays"
        case .general: return "settings.general"
        case .language: return "menu.language"
        case .update: return "update.check_for_updates"
        }
    }
}

struct NewPreferencesView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: SettingsTab = .displays
    @State private var selectedDisplay: BetterDisplayInfo?
    @State private var showRestartAlert = false
    @State private var previewBrightness: Float = 0.0
    @State private var isPreviewing = false
    @StateObject private var updateManager = UpdateManager.shared
    @StateObject private var betterDisplayManager = BetterDisplayManager.shared
    @State private var showUpdateAlert = false
    @State private var latestRelease: GitHubRelease?
    
    // 显示器测试状态
    @State private var testBrightness: Float = 0.5
    @State private var currentBrightness: Float? = nil
    @State private var testMessage: String = ""
    @State private var isTestingBrightness = false
    
    var body: some View {
        VStack(spacing: 0) {
            titleBar
            Divider()
            
            HStack(spacing: 0) {
                // 左侧侧边栏
                sidebar
                    .frame(width: 200)
                
                Divider()
                
                // 右侧内容区
                contentArea
            }
            
            Divider()
            bottomBar
        }
        .frame(width: 800, height: 600)
        .onAppear {
            previewBrightness = appModel.lowBrightnessLevel
            betterDisplayManager.checkInstallation()
            if betterDisplayManager.isInstalled && betterDisplayManager.isEnabled {
                betterDisplayManager.refreshDisplays()
            }
        }
        .onDisappear {
            if isPreviewing {
                appModel.brightnessControl.restoreBrightness()
                isPreviewing = false
            }
        }
        .alert("menu.language.restart_required".localized, isPresented: $showRestartAlert) {
            Button("button.done".localized) {
                showRestartAlert = false
            }
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
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                    if tab == .displays {
                        selectedDisplay = nil
                    }
                }) {
                    HStack {
                        Image(systemName: tab.icon)
                            .foregroundColor(selectedTab == tab ? .white : .primary)
                            .frame(width: 20)
                        
                        Text(tab.localizedKey.localized)
                            .foregroundColor(selectedTab == tab ? .white : .primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        selectedTab == tab ? Color.accentColor : Color.clear
                    )
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Content Area
    
    private var contentArea: some View {
        Group {
            switch selectedTab {
            case .displays:
                displaysContent
            case .general:
                generalContent
            case .language:
                languageContent
            case .update:
                updateContent
            }
        }
    }
    
    // MARK: - Displays Content
    
    private var displaysContent: some View {
        HStack(spacing: 0) {
            // 显示器列表
            displaysList
                .frame(width: 250)
            
            Divider()
            
            // 显示器详情
            displayDetail
        }
    }
    
    private var displaysList: some View {
        VStack(alignment: .leading, spacing: 0) {
            // BetterDisplay 状态
            VStack(alignment: .leading, spacing: 12) {
                Text("betterdisplay.title".localized)
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 16)
                
                if betterDisplayManager.isInstalled {
                    VStack(alignment: .leading, spacing: 8) {
                        // 运行状态指示
                        HStack {
                            Circle()
                                .fill(betterDisplayManager.isRunning ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text((betterDisplayManager.isRunning ? "betterdisplay.running" : "betterdisplay.not_running").localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Toggle("betterdisplay.enable_integration".localized, isOn: Binding(
                            get: { betterDisplayManager.isEnabled },
                            set: { newValue in
                                betterDisplayManager.setEnabled(newValue)
                                appModel.brightnessControl.updateDisplayMapping()
                                if newValue {
                                    betterDisplayManager.testConnection { success in
                                        if success {
                                            betterDisplayManager.refreshDisplays()
                                        }
                                    }
                                }
                            }
                        ))
                        .toggleStyle(.switch)
                        .disabled(!betterDisplayManager.isRunning)
                        
                        // 测试连接按钮
                        Button {
                            betterDisplayManager.testConnection { success in
                                if success {
                                    betterDisplayManager.refreshDisplays()
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                Text("betterdisplay.test_connection".localized)
                            }
                            .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.horizontal)
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("betterdisplay.not_installed".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    Button {
                        if let url = URL(string: "https://github.com/waydabber/BetterDisplay") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "safari")
                            Text("Open BetterDisplay")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 12)
            
            Divider()
            
            // 显示器列表
            if betterDisplayManager.isEnabled && !betterDisplayManager.displays.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("显示器列表")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 12)
                        
                        ForEach(betterDisplayManager.displays) { display in
                            displayListItem(display)
                        }
                    }
                    .padding(.bottom, 12)
                }
            } else if betterDisplayManager.isEnabled {
                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "display.trianglebadge.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("未检测到显示器")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Button {
                            betterDisplayManager.refreshDisplays()
                            appModel.brightnessControl.updateDisplayMapping()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("betterdisplay.refresh_displays".localized)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "display.2")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("请启用 BetterDisplay 集成")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func displayListItem(_ display: BetterDisplayInfo) -> some View {
        Button(action: {
            selectedDisplay = display
            // 清空测试状态
            currentBrightness = nil
            testMessage = ""
        }) {
            HStack {
                Image(systemName: "display")
                    .foregroundColor(selectedDisplay?.id == display.id ? .white : .primary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(display.name)
                        .font(.subheadline)
                        .foregroundColor(selectedDisplay?.id == display.id ? .white : .primary)
                    
                    Text("ID: \(display.displayID)")
                        .font(.caption)
                        .foregroundColor(selectedDisplay?.id == display.id ? .white.opacity(0.8) : .secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                selectedDisplay?.id == display.id ? Color.accentColor : Color.clear
            )
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
    
    private var displayDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let display = selectedDisplay {
                    // 显示器详情
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "display")
                                .font(.largeTitle)
                                .foregroundColor(.accentColor)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(display.name)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                Text(display.productName ?? display.name)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Divider()
                        
                        // 显示器信息
                        VStack(alignment: .leading, spacing: 12) {
                            Text("显示器信息")
                                .font(.headline)
                            
                            if let displayID = display.displayID {
                                infoRow(label: "Display ID", value: displayID)
                            }
                            if let uuid = display.UUID {
                                infoRow(label: "UUID", value: uuid)
                            }
                            if let serial = display.serial {
                                infoRow(label: "序列号", value: serial)
                            }
                            if let model = display.model {
                                infoRow(label: "型号", value: model)
                            }
                            if let vendor = display.vendor {
                                infoRow(label: "厂商", value: vendor)
                            }
                            if let alphanumericSerial = display.alphanumericSerial, !alphanumericSerial.isEmpty {
                                infoRow(label: "字母序列号", value: alphanumericSerial)
                            }
                            if let year = display.yearOfManufacture, let week = display.weekOfManufacture {
                                infoRow(label: "制造日期", value: "\(year) 年第 \(week) 周")
                            }
                        }
                        
                        Divider()
                        
                        // 亮度测试区域
                        displayBrightnessTest(for: display)
                    }
                } else {
                    // 亮度设置
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Image(systemName: "sun.max.fill")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("settings.low_brightness".localized)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                Text("settings.brightness_preview_hint".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("settings.brightness_level".localized)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("\(Int(appModel.lowBrightnessLevel * 100))%")
                                    .foregroundColor(.secondary)
                                    .font(.system(.body, design: .monospaced))
                            }
                            
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
                        
                        Divider()
                        
                        if !betterDisplayManager.isEnabled {
                            HStack(alignment: .top) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("betterdisplay.disabled_warning".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        } else {
                            HStack(alignment: .top) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("betterdisplay.integration_hint".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
                .textSelection(.enabled)
            
            Spacer()
        }
    }
    
    // MARK: - Display Brightness Test
    
    private func displayBrightnessTest(for display: BetterDisplayInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("亮度测试")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                // 1. 获取当前亮度
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. 获取当前亮度")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 12) {
                        Button {
                            if let uuid = display.UUID {
                                isTestingBrightness = true
                                testMessage = "正在获取亮度..."
                                
                                betterDisplayManager.cacheBrightnessByUUID(uuid: uuid) { brightness in
                                    DispatchQueue.main.async {
                                        isTestingBrightness = false
                                        if let brightness = brightness {
                                            currentBrightness = brightness
                                            testMessage = "✅ 当前亮度: \(Int(brightness * 100))%"
                                        } else {
                                            testMessage = "❌ 获取亮度失败"
                                        }
                                    }
                                }
                            } else {
                                testMessage = "❌ 显示器无 UUID"
                            }
                        } label: {
                            HStack {
                                if isTestingBrightness {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .frame(width: 16, height: 16)
                                } else {
                                    Image(systemName: "lightbulb.fill")
                                }
                                Text("获取亮度")
                            }
                            .frame(width: 120)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isTestingBrightness || display.UUID == nil)
                        
                        if let brightness = currentBrightness {
                            Text("\(Int(brightness * 100))%")
                                .font(.system(.title3, design: .monospaced))
                                .fontWeight(.semibold)
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                
                Divider()
                
                // 2. 设置指定亮度
                VStack(alignment: .leading, spacing: 8) {
                    Text("2. 设置指定亮度")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Slider(value: $testBrightness, in: 0...1)
                                    .frame(width: 200)
                                
                                Text("\(Int(testBrightness * 100))%")
                                    .font(.system(.body, design: .monospaced))
                                    .frame(width: 50, alignment: .trailing)
                            }
                            
                            HStack {
                                Text("0%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("100%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 200)
                        }
                        
                        Button {
                            if let uuid = display.UUID {
                                isTestingBrightness = true
                                testMessage = "正在设置亮度..."
                                
                                betterDisplayManager.setBrightnessByUUID(uuid: uuid, brightness: testBrightness) { success in
                                    DispatchQueue.main.async {
                                        isTestingBrightness = false
                                        if success {
                                            testMessage = "✅ 成功设置亮度为 \(Int(testBrightness * 100))%"
                                        } else {
                                            testMessage = "❌ 设置亮度失败"
                                        }
                                    }
                                }
                            } else {
                                testMessage = "❌ 显示器无 UUID"
                            }
                        } label: {
                            HStack {
                                if isTestingBrightness {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .frame(width: 16, height: 16)
                                } else {
                                    Image(systemName: "sun.max.fill")
                                }
                                Text("设置亮度")
                            }
                            .frame(width: 120)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isTestingBrightness || display.UUID == nil)
                    }
                }
                
                // 测试消息显示
                if !testMessage.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: testMessage.hasPrefix("✅") ? "checkmark.circle.fill" : testMessage.hasPrefix("❌") ? "xmark.circle.fill" : "info.circle.fill")
                            .foregroundColor(testMessage.hasPrefix("✅") ? .green : testMessage.hasPrefix("❌") ? .red : .blue)
                            .font(.caption)
                        
                        Text(testMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                }
                
                // 提示信息
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    Text("测试功能仅针对当前选中的显示器，不会影响其他显示器的亮度设置")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            )
        }
    }
    
    // MARK: - General Content
    
    private var generalContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    
                    Text("settings.macafk_settings".localized)
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 16) {
                    Toggle("settings.launch_at_login".localized, isOn: $appModel.launchAtLogin)
                        .toggleStyle(.switch)
                        .help("settings.launch_at_login.help".localized)
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - Language Content
    
    private var languageContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(systemName: "globe")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("menu.language".localized)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("menu.language.restart_required".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        languageButton(for: language)
                    }
                }
            }
            .padding(20)
        }
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
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(languageManager.currentLanguage == language ? Color.blue.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Update Content
    
    private var updateContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(systemName: "arrow.down.circle")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    
                    Text("update.check_for_updates".localized)
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("update.current_version".localized)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(getCurrentVersion())
                            .foregroundColor(.secondary)
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    updateStatusView
                    
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
            }
            .padding(20)
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
    
    // MARK: - Bottom Bar
    
    private var bottomBar: some View {
        HStack {
            if betterDisplayManager.isEnabled {
                Button {
                    betterDisplayManager.refreshDisplays()
                    appModel.brightnessControl.updateDisplayMapping()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("betterdisplay.refresh_displays".localized)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
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
