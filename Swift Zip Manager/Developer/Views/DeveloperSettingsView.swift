//
//  DeveloperSettingsView.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

struct DeveloperSettingsView: View {
    @ObservedObject var appState: AppState
    @State private var selectedCategory: DevCategory = .debug
    
    enum DevCategory: String, CaseIterable {
        case debug = "developer.category.debug"
        case experimental = "developer.category.experimental"
        case unstable = "developer.category.unstable"
        case advanced = "developer.category.advanced"
        
        var localizedTitle: String {
            self.rawValue.localized
        }
        
        var icon: String {
            switch self {
            case .debug: return "ladybug.fill"
            case .experimental: return "flask.fill"
            case .unstable: return "exclamationmark.triangle.fill"
            case .advanced: return "gearshape.2.fill"
            }
        }
        
        var descriptionKey: String {
            switch self {
            case .debug: return "developer.category.debug.desc"
            case .experimental: return "developer.category.experimental.desc"
            case .unstable: return "developer.category.unstable.desc"
            case .advanced: return "developer.category.advanced.desc"
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("developer.title".localized)
                .font(.largeTitle)
                .bold()
            
            Text("developer.subtitle".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Divider()
            
            Picker("", selection: $selectedCategory) {
                ForEach(DevCategory.allCases, id: \.self) { category in
                    Label(category.localizedTitle, systemImage: category.icon).tag(category)
                }
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 8)
            
            Text(selectedCategory.descriptionKey.localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
            
            Divider()
            
            ScrollView {
                switch selectedCategory {
                case .debug:
                    DebugSettingsView(appState: appState)
                case .experimental:
                    ExperimentalSettingsView(appState: appState)
                case .unstable:
                    UnstableSettingsView(appState: appState)
                case .advanced:
                    AdvancedSettingsView(appState: appState)
                }
            }
        }
        .onDisappear {
            appState.saveDeveloperSettings()
            NotificationCenter.default.post(name: .developerSettingsChanged, object: nil)
        }
    }
}
