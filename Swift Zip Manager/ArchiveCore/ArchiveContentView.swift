//
//  ArchiveContentView.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

struct ArchiveContentView: View {
    @ObservedObject var manager: ArchiveManager
    @EnvironmentObject var languageManager: LanguageManager
    @State private var showPasswordDialog = false
    @State private var pendingFileName: String?
    @State private var pendingDestination: URL?
    @State private var passwordInput = ""
    
    var body: some View {
        VStack(spacing: 0) {
            archiveHeader
            Divider()
            archiveList
        }
        .sheet(isPresented: $showPasswordDialog) {
            ArchivePasswordDialog(
                isPresented: $showPasswordDialog,
                password: $passwordInput,
                fileName: pendingFileName,
                onConfirm: { password in
                    if let fileName = pendingFileName, let dest = pendingDestination {
                        extractWithPassword(fileName: fileName, destination: dest, password: password)
                    }
                    pendingFileName = nil
                    pendingDestination = nil
                }
            )
            .environmentObject(languageManager)
        }
        .onReceive(NotificationCenter.default.publisher(for: .extractSelectedNotification)) { _ in
            if let firstID = manager.selectedArchiveIDs.first,
               let entry = manager.entries.first(where: { $0.id == firstID }) {
                extractFile(entry)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .extractAllNotification)) { _ in
            extractAllFiles()
        }
        .onReceive(NotificationCenter.default.publisher(for: .deleteSelectedNotification)) { _ in
            for id in manager.selectedArchiveIDs {
                if let entry = manager.entries.first(where: { $0.id == id }) {
                    deleteFromArchive(entry)
                }
            }
        }
    }
    
    @ViewBuilder
    private var archiveHeader: some View {
        if let archive = manager.currentArchive {
            HStack {
                Image(systemName: "doc.zipper").foregroundColor(.blue)
                Text(archive.lastPathComponent).font(.headline)
                Spacer()
                Text(String(format: "archive.items".localized, manager.entries.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        }
    }
    
    private var archiveList: some View {
        List(manager.entries) { entry in
            ArchiveEntryRow(
                entry: entry,
                isSelected: manager.selectedArchiveIDs.contains(entry.id),
                onExtract: extractFile,
                onDelete: deleteFromArchive,
                onExtractAll: extractAllFiles
            )
        }
        .listStyle(.inset)
    }
    
    func extractFile(_ entry: ArchiveEntry) {
        guard let archive = manager.currentArchive else { return }
        
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.message = String(format: "archive.extract.selected".localized + " %@", entry.name)
        
        panel.begin { response in
            if response == .OK, let destination = panel.url {
                let ext = archive.pathExtension.lowercased()
                if ext == "zip" || ext == "rar" || ext == "7z" {
                    pendingFileName = entry.name
                    pendingDestination = destination
                    passwordInput = ""
                    showPasswordDialog = true
                } else {
                    extractDirect(fileName: entry.name, archive: archive, destination: destination)
                }
            }
        }
    }
    
    func extractDirect(fileName: String, archive: URL, destination: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xf", archive.path, "-C", destination.path, fileName]
        
        try? process.run()
        process.waitUntilExit()
        
        if process.terminationStatus == 0 {
            DispatchQueue.main.async {
                manager.error = String(format: "archive.extraction.complete".localized, fileName)
                manager.showAlert = true
            }
        }
    }
    
    func extractWithPassword(fileName: String, destination: URL, password: String) {
        guard let archive = manager.currentArchive else { return }
        let ext = archive.pathExtension.lowercased()
        
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            
            if ext == "zip" {
                process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                process.arguments = ["-P", password, archive.path, fileName, "-d", destination.path]
            } else {
                guard let toolPath = ToolPathResolver().resolve("7zz") else {
                    DispatchQueue.main.async {
                        manager.error = "error.tool.not.found".localized(with: "7zz")
                        manager.showAlert = true
                    }
                    return
                }
                process.executableURL = URL(fileURLWithPath: toolPath)
                process.arguments = ["x", archive.path, "-o\(destination.path)", fileName, "-y", "-p\(password)"]
            }
            
            try? process.run()
            process.waitUntilExit()
            
            DispatchQueue.main.async {
                if process.terminationStatus == 0 {
                    manager.error = String(format: "archive.extraction.complete".localized, fileName)
                } else {
                    manager.error = "archive.password.wrong".localized
                }
                manager.showAlert = true
            }
        }
    }
    
    func deleteFromArchive(_ entry: ArchiveEntry) {
        guard let archive = manager.currentArchive,
              let toolPath = ToolPathResolver().resolve("7zz") else { return }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: toolPath)
        process.arguments = ["d", archive.path, entry.name]
        
        try? process.run()
        process.waitUntilExit()
        
        if process.terminationStatus == 0 {
            manager.loadArchive(archive)
        }
    }
    
    func extractAllFiles() {
        guard let archive = manager.currentArchive else { return }
        
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let ext = archive.pathExtension.lowercased()
                if ext == "zip" || ext == "rar" || ext == "7z" {
                    pendingFileName = nil
                    pendingDestination = url
                    passwordInput = ""
                    showPasswordDialog = true
                } else {
                    manager.extractArchive(to: url)
                }
            }
        }
    }
}
