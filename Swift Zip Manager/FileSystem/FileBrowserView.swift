//
//  FileBrowserView.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI
import UniformTypeIdentifiers

struct FileBrowserView: View {
    @ObservedObject var manager: ArchiveManager
    @ObservedObject var recentManager: RecentFilesManager
    @Binding var currentDirectory: URL?
    @Binding var viewMode: ViewMode
    
    @State private var items: [FileItem] = []
    @State private var isLoading = false
    @State private var isDragTarget = false
    
    enum ViewMode: String, CaseIterable {
        case list = "list.bullet"
        case grid = "square.grid.2x2"
        
        var icon: String { rawValue }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            FileBrowserToolbar(
                viewMode: $viewMode,
                onGoUp: goUp,
                onExtractAll: manager.currentArchive != nil ? extractAll : nil
            )
            Divider()
            
            contentView
        }
        .onAppear {
            if currentDirectory == nil {
                currentDirectory = FileManager.default.homeDirectoryForCurrentUser
            }
            loadContents()
        }
        .onChange(of: currentDirectory) { _ in
            loadContents()
        }
        .onDrop(of: [.fileURL], isTargeted: $isDragTarget) { providers in
            handleDrop(providers: providers)
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if manager.currentArchive != nil {
            ArchiveContentView(manager: manager)
        } else if viewMode == .list {
            FileListView(items: items, onItemTap: handleItemTap)
        } else {
            FileGridView(items: items, onItemTap: handleItemTap)
        }
    }
    
    func loadContents() {
        guard let dir = currentDirectory else { return }
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let loadedItems = loadDirectoryContents(dir)
            DispatchQueue.main.async {
                items = loadedItems
                isLoading = false
            }
        }
    }
    
    func loadDirectoryContents(_ url: URL) -> [FileItem] {
        var fileItems: [FileItem] = []
        let fm = FileManager.default
        
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey]
        ) else {
            return fileItems
        }
        
        for url in contents {
            if let isHidden = try? url.resourceValues(forKeys: [.isHiddenKey]).isHidden,
               isHidden { continue }
            
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let isArchive = !isDirectory && url.isArchive
            let size = isDirectory ? nil : url.fileSize
            let modDate = url.modificationDate
            
            fileItems.append(FileItem(
                url: url,
                name: url.lastPathComponent,
                isDirectory: isDirectory,
                isArchive: isArchive,
                size: size,
                modificationDate: modDate
            ))
        }
        
        fileItems.sort { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory && !b.isDirectory }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
        
        return fileItems
    }
    
    func goUp() {
        if let dir = currentDirectory?.deletingLastPathComponent() {
            currentDirectory = dir
            loadContents()
        }
    }
    
    func extractAll() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.begin { response in
            if response == .OK, let url = panel.url {
                manager.extractArchive(to: url)
            }
        }
    }
    
    func handleItemTap(_ item: FileItem) {
        if item.isDirectory {
            currentDirectory = item.url
            loadContents()
        } else if item.isArchive {
            manager.loadArchive(item.url, recentManager: recentManager)
        }
    }
    
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        let ext = url.pathExtension.lowercased()
                        if ["zip", "7z", "rar", "tar", "gz", "tgz"].contains(ext) {
                            manager.loadArchive(url, recentManager: recentManager)
                        } else {
                            currentDirectory = url.deletingLastPathComponent()
                            loadContents()
                        }
                    }
                }
            }
        }
        return true
    }
}
