import SwiftUI

struct SettingsView: View {
    @ObservedObject var appModel: AppModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("settings.macafk_settings".localized)
                .font(.headline)
            
            Toggle("settings.enable_low_brightness_mode".localized, isOn: $appModel.isLowBrightness)
                .help("settings.low_brightness_mode.help".localized)
            
            Toggle("settings.launch_at_login".localized, isOn: $appModel.launchAtLogin)
                .help("settings.launch_at_login.help".localized)
            
            Divider()
            
            Text("settings.shortcuts".localized)
                .font(.subheadline)
            Text("settings.toggle_jiggler_shortcut".localized)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
            
            Button("button.quit_macafk".localized) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 300)
    }
}
