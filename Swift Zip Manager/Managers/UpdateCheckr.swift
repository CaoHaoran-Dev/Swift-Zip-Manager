import SwiftUI
import AppKit

// MARK: - Update Checker
class UpdateChecker: ObservableObject {
    @Published var isChecking = false
    @Published var downloadProgress: Double = 0
    @Published var downloadStatus = ""
    @Published var updateAvailable: UpdateInfo?
    @Published var isDownloading = false
    @Published var showUpdateAlert = false
    @Published var countdownSeconds = 5
    
    private let repoOwner = "CaoHaoran-Dev"
    private let repoName = "Swift-Zip-Manager"
    private let targetFileName = "Swift.Zip.Manager.zip"
    private let appName = "Swift Zip Manager.app"
    private let bundleIdentifier = "com.haoran.Swift-Zip-Manager"
    
    private var downloadTask: URLSessionDownloadTask?
    private var progressObservation: NSKeyValueObservation?
    private var countdownTimer: Timer?
    private var updateCompletion: ((Bool, String) -> Void)?
    
    // MARK: - Paths
    private var appSupportFolder: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent(bundleIdentifier)
    }
    
    private var downloadedZipURL: URL {
        return appSupportFolder.appendingPathComponent("update.zip")
    }
    
    private var extractedAppURL: URL {
        return appSupportFolder.appendingPathComponent(appName)
    }
    
    // MARK: - Version Info
    private var currentBuildNumber: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }
    
    private var currentVersionDisplay: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        return "v\(shortVersion) (Build \(currentBuildNumber))"
    }
    
    // MARK: - Update Info Model
    struct UpdateInfo {
        let version: String
        let buildNumber: String
        let body: String
        let downloadURL: URL
        let isNewer: Bool
        let isPrerelease: Bool
        let fileSize: Int64?
    }
    
    // MARK: - Version Parsing
    private struct BuildVersion {
        let mainBuild: Int
        let revision: Int
        
        init(_ string: String) {
            let parts = string.split(separator: ".")
            self.mainBuild = Int(parts[0]) ?? 0
            self.revision = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        }
    }
    
    // MARK: - Version Comparison (Strictly follows Document Spec 2.2)
    private func shouldUpdate(current: String, latest: String) -> Bool {
        let currentVer = BuildVersion(current)
        let latestVer = BuildVersion(latest)
        
        if latestVer.revision == 0 {
            // 最新版是正式版（无修订号）
            if latestVer.mainBuild >= currentVer.mainBuild {
                return true  // 大于或等于都更新（等于用于测试版→正式版平替）
            } else {
                return false
            }
        } else {
            // 最新版是测试版（有修订号）
            if latestVer.mainBuild > currentVer.mainBuild {
                return true  // 主构建号更大，直接更新
            } else if latestVer.mainBuild == currentVer.mainBuild {
                if latestVer.revision > currentVer.revision {
                    return true  // 同主版本，修订号更大才更新
                } else {
                    return false
                }
            } else {
                return false  // 主构建号更小，不更新
            }
        }
    }
    
    // MARK: - Extract Build Number from Tag
    private func extractBuildNumber(from tagName: String) -> String {
        // Tag format is pure build number: "1000" or "1000.1"
        return tagName
    }
    
    // MARK: - Clean Old Files (Only called after successful update, per Spec 4.3)
    private func cleanOldFiles() {
        let fm = FileManager.default
        if fm.fileExists(atPath: downloadedZipURL.path) {
            try? fm.removeItem(at: downloadedZipURL)
        }
        if fm.fileExists(atPath: extractedAppURL.path) {
            try? fm.removeItem(at: extractedAppURL)
        }
    }
    
    // MARK: - Check for Updates (Spec 3.2)
    func checkForUpdates(includePrerelease: Bool, showIfNone: Bool = false, completion: ((Bool, String?) -> Void)? = nil) {
        isChecking = true
        
        let urlString: String
        if includePrerelease {
            // 开关开启：接收所有版本（含测试版）
            urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases?per_page=10"
        } else {
            // 开关关闭：仅接收正式版
            urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        }
        
        guard let url = URL(string: urlString) else {
            isChecking = false
            completion?(false, "Invalid GitHub API URL")
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isChecking = false
                
                if let error = error {
                    completion?(false, error.localizedDescription)
                    return
                }
                
                guard let data = data else {
                    completion?(false, "No data received")
                    return
                }
                
                do {
                    if includePrerelease {
                        guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                              let firstRelease = jsonArray.first else {
                            completion?(false, "No releases found")
                            return
                        }
                        self?.processRelease(firstRelease, showIfNone: showIfNone, completion: completion)
                    } else {
                        guard let release = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                            completion?(false, "Failed to parse release data")
                            return
                        }
                        self?.processRelease(release, showIfNone: showIfNone, completion: completion)
                    }
                } catch {
                    completion?(false, error.localizedDescription)
                }
            }
        }.resume()
    }
    
    private func processRelease(_ release: [String: Any], showIfNone: Bool, completion: ((Bool, String?) -> Void)?) {
        guard let tagName = release["tag_name"] as? String,
              let assets = release["assets"] as? [[String: Any]] else {
            if showIfNone {
                showNoUpdateAlert()
            }
            completion?(false, "Failed to parse release data")
            return
        }
        
        let body = release["body"] as? String ?? ""
        let buildNumber = extractBuildNumber(from: tagName)
        let isPrerelease = release["prerelease"] as? Bool ?? false
        
        var assetURL: URL?
        var fileSize: Int64?
        for asset in assets {
            if let name = asset["name"] as? String,
               name == targetFileName,
               let urlString = asset["browser_download_url"] as? String {
                assetURL = URL(string: urlString)
                fileSize = asset["size"] as? Int64
                break
            }
        }
        
        guard let downloadURL = assetURL else {
            if showIfNone {
                showAlert(title: "Error", message: "Could not find download file")
            }
            completion?(false, "ZIP file not found in release")
            return
        }
        
        let isNewer = shouldUpdate(current: currentBuildNumber, latest: buildNumber)
        
        let updateInfo = UpdateInfo(
            version: tagName,
            buildNumber: buildNumber,
            body: body,
            downloadURL: downloadURL,
            isNewer: isNewer,
            isPrerelease: isPrerelease,
            fileSize: fileSize
        )
        
        self.updateAvailable = updateInfo
        
        if isNewer {
            completion?(true, nil)
        } else if showIfNone {
            showNoUpdateAlert()
            completion?(false, "No update available")
        } else {
            completion?(false, nil)
        }
    }
    
    // MARK: - Download and Install (Spec 4.1 - 4.3)
    func downloadAndInstall(progress: @escaping (Double, String) -> Void, completion: @escaping (Bool, String) -> Void) {
        guard let update = updateAvailable else {
            completion(false, "No update available")
            return
        }
        
        isDownloading = true
        downloadProgress = 0
        downloadStatus = "Downloading..."
        self.updateCompletion = completion
        
        // Step 1: Create app support directory
        try? FileManager.default.createDirectory(at: appSupportFolder, withIntermediateDirectories: true)
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        let session = URLSession(configuration: config)
        
        downloadTask = session.downloadTask(with: update.downloadURL) { [weak self] tempURL, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.isDownloading = false
                    guard let completion = self?.updateCompletion else { return }
                    completion(false, error.localizedDescription)
                    self?.updateCompletion = nil
                    return
                }
                
                guard let tempURL = tempURL else {
                    self?.isDownloading = false
                    guard let completion = self?.updateCompletion else { return }
                    completion(false, "No file received")
                    self?.updateCompletion = nil
                    return
                }
                
                guard let self = self else { return }
                
                do {
                    // Download new app to Application Support (Spec 4.1 Step 3)
                    if FileManager.default.fileExists(atPath: self.downloadedZipURL.path) {
                        try FileManager.default.removeItem(at: self.downloadedZipURL)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: self.downloadedZipURL)
                    print("ZIP saved to: \(self.downloadedZipURL.path)")
                    
                    // Extract ZIP
                    self.downloadStatus = "Extracting..."
                    progress(0.9, "Extracting...")
                    try self.extractZip()
                    
                    // Perform update (Spec 4.2 - 4.3)
                    self.performUpdate()
                } catch {
                    self.isDownloading = false
                    guard let completion = self.updateCompletion else { return }
                    completion(false, "Failed to prepare update: \(error.localizedDescription)")
                    self.updateCompletion = nil
                }
            }
        }
        
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
    
    // MARK: - Extract ZIP
    private func extractZip() throws {
        let fm = FileManager.default
        
        // Clean old extracted app
        if fm.fileExists(atPath: extractedAppURL.path) {
            try fm.removeItem(at: extractedAppURL)
        }
        
        // Use ditto to extract zip (preserves permissions)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", downloadedZipURL.path, appSupportFolder.path]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw NSError(domain: "ExtractError", code: Int(process.terminationStatus),
                         userInfo: [NSLocalizedDescriptionKey: "Failed to extract ZIP"])
        }
        
        guard fm.fileExists(atPath: extractedAppURL.path) else {
            throw NSError(domain: "ExtractError", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Extracted app not found"])
        }
        
        print("App extracted to: \(extractedAppURL.path)")
    }
    
    // MARK: - Perform Update (Strictly follows Document Spec 4.2 - 4.3)
    private func performUpdate() {
        let fm = FileManager.default
        let appPath = Bundle.main.bundleURL
        let appName = appPath.lastPathComponent
        let applicationsDir = appPath.deletingLastPathComponent()
        let targetPath = applicationsDir.appendingPathComponent(appName)
        
        // Step 4: Delete old app from /Applications (app is still running in memory)
        downloadStatus = "Removing old version..."
        do {
            if fm.fileExists(atPath: targetPath.path) {
                try fm.removeItem(at: targetPath)
                print("Step 4: Removed old app from: \(targetPath.path)")
            }
        } catch {
            print("Failed to delete old app: \(error)")
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Update Requires Permission"
                alert.informativeText = "Please enter your password to replace the app in /Applications"
                alert.addButton(withTitle: "Continue")
                alert.addButton(withTitle: "Cancel")
                alert.alertStyle = .critical
                
                if alert.runModal() == .alertFirstButtonReturn {
                    self.deleteWithAdminPrivileges(path: targetPath.path) { success in
                        if success {
                            // After successful admin deletion, continue with move and launch
                            self.moveAppToApplicationsAndLaunch(targetPath: targetPath)
                        } else {
                            self.isDownloading = false
                            guard let completion = self.updateCompletion else { return }
                            completion(false, "Failed to delete old app")
                            self.updateCompletion = nil
                        }
                    }
                } else {
                    self.isDownloading = false
                    guard let completion = self.updateCompletion else { return }
                    completion(false, "Update cancelled")
                    self.updateCompletion = nil
                }
            }
            return
        }
        
        // Continue with move and launch
        moveAppToApplicationsAndLaunch(targetPath: targetPath)
    }
    
    // MARK: - Move App and Launch (Spec 4.2 Step 5-7)
    private func moveAppToApplicationsAndLaunch(targetPath: URL) {
        let fm = FileManager.default
        
        // Defensive deletion: if target path already exists, delete it with normal permissions
        if fm.fileExists(atPath: targetPath.path) {
            do {
                try fm.removeItem(at: targetPath)
                print("Defensive deletion: Removed existing app at: \(targetPath.path)")
            } catch {
                print("Defensive deletion failed: \(error)")
                // If normal deletion fails, try admin privileges
                let semaphore = DispatchSemaphore(value: 0)
                var deletionSuccess = false
                deleteWithAdminPrivileges(path: targetPath.path) { success in
                    deletionSuccess = success
                    semaphore.signal()
                }
                semaphore.wait()
                
                if !deletionSuccess {
                    self.isDownloading = false
                    guard let completion = self.updateCompletion else { return }
                    completion(false, "Failed to delete existing app at target path")
                    self.updateCompletion = nil
                    return
                }
                print("Defensive deletion with admin privileges: Removed existing app at: \(targetPath.path)")
            }
        }
        
        // Step 5 & 6: Move new app from Application Support to /Applications
        downloadStatus = "Installing new version..."
        do {
            try fm.moveItem(at: extractedAppURL, to: targetPath)
            print("Step 6: Moved new app from Application Support to: \(targetPath.path)")
        } catch {
            self.isDownloading = false
            guard let completion = self.updateCompletion else { return }
            completion(false, "Failed to move new app: \(error.localizedDescription)")
            self.updateCompletion = nil
            return
        }
        
        // Step 7: ⏱ sleep(5) - Wait 5 seconds before launching new app
        downloadStatus = "Waiting 5 seconds before restart..."
        print("Step 7: Waiting 5 seconds...")
        
        // Start countdown immediately (parallel with sleep)
        // Step 9: Old app enters 5 second countdown
        startCountdownAndExit()
        
        // Step 7 (continued): Sleep 5 seconds, then launch new app
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            // Step 7: Start new app from /Applications
            self.downloadStatus = "Launching new version..."
            print("Step 7: Launching new app from /Applications")
            
            let success = NSWorkspace.shared.open(targetPath)
            if success {
                print("New app launched successfully")
            } else {
                // Fallback: use open command
                let openProcess = Process()
                openProcess.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                openProcess.arguments = [targetPath.path]
                try? openProcess.run()
            }
        }
    }
    
    // MARK: - Countdown and Exit (Spec 4.3)
    private func startCountdownAndExit() {
        // Step 9: Old app enters 5 second countdown
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
            
            // Step 10: Last 3 seconds show alert
            if self.countdownSeconds <= 3 {
                self.showUpdateAlert = true
            }
            
            if self.countdownSeconds <= 0 {
                timer.invalidate()
                self.showUpdateAlert = false
                
                // Step 11: Old app exits, new app is already running
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("Step 11: Old app exiting...")
                    
                    // Step 12: ✅ Update complete - Clean up after successful update (Spec 4.3)
                    self.cleanOldFiles()
                    
                    self.isDownloading = false
                    guard let completion = self.updateCompletion else { return }
                    completion(true, "Update complete")
                    self.updateCompletion = nil
                    
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        
        isDownloading = false
    }
    
    // MARK: - Admin Privileges Helper
    private func deleteWithAdminPrivileges(path: String, completion: @escaping (Bool) -> Void) {
        let script = """
        do shell script "rm -rf '\(path)'" with administrator privileges
        """
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        
        do {
            try process.run()
            process.waitUntilExit()
            completion(process.terminationStatus == 0)
        } catch {
            completion(false)
        }
    }
    
    // MARK: - Cancel Download
    func cancelDownload() {
        downloadTask?.cancel()
        progressObservation?.invalidate()
        progressObservation = nil
        isDownloading = false
        downloadProgress = 0
        downloadStatus = ""
        countdownTimer?.invalidate()
        countdownTimer = nil
        updateCompletion = nil
    }
    
    // MARK: - Alerts
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
