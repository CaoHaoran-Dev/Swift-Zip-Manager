//
//  ToolInstaller.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI
import Security

class ToolInstaller: ObservableObject {
    @Published var isInstalling = false
    @Published var installProgress: Double = 0
    @Published var installMessage = ""
    
    private let toolResolver = ToolPathResolver()
    private let fileManager = FileManager.default
    
    private var installPath: String {
        let home = fileManager.homeDirectoryForCurrentUser.path
        let path = "\(home)/Library/Application Support/com.haoran.Swift-Zip-Manager/tools"
        try? fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }
    
    func checkTools() -> [String] {
        var missing: [String] = []
        if !toolResolver.isInstalled("7zz") { missing.append("7zz") }
        if !toolResolver.isInstalled("rar") { missing.append("rar") }
        return missing
    }
    
    func installTools(_ tools: [String], progress: @escaping (Double, String) -> Void, completion: @escaping (Bool, String) -> Void) {
        isInstalling = true
        installProgress = 0
        installMessage = ""
        
        DispatchQueue.global(qos: .userInitiated).async {
            var allSuccess = true
            var outputMessage = ""
            
            for (index, tool) in tools.enumerated() {
                progress(Double(index) / Double(tools.count), "Installing \(tool)...")
                
                let success: Bool
                if tool == "7zz" {
                    success = self.install7zz()
                } else if tool == "rar" {
                    success = self.installRAR()
                } else {
                    success = false
                }
                
                if !success {
                    allSuccess = false
                    outputMessage = "Failed to install \(tool)"
                    break
                }
            }
            
            progress(1.0, "Installation complete")
            DispatchQueue.main.async {
                self.isInstalling = false
                self.installProgress = 1.0
                completion(allSuccess, outputMessage)
            }
        }
    }
    
    private func install7zz() -> Bool {
        guard let url = URL(string: AppConstants.ToolDownloadURL.sevenzz) else { return false }
        
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let archivePath = tempDir.appendingPathComponent("7zz.tar.xz")
        
        guard downloadFile(from: url, to: archivePath) else { return false }
        
        // 解压
        let extractProcess = Process()
        extractProcess.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        extractProcess.arguments = ["-xf", archivePath.path, "-C", tempDir.path]
        try? extractProcess.run()
        extractProcess.waitUntilExit()
        
        // 查找 7zz
        guard let foundPath = findFile(named: "7zz", in: tempDir) else {
            try? fileManager.removeItem(at: tempDir)
            return false
        }
        
        let destPath = "\(installPath)/7zz"
        try? fileManager.removeItem(atPath: destPath)
        try? fileManager.copyItem(atPath: foundPath, toPath: destPath)
        try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destPath)
        
        try? fileManager.removeItem(at: tempDir)
        return fileManager.fileExists(atPath: destPath)
    }
    
    private func installRAR() -> Bool {
        guard let url = URL(string: AppConstants.ToolDownloadURL.rar) else { return false }
        
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let archivePath = tempDir.appendingPathComponent("rar.tar.gz")
        
        guard downloadFile(from: url, to: archivePath) else { return false }
        
        let extractProcess = Process()
        extractProcess.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        extractProcess.arguments = ["-xzf", archivePath.path, "-C", tempDir.path]
        try? extractProcess.run()
        extractProcess.waitUntilExit()
        
        guard let foundPath = findFile(named: "rar", in: tempDir) else {
            try? fileManager.removeItem(at: tempDir)
            return false
        }
        
        let destPath = "\(installPath)/rar"
        try? fileManager.removeItem(atPath: destPath)
        try? fileManager.copyItem(atPath: foundPath, toPath: destPath)
        try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destPath)
        
        try? fileManager.removeItem(at: tempDir)
        return fileManager.fileExists(atPath: destPath)
    }
    
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
    
    private func downloadFile(from url: URL, to destination: URL) -> Bool {
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
        task.resume()
        semaphore.wait()
        
        return success
    }
    
    func deleteTools() -> Bool {
        try? fileManager.removeItem(atPath: installPath)
        return true
    }
}
