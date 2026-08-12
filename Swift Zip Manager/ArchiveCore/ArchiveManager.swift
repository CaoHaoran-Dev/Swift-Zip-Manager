//
//  ArchiveManager.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

class ArchiveManager: ObservableObject {
    @Published var currentArchive: URL?
    @Published var entries: [ArchiveEntry] = []
    @Published var selectedArchiveIDs = Set<UUID>()
    @Published var isProcessing = false
    @Published var progress: Double = 0
    @Published var error: String?
    @Published var showAlert = false
    
    let formats = ["zip", "tar", "gz", "7z", "rar"]
    
    private let loader = ArchiveLoader()
    private let extractor = ArchiveExtractor()
    private let creator = ArchiveCreator()
    private let toolResolver = ToolPathResolver()
    
    weak var appState: AppState? {
        didSet {
            extractor.appState = appState
            creator.appState = appState
        }
    }
    
    // MARK: - 加载归档
    
    func loadArchive(_ url: URL, recentManager: RecentFilesManager? = nil) {
        currentArchive = url
        recentManager?.add(url)
        
        let ext = url.pathExtension.lowercased()
        
        // ✅ 如果是 7z/RAR，先检查密码缓存
        if ext == "7z" || ext == "rar" {
            let path = url.path
            if let cachedPassword = PasswordCache.shared.peekPassword(for: path) {
                print("🔑 [ArchiveManager] Using cached password for: \(url.lastPathComponent)")
                // 使用缓存密码加载
                loader.loadArchiveWithPassword(url, password: cachedPassword) { [weak self] result in
                    DispatchQueue.main.async {
                        self?.handleLoadResult(result, url: url, usedPassword: cachedPassword)
                    }
                }
                return
            }
        }
        
        // 无缓存密码，正常加载
        loader.loadArchive(url) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let entries):
                    self.entries = entries
                    self.selectedArchiveIDs.removeAll()
                    
                case .failure(let error):
                    if error == .passwordRequired {
                        // ✅ 需要密码 → 弹窗
                        print("🔐 [ArchiveManager] Password required for: \(url.lastPathComponent)")
                        NotificationCenter.default.post(
                            name: .showPasswordDialogNotification,
                            object: nil,
                            userInfo: [
                                "archiveURL": url,
                                "format": ext,
                                "isLoading": true
                            ]
                        )
                    } else {
                        self.error = error.localizedDescription
                        self.showAlert = true
                    }
                }
            }
        }
    }
    
    // MARK: - 带密码加载（密码缓存会存储）
    
    func loadArchiveWithPassword(_ url: URL, password: String, recentManager: RecentFilesManager? = nil) {
        currentArchive = url
        recentManager?.add(url)
        
        // ✅ 存储密码到缓存（供后续提取使用）
        PasswordCache.shared.setPassword(password, for: url.path)
        
        loader.loadArchiveWithPassword(url, password: password) { [weak self] result in
            DispatchQueue.main.async {
                self?.handleLoadResult(result, url: url, usedPassword: password)
            }
        }
    }
    
    private func handleLoadResult(_ result: Result<[ArchiveEntry], ArchiveError>, url: URL, usedPassword: String?) {
        switch result {
        case .success(let entries):
            self.entries = entries
            self.selectedArchiveIDs.removeAll()
            print("✅ [ArchiveManager] Loaded \(entries.count) entries")
            
        case .failure(let error):
            if error == .wrongPassword {
                // ✅ 密码错误，清除缓存
                PasswordCache.shared.clearPassword(for: url.path)
                self.error = "archive.password.wrong".localized
                self.showAlert = true
                // 重新弹窗
                NotificationCenter.default.post(
                    name: .showPasswordDialogNotification,
                    object: nil,
                    userInfo: [
                        "archiveURL": url,
                        "format": url.pathExtension.lowercased(),
                        "isLoading": true,
                        "retry": true,
                        "error": "archive.password.wrong".localized
                    ]
                )
            } else if error == .passwordRequired {
                // 仍需要密码（理论上不会发生）
                NotificationCenter.default.post(
                    name: .showPasswordDialogNotification,
                    object: nil,
                    userInfo: [
                        "archiveURL": url,
                        "format": url.pathExtension.lowercased(),
                        "isLoading": true
                    ]
                )
            } else {
                self.error = error.localizedDescription
                self.showAlert = true
            }
        }
    }
    
    // MARK: - 提取归档（优先使用缓存密码）
    
    func extractArchive(to destination: URL, password: String? = nil) {
        guard let source = currentArchive else { return }
        
        let ext = source.pathExtension.lowercased()
        var finalPassword = password
        
        // ✅ 如果是 7z/RAR 且没有提供密码，尝试从缓存获取
        if (ext == "7z" || ext == "rar") && (password == nil || password?.isEmpty == true) {
            if let cachedPassword = PasswordCache.shared.peekPassword(for: source.path) {
                print("🔑 [ArchiveManager] Using cached password for extraction: \(source.lastPathComponent)")
                finalPassword = cachedPassword
            }
        }
        
        DispatchQueue.main.async {
            self.isProcessing = true
            self.progress = 0
        }
        
        performExtract(source, to: destination, password: finalPassword)
    }
    
    private func performExtract(_ source: URL, to destination: URL, password: String?) {
        extractor.extract(source, to: destination, password: password) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isProcessing = false
                self.progress = 1.0
                
                switch result {
                case .success:
                    // ✅ 提取成功，清除密码缓存（一次性使用）
                    if password != nil && !password!.isEmpty {
                        PasswordCache.shared.clearPassword(for: source.path)
                        print("🔑 [ArchiveManager] Password used and cleared for: \(source.lastPathComponent)")
                    }
                    self.error = String(format: "archive.extraction.complete".localized, source.lastPathComponent)
                    self.showAlert = true
                    
                case .failure(let error):
                    if error == .passwordRequired || error == .wrongPassword {
                        // 需要密码或密码错误
                        if let pwd = password, !pwd.isEmpty {
                            // 提供的密码错误 → 清除缓存
                            PasswordCache.shared.clearPassword(for: source.path)
                            print("❌ [ArchiveManager] Wrong password, cleared cache")
                        }
                        
                        NotificationCenter.default.post(
                            name: .showPasswordDialogNotification,
                            object: nil,
                            userInfo: [
                                "archiveURL": source,
                                "destination": destination,
                                "format": source.pathExtension.lowercased(),
                                "isExtractAll": true,
                                "retry": password != nil && !password!.isEmpty
                            ]
                        )
                        return
                    }
                    
                    if error.isPasswordError {
                        self.error = "archive.password.wrong".localized
                    } else {
                        self.error = "archive.extraction.failed".localized + ": " + error.localizedDescription
                    }
                    self.showAlert = true
                }
            }
        }
    }
    
    // MARK: - 创建归档
    
    func createArchiveWithEncryption(files: [URL], format: String, name: String, destination: URL, password: String) {
        guard validateToolForFormat(format) else {
            error = "error.tool.not.found".localized(with: format)
            showAlert = true
            return
        }
        
        DispatchQueue.main.async {
            self.isProcessing = true
        }
        
        creator.create(files: files, format: format, name: name, destination: destination, password: password) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isProcessing = false
                
                switch result {
                case .success:
                    self.error = "archive.creation.success".localized
                case .failure(let error):
                    self.error = "archive.creation.failed".localized + ": " + error.localizedDescription
                }
                self.showAlert = true
            }
        }
    }
    
    func createArchive(files: [URL], format: String, name: String, destination: URL) {
        createArchiveWithEncryption(files: files, format: format, name: name, destination: destination, password: "")
    }
    
    // MARK: - 验证工具
    
    private func validateToolForFormat(_ format: String) -> Bool {
        if format == "rar" || format == "7z" {
            return toolResolver.resolve(format == "rar" ? "rar" : "7zz") != nil
        }
        return true
    }
    
    func getExtension(for format: String) -> String {
        return ["zip": "zip", "tar": "tar", "gz": "tar.gz", "7z": "7z", "rar": "rar"][format] ?? "zip"
    }
    
    // MARK: - 批量删除
    
    func deleteEntries(_ entries: [ArchiveEntry], completion: @escaping (Result<Int, ArchiveError>) -> Void) {
        guard !entries.isEmpty else {
            completion(.success(0))
            return
        }
        
        guard let archive = currentArchive,
              let toolPath = toolResolver.resolve("7zz") else {
            completion(.failure(.toolNotFound("7zz")))
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
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
                    if process.terminationStatus == 0 {
                        completion(.success(fileNames.count))
                    } else {
                        completion(.failure(.commandFailed(errorMsg)))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.commandFailed(error.localizedDescription)))
                }
            }
        }
    }
}
