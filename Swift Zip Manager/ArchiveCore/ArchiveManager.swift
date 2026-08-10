//
//  ArchiveManager.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

class ArchiveManager: ObservableObject {
    @Published var currentArchive: URL?
    @Published var entries: [ArchiveEntry] = []
    @Published var selectedArchiveIDs = Set<UUID>()
    @Published var isProcessing = false
    @Published var progress: Double = 0
    @Published var error: String?
    @Published var showAlert = false
    
    let formats = ["zip", "tar", "gz", "7z", "rar"]
    
    private let loader = ArchiveLoader()
    private let extractor = ArchiveExtractor()
    private let creator = ArchiveCreator()
    private let toolResolver = ToolPathResolver()
    
    // ✅ #21: 绑定 AppState
    weak var appState: AppState? {
        didSet {
            extractor.appState = appState
            creator.appState = appState
        }
    }
    
    func loadArchive(_ url: URL, recentManager: RecentFilesManager? = nil) {
        currentArchive = url
        recentManager?.add(url)
        
        loader.loadArchive(url) { [weak self] result in
            switch result {
            case .success(let entries):
                DispatchQueue.main.async {
                    self?.entries = entries
                    self?.selectedArchiveIDs.removeAll()
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.error = error.localizedDescription
                    self?.showAlert = true
                }
            }
        }
    }
    
    func extractArchive(to destination: URL, password: String? = nil) {
        guard let source = currentArchive else { return }
        
        DispatchQueue.main.async {
            self.isProcessing = true
            self.progress = 0
        }
        
        performExtract(source, to: destination, password: password)
    }
    
    private func performExtract(_ source: URL, to destination: URL, password: String?) {
        extractor.extract(source, to: destination, password: password) { [weak self] result in
            DispatchQueue.main.async {
                self?.isProcessing = false
                self?.progress = 1.0
                switch result {
                case .success:
                    self?.error = String(format: "archive.extraction.complete".localized, source.lastPathComponent)
                case .failure(let error):
                    if error.isPasswordError {
                        self?.error = "archive.password.wrong".localized
                    } else {
                        self?.error = "archive.extraction.failed".localized + ": " + error.localizedDescription
                    }
                }
                self?.showAlert = true
            }
        }
    }
    
    func createArchiveWithEncryption(files: [URL], format: String, name: String, destination: URL, password: String) {
        guard validateToolForFormat(format) else {
            error = "error.tool.not.found".localized(with: format)
            showAlert = true
            return
        }
        
        DispatchQueue.main.async {
            self.isProcessing = true
        }
        
        creator.create(files: files, format: format, name: name, destination: destination, password: password) { [weak self] result in
            DispatchQueue.main.async {
                self?.isProcessing = false
                switch result {
                case .success:
                    self?.error = "archive.creation.success".localized
                case .failure(let error):
                    self?.error = "archive.creation.failed".localized + ": " + error.localizedDescription
                }
                self?.showAlert = true
            }
        }
    }
    
    func createArchive(files: [URL], format: String, name: String, destination: URL) {
        createArchiveWithEncryption(files: files, format: format, name: name, destination: destination, password: "")
    }
    
    private func validateToolForFormat(_ format: String) -> Bool {
        if format == "rar" || format == "7z" {
            return toolResolver.resolve(format == "rar" ? "rar" : "7zz") != nil
        }
        return true
    }
    
    func getExtension(for format: String) -> String {
        return ["zip": "zip", "tar": "tar", "gz": "tar.gz", "7z": "7z", "rar": "rar"][format] ?? "zip"
    }
}
