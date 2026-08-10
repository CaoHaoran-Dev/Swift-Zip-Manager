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
    
    private var downloadTask: URLSessionDownloadTask?
    private var progressObservation: NSKeyValueObservation?
    private var completionHandler: ((Result<URL, Error>) -> Void)?
    
    /// 下载目标路径
    private var downloadedZipURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = appSupport.appendingPathComponent(bundleIdentifier)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("update.zip")
    }
    
    // MARK: - 公开接口
    
    func download(
        from url: URL,
        progress: @escaping (Double, String) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        // 如果已在下载，先取消
        if isDownloading {
            cancelDownload()
        }
        
        isDownloading = true
        downloadProgress = 0
        downloadStatus = "Starting download..."
        completionHandler = completion
        
        // 确保目标目录存在
        let targetFolder = downloadedZipURL.deletingLastPathComponent()
        try? fileManager.createDirectory(at: targetFolder, withIntermediateDirectories: true)
        
        // 清理旧的下载文件
        if fileManager.fileExists(atPath: downloadedZipURL.path) {
            try? fileManager.removeItem(at: downloadedZipURL)
        }
        
        // ✅ 配置 URLSession
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
        
        // ✅ 设置 User-Agent（GitHub 要求）
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let userAgent = "Swift-Zip-Manager/\(appVersion) (macOS)"
        config.httpAdditionalHeaders = [
            "User-Agent": userAgent,
            "Accept": "application/octet-stream"
        ]
        
        // ✅ 允许重定向
        config.httpShouldUsePipelining = true
        
        let session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        
        downloadTask = session.downloadTask(with: url)
        
        // ✅ 观察下载进度
        progressObservation = downloadTask?.progress.observe(\.fractionCompleted) { [weak self] progressObj, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.downloadProgress = progressObj.fractionCompleted
                let percent = Int(progressObj.fractionCompleted * 100)
                self.downloadStatus = "Downloading... \(percent)%"
                progress(progressObj.fractionCompleted, self.downloadStatus)
            }
        }
        
        print("📥 Starting download from: \(url)")
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
        print("📥 Download cancelled")
    }
    
    func getDownloadedZipURL() -> URL? {
        guard fileManager.fileExists(atPath: downloadedZipURL.path) else {
            return nil
        }
        return downloadedZipURL
    }
}

// MARK: - URLSessionDownloadDelegate

extension UpdateDownloader: URLSessionDownloadDelegate {
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        print("📥 Download finished, moving file...")
        
        do {
            // 如果已有旧的 zip 文件，删除
            if fileManager.fileExists(atPath: downloadedZipURL.path) {
                try fileManager.removeItem(at: downloadedZipURL)
            }
            
            // 移动下载完成的文件到目标位置
            try fileManager.moveItem(at: location, to: downloadedZipURL)
            
            print("✅ Download saved to: \(downloadedZipURL.path)")
            
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
            print("❌ Failed to move downloaded file: \(error)")
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
            
            // 用户取消不算错误
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                print("📥 Download cancelled by user")
                return
            }
            
            // ✅ 打印详细错误信息
            print("❌ Download error:")
            print("   Domain: \(nsError.domain)")
            print("   Code: \(nsError.code)")
            print("   Description: \(nsError.localizedDescription)")
            print("   UserInfo: \(nsError.userInfo)")
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isDownloading = false
                self.downloadStatus = "Download failed"
                self.progressObservation?.invalidate()
                self.progressObservation = nil
                self.completionHandler?(.failure(error))
                self.completionHandler = nil
            }
        } else {
            print("✅ Download task completed successfully")
        }
    }
}

// MARK: - URLSessionTaskDelegate (处理重定向)

extension UpdateDownloader: URLSessionTaskDelegate {
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        print("🔄 Redirecting to: \(request.url?.absoluteString ?? "nil")")
        // ✅ 允许重定向
        completionHandler(request)
    }
}
