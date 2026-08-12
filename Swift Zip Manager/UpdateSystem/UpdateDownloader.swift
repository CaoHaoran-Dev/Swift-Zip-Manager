//
//  UpdateDownloader.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import Foundation
import AppKit
import CryptoKit

class UpdateDownloader: NSObject, ObservableObject {
    @Published var downloadProgress: Double = 0
    @Published var downloadStatus = ""
    @Published var isDownloading = false
    
    private let fileManager = FileManager.default
    private let bundleIdentifier = AppConstants.bundleIdentifier
    
    private var downloadTask: URLSessionDownloadTask?
    private var progressObservation: NSKeyValueObservation?
    private var completionHandler: ((Result<URL, Error>) -> Void)?
    
    private var downloadedZipURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = appSupport.appendingPathComponent(bundleIdentifier)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("update.zip")
    }
    
    // MARK: - 公开接口
    
    func download(
        from url: URL,
        expectedSHA256: String? = nil,
        progress: @escaping (Double, String) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        if isDownloading {
            cancelDownload()
        }
        
        isDownloading = true
        downloadProgress = 0
        downloadStatus = "Starting download..."
        completionHandler = completion
        
        let targetFolder = downloadedZipURL.deletingLastPathComponent()
        try? fileManager.createDirectory(at: targetFolder, withIntermediateDirectories: true)
        
        if fileManager.fileExists(atPath: downloadedZipURL.path) {
            try? fileManager.removeItem(at: downloadedZipURL)
        }
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
        
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        config.httpAdditionalHeaders = [
            "User-Agent": "Swift-Zip-Manager/\(appVersion) (macOS)",
            "Accept": "application/octet-stream"
        ]
        config.httpShouldUsePipelining = true
        
        let session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        
        downloadTask = session.downloadTask(with: url)
        downloadTask?.expectedSHA256 = expectedSHA256
        
        progressObservation = downloadTask?.progress.observe(\.fractionCompleted) { [weak self] progressObj, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.downloadProgress = progressObj.fractionCompleted
                let percent = Int(progressObj.fractionCompleted * 100)
                self.downloadStatus = "Downloading... \(percent)%"
                progress(progressObj.fractionCompleted, self.downloadStatus)
            }
        }
        
        print("📥 [Downloader] Starting download from: \(url)")
        if let sha = expectedSHA256, !sha.isEmpty {
            print("📥 [Downloader] Expected SHA256: \(sha.prefix(16))...")
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
        
        if fileManager.fileExists(atPath: downloadedZipURL.path) {
            try? fileManager.removeItem(at: downloadedZipURL)
        }
        
        completionHandler = nil
        print("📥 [Downloader] Download cancelled")
    }
    
    func getDownloadedZipURL() -> URL? {
        guard fileManager.fileExists(atPath: downloadedZipURL.path) else {
            return nil
        }
        return downloadedZipURL
    }
    
    // MARK: - SHA256 校验
    
    private func verifySHA256(at url: URL, expected: String) -> Bool {
        guard let fileHandle = FileHandle(forReadingAtPath: url.path) else {
            print("❌ [Downloader] Cannot open file for SHA256")
            return false
        }
        defer { try? fileHandle.close() }
        
        var hasher = SHA256()
        while let data = try? fileHandle.read(upToCount: 1024 * 1024), !data.isEmpty {
            hasher.update(data: data)
        }
        
        let digest = hasher.finalize()
        let calculated = digest.map { String(format: "%02x", $0) }.joined()
        
        let result = calculated.lowercased() == expected.lowercased()
        if result {
            print("✅ [Downloader] SHA256 verified: \(calculated.prefix(16))...")
        } else {
            print("❌ [Downloader] SHA256 mismatch: expected \(expected.prefix(16))..., got \(calculated.prefix(16))...")
        }
        return result
    }
    
    // MARK: - ZIP 完整性验证（备用）
    
    private func verifyZipIntegrity(at url: URL) -> Bool {
        guard let attrs = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64,
              size > 0 else {
            print("❌ [Downloader] ZIP file is empty")
            return false
        }
        print("📥 [Downloader] ZIP size: \(size) bytes")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", url.path, "/dev/null"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                print("✅ [Downloader] ZIP integrity verified")
                return true
            } else {
                print("❌ [Downloader] ZIP integrity check failed")
                return false
            }
        } catch {
            print("❌ [Downloader] ZIP integrity check error: \(error)")
            return false
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension UpdateDownloader: URLSessionDownloadDelegate {
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        print("📥 [Downloader] Download finished, moving file...")
        
        do {
            if fileManager.fileExists(atPath: downloadedZipURL.path) {
                try fileManager.removeItem(at: downloadedZipURL)
            }
            
            try fileManager.moveItem(at: location, to: downloadedZipURL)
            
            let expectedSHA = downloadTask.expectedSHA256
            
            if let sha = expectedSHA, !sha.isEmpty {
                guard verifySHA256(at: downloadedZipURL, expected: sha) else {
                    try? fileManager.removeItem(at: downloadedZipURL)
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.isDownloading = false
                        self.downloadStatus = "Download failed - SHA256 mismatch"
                        self.progressObservation?.invalidate()
                        self.progressObservation = nil
                        self.completionHandler?(.failure(NSError(
                            domain: "UpdateDownloader",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "SHA256 mismatch - file may be corrupted"]
                        )))
                        self.completionHandler = nil
                    }
                    return
                }
            } else {
                guard verifyZipIntegrity(at: downloadedZipURL) else {
                    try? fileManager.removeItem(at: downloadedZipURL)
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.isDownloading = false
                        self.downloadStatus = "Download failed - corrupt file"
                        self.progressObservation?.invalidate()
                        self.progressObservation = nil
                        self.completionHandler?(.failure(NSError(
                            domain: "UpdateDownloader",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Downloaded file is corrupt or invalid"]
                        )))
                        self.completionHandler = nil
                    }
                    return
                }
            }
            
            print("✅ [Downloader] Download verified and saved to: \(downloadedZipURL.path)")
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isDownloading = false
                self.downloadStatus = "Download complete"
                self.progressObservation?.invalidate()
                self.progressObservation = nil
                self.completionHandler?(.success(self.downloadedZipURL))
                self.completionHandler = nil
            }
            
        } catch {
            print("❌ [Downloader] Failed to move downloaded file: \(error)")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isDownloading = false
                self.downloadStatus = "Download failed"
                self.progressObservation?.invalidate()
                self.progressObservation = nil
                self.completionHandler?(.failure(error))
                self.completionHandler = nil
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                print("📥 [Downloader] Download cancelled by user")
                return
            }
            
            print("❌ [Downloader] Download error: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isDownloading = false
                self.downloadStatus = "Download failed"
                self.progressObservation?.invalidate()
                self.progressObservation = nil
                self.completionHandler?(.failure(error))
                self.completionHandler = nil
            }
        }
    }
}

// MARK: - URLSessionTaskDelegate

extension UpdateDownloader: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        print("🔄 [Downloader] Redirecting to: \(request.url?.absoluteString ?? "nil")")
        completionHandler(request)
    }
}

// MARK: - 存储期望 SHA256 到 Task

private var expectedSHA256Key: UInt8 = 0

extension URLSessionTask {
    var expectedSHA256: String? {
        get {
            return objc_getAssociatedObject(self, &expectedSHA256Key) as? String
        }
        set {
            objc_setAssociatedObject(self, &expectedSHA256Key, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
