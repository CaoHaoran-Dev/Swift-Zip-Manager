//
//  ToolInstaller.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI
import CryptoKit

class ToolInstaller: ObservableObject {
    @Published var isInstalling = false
    @Published var installProgress: Double = 0
    @Published var installMessage = ""
    @Published var downloadProgress: Double = 0
    
    private let fileManager = FileManager.default
    private let toolResolver = ToolPathResolver()
    
    /// 重试配置
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 2.0
    
    /// 应用支持目录下的工具路径
    private var installPath: String {
        let home = fileManager.homeDirectoryForCurrentUser.path
        let path = "\(home)/Library/Application Support/com.haoran.Swift-Zip-Manager/tools"
        try? fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }
    
    // MARK: - 公开接口
    
    func checkTools() -> [String] {
        let missing = toolResolver.getMissingTools()
        print("🔍 Tool check result: missing = \(missing)")
        return missing
    }
    
    func checkTool(_ command: String) -> Bool {
        return toolResolver.isInstalled(command)
    }
    
    func installTools(_ tools: [String], progress: @escaping (Double, String) -> Void, completion: @escaping (Bool, String) -> Void) {
        isInstalling = true
        installProgress = 0
        installMessage = ""
        downloadProgress = 0
        
        DispatchQueue.global(qos: .userInitiated).async {
            var allSuccess = true
            var outputMessage = ""
            
            for (index, tool) in tools.enumerated() {
                let toolName = tool
                let displayName = toolName == "7zz" ? "7-Zip" : "RAR"
                progress(Double(index) / Double(tools.count), String(format: "tools.install.downloading".localized, displayName))
                
                let success: Bool
                if toolName == "7zz" {
                    success = self.install7zzWithRetry(progress: { p, msg in
                        DispatchQueue.main.async {
                            self.downloadProgress = p
                            progress(Double(index + Int(p)) / Double(tools.count), msg)
                        }
                    })
                } else if toolName == "rar" {
                    success = self.installRARWithRetry(progress: { p, msg in
                        DispatchQueue.main.async {
                            self.downloadProgress = p
                            progress(Double(index + Int(p)) / Double(tools.count), msg)
                        }
                    })
                } else {
                    success = false
                }
                
                if !success {
                    allSuccess = false
                    outputMessage = String(format: "tools.install.failed".localized, displayName)
                    break
                }
            }
            
            // 安装完成后刷新缓存
            if allSuccess {
                self.toolResolver.invalidateCache()
            }
            
            progress(1.0, "tools.install.complete".localized)
            DispatchQueue.main.async {
                self.isInstalling = false
                self.installProgress = 1.0
                completion(allSuccess, outputMessage)
            }
        }
    }
    
    // MARK: - 7zz 安装（带重试）
    
    private func install7zzWithRetry(progress: @escaping (Double, String) -> Void) -> Bool {
        for attempt in 1...maxRetries {
            progress(0.0, String(format: "tools.install.retry".localized, attempt, maxRetries))
            
            let installSuccess = install7zz(progress: progress)
            
            if installSuccess {
                let destPath = "\(installPath)/7zz"
                if fileManager.fileExists(atPath: destPath) && fileManager.isExecutableFile(atPath: destPath) {
                    print("✅ 7zz installed successfully")
                    return true
                }
            }
            
            if attempt < maxRetries {
                Thread.sleep(forTimeInterval: retryDelay)
            }
        }
        return false
    }
    
    private func install7zz(progress: @escaping (Double, String) -> Void) -> Bool {
        guard let url = URL(string: AppConstants.ToolDownloadURL.sevenzz) else {
            print("❌ Invalid 7zz download URL")
            return false
        }
        
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }
        
        let archivePath = tempDir.appendingPathComponent("7zz.tar.xz")
        
        // 1. 下载
        progress(0.1, "tools.install.downloading".localized)
        guard downloadFile(from: url, to: archivePath, progress: { p in
            progress(0.1 + p * 0.6, String(format: "tools.install.downloading".localized + " \(Int(p * 100))%"))
        }) else {
            print("❌ Failed to download 7zz")
            return false
        }
        
        // 2. 获取 SHA256（从缓存获取，否则使用硬编码备份）
        let expectedSHA = SevenzzVersionCache.shared.getLatestSHA() ?? AppConstants.ToolChecksums.sevenzzFallback
        
        // 3. 用 CryptoKit 校验
        if !verifyPackageIntegrity(at: archivePath, expectedSHA256: expectedSHA) {
            print("❌ 7zz package integrity check failed")
            return false
        }
        print("✅ 7zz package integrity verified")
        
        // 4. 解压
        progress(0.7, "tools.install.extracting".localized)
        let extractProcess = Process()
        extractProcess.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        extractProcess.arguments = ["-xf", archivePath.path, "-C", tempDir.path]
        try? extractProcess.run()
        extractProcess.waitUntilExit()
        
        if extractProcess.terminationStatus != 0 {
            print("❌ Failed to extract 7zz")
            return false
        }
        
        // 5. 查找 7zz 可执行文件
        guard let foundPath = findFile(named: "7zz", in: tempDir) else {
            print("❌ 7zz not found in extracted files")
            return false
        }
        
        // 6. 复制到 App Support
        progress(0.9, "tools.install.installing".localized)
        let destPath = "\(installPath)/7zz"
        try? fileManager.removeItem(atPath: destPath)
        try? fileManager.copyItem(atPath: foundPath, toPath: destPath)
        try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destPath)
        
        // 验证安装
        let success = fileManager.fileExists(atPath: destPath) && fileManager.isExecutableFile(atPath: destPath)
        print(success ? "✅ 7zz installed to: \(destPath)" : "❌ Failed to install 7zz")
        progress(1.0, "tools.install.complete".localized)
        return success
    }
    
    // MARK: - RAR 安装（带重试）
    
    private func installRARWithRetry(progress: @escaping (Double, String) -> Void) -> Bool {
        for attempt in 1...maxRetries {
            progress(0.0, String(format: "tools.install.retry".localized, attempt, maxRetries))
            
            let installSuccess = installRAR(progress: progress)
            
            if installSuccess {
                let destPath = "\(installPath)/rar"
                if fileManager.fileExists(atPath: destPath) && fileManager.isExecutableFile(atPath: destPath) {
                    print("✅ RAR installed successfully")
                    return true
                }
            }
            
            if attempt < maxRetries {
                Thread.sleep(forTimeInterval: retryDelay)
            }
        }
        return false
    }
    
    private func installRAR(progress: @escaping (Double, String) -> Void) -> Bool {
        guard let url = URL(string: AppConstants.ToolDownloadURL.rar) else {
            print("❌ Invalid RAR download URL")
            return false
        }
        
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }
        
        let archivePath = tempDir.appendingPathComponent("rar.tar.gz")
        
        // 1. 下载
        progress(0.1, "tools.install.downloading".localized)
        guard downloadFile(from: url, to: archivePath, progress: { p in
            progress(0.1 + p * 0.6, String(format: "tools.install.downloading".localized + " \(Int(p * 100))%"))
        }) else {
            print("❌ Failed to download RAR")
            return false
        }
        
        // 2. 用 CryptoKit 校验（使用硬编码的 SHA256）
        if !verifyPackageIntegrity(at: archivePath, expectedSHA256: AppConstants.ToolChecksums.rar) {
            print("❌ RAR package integrity check failed")
            return false
        }
        print("✅ RAR package integrity verified")
        
        // 3. 解压
        progress(0.7, "tools.install.extracting".localized)
        let extractProcess = Process()
        extractProcess.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        extractProcess.arguments = ["-xzf", archivePath.path, "-C", tempDir.path]
        try? extractProcess.run()
        extractProcess.waitUntilExit()
        
        if extractProcess.terminationStatus != 0 {
            print("❌ Failed to extract RAR")
            return false
        }
        
        // 4. 查找 rar 可执行文件
        guard let foundPath = findFile(named: "rar", in: tempDir) else {
            print("❌ RAR not found in extracted files")
            return false
        }
        
        // 5. 复制到 App Support
        progress(0.9, "tools.install.installing".localized)
        let destPath = "\(installPath)/rar"
        try? fileManager.removeItem(atPath: destPath)
        try? fileManager.copyItem(atPath: foundPath, toPath: destPath)
        try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destPath)
        
        // 验证安装
        let success = fileManager.fileExists(atPath: destPath) && fileManager.isExecutableFile(atPath: destPath)
        print(success ? "✅ RAR installed to: \(destPath)" : "❌ Failed to install RAR")
        progress(1.0, "tools.install.complete".localized)
        return success
    }
    
    // MARK: - CryptoKit SHA256 校验
    
    private func calculateSHA256(for fileURL: URL) -> String? {
        guard let fileHandle = FileHandle(forReadingAtPath: fileURL.path) else {
            print("❌ Cannot open file for SHA256 calculation")
            return nil
        }
        defer { try? fileHandle.close() }
        
        var hasher = SHA256()
        while let data = try? fileHandle.read(upToCount: 1024 * 1024), !data.isEmpty {
            hasher.update(data: data)
        }
        
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    private func verifyPackageIntegrity(at path: URL, expectedSHA256: String) -> Bool {
        guard !expectedSHA256.isEmpty else {
            print("⚠️ No expected SHA256 provided, skipping verification")
            return true
        }
        
        guard let calculated = calculateSHA256(for: path) else {
            print("❌ Failed to calculate SHA256 for package")
            return false
        }
        
        let result = calculated.lowercased() == expectedSHA256.lowercased()
        if result {
            print("✅ Package SHA256 verified")
        } else {
            print("❌ SHA256 mismatch: expected \(expectedSHA256), got \(calculated)")
        }
        return result
    }
    
    // MARK: - Helper Methods
    
    private func findFile(named name: String, in directory: URL) -> String? {
        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            return nil
        }
        
        for case let url as URL in enumerator {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
               !isDirectory.boolValue,
               url.lastPathComponent == name {
                return url.path
            }
        }
        return nil
    }
    
    private func downloadFile(from url: URL, to destination: URL, progress: @escaping (Double) -> Void) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var success = false
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 300
        let session = URLSession(configuration: config)
        
        let task = session.downloadTask(with: url) { tempURL, response, error in
            if let tempURL = tempURL, error == nil {
                do {
                    if self.fileManager.fileExists(atPath: destination.path) {
                        try self.fileManager.removeItem(at: destination)
                    }
                    try self.fileManager.moveItem(at: tempURL, to: destination)
                    success = true
                } catch {
                    print("Download move error: \(error)")
                }
            } else if let error = error {
                print("Download failed: \(error)")
            }
            semaphore.signal()
        }
        
        let observation = task.progress.observe(\.fractionCompleted) { progressObj, _ in
            DispatchQueue.main.async {
                progress(progressObj.fractionCompleted)
            }
        }
        
        task.resume()
        semaphore.wait()
        observation.invalidate()
        
        return success
    }
    
    func deleteTools() -> Bool {
        do {
            try fileManager.removeItem(atPath: installPath)
            toolResolver.invalidateCache()
            print("✅ Tools deleted from: \(installPath)")
            return true
        } catch {
            print("❌ Failed to delete tools: \(error)")
            return false
        }
    }
}
