//
//  ToolInstaller.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

class ToolInstaller: ObservableObject {
    @Published var isInstalling = false
    @Published var installProgress: Double = 0
    @Published var installMessage = ""
    @Published var downloadProgress: Double = 0  // ✅ #17: 下载进度
    
    private let fileManager = FileManager.default
    private let toolResolver = ToolPathResolver()
    
    /// 应用支持目录下的工具路径
    private var installPath: String {
        let home = fileManager.homeDirectoryForCurrentUser.path
        let path = "\(home)/Library/Application Support/com.haoran.Swift-Zip-Manager/tools"
        try? fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }
    
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
                progress(Double(index) / Double(tools.count), "Installing \(toolName)...")
                
                let success: Bool
                if toolName == "7zz" {
                    success = self.install7zz(progress: { p, msg in
                        DispatchQueue.main.async {
                            self.downloadProgress = p
                            progress(Double(index + Int(p)) / Double(tools.count), msg)
                        }
                    })
                } else if toolName == "rar" {
                    success = self.installRAR(progress: { p, msg in
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
                    outputMessage = "Failed to install \(toolName)"
                    break
                }
            }
            
            // ✅ #18: 安装完成后刷新缓存
            if allSuccess {
                self.toolResolver.invalidateCache()
            }
            
            progress(1.0, "Installation complete")
            DispatchQueue.main.async {
                self.isInstalling = false
                self.installProgress = 1.0
                completion(allSuccess, outputMessage)
            }
        }
    }
    
    // MARK: - 7zz 安装（带进度）
    
    private func install7zz(progress: @escaping (Double, String) -> Void) -> Bool {
        guard let url = URL(string: AppConstants.ToolDownloadURL.sevenzz) else {
            print("❌ Invalid 7zz download URL")
            return false
        }
        
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }
        
        let archivePath = tempDir.appendingPathComponent("7zz.tar.xz")
        
        // 1. 下载（带进度）
        progress(0.1, "Downloading 7zz...")
        guard downloadFile(from: url, to: archivePath, progress: { p in
            progress(0.1 + p * 0.6, "Downloading 7zz... \(Int(p * 100))%")
        }) else {
            print("❌ Failed to download 7zz")
            return false
        }
        
        // 2. 解压
        progress(0.7, "Extracting 7zz...")
        let extractProcess = Process()
        extractProcess.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        extractProcess.arguments = ["-xf", archivePath.path, "-C", tempDir.path]
        try? extractProcess.run()
        extractProcess.waitUntilExit()
        
        if extractProcess.terminationStatus != 0 {
            print("❌ Failed to extract 7zz")
            return false
        }
        
        // 3. 查找 7zz 可执行文件
        guard let foundPath = findFile(named: "7zz", in: tempDir) else {
            print("❌ 7zz not found in extracted files")
            return false
        }
        
        // 4. 确保目标目录存在
        try? fileManager.createDirectory(atPath: installPath, withIntermediateDirectories: true)
        
        // 5. 复制到 App Support
        progress(0.9, "Installing 7zz...")
        let destPath = "\(installPath)/7zz"
        try? fileManager.removeItem(atPath: destPath)
        try? fileManager.copyItem(atPath: foundPath, toPath: destPath)
        try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destPath)
        
        // 6. 验证安装
        let success = fileManager.fileExists(atPath: destPath) && fileManager.isExecutableFile(atPath: destPath)
        print(success ? "✅ 7zz installed to: \(destPath)" : "❌ Failed to install 7zz")
        progress(1.0, "7zz installed")
        return success
    }
    
    // MARK: - RAR 安装（带进度）
    
    private func installRAR(progress: @escaping (Double, String) -> Void) -> Bool {
        guard let url = URL(string: AppConstants.ToolDownloadURL.rar) else {
            print("❌ Invalid RAR download URL")
            return false
        }
        
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }
        
        let archivePath = tempDir.appendingPathComponent("rar.tar.gz")
        
        // 1. 下载（带进度）
        progress(0.1, "Downloading RAR...")
        guard downloadFile(from: url, to: archivePath, progress: { p in
            progress(0.1 + p * 0.6, "Downloading RAR... \(Int(p * 100))%")
        }) else {
            print("❌ Failed to download RAR")
            return false
        }
        
        // 2. 解压
        progress(0.7, "Extracting RAR...")
        let extractProcess = Process()
        extractProcess.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        extractProcess.arguments = ["-xzf", archivePath.path, "-C", tempDir.path]
        try? extractProcess.run()
        extractProcess.waitUntilExit()
        
        if extractProcess.terminationStatus != 0 {
            print("❌ Failed to extract RAR")
            return false
        }
        
        // 3. 查找 rar 可执行文件
        guard let foundPath = findFile(named: "rar", in: tempDir) else {
            print("❌ RAR not found in extracted files")
            return false
        }
        
        // 4. 确保目标目录存在
        try? fileManager.createDirectory(atPath: installPath, withIntermediateDirectories: true)
        
        // 5. 复制到 App Support
        progress(0.9, "Installing RAR...")
        let destPath = "\(installPath)/rar"
        try? fileManager.removeItem(atPath: destPath)
        try? fileManager.copyItem(atPath: foundPath, toPath: destPath)
        try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destPath)
        
        // 6. 验证安装
        let success = fileManager.fileExists(atPath: destPath) && fileManager.isExecutableFile(atPath: destPath)
        print(success ? "✅ RAR installed to: \(destPath)" : "❌ Failed to install RAR")
        progress(1.0, "RAR installed")
        return success
    }
    
    // MARK: - Helper Methods
    
    private func findFile(named name: String, in directory: URL) -> String? {
        let findProcess = Process()
        let pipe = Pipe()
        findProcess.executableURL = URL(fileURLWithPath: "/usr/bin/find")
        findProcess.arguments = [directory.path, "-name", name, "-type", "f"]
        findProcess.standardOutput = pipe
        
        try? findProcess.run()
        findProcess.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let result = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return result?.isEmpty == false ? result : nil
    }
    
    // ✅ #17: 带进度的下载
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
        
        // ✅ #17: 观察下载进度
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
            // ✅ #18: 删除后刷新缓存
            toolResolver.invalidateCache()
            print("✅ Tools deleted from: \(installPath)")
            return true
        } catch {
            print("❌ Failed to delete tools: \(error)")
            return false
        }
    }
}
