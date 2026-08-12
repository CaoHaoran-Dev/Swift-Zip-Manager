//
//  UpdatesSettingsView.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

struct UpdatesSettingsView: View {
    @StateObject private var updateChecker = UpdateChecker()
    @AppStorage("autoCheckUpdates") private var autoCheckUpdates = true
    @AppStorage("includePrereleaseUpdates") private var includePrereleaseUpdates = false
    @State private var showUpdateSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("settings.updates.title".localized)
                .font(.largeTitle)
                .bold()
            
            Text("settings.updates.subtitle".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                currentVersionRow
                Divider()
                updateChannelRow
                Divider()
                autoCheckRow
                checkButtonRow
                checkStatusRow  // ✅ 显示检查过程
                
                if let update = updateChecker.updateAvailable {
                    updateAvailableRow(update)
                }
                
                if updateChecker.isDownloading {
                    downloadProgressRow
                }
                
                updateInfoFooter
            }
        }
        .sheet(isPresented: $showUpdateSheet) {
            if let update = updateChecker.updateAvailable {
                UpdateAlertView(
                    update: update,
                    onDownload: startDownload,
                    onDismiss: { showUpdateSheet = false }
                )
            }
        }
        .alert("settings.updates.no.update.title".localized, isPresented: $updateChecker.showCheckResult) {
            Button("alert.ok".localized) { }
        } message: {
            Text(updateChecker.checkResultMessage ?? "settings.updates.no.update.message".localized)
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var currentVersionRow: some View {
        HStack {
            Text("settings.updates.current.version".localized)
                .frame(width: 140, alignment: .leading)
                .font(.headline)
            Text(Bundle.main.appVersion)
        }
    }
    
    @ViewBuilder
    private var updateChannelRow: some View {
        HStack(alignment: .top, spacing: 0) {
            Text("settings.updates.channel".localized)
                .frame(width: 140, alignment: .leading)
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                Picker("", selection: $includePrereleaseUpdates) {
                    Text("settings.updates.channel.stable".localized).tag(false)
                    Text("settings.updates.channel.beta".localized).tag(true)
                }
                .pickerStyle(.radioGroup)
                .horizontalRadioGroupLayout()
                
                Text(includePrereleaseUpdates ? "settings.updates.channel.beta.desc".localized : "settings.updates.channel.stable.desc".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var autoCheckRow: some View {
        HStack {
            Text("settings.updates.auto.check".localized)
                .frame(width: 140, alignment: .leading)
                .font(.headline)
            Toggle("settings.updates.auto.check.desc".localized, isOn: $autoCheckUpdates)
                .toggleStyle(.switch)
        }
    }
    
    @ViewBuilder
    private var checkButtonRow: some View {
        HStack {
            Text("")
                .frame(width: 140, alignment: .leading)
            Button(action: { checkForUpdates() }) {
                if updateChecker.isChecking {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("settings.updates.checking".localized)
                    }
                } else {
                    Text("settings.updates.check.button".localized)
                }
            }
            .buttonStyle(.bordered)
            .disabled(updateChecker.isChecking)
        }
    }
    
    // MARK: - ✅ 显示检查状态
    
    @ViewBuilder
    private var checkStatusRow: some View {
        if updateChecker.isChecking {
            HStack {
                Text("")
                    .frame(width: 140, alignment: .leading)
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("settings.updates.checking.progress".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } else if updateChecker.checkResultMessage != nil && !updateChecker.showCheckResult {
            HStack {
                Text("")
                    .frame(width: 140, alignment: .leading)
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text(updateChecker.checkResultMessage ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private func updateAvailableRow(_ update: UpdateChecker.UpdateInfo) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(update.isPrerelease ? .orange : .blue)
            Text(String(format: "settings.updates.available".localized, update.buildNumber))
                .font(.caption)
            if update.isPrerelease {
                Text("settings.updates.beta".localized)
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            Button("settings.updates.view".localized) { showUpdateSheet = true }
                .buttonStyle(.plain)
                .font(.caption)
        }
        .padding(.leading, 148)
    }
    
    @ViewBuilder
    private var downloadProgressRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                ProgressView(value: updateChecker.downloadProgress)
                    .progressViewStyle(.linear)
                    .frame(width: 200)
                Text(String(format: "settings.updates.downloading".localized, Int(updateChecker.downloadProgress * 100)))
                    .font(.caption)
            }
            Button("settings.updates.cancel".localized) { updateChecker.cancelDownload() }
                .buttonStyle(.plain)
                .font(.caption)
        }
        .padding(.leading, 148)
    }
    
    @ViewBuilder
    private var updateInfoFooter: some View {
        Text("settings.updates.footer".localized)
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.leading, 148)
    }
    
    // MARK: - Actions
    
    private func checkForUpdates() {
        updateChecker.checkResultMessage = nil
        updateChecker.updateAvailable = nil
        
        updateChecker.manualCheckForUpdates(
            includePrerelease: includePrereleaseUpdates,
            showIfNone: true
        ) { hasUpdate, message in
            if hasUpdate {
                showUpdateSheet = true
            }
            // 无更新时，alert 会自动显示
        }
    }
    
    private func startDownload() {
        updateChecker.downloadAndInstall(
            progress: { _, _ in },
            completion: { success, msg in
                if !success {
                    let alert = NSAlert()
                    alert.messageText = "settings.updates.download.failed".localized
                    alert.informativeText = msg
                    alert.runModal()
                }
                showUpdateSheet = false
            }
        )
    }
}
