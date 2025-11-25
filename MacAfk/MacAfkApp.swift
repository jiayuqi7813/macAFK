//
//  MacAfkApp.swift
//  MacAfk
//
//  Created by Sn1waR on 11/21/25.
//

import SwiftUI

@main
struct MacAfkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var languageManager = LanguageManager.shared
    @State private var showingPreferences = false
    
    var body: some Scene {
        WindowGroup {
            ContentView(appModel: appDelegate.appModel)
                .environmentObject(languageManager)
                .sheet(isPresented: $showingPreferences) {
                    NewPreferencesView()
                        .environmentObject(languageManager)
                        .environmentObject(appDelegate.appModel)
                }
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("menu.preferences".localized) {
                    showingPreferences = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            
            // 添加设置菜单
            CommandMenu("menu.settings".localized) {
                Button("menu.preferences".localized) {
                    showingPreferences = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
