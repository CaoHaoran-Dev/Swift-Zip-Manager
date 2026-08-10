//
//  UpdateChecker.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI
import AppKit

class UpdateChecker: ObservableObject {
    @Published var isChecking = false
    @Published var downloadProgress: Double = 0
    @Published var downloadStatus = ""
    @Published var isDownloading = false
    @Published var updateAvailable: UpdateInfo?
    
    private let apiClient = GitHubAPIClient()
    private let downloader = UpdateDownloader()
    private let installer = UpdateInstaller()
    private let versionComparator = VersionComparator.self
    private var updateCompletion: ((Bool, String?) -> Void)?
    
    struct UpdateInfo {
        let version: String
        let buildNumber: String
        let body: String
        let downloadURL: URL
        let isNewer: Bool
        let isPrerelease: Bool
        let fileSize: Int64?
    }
    
    private var currentBuildNumber: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }
    
    private var currentVersionDisplay: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        return "v\(shortVersion) (Build \(currentBuildNumber))"
    }
    
    // MARK: - 检查更新
    
    func checkForUpdates(includePrerelease: Bool, showIfNone: Bool = false, completion: ((Bool, String?) -> Void)? = nil) {
        isChecking = true
        self.updateCompletion = completion
        
        Task {
            do {
                let releases = try await apiClient.fetchReleases(includePrerelease: includePrerelease)
                
                guard let firstRelease = releases.first else {
                    await handleNoUpdate(showIfNone: showIfNone, message: "No releases found")
                    return
                }
                
                await processRelease(firstRelease, showIfNone: showIfNone)
            } catch {
                await handleNoUpdate(showIfNone: showIfNone, message: error.localizedDescription)
            }
        }
    }
    
    @MainActor
    private func processRelease(_ release: Release, showIfNone: Bool) {
        isChecking = false
        
        let buildNumber = release.tagName
        let isNewer = versionComparator.shouldUpdate(current: currentBuildNumber, latest: buildNumber)
        
        guard let asset = release.assets.first(where: { $0.name == AppConstants.targetFileName }) else {
            if showIfNone {
                let alert = NSAlert()
                alert.messageText = "settings.updates.error".localized
                alert.informativeText = "settings.updates.file.not.found".localized
                alert.addButton(withTitle: "alert.ok".localized)
                alert.runModal()
            }
            updateCompletion?(false, "ZIP file not found in release")
            updateCompletion = nil
            return
        }
        
        let updateInfo = UpdateInfo(
            version: release.tagName,
            buildNumber: buildNumber,
            body: release.body,
            downloadURL: asset.browserDownloadURL,
            isNewer: isNewer,
            isPrerelease: release.prerelease,
            fileSize: asset.size
        )
        
        self.updateAvailable = updateInfo
        
        if isNewer {
            updateCompletion?(true, nil)
        } else if showIfNone {
            showNoUpdateAlert()
            updateCompletion?(false, "No update available")
        } else {
            updateCompletion?(false, nil)
        }
        updateCompletion = nil
    }
    
    @MainActor
    private func handleNoUpdate(showIfNone: Bool, message: String) {
        isChecking = false
        if showIfNone {
            showNoUpdateAlert()
        }
        updateCompletion?(false, message)
        updateCompletion = nil
    }
    
    // MARK: - 下载并安装
    
    func downloadAndInstall(
        progress: @escaping (Double, String) -> Void,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard let update = updateAvailable else {
            completion(false, "No update available")
            return
        }
        
        isDownloading = true
        downloadProgress = 0
        downloadStatus = "Starting..."
        
        // 1. 下载
        downloader.download(
            from: update.downloadURL,
            progress: { [weak self] p, status in
                DispatchQueue.main.async {
                    self?.downloadProgress = p
                    self?.downloadStatus = status
                    progress(p, status)
                }
            },
            completion: { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let zipURL):
                    // 2. 下载完成 → 安装
                    self.downloadStatus = "Installing..."
                    progress(1.0, "Installing...")
                    
                    self.installer.install(
                        from: zipURL,
                        progress: { p, status in
                            DispatchQueue.main.async {
                                self.downloadProgress = p
                                self.downloadStatus = status
                                progress(p, status)
                            }
                        },
                        completion: { success, message in
                            DispatchQueue.main.async {
                                self.isDownloading = false
                                // 如果成功，当前进程可能已退出，completion 可能不会执行
                                // 保留作为 fallback
                                completion(success, message)
                            }
                        }
                    )
                    
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.isDownloading = false
                        self.downloadStatus = "Download failed"
                        completion(false, error.localizedDescription)
                    }
                }
            }
        )
    }
    
    /// 取消下载/安装
    func cancelDownload() {
        downloader.cancelDownload()
        installer.cancelInstallation()
        isDownloading = false
        downloadProgress = 0
        downloadStatus = ""
    }
    
    // MARK: - UI 提示
    
    private func showNoUpdateAlert() {
        let alert = NSAlert()
        alert.messageText = "settings.updates.no.update.title".localized
        alert.informativeText = "settings.updates.no.update.message".localized
        alert.alertStyle = .informational
        alert.addButton(withTitle: "alert.ok".localized)
        alert.runModal()
    }
}
