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
    
    private var isInstalling = false
    private var shouldCancel = false
    
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
        guard !isInstalling else {
            completion(false, "Installation already in progress")
            return
        }
        
        isInstalling = true
        shouldCancel = false
        
        let sourceURL = zipURL ?? downloadedZipURL
        
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            isInstalling = false
            completion(false, "Update package not found")
            return
        }
        
        print("📦 [UpdateInstaller] Starting installation...")
        
        do {
            try fileManager.createDirectory(at: appSupportFolder, withIntermediateDirectories: true)
        } catch {
            isInstalling = false
            completion(false, "Failed to create directory: \(error.localizedDescription)")
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                progress(0.2, "Extracting...")
                try self.extractZip(from: sourceURL)
                
                guard self.fileManager.fileExists(atPath: self.extractedAppURL.path) else {
                    throw InstallError.extractedAppNotFound
                }
                
                progress(0.6, "Installing...")
                try self.replaceApp()
                
                progress(0.8, "Cleaning up...")
                self.cleanOldFiles()
                
                progress(1.0, "Complete")
                UserDefaults.standard.synchronize()
                
                DispatchQueue.main.async {
                    self.isInstalling = false
                    self.showRestartPrompt(completion: completion)
                }
                
            } catch let error as InstallError {
                DispatchQueue.main.async {
                    self.isInstalling = false
                    completion(false, error.localizedDescription)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isInstalling = false
                    completion(false, "Installation failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func cancelInstallation() {
        shouldCancel = true
    }
    
    // MARK: - 私有方法
    
    private func extractZip(from sourceURL: URL) throws {
        if fileManager.fileExists(atPath: extractedAppURL.path) {
            try fileManager.removeItem(at: extractedAppURL)
        }
        
        let tempExtractDir = appSupportFolder.appendingPathComponent("extracted_temp")
        try? fileManager.removeItem(at: tempExtractDir)
        try fileManager.createDirectory(at: tempExtractDir, withIntermediateDirectories: true)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", sourceURL.path, tempExtractDir.path]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw InstallError.extractionFailed(status: process.terminationStatus)
        }
        
        let contents = try fileManager.contentsOfDirectory(at: tempExtractDir, includingPropertiesForKeys: nil)
        guard let extractedApp = contents.first(where: { $0.pathExtension == "app" }) else {
            throw InstallError.extractedAppNotFound
        }
        
        try fileManager.moveItem(at: extractedApp, to: extractedAppURL)
        try? fileManager.removeItem(at: tempExtractDir)
    }
    
    private func replaceApp() throws {
        let targetPath = targetAppURL.path
        
        if fileManager.fileExists(atPath: targetPath) {
            try fileManager.removeItem(at: targetAppURL)
        }
        
        try fileManager.moveItem(at: extractedAppURL, to: targetAppURL)
    }
    
    private func cleanOldFiles() {
        try? fileManager.removeItem(at: downloadedZipURL)
        try? fileManager.removeItem(at: extractedAppURL)
    }
    
    // MARK: - 重启
    
    private func showRestartPrompt(completion: @escaping CompletionHandler) {
        let alert = NSAlert()
        alert.messageText = "settings.updates.complete.title".localized
        alert.informativeText = "settings.updates.complete.message".localized
        alert.alertStyle = .informational
        alert.addButton(withTitle: "settings.updates.complete.restart".localized)
        alert.addButton(withTitle: "settings.updates.complete.later".localized)
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            launchNewInstanceAndExit(completion: completion)
        } else {
            completion(true, "Update installed. Please restart manually.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.terminate(nil)
            }
        }
    }
    
    private func launchNewInstanceAndExit(completion: @escaping CompletionHandler) {
        let targetPath = targetAppURL
        
        guard fileManager.fileExists(atPath: targetPath.path) else {
            completion(false, "Target app not found")
            return
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", targetPath.path]
        
        do {
            try process.run()
            completion(true, "Update complete, restarting...")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                NSApp.terminate(nil)
            }
        } catch {
            completion(false, error.localizedDescription)
        }
    }
}

// MARK: - 错误类型

enum InstallError: LocalizedError {
    case extractionFailed(status: Int32)
    case extractedAppNotFound
    
    var errorDescription: String? {
        switch self {
        case .extractionFailed(let status):
            return "Extraction failed (status: \(status))"
        case .extractedAppNotFound:
            return "Extracted app not found"
        }
    }
}
