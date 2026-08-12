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
    @Published var checkResultMessage: String?  // ✅ 显示检查结果
    @Published var showCheckResult = false      // ✅ 显示结果弹窗
    
    private let apiClient = GitHubAPIClient()
    private let downloader = UpdateDownloader()
    private let installer = UpdateInstaller()
    private let versionComparator = VersionComparator.self
    
    private var updateCompletion: ((Bool, String?) -> Void)?
    private let completionLock = NSLock()
    
    private var updateResultFile: URL {
        let temp = FileManager.default.temporaryDirectory
        return temp.appendingPathComponent("com.haoran.SwiftZipManager.update_result.json")
    }
    
    struct UpdateInfo {
        let version: String
        let buildNumber: String
        let body: String
        let downloadURL: URL
        let isNewer: Bool
        let isPrerelease: Bool
        let fileSize: Int64?
        let sha256: String?
    }
    
    private var currentBuildNumber: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }
    
    private var currentVersionDisplay: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        return "v\(shortVersion) (Build \(currentBuildNumber))"
    }
    
    // MARK: - ✅ 自动检查更新（无提示，有更新才弹窗）
    
    func autoCheckForUpdates(includePrerelease: Bool) {
        print("🔄 [UpdateChecker] Auto checking for updates...")
        
        isChecking = true
        
        Task {
            do {
                let releases = try await apiClient.fetchReleases(includePrerelease: includePrerelease)
                
                guard let latestRelease = releases.first else {
                    await handleAutoCheckResult(hasUpdate: false)
                    return
                }
                
                await processAutoCheckRelease(latestRelease)
            } catch {
                print("❌ [UpdateChecker] Auto check failed: \(error.localizedDescription)")
                await handleAutoCheckResult(hasUpdate: false)
            }
        }
    }
    
    @MainActor
    private func processAutoCheckRelease(_ release: Release) {
        isChecking = false
        
        let buildNumber = release.tagName
        let isNewer = VersionComparator.shouldUpdate(current: currentBuildNumber, latest: buildNumber)
        
        print("📡 [UpdateChecker] Auto check - current: \(currentBuildNumber), latest: \(buildNumber), isNewer: \(isNewer)")
        
        if isNewer {
            // ✅ 有更新 → 弹窗提示
            guard let asset = release.assets.first(where: { $0.name == AppConstants.targetFileName }) else {
                return
            }
            
            let sha256 = asset.sha256
            let updateInfo = UpdateInfo(
                version: release.tagName,
                buildNumber: buildNumber,
                body: release.body,
                downloadURL: asset.browserDownloadURL,
                isNewer: isNewer,
                isPrerelease: release.prerelease,
                fileSize: asset.size,
                sha256: sha256
            )
            
            self.updateAvailable = updateInfo
            showUpdateAlert()
        }
        // ✅ 无更新 → 不提示
    }
    
    @MainActor
    private func handleAutoCheckResult(hasUpdate: Bool) {
        isChecking = false
        // 无更新不提示
        if hasUpdate {
            showUpdateAlert()
        }
    }
    
    // MARK: - ✅ 手动检查更新（有更新弹窗，无更新也提示）
    
    func manualCheckForUpdates(includePrerelease: Bool, showIfNone: Bool = true, completion: ((Bool, String?) -> Void)? = nil) {
        isChecking = true
        
        completionLock.lock()
        self.updateCompletion = completion
        completionLock.unlock()
        
        Task {
            do {
                let releases = try await apiClient.fetchReleases(includePrerelease: includePrerelease)
                
                guard let latestRelease = releases.first else {
                    await handleManualNoUpdate(showIfNone: showIfNone, message: "No releases found")
                    return
                }
                
                await processManualRelease(latestRelease, showIfNone: showIfNone)
            } catch {
                await handleManualNoUpdate(showIfNone: showIfNone, message: error.localizedDescription)
            }
        }
    }
    
    @MainActor
    private func processManualRelease(_ release: Release, showIfNone: Bool) {
        isChecking = false
        
        let buildNumber = release.tagName
        let isNewer = VersionComparator.shouldUpdate(current: currentBuildNumber, latest: buildNumber)
        
        print("📡 [UpdateChecker] Manual check - current: \(currentBuildNumber), latest: \(buildNumber), isNewer: \(isNewer)")
        
        guard let asset = release.assets.first(where: { $0.name == AppConstants.targetFileName }) else {
            if showIfNone {
                checkResultMessage = "settings.updates.file.not.found".localized
                showCheckResult = true
            }
            completeUpdate(success: false, message: "ZIP file not found in release")
            return
        }
        
        let sha256 = asset.sha256
        let updateInfo = UpdateInfo(
            version: release.tagName,
            buildNumber: buildNumber,
            body: release.body,
            downloadURL: asset.browserDownloadURL,
            isNewer: isNewer,
            isPrerelease: release.prerelease,
            fileSize: asset.size,
            sha256: sha256
        )
        
        self.updateAvailable = updateInfo
        
        if isNewer {
            // ✅ 有更新 → 弹窗
            showUpdateAlert()
            completeUpdate(success: true, message: nil)
        } else if showIfNone {
            // ✅ 无更新 → 提示"已是最新版本"
            checkResultMessage = "settings.updates.no.update.message".localized
            showCheckResult = true
            completeUpdate(success: false, message: "No update available")
        } else {
            completeUpdate(success: false, message: nil)
        }
    }
    
    @MainActor
    private func handleManualNoUpdate(showIfNone: Bool, message: String) {
        isChecking = false
        if showIfNone {
            checkResultMessage = "settings.updates.no.update.message".localized
            showCheckResult = true
        }
        completeUpdate(success: false, message: message)
    }
    
    // MARK: - 显示更新弹窗
    
    @MainActor
    private func showUpdateAlert() {
        guard let update = updateAvailable else { return }
        
        let alert = NSAlert()
        alert.messageText = "settings.updates.new.available.title".localized
        alert.informativeText = String(format: "settings.updates.new.available.message".localized, update.buildNumber)
        alert.alertStyle = .informational
        alert.addButton(withTitle: "settings.updates.new.available.download".localized)
        alert.addButton(withTitle: "settings.updates.new.available.later".localized)
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // ✅ 用户点击"下载"
            downloadAndInstall(
                progress: { _, _ in },
                completion: { success, message in
                    if !success {
                        self.showErrorAlert(message: message)
                    }
                }
            )
        }
    }
    
    @MainActor
    private func showErrorAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "settings.updates.download.failed".localized
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "alert.ok".localized)
        alert.runModal()
    }
    
    // MARK: - 旧版兼容方法（保留给设置界面调用）
    
    func checkForUpdates(includePrerelease: Bool, showIfNone: Bool = false, completion: ((Bool, String?) -> Void)? = nil) {
        manualCheckForUpdates(includePrerelease: includePrerelease, showIfNone: showIfNone, completion: completion)
    }
    
    // MARK: - 完成回调
    
    private func completeUpdate(success: Bool, message: String?) {
        let result: [String: Any] = [
            "success": success,
            "message": message ?? "",
            "timestamp": Date().timeIntervalSince1970
        ]
        if let data = try? JSONSerialization.data(withJSONObject: result) {
            try? data.write(to: updateResultFile)
        }
        
        completionLock.lock()
        let completion = updateCompletion
        updateCompletion = nil
        completionLock.unlock()
        completion?(success, message)
    }
    
    // MARK: - 读取上次更新结果
    
    func readLastUpdateResult() -> (success: Bool, message: String)? {
        guard let data = try? Data(contentsOf: updateResultFile),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = json["success"] as? Bool,
              let message = json["message"] as? String else {
            return nil
        }
        try? FileManager.default.removeItem(at: updateResultFile)
        return (success, message)
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
        
        let sha256 = update.sha256 ?? ""
        
        if !sha256.isEmpty {
            print("📥 [UpdateChecker] Using SHA256 for verification: \(sha256.prefix(16))...")
        } else {
            print("📥 [UpdateChecker] No SHA256, using ZIP integrity check")
        }
        
        isDownloading = true
        downloadProgress = 0
        downloadStatus = "Starting..."
        
        downloader.download(
            from: update.downloadURL,
            expectedSHA256: sha256,
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
                                let result: [String: Any] = [
                                    "success": success,
                                    "message": message,
                                    "timestamp": Date().timeIntervalSince1970
                                ]
                                if let data = try? JSONSerialization.data(withJSONObject: result) {
                                    try? data.write(to: self.updateResultFile)
                                }
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
    
    func cancelDownload() {
        downloader.cancelDownload()
        installer.cancelInstallation()
        isDownloading = false
        downloadProgress = 0
        downloadStatus = ""
    }
}
