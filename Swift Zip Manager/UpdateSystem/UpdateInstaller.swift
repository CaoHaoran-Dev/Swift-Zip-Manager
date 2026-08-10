//
//  UpdateInstaller.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/10.
//

import Foundation
import AppKit

class UpdateInstaller {
    private let fileManager = FileManager.default
    private let bundleIdentifier = AppConstants.bundleIdentifier
    private let appFileName = AppConstants.appFileName
    
    typealias ProgressHandler = (Double, String) -> Void
    typealias CompletionHandler = (Bool, String) -> Void
    
    // MARK: - 路径属性
    
    private var appSupportFolder: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent(bundleIdentifier)
    }
    
    private var downloadedZipURL: URL {
        return appSupportFolder.appendingPathComponent("update.zip")
    }
    
    private var extractedAppURL: URL {
        return appSupportFolder.appendingPathComponent(appFileName)
    }
    
    private var appContainer: URL {
        return Bundle.main.bundleURL.deletingLastPathComponent()
    }
    
    private var targetAppURL: URL {
        return appContainer.appendingPathComponent(appFileName)
    }
    
    // MARK: - 公开接口
    
    func install(
        from zipURL: URL? = nil,
        progress: @escaping ProgressHandler,
        completion: @escaping CompletionHandler
    ) {
        let sourceURL = zipURL ?? downloadedZipURL
        
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            completion(false, "Update package not found at: \(sourceURL.path)")
            return
        }
        
        do {
            try fileManager.createDirectory(at: appSupportFolder, withIntermediateDirectories: true)
        } catch {
            completion(false, "Failed to create App Support directory: \(error.localizedDescription)")
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                progress(0.2, "Extracting update...")
                try self.extractZip(from: sourceURL)
                
                guard self.fileManager.fileExists(atPath: self.extractedAppURL.path) else {
                    throw InstallError.extractedAppNotFound
                }
                
                progress(0.6, "Installing update...")
                try self.replaceApp()
                
                progress(0.8, "Cleaning up...")
                self.cleanOldFiles()
                
                progress(1.0, "Update complete")
                
                DispatchQueue.main.async {
                    self.showRestartPrompt(completion: completion)
                }
                
            } catch let error as InstallError {
                DispatchQueue.main.async {
                    completion(false, error.localizedDescription)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, "Installation failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func cancelInstallation() {
        cleanOldFiles()
    }
    
    // MARK: - 私有方法
    
    private func extractZip(from sourceURL: URL) throws {
        if fileManager.fileExists(atPath: extractedAppURL.path) {
            try fileManager.removeItem(at: extractedAppURL)
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", sourceURL.path, appSupportFolder.path]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw InstallError.extractionFailed(status: process.terminationStatus)
        }
        
        guard fileManager.fileExists(atPath: extractedAppURL.path) else {
            throw InstallError.extractedAppNotFound
        }
    }
    
    private func replaceApp() throws {
        let targetPath = targetAppURL.path
        
        print("🔄 Replacing app at: \(targetPath)")
        
        if fileManager.fileExists(atPath: targetPath) {
            print("🗑️ Removing old app...")
            try fileManager.removeItem(at: targetAppURL)
        }
        
        print("📦 Moving new app to: \(targetPath)")
        try fileManager.moveItem(at: extractedAppURL, to: targetAppURL)
        
        print("✅ App replacement complete")
    }
    
    private func cleanOldFiles() {
        if fileManager.fileExists(atPath: downloadedZipURL.path) {
            try? fileManager.removeItem(at: downloadedZipURL)
        }
        if fileManager.fileExists(atPath: extractedAppURL.path) {
            try? fileManager.removeItem(at: extractedAppURL)
        }
    }
    
    // MARK: - 重启提示
    
    private func showRestartPrompt(completion: @escaping CompletionHandler) {
        let alert = NSAlert()
        alert.messageText = "settings.updates.complete.title".localized
        alert.informativeText = "settings.updates.complete.message".localized
        alert.alertStyle = .informational
        alert.addButton(withTitle: "settings.updates.complete.restart".localized)
        alert.addButton(withTitle: "settings.updates.complete.later".localized)
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            print("🚀 User chose to restart now")
            launchNewInstanceAndExit(completion: completion)
        } else {
            print("👋 User chose to restart later, exiting...")
            completion(true, "Update installed. Please restart the app manually.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.terminate(nil)
            }
        }
    }
    
    // MARK: - 启动新实例并退出旧实例
    
    private func launchNewInstanceAndExit(completion: @escaping CompletionHandler) {
        let targetPath = targetAppURL
        
        guard fileManager.fileExists(atPath: targetPath.path) else {
            print("❌ Target app not found at: \(targetPath.path)")
            showManualRestartAlert(message: "settings.updates.error.app.missing".localized)
            completion(false, "Target app not found")
            return
        }
        
        print("🚀 Launching new instance: \(targetPath.path)")
        
        // ✅ 使用 /usr/bin/open -n 强制启动新实例
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", targetPath.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                print("✅ New instance launched successfully")
                completion(true, "Update complete, restarting...")
                
                // ✅ 启动成功后，退出旧实例
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    print("🔄 Terminating old instance...")
                    NSApp.terminate(nil)
                }
            } else {
                let errorPipe = process.standardError as? Pipe
                let errorData = errorPipe?.fileHandleForReading.readDataToEndOfFile()
                let errorMsg = errorData.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown error"
                
                print("❌ Failed to launch: \(errorMsg)")
                showManualRestartAlert(message: "Failed to launch: \(errorMsg)")
                completion(false, errorMsg)
            }
        } catch {
            print("❌ Failed to launch: \(error)")
            showManualRestartAlert(message: "Failed to launch: \(error.localizedDescription)")
            completion(false, error.localizedDescription)
        }
    }
    
    private func showManualRestartAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "settings.updates.complete.title".localized
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "alert.ok".localized)
        alert.runModal()
    }
}

// MARK: - 错误类型

enum InstallError: LocalizedError {
    case extractionFailed(status: Int32)
    case extractedAppNotFound
    
    var errorDescription: String? {
        switch self {
        case .extractionFailed(let status):
            return "Failed to extract update package (status: \(status))"
        case .extractedAppNotFound:
            return "Extracted app not found in update package"
        }
    }
}
