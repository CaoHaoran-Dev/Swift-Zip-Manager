//
//  ArchiveContentView.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

struct ArchiveContentView: View {
    @ObservedObject var manager: ArchiveManager
    @EnvironmentObject var languageManager: LanguageManager
    @State private var showPasswordDialog = false
    @State private var pendingFileName: String?
    @State private var pendingDestination: URL?
    @State private var pendingIsExtractAll = false
    @State private var passwordInput = ""
    @State private var isDeleting = false
    
    var body: some View {
        VStack(spacing: 0) {
            archiveHeader
            Divider()
            
            // ✅ #1: 删除时显示加载状态
            if isDeleting {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 4)
                    Text("archive.deleting".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }
            
            archiveList
        }
        .sheet(isPresented: $showPasswordDialog) {
            ArchivePasswordDialog(
                isPresented: $showPasswordDialog,
                password: $passwordInput,
                fileName: pendingFileName,
                onConfirm: { password in
                    if pendingIsExtractAll {
                        if let dest = pendingDestination {
                            manager.extractArchive(to: dest, password: password)
                        }
                    } else {
                        if let fileName = pendingFileName, let dest = pendingDestination {
                            extractWithPassword(fileName: fileName, destination: dest, password: password)
                        }
                    }
                    clearPendingState()
                }
            )
            .environmentObject(languageManager)
            .onDisappear {
                clearPendingState()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .extractSelectedNotification)) { _ in
            if let firstID = manager.selectedArchiveIDs.first,
               let entry = manager.entries.first(where: { $0.id == firstID }) {
                extractFile(entry)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .extractAllNotification)) { _ in
            extractAllFiles()
        }
        .onReceive(NotificationCenter.default.publisher(for: .deleteSelectedNotification)) { _ in
            let idsToDelete = manager.selectedArchiveIDs
            let entriesToDelete = manager.entries.filter { idsToDelete.contains($0.id) }
            manager.selectedArchiveIDs.removeAll()
            
            // ✅ #1: 批量删除
            deleteEntries(entriesToDelete)
        }
    }
    
    // MARK: - 批量删除

    private func deleteEntries(_ entries: [ArchiveEntry]) {
        guard !entries.isEmpty else { return }
        
        // 显示删除状态
        isDeleting = true
        
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            guard let archive = self.manager.currentArchive,
                  let toolPath = ToolPathResolver().resolve("7zz") else {
                DispatchQueue.main.async {
                    self.isDeleting = false
                    self.manager.error = "error.tool.not.found".localized(with: "7zz")
                    self.manager.showAlert = true
                }
                return
            }
            
            var failedCount = 0
            let totalCount = entries.count
            
            for entry in entries {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: toolPath)
                process.arguments = ["d", archive.path, entry.name]
                
                do {
                    try process.runWithTimeout(seconds: 120)
                    if process.terminationStatus != 0 {
                        failedCount += 1
                    }
                } catch {
                    failedCount += 1
                }
            }
            
            DispatchQueue.main.async {
                self.isDeleting = false
                
                if failedCount == 0 {
                    self.manager.loadArchive(archive)
                    self.manager.error = String(format: "archive.delete.success".localized, totalCount)
                } else if failedCount == totalCount {
                    self.manager.error = "archive.delete.all.failed".localized
                } else {
                    self.manager.error = String(format: "archive.delete.partial".localized, totalCount - failedCount, totalCount)
                }
                self.manager.showAlert = true
            }
        }
    }
    
    // MARK: - 单文件删除（复用批量删除）
    
    func deleteFromArchive(_ entry: ArchiveEntry) {
        deleteEntries([entry])
    }
    
    private func clearPendingState() {
        pendingFileName = nil
        pendingDestination = nil
        pendingIsExtractAll = false
        passwordInput = ""
    }
    
    @ViewBuilder
    private var archiveHeader: some View {
        if let archive = manager.currentArchive {
            HStack {
                Image(systemName: "doc.zipper").foregroundColor(.blue)
                Text(archive.lastPathComponent).font(.headline)
                Spacer()
                Text(String(format: "archive.items".localized, manager.entries.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        }
    }
    
    private var archiveList: some View {
        List(manager.entries) { entry in
            ArchiveEntryRow(
                entry: entry,
                isSelected: manager.selectedArchiveIDs.contains(entry.id),
                onExtract: extractFile,
                onDelete: deleteFromArchive,
                onExtractAll: extractAllFiles
            )
        }
        .listStyle(.inset)
        .disabled(isDeleting)
        .opacity(isDeleting ? 0.6 : 1.0)
    }
    
    func extractFile(_ entry: ArchiveEntry) {
        guard let archive = manager.currentArchive else { return }
        
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.message = String(format: "archive.extract.selected".localized + " %@", entry.name)
        
        panel.begin { response in
            if response == .OK, let destination = panel.url {
                let ext = archive.pathExtension.lowercased()
                if ext == "zip" || ext == "rar" || ext == "7z" {
                    pendingFileName = entry.name
                    pendingDestination = destination
                    pendingIsExtractAll = false
                    passwordInput = ""
                    showPasswordDialog = true
                } else {
                    extractDirect(fileName: entry.name, archive: archive, destination: destination)
                }
            }
        }
    }
    
    func extractDirect(fileName: String, archive: URL, destination: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-xf", archive.path, "-C", destination.path, fileName]
            
            do {
                try process.runWithTimeout(seconds: 300)
                
                DispatchQueue.main.async {
                    manager.error = String(format: "archive.extraction.complete".localized, fileName)
                    manager.showAlert = true
                }
            } catch {
                DispatchQueue.main.async {
                    if let archiveError = error as? ArchiveError,
                       archiveError == .timeout {
                        manager.error = "archive.extraction.timeout".localized
                    } else {
                        manager.error = "archive.extraction.failed".localized + ": \(error.localizedDescription)"
                    }
                    manager.showAlert = true
                }
            }
        }
    }
    
    func extractWithPassword(fileName: String, destination: URL, password: String) {
        guard let archive = manager.currentArchive else { return }
        let ext = archive.pathExtension.lowercased()
        
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            var environment = ProcessInfo.processInfo.environment
            environment["EXTRACT_PASSWORD"] = password
            process.environment = environment
            
            if ext == "zip" {
                process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                // ✅ #10: ZIP 使用 -P 参数（必须），但尽量降低可见性
                process.arguments = ["-P", password, archive.path, fileName, "-d", destination.path]
            } else if ext == "7z" || ext == "rar" {
                guard let toolPath = ToolPathResolver().resolve(ext == "7z" ? "7zz" : "rar") else {
                    DispatchQueue.main.async {
                        manager.error = "error.tool.not.found".localized(with: ext)
                        manager.showAlert = true
                    }
                    return
                }
                process.executableURL = URL(fileURLWithPath: toolPath)
                
                if ext == "7z" {
                    // ✅ #10: 7z 使用环境变量 + 参数
                    process.arguments = ["x", archive.path, "-o\(destination.path)", fileName, "-y", "-p\(password)"]
                } else {
                    process.arguments = ["x", "-p\(password)", archive.path, destination.path]
                }
            } else {
                return
            }
            
            do {
                try process.runWithTimeout(seconds: 300)
                _ = password
                DispatchQueue.main.async {
                    manager.error = String(format: "archive.extraction.complete".localized, fileName)
                    manager.showAlert = true
                }
            } catch {
                _ = password
                DispatchQueue.main.async {
                    if let archiveError = error as? ArchiveError,
                       archiveError == .timeout {
                        manager.error = "archive.extraction.timeout".localized
                    } else {
                        manager.error = "archive.password.wrong".localized
                    }
                    manager.showAlert = true
                }
            }
        }
    }
    
    func extractAllFiles() {
        guard let archive = manager.currentArchive else { return }
        
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let ext = archive.pathExtension.lowercased()
                if ext == "zip" || ext == "rar" || ext == "7z" {
                    pendingFileName = nil
                    pendingDestination = url
                    pendingIsExtractAll = true
                    passwordInput = ""
                    showPasswordDialog = true
                } else {
                    manager.extractArchive(to: url, password: nil)
                }
            }
        }
    }
}
