//
//  AdvancedSettingsView.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

struct AdvancedSettingsView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("developer.advanced.memory.limit".localized)
                            .frame(width: 120, alignment: .leading)
                        TextField("512", value: $appState.advancedMemoryLimit, formatter: NumberFormatter())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Text("MB")
                            .font(.caption)
                        Button("developer.advanced.memory.apply".localized) {
                            appState.saveDeveloperSettings()
                            appState.addDevLog("Memory limit set to \(appState.advancedMemoryLimit) MB", type: .info)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    Text("developer.advanced.memory.desc".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 124)
                    
                    Divider()
                    
                    HStack {
                        Text("developer.advanced.temp.dir".localized)
                            .frame(width: 120, alignment: .leading)
                        TextField("/tmp", text: $appState.advancedTempDir)
                            .textFieldStyle(.roundedBorder)
                        Button("developer.advanced.temp.browse".localized) {
                            let panel = NSOpenPanel()
                            panel.canChooseDirectories = true
                            panel.canCreateDirectories = true
                            panel.begin { response in
                                if response == .OK, let url = panel.url {
                                    appState.advancedTempDir = url.path
                                    appState.saveDeveloperSettings()
                                    appState.addDevLog("Temp directory set to \(url.path)", type: .info)
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        Button("developer.advanced.temp.apply".localized) {
                            let dir = appState.advancedTempDir
                            if !dir.isEmpty {
                                try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
                            }
                            appState.saveDeveloperSettings()
                            appState.addDevLog("Temp directory applied", type: .info)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    Text("developer.advanced.temp.desc".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 124)
                    
                    Divider()
                    
                    HStack {
                        Text("developer.advanced.max.concurrent".localized)
                            .frame(width: 120, alignment: .leading)
                        Picker("", selection: $appState.advancedMaxConcurrent) {
                            Text("1").tag(1)
                            Text("2").tag(2)
                            Text("4").tag(4)
                            Text("8").tag(8)
                            Text("16").tag(16)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 80)
                    }
                    
                    Text("developer.advanced.max.concurrent.desc".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 124)
                }
                .padding()
            } label: {
                Text("developer.advanced.title".localized)
            }
            
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Button("developer.advanced.reset".localized) {
                        resetAdvancedSettings()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                    
                    Button("developer.advanced.clear.cache".localized) {
                        clearCache()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("developer.advanced.open.support".localized) {
                        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                        let appDir = appSupport.appendingPathComponent(AppConstants.bundleIdentifier)
                        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
                        NSWorkspace.shared.open(appDir)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            } label: {
                Text("developer.advanced.danger".localized)
            }
        }
    }
    
    private func resetAdvancedSettings() {
        appState.advancedMemoryLimit = 512
        appState.advancedTempDir = ""
        appState.advancedMaxConcurrent = 4
        appState.useCustomToolPaths = false
        appState.customToolPath7zz = ""
        appState.customToolPathRar = ""
        appState.debugLoggingEnabled = false
        appState.showHiddenFiles = false
        appState.experimentalParallelExtract = false
        appState.experimentalNewExtractor = false
        appState.experimentalFastZip = false
        appState.unstableAsyncWrite = false
        appState.unstableMemoryExtract = false
        appState.unstableSkipPermissions = false
        
        appState.saveDeveloperSettings()
        appState.addDevLog("All advanced settings reset", type: .warning)
        NotificationCenter.default.post(name: .developerSettingsReset, object: nil)
    }
    
    private func clearCache() {
        let tempDir = FileManager.default.temporaryDirectory
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        
        var cleared = 0
        do {
            let tempContents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            for item in tempContents where item.lastPathComponent.hasPrefix("SwiftZip") {
                try? FileManager.default.removeItem(at: item)
                cleared += 1
            }
            
            let cacheContents = try FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)
            for item in cacheContents where item.lastPathComponent.hasPrefix(AppConstants.bundleIdentifier) {
                try? FileManager.default.removeItem(at: item)
                cleared += 1
            }
            
            appState.addDevLog("Cache cleared (\(cleared) items)", type: .success)
        } catch {
            appState.addDevLog("Failed to clear cache: \(error.localizedDescription)", type: .error)
        }
    }
}
