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
    
    // MARK: - 状态
    
    @State private var showPasswordDialog = false
    @State private var pendingFileName: String?
    @State private var pendingDestination: URL?
    @State private var pendingIsExtractAll = false
    @State private var passwordInput = ""
    @State private var isDeleting = false
    @State private var showDeleteConfirm = false
    @State private var entriesToDelete: [ArchiveEntry] = []
    
    // 提取重试状态
    @State private var retryEntry: ArchiveEntry?
    @State private var retryDestination: URL?
    @State private var retryIsExtractAll = false
    @State private var retryFileName: String?
    @State private var retryFormat: String = "zip"
    @State private var retryArchiveURL: URL?
    @State private var retryIsLoading = false
    @State private var passwordError: String?
    
    var body: some View {
        VStack(spacing: 0) {
            archiveHeader
            Divider()
            
            // ✅ 只有 "Extract All" 按钮（删除按钮已移除）
            extractAllToolbar
            
            if isDeleting {
                deleteProgressView
            }
            
            archiveList
        }
        .sheet(isPresented: $showPasswordDialog) {
            ArchivePasswordDialog(
                isPresented: $showPasswordDialog,
                password: $passwordInput,
                fileName: pendingFileName ?? (retryEntry?.name ?? retryArchiveURL?.lastPathComponent ?? "archive"),
                onConfirm: { password in
                    handlePasswordConfirm(password)
                }
            )
            .environmentObject(languageManager)
            .onDisappear {
                // 如果用户取消，清除状态
                if !showPasswordDialog {
                    clearPendingState()
                }
            }
        }
        .alert("archive.delete.confirm.title".localized, isPresented: $showDeleteConfirm) {
            Button("archive.delete.confirm.delete".localized, role: .destructive) {
                performBatchDelete()
            }
            Button("archive.delete.confirm.cancel".localized, role: .cancel) {
                entriesToDelete.removeAll()
            }
        } message: {
            Text(String(format: "archive.delete.confirm.message".localized, entriesToDelete.count))
        }
        .onReceive(NotificationCenter.default.publisher(for: .extractSelectedNotification)) { _ in
            handleExtractSelected()
        }
        .onReceive(NotificationCenter.default.publisher(for: .extractAllNotification)) { _ in
            extractAllFiles()
        }
        .onReceive(NotificationCenter.default.publisher(for: .deleteSelectedNotification)) { _ in
            handleDeleteSelected()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showPasswordDialogNotification)) { notification in
            handlePasswordNotification(notification)
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var archiveHeader: some View {
        if let archive = manager.currentArchive {
            HStack {
                Image(systemName: "doc.zipper")
                    .foregroundColor(.blue)
                Text(archive.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(String(format: "archive.items".localized, manager.entries.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        }
    }
    
    // ✅ 只有 "Extract All" 按钮（删除按钮已移除）
    @ViewBuilder
    private var extractAllToolbar: some View {
        HStack {
            Spacer()
            
            Button(action: extractAllFiles) {
                Label("archive.extract.all".localized, systemImage: "tray.and.arrow.down")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(manager.entries.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
    }
    
    @ViewBuilder
    private var deleteProgressView: some View {
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
    
    @ViewBuilder
    private var archiveList: some View {
        if manager.entries.isEmpty {
            emptyState
        } else {
            List(manager.entries, selection: $manager.selectedArchiveIDs) { entry in
                ArchiveEntryRow(
                    entry: entry,
                    isSelected: manager.selectedArchiveIDs.contains(entry.id),
                    onExtract: extractFile,
                    onDelete: { entry in
                        entriesToDelete = [entry]
                        showDeleteConfirm = true
                    },
                    onExtractAll: extractAllFiles
                )
            }
            .listStyle(.inset)
            .disabled(isDeleting)
            .opacity(isDeleting ? 0.6 : 1.0)
        }
    }
    
    @ViewBuilder
    private var emptyState: some View {
        EmptyStateView(
            icon: "doc.zipper",
            title: "archive.empty.title".localized,
            message: "archive.empty.message".localized
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 密码通知处理
    
    private func handlePasswordNotification(_ notification: Notification) {
        let userInfo = notification.userInfo ?? [:]
        
        if let url = userInfo["archiveURL"] as? URL {
            retryArchiveURL = url
            retryFormat = userInfo["format"] as? String ?? url.pathExtension.lowercased()
        }
        
        retryIsLoading = userInfo["isLoading"] as? Bool ?? false
        retryIsExtractAll = userInfo["isExtractAll"] as? Bool ?? false
        
        if let dest = userInfo["destination"] as? URL {
            retryDestination = dest
            pendingDestination = dest
        }
        
        if let errorMsg = userInfo["error"] as? String {
            passwordError = errorMsg
            manager.error = errorMsg
            manager.showAlert = true
        }
        
        pendingFileName = userInfo["fileName"] as? String
        passwordInput = ""
        showPasswordDialog = true
    }
    
    // MARK: - 提取文件（入口）
    
    private func extractFile(_ entry: ArchiveEntry) {
        guard let archive = manager.currentArchive else { return }
        
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.message = String(format: "archive.extract.selected".localized + " %@", entry.name)
        
        panel.begin { response in
            if response == .OK, let destination = panel.url {
                let ext = archive.pathExtension.lowercased()
                retryArchiveURL = archive
                retryFormat = ext
                retryEntry = entry
                retryFileName = entry.path
                retryDestination = destination
                retryIsExtractAll = false
                retryIsLoading = false
                pendingIsExtractAll = false
                
                // ✅ 先尝试从密码缓存获取密码
                let cachedPassword = PasswordCache.shared.peekPassword(for: archive.path)
                if let password = cachedPassword, (ext == "7z" || ext == "rar") {
                    print("🔑 [ArchiveContentView] Using cached password for extraction")
                    performExtract(
                        archive: archive,
                        fileName: entry.path,
                        destination: destination,
                        password: password,
                        format: ext,
                        isExtractAll: false
                    )
                } else {
                    performExtract(
                        archive: archive,
                        fileName: entry.path,
                        destination: destination,
                        password: nil,
                        format: ext,
                        isExtractAll: false
                    )
                }
            }
        }
    }
    
    // MARK: - 提取全部
    
    private func extractAllFiles() {
        guard let archive = manager.currentArchive else { return }
        
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let ext = archive.pathExtension.lowercased()
                retryArchiveURL = archive
                retryFormat = ext
                retryDestination = url
                retryIsExtractAll = true
                pendingIsExtractAll = true
                retryIsLoading = false
                retryFileName = nil
                retryEntry = nil
                
                // ✅ 先尝试从密码缓存获取密码
                let cachedPassword = PasswordCache.shared.peekPassword(for: archive.path)
                if let password = cachedPassword, (ext == "7z" || ext == "rar") {
                    print("🔑 [ArchiveContentView] Using cached password for extract all")
                    performExtract(
                        archive: archive,
                        fileName: nil,
                        destination: url,
                        password: password,
                        format: ext,
                        isExtractAll: true
                    )
                } else {
                    performExtract(
                        archive: archive,
                        fileName: nil,
                        destination: url,
                        password: nil,
                        format: ext,
                        isExtractAll: true
                    )
                }
            }
        }
    }
    
    // MARK: - 核心提取方法
    
    private func performExtract(
        archive: URL,
        fileName: String?,
        destination: URL,
        password: String?,
        format: String,
        isExtractAll: Bool
    ) {
        print("🔍 [Extract] Starting: format=\(format), isExtractAll=\(isExtractAll), hasPassword=\(password != nil && !password!.isEmpty)")
        
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            var environment = ProcessInfo.processInfo.environment
            var args: [String] = []
            
            if let pwd = password, !pwd.isEmpty {
                environment["EXTRACT_PASSWORD"] = pwd
                if format == "7z" {
                    environment["7Z_PASSWORD"] = pwd
                } else if format == "rar" {
                    environment["RAR_PASSWORD"] = pwd
                }
            }
            process.environment = environment
            
            switch format {
            case "zip":
                process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                if let pwd = password, !pwd.isEmpty {
                    if isExtractAll {
                        args = ["-o", "-P", pwd, archive.path, "-d", destination.path]
                    } else if let name = fileName {
                        args = ["-o", "-P", pwd, archive.path, name, "-d", destination.path]
                    }
                } else {
                    if isExtractAll {
                        args = ["-o", archive.path, "-d", destination.path]
                    } else if let name = fileName {
                        args = ["-o", archive.path, name, "-d", destination.path]
                    }
                }
                
            case "7z":
                guard let toolPath = ToolPathResolver().resolve("7zz") else {
                    DispatchQueue.main.async {
                        self.manager.error = "error.tool.not.found".localized(with: "7zz")
                        self.manager.showAlert = true
                    }
                    return
                }
                process.executableURL = URL(fileURLWithPath: toolPath)
                if let pwd = password, !pwd.isEmpty {
                    if isExtractAll {
                        args = ["x", archive.path, "-o\(destination.path)", "-y", "-p\(pwd)"]
                    } else if let name = fileName {
                        args = ["x", archive.path, "-o\(destination.path)", name, "-y", "-p\(pwd)"]
                    }
                } else {
                    if isExtractAll {
                        args = ["x", archive.path, "-o\(destination.path)", "-y"]
                    } else if let name = fileName {
                        args = ["x", archive.path, "-o\(destination.path)", name, "-y"]
                    }
                }
                
            case "rar":
                guard let toolPath = ToolPathResolver().resolve("rar") else {
                    DispatchQueue.main.async {
                        self.manager.error = "error.tool.not.found".localized(with: "rar")
                        self.manager.showAlert = true
                    }
                    return
                }
                process.executableURL = URL(fileURLWithPath: toolPath)
                if let pwd = password, !pwd.isEmpty {
                    if isExtractAll {
                        args = ["x", "-p\(pwd)", archive.path, destination.path]
                    } else if let name = fileName {
                        args = ["x", "-p\(pwd)", archive.path, destination.path, name]
                    }
                } else {
                    if isExtractAll {
                        args = ["x", archive.path, destination.path]
                    } else if let name = fileName {
                        args = ["x", archive.path, destination.path, name]
                    }
                }
                
            default:
                return
            }
            
            if args.isEmpty {
                DispatchQueue.main.async {
                    self.manager.error = "archive.extraction.failed".localized + ": " + "archive.error.invalid.parameters".localized
                    self.manager.showAlert = true
                }
                return
            }
            
            process.arguments = args
            
            let errorPipe = Pipe()
            let outputPipe = Pipe()
            process.standardError = errorPipe
            process.standardOutput = outputPipe
            
            do {
                try process.runWithTimeout(seconds: 300)
                
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMsg = String(data: errorData, encoding: .utf8) ?? ""
                let lowercasedError = errorMsg.lowercased()
                
                print("🔍 [Extract] Exit code: \(process.terminationStatus)")
                print("🔍 [Extract] Error: \(errorMsg)")
                
                let needsPassword = lowercasedError.contains("password") ||
                                    lowercasedError.contains("encrypted") ||
                                    lowercasedError.contains("wrong") ||
                                    lowercasedError.contains("bad") ||
                                    lowercasedError.contains("incorrect") ||
                                    lowercasedError.contains("need") ||
                                    lowercasedError.contains("enter")
                
                // ✅ 没有提供密码，且需要密码 → 弹窗
                if (password == nil || password?.isEmpty == true) && needsPassword {
                    DispatchQueue.main.async {
                        print("🔍 [Extract] 🔐 Password required, showing dialog")
                        self.pendingFileName = fileName
                        self.pendingDestination = destination
                        self.pendingIsExtractAll = isExtractAll
                        self.passwordInput = ""
                        self.retryFormat = format
                        self.retryArchiveURL = archive
                        self.retryFileName = fileName
                        self.retryDestination = destination
                        self.retryIsExtractAll = isExtractAll
                        self.retryIsLoading = false
                        self.showPasswordDialog = true
                    }
                    return
                }
                
                // ✅ 提供了密码但错误 → 清除缓存，弹窗重试
                if let pwd = password, !pwd.isEmpty, needsPassword {
                    DispatchQueue.main.async {
                        // 清除缓存密码
                        PasswordCache.shared.clearPassword(for: archive.path)
                        print("❌ [Extract] Wrong password, cache cleared")
                        
                        // 显示错误并重新弹窗
                        self.manager.error = "archive.password.wrong".localized
                        self.manager.showAlert = true
                        
                        // 延迟后重新弹窗
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.pendingFileName = fileName
                            self.pendingDestination = destination
                            self.pendingIsExtractAll = isExtractAll
                            self.passwordInput = ""
                            self.retryFormat = format
                            self.retryArchiveURL = archive
                            self.retryFileName = fileName
                            self.retryDestination = destination
                            self.retryIsExtractAll = isExtractAll
                            self.retryIsLoading = false
                            self.showPasswordDialog = true
                        }
                    }
                    return
                }
                
                if process.terminationStatus != 0 {
                    DispatchQueue.main.async {
                        self.manager.error = "archive.extraction.failed".localized + ": \(errorMsg)"
                        self.manager.showAlert = true
                    }
                    return
                }
                
                // ✅ 提取成功，清除密码缓存（一次性使用）
                if let pwd = password, !pwd.isEmpty {
                    PasswordCache.shared.clearPassword(for: archive.path)
                    print("🔑 [Extract] Password used and cleared for: \(archive.lastPathComponent)")
                }
                
                DispatchQueue.main.async {
                    let msg = isExtractAll ? "archive.extraction.complete".localized : String(format: "archive.extraction.complete".localized, fileName ?? "")
                    print("✅ [Extract] Success: \(msg)")
                    self.manager.error = msg
                    self.manager.showAlert = true
                }
                
            } catch let error as ArchiveError {
                DispatchQueue.main.async {
                    if error == .timeout {
                        self.manager.error = "archive.extraction.timeout".localized
                    } else {
                        self.manager.error = error.localizedDescription
                    }
                    self.manager.showAlert = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.manager.error = "archive.extraction.failed".localized + ": \(error.localizedDescription)"
                    self.manager.showAlert = true
                }
            }
        }
    }
    
    // MARK: - 密码确认
    
    private func handlePasswordConfirm(_ password: String) {
        print("🔍 [Password] Confirmed, length: \(password.count)")
        
        // ✅ 如果是加载归档时需要密码
        if retryIsLoading, let url = retryArchiveURL {
            print("🔍 [Password] Loading archive with password")
            // 存储密码到缓存
            PasswordCache.shared.setPassword(password, for: url.path)
            manager.loadArchiveWithPassword(url, password: password)
            clearPendingState()
            return
        }
        
        // ✅ 如果是提取时需要密码
        guard let archive = retryArchiveURL ?? manager.currentArchive else {
            print("❌ [Password] No archive URL")
            return
        }
        
        // 存储密码到缓存（用于后续重试）
        PasswordCache.shared.setPassword(password, for: archive.path)
        
        performExtract(
            archive: archive,
            fileName: retryFileName ?? pendingFileName,
            destination: retryDestination ?? pendingDestination ?? FileManager.default.homeDirectoryForCurrentUser,
            password: password,
            format: retryFormat,
            isExtractAll: retryIsExtractAll || pendingIsExtractAll
        )
        
        clearPendingState()
    }
    
    // MARK: - 删除
    
    private func handleDeleteSelected() {
        let idsToDelete = manager.selectedArchiveIDs
        let entries = manager.entries.filter { idsToDelete.contains($0.id) }
        
        guard !entries.isEmpty else { return }
        
        entriesToDelete = entries
        showDeleteConfirm = true
        manager.selectedArchiveIDs.removeAll()
    }
    
    private func performBatchDelete() {
        guard !entriesToDelete.isEmpty else { return }
        
        isDeleting = true
        let entries = entriesToDelete
        
        print("🗑️ [Delete] Deleting \(entries.count) entries")
        
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
            
            let fileNames = entries.map { $0.path }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: toolPath)
            process.arguments = ["d", archive.path] + fileNames
            
            let errorPipe = Pipe()
            process.standardError = errorPipe
            
            do {
                try process.runWithTimeout(seconds: 120)
                
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMsg = String(data: errorData, encoding: .utf8) ?? ""
                
                DispatchQueue.main.async {
                    self.isDeleting = false
                    self.entriesToDelete.removeAll()
                    
                    if process.terminationStatus == 0 {
                        if let archive = self.manager.currentArchive {
                            self.manager.loadArchive(archive)
                        }
                        self.manager.error = String(format: "archive.delete.success".localized, entries.count)
                    } else {
                        self.manager.error = "archive.delete.failed".localized + ": \(errorMsg)"
                    }
                    self.manager.showAlert = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.isDeleting = false
                    self.entriesToDelete.removeAll()
                    self.manager.error = "archive.delete.failed".localized + ": \(error.localizedDescription)"
                    self.manager.showAlert = true
                }
            }
        }
    }
    
    private func handleExtractSelected() {
        guard let firstID = manager.selectedArchiveIDs.first,
              let entry = manager.entries.first(where: { $0.id == firstID }) else {
            return
        }
        extractFile(entry)
    }
    
    // MARK: - Helpers
    
    private func clearPendingState() {
        pendingFileName = nil
        pendingDestination = nil
        pendingIsExtractAll = false
        passwordInput = ""
        retryEntry = nil
        retryDestination = nil
        retryIsExtractAll = false
        retryFileName = nil
        retryFormat = "zip"
        retryArchiveURL = nil
        retryIsLoading = false
        passwordError = nil
    }
}
