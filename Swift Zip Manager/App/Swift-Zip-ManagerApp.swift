//
//  Swift-Zip-ManagerApp.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

@main
struct SwiftZipManagerApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var languageManager = LanguageManager()
    @StateObject private var updateChecker = UpdateChecker()
    @AppStorage("autoCheckUpdates") private var autoCheckUpdates = true
    @AppStorage("includePrereleaseUpdates") private var includePrereleaseUpdates = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(languageManager)
                .frame(minWidth: 900, minHeight: 600)
                .onReceive(NotificationCenter.default.publisher(for: .openArchiveNotification)) { _ in
                    NotificationCenter.default.post(name: .showOpenPanelNotification, object: nil)
                }
                .onReceive(NotificationCenter.default.publisher(for: .showHelpNotification)) { _ in
                    appState.showHelp = true
                }
                .onReceive(NotificationCenter.default.publisher(for: .checkForUpdatesNotification)) { _ in
                    updateChecker.checkForUpdates(
                        includePrerelease: includePrereleaseUpdates,
                        showIfNone: true
                    )
                }
                .onAppear {
                    if autoCheckUpdates {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            updateChecker.checkForUpdates(
                                includePrerelease: includePrereleaseUpdates
                            )
                        }
                    }
                }
                // ✅ 监听 Settings 和 Help 状态
                .onReceive(appState.$showSettings) { show in
                    if show {
                        WindowManager.shared.openSettings(appState: appState, languageManager: languageManager)
                    }
                }
                .onReceive(appState.$showHelp) { show in
                    if show {
                        WindowManager.shared.openHelp(appState: appState)
                    }
                }
        }
        .commands {
            // MARK: - File Menu
            CommandGroup(after: .newItem) {
                Button("New Archive") {
                    appState.showNewArchive = true
                }
                .keyboardShortcut("a", modifiers: .command)
                
                Button("Open Archive") {
                    NotificationCenter.default.post(name: .openArchiveNotification, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Divider()

                Button("Close Window") {
                    closeCurrentWindow()
                }
                .keyboardShortcut("w", modifiers: .command)
            }
            
            // MARK: - Edit Menu
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Extract Selected") {
                    NotificationCenter.default.post(name: .extractSelectedNotification, object: nil)
                }
                .keyboardShortcut("e", modifiers: .command)
                
                Button("Extract All") {
                    NotificationCenter.default.post(name: .extractAllNotification, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Delete from Archive") {
                    NotificationCenter.default.post(name: .deleteSelectedNotification, object: nil)
                }
                .keyboardShortcut(.delete, modifiers: [])
            }
            
            // MARK: - View Menu
            CommandGroup(after: .toolbar) {
                Button("Show in Finder") {
                    NotificationCenter.default.post(name: .showInFinderNotification, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)
            }
            
            // MARK: - App Menu
            CommandGroup(after: .appInfo) {
                Divider()
                Button("Settings...") {
                    print("⚙️ Settings triggered from menu (cmd+ ,)")
                    appState.showSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
                
                Divider()
                Button("Check for Updates...") {
                    updateChecker.checkForUpdates(
                        includePrerelease: includePrereleaseUpdates,
                        showIfNone: true
                    )
                }
                .keyboardShortcut("u", modifiers: .command)
            }
            
            // MARK: - Help Menu
            CommandGroup(replacing: .help) {
                Button("Swift Zip Manager Help") {
                    print("📖 Help triggered from menu (cmd+?)")
                    NotificationCenter.default.post(name: .showHelpNotification, object: nil)
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }
    }
    
    // MARK: - Window Management
    private func newWindow() {
        let url = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in }
    }
    
    private func closeCurrentWindow() {
        NSApplication.shared.keyWindow?.close()
    }
}
