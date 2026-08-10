//
//  UpdateChecker.swift.swift
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
    @Published var showUpdateAlert = false
    @Published var countdownSeconds = 5
    
    private let apiClient = GitHubAPIClient()
    private let downloader = UpdateDownloader()
    private let versionComparator = VersionComparator.self
    private var countdownTimer: Timer?
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
                showAlert(title: "Error", message: "Could not find download file")
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
    
    func downloadAndInstall(progress: @escaping (Double, String) -> Void, completion: @escaping (Bool, String) -> Void) {
        guard let update = updateAvailable else {
            completion(false, "No update available")
            return
        }
        
        isDownloading = true
        
        downloader.downloadAndInstall(
            from: update.downloadURL,
            progress: progress
        ) { [weak self] success, message in
            DispatchQueue.main.async {
                self?.isDownloading = false
                if success {
                    self?.startCountdownAndExit()
                }
                completion(success, message)
            }
        }
    }
    
    func cancelDownload() {
        downloader.cancelDownload()
        isDownloading = false
        downloadProgress = 0
        downloadStatus = ""
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
    
    private func startCountdownAndExit() {
        countdownSeconds = 5
        downloadStatus = "Restarting in \(countdownSeconds)s..."
        showUpdateAlert = true
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            self.countdownSeconds -= 1
            self.downloadStatus = "Restarting in \(self.countdownSeconds)s..."
            
            if self.countdownSeconds <= 3 {
                self.showUpdateAlert = true
            }
            
            if self.countdownSeconds <= 0 {
                timer.invalidate()
                self.showUpdateAlert = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isDownloading = false
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }
    
    private func showNoUpdateAlert() {
        let alert = NSAlert()
        alert.messageText = "No Update Available"
        alert.informativeText = "You're running the latest version (Build \(currentBuildNumber))."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
