//
//  ContentView.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()
    @StateObject private var languageManager = LanguageManager()
    @StateObject private var manager = ArchiveManager()
    @StateObject private var recentManager = RecentFilesManager()
    @StateObject private var toolInstaller = ToolInstaller()
    @State private var currentDirectory: URL? = FileManager.default.homeDirectoryForCurrentUser
    @State private var viewMode: FileBrowserView.ViewMode = .list
    @State private var showInstallAlert = false
    @State private var missingTools: [String] = []
    
    var body: some View {
        NavigationSplitView {
            SidebarView(
                manager: manager,
                recentManager: recentManager,
                currentDirectory: $currentDirectory
            )
            .environmentObject(appState)
            .environmentObject(languageManager)
        } detail: {
            // ✅ 由上层决定显示哪个视图
            if manager.currentArchive != nil {
                ArchiveContentView(manager: manager)
                    .environmentObject(languageManager)
            } else {
                FileBrowserView(
                    manager: manager,
                    recentManager: recentManager,
                    currentDirectory: $currentDirectory,
                    viewMode: $viewMode
                )
                .environmentObject(languageManager)
            }
        }
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .alert(manager.error ?? "alert.done".localized, isPresented: $manager.showAlert) {
            Button("alert.ok".localized) { }
        }
        .sheet(isPresented: $appState.showNewArchive) {
            ArchiveCreatorView(manager: manager)
                .environmentObject(languageManager)
        }
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
        .onAppear {
            manager.appState = appState
            recentManager.refresh()
            
            let missing = toolInstaller.checkTools()
            if !missing.isEmpty {
                missingTools = missing
                showInstallAlert = true
            }
        }
        .alert("settings.tools.install.alert.title".localized, isPresented: $showInstallAlert) {
            Button("settings.tools.install.alert.install".localized) {
                installTools()
            }
            Button("settings.tools.install.alert.cancel".localized, role: .cancel) { }
        } message: {
            Text("settings.tools.install.alert.message".localized)
        }
    }
    
    func installTools() {
        toolInstaller.installTools(missingTools, progress: { _, _ in }, completion: { success, message in
            if success {
                manager.error = "settings.tools.complete".localized + ". " + "settings.tools.deleted.message".localized
            } else {
                manager.error = "settings.tools.failed".localized + ": \(message)"
            }
            manager.showAlert = true
        })
    }
}
