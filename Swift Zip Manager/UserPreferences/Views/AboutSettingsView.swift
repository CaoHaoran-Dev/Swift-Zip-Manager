//
//  AboutSettingsView.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

struct AboutSettingsView: View {
    @ObservedObject var appState: AppState
    let githubURL = "https://github.com/CaoHaoran-Dev/Swift-Zip-Manager"
    @State private var versionTapCount = 0
    @State private var lastTapTime = Date()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("settings.about.title".localized)
                .font(.largeTitle)
                .bold()
            
            Divider()
            
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "archivebox")
                        .foregroundColor(.blue)
                        .font(.system(size: 48))
                    VStack(alignment: .leading) {
                        Text("app.name".localized)
                            .font(.title2)
                            .bold()
                        Text(String(format: "settings.about.version".localized, Bundle.main.appVersion))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .onTapGesture {
                                handleVersionTap()
                            }
                            .onHover { hovering in
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                    }
                }
                
                if appState.isDeveloperMode {
                    HStack {
                        Image(systemName: "hammer.fill").foregroundColor(.orange)
                        Text("settings.about.developer.mode".localized).font(.caption).foregroundColor(.orange)
                    }
                }
                
                Divider()
                
                Link("GitHub", destination: URL(string: githubURL)!)
                Text("settings.about.license".localized).font(.caption).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func handleVersionTap() {
        let now = Date()
        if now.timeIntervalSince(lastTapTime) > 1.0 {
            versionTapCount = 0
        }
        lastTapTime = now
        versionTapCount += 1
        if versionTapCount >= 5 {
            appState.toggleDeveloperMode()
            versionTapCount = 0
        }
    }
}
