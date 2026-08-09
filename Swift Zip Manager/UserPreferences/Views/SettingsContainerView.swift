//
//  SettingsContainerView.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

struct SettingsContainerView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var languageManager: LanguageManager
    @ObservedObject var toolInstaller: ToolInstaller
    @State private var selectedTab = "general"
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Label("settings.tab.general".localized, systemImage: "gear").tag("general")
                Label("settings.tab.tools".localized, systemImage: "wrench.and.screwdriver").tag("tools")
                Label("settings.tab.updates".localized, systemImage: "arrow.triangle.2.circlepath").tag("updates")
                Label("settings.tab.about".localized, systemImage: "info.circle").tag("about")
                
                if appState.isDeveloperMode {
                    Divider()
                    Label("settings.tab.developer".localized, systemImage: "hammer.fill")
                        .foregroundColor(.orange)
                        .tag("developer")
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            settingsDetail
        }
        .frame(minWidth: 750, minHeight: 550)
    }
    
    @ViewBuilder
    private var settingsDetail: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case "general":
                        GeneralSettingsView(languageManager: languageManager)
                    case "tools":
                        ToolsSettingsView(toolInstaller: toolInstaller)
                    case "updates":
                        UpdatesSettingsView()
                    case "about":
                        AboutSettingsView(appState: appState)
                    case "developer":
                        DeveloperSettingsView(appState: appState)
                    default:
                        EmptyView()
                    }
                }
                .padding(24)
            }
        }
        .frame(minWidth: 500)
    }
}
