//
//  ToolsSettingsView.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

struct ToolsSettingsView: View {
    @ObservedObject var toolInstaller: ToolInstaller
    @State private var isCheckingTools = false
    @State private var missingTools: [String] = []
    @State private var showInstallAlert = false
    @State private var installProgress: Double = 0
    @State private var isInstalling = false
    @State private var installMessage = ""
    @State private var showDeleteConfirm = false
    @State private var toolStatusMessage = ""
    @State private var showStatusAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("settings.tools.title".localized)
                .font(.largeTitle)
                .bold()
            
            Text("settings.tools.subtitle".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    Text("settings.tools.status".localized)
                        .frame(width: 100, alignment: .leading)
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        if isInstalling {
                            VStack {
                                ProgressView(value: installProgress)
                                    .progressViewStyle(.linear)
                                    .frame(width: 250)
                                if !installMessage.isEmpty {
                                    Text(installMessage).font(.caption)
                                }
                            }
                        } else if isCheckingTools {
                            HStack {
                                ProgressView().controlSize(.small)
                                Text("settings.tools.checking".localized).font(.caption)
                            }
                        } else {
                            let missing = toolInstaller.checkTools()
                            if missing.isEmpty {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                    Text("settings.tools.installed".localized).foregroundColor(.green)
                                }
                            } else {
                                VStack(alignment: .leading) {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                                        Text(String(format: "settings.tools.missing".localized, missing.count)).foregroundColor(.orange)
                                    }
                                    ForEach(missing, id: \.self) { tool in
                                        Text(tool).font(.caption).padding(.leading, 20)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Divider()
                
                HStack(spacing: 16) {
                    Button(action: checkAndInstallTools) {
                        Label(isInstalling ? "settings.tools.installing".localized : "settings.tools.install".localized, systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isInstalling || isCheckingTools)
                    
                    Button(action: { showDeleteConfirm = true }) {
                        Label("settings.tools.delete".localized, systemImage: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isInstalling || isCheckingTools)
                }
                
                Text("settings.tools.description".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .alert("settings.tools.install.alert.title".localized, isPresented: $showInstallAlert) {
            Button("settings.tools.install.alert.install".localized) { installTools() }
            Button("settings.tools.install.alert.cancel".localized, role: .cancel) { }
        } message: {
            Text("settings.tools.install.alert.message".localized)
        }
        .alert("settings.tools.delete.confirm.title".localized, isPresented: $showDeleteConfirm) {
            Button("settings.tools.delete.confirm.delete".localized, role: .destructive) { deleteTools() }
            Button("settings.tools.delete.confirm.cancel".localized, role: .cancel) { }
        } message: {
            Text("settings.tools.delete.confirm.message".localized)
        }
        .alert(toolStatusMessage, isPresented: $showStatusAlert) {
            Button("alert.ok".localized) { }
        }
    }
    
    private func checkAndInstallTools() {
        isCheckingTools = true
        DispatchQueue.global().async {
            let missing = toolInstaller.checkTools()
            DispatchQueue.main.async {
                isCheckingTools = false
                if !missing.isEmpty {
                    missingTools = missing
                    showInstallAlert = true
                }
            }
        }
    }
    
    private func installTools() {
        isInstalling = true
        installProgress = 0
        toolInstaller.installTools(missingTools, progress: { p, msg in
            DispatchQueue.main.async {
                installProgress = p
                installMessage = msg
            }
        }, completion: { success, msg in
            DispatchQueue.main.async {
                isInstalling = false
                toolStatusMessage = success ? "settings.tools.complete".localized : "settings.tools.failed".localized
                if !success {
                    toolStatusMessage += ": \(msg)"
                }
                showStatusAlert = true
            }
        })
    }
    
    private func deleteTools() {
        let success = toolInstaller.deleteTools()
        toolStatusMessage = success ? "settings.tools.deleted".localized : "settings.tools.delete.failed".localized
        showStatusAlert = true
        // ✅ 不再需要重启，只刷新状态
    }
}
