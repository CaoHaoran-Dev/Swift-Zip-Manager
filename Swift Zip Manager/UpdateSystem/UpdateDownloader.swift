//
//  UpdateDownloader.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import Foundation
import AppKit

class UpdateDownloader: NSObject, ObservableObject {
    @Published var downloadProgress: Double = 0
    @Published var downloadStatus = ""
    @Published var isDownloading = false
    
    private let fileManager = FileManager.default
    private let bundleIdentifier = AppConstants.bundleIdentifier
    private let targetFileName = AppConstants.targetFileName
    private let appFileName = AppConstants.appFileName
    
    private var downloadTask: URLSessionDownloadTask?
    private var progressObservation: NSKeyValueObservation?
    private var completionHandler: ((Bool, String) -> Void)?
    
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
    
    func downloadAndInstall(from url: URL, progress: @escaping (Double, String) -> Void, completion: @escaping (Bool, String) -> Void) {
        isDownloading = true
        downloadProgress = 0
        downloadStatus = "Downloading..."
        completionHandler = completion
        
        try? fileManager.createDirectory(at: appSupportFolder, withIntermediateDirectories: true)
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        let session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        
        downloadTask = session.downloadTask(with: url)
        
        progressObservation = downloadTask?.progress.observe(\.fractionCompleted) { [weak self] progressObj, _ in
            DispatchQueue.main.async {
                self?.downloadProgress = progressObj.fractionCompleted
                let percent = Int(progressObj.fractionCompleted * 100)
                self?.downloadStatus = "Downloading... \(percent)%"
                progress(progressObj.fractionCompleted, self?.downloadStatus ?? "")
            }
        }
        
        downloadTask?.resume()
    }
    
    func cancelDownload() {
        downloadTask?.cancel()
        progressObservation?.invalidate()
        progressObservation = nil
        isDownloading = false
        downloadProgress = 0
        downloadStatus = ""
        completionHandler = nil
    }
    
    private func extractZip() throws {
        if fileManager.fileExists(atPath: extractedAppURL.path) {
            try fileManager.removeItem(at: extractedAppURL)
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", downloadedZipURL.path, appSupportFolder.path]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw NSError(domain: "ExtractError", code: Int(process.terminationStatus))
        }
        
        guard fileManager.fileExists(atPath: extractedAppURL.path) else {
            throw NSError(domain: "ExtractError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Extracted app not found"])
        }
    }
    
    private func performUpdate(completion: @escaping (Bool, String) -> Void) {
        let appPath = Bundle.main.bundleURL
        let targetPath = appPath.deletingLastPathComponent().appendingPathComponent(appFileName)
        
        do {
            if fileManager.fileExists(atPath: targetPath.path) {
                try fileManager.removeItem(at: targetPath)
            }
            try fileManager.moveItem(at: extractedAppURL, to: targetPath)
            
            // 启动新应用
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                _ = NSWorkspace.shared.open(targetPath)
            }
            
            // 清理
            cleanOldFiles()
            completion(true, "Update complete")
        } catch {
            completion(false, error.localizedDescription)
        }
    }
    
    private func cleanOldFiles() {
        if fileManager.fileExists(atPath: downloadedZipURL.path) {
            try? fileManager.removeItem(at: downloadedZipURL)
        }
        if fileManager.fileExists(atPath: extractedAppURL.path) {
            try? fileManager.removeItem(at: extractedAppURL)
        }
    }
}

extension UpdateDownloader: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            do {
                if self.fileManager.fileExists(atPath: self.downloadedZipURL.path) {
                    try self.fileManager.removeItem(at: self.downloadedZipURL)
                }
                try self.fileManager.moveItem(at: location, to: self.downloadedZipURL)
                
                self.downloadStatus = "Extracting..."
                try self.extractZip()
                
                self.performUpdate { success, message in
                    self.isDownloading = false
                    self.completionHandler?(success, message)
                    self.completionHandler = nil
                }
            } catch {
                self.isDownloading = false
                self.completionHandler?(false, error.localizedDescription)
                self.completionHandler = nil
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async { [weak self] in
                self?.isDownloading = false
                self?.completionHandler?(false, error.localizedDescription)
                self?.completionHandler = nil
            }
        }
    }
}
