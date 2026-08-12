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
    @State private var selectedItemIDs = Set<UUID>()
    @State private var isLoading = false
    @State private var isDragTarget = false
    
    private let cache = NSCache<NSString, NSArray>()
    
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
                onExtractAll: extractAll
            )
            Divider()
            
            contentView
        }
        .task(id: currentDirectory) {
            await loadDirectory()
        }
        .onDrop(of: [.fileURL], isTargeted: $isDragTarget) { providers in
            handleDrop(providers: providers)
        }
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            LoadingView("filebrowser.loading".localized)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if manager.currentArchive != nil {
            // ✅ 显示归档内容视图（带提取全部按钮）
            ArchiveContentView(manager: manager)
                .environmentObject(LanguageManager())
        } else if items.isEmpty {
            EmptyStateView(
                icon: "folder",
                title: "filebrowser.empty.title".localized,
                message: currentDirectory?.path ?? "filebrowser.empty.message".localized,
                action: {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canCreateDirectories = false
                    panel.begin { response in
                        if response == .OK, let url = panel.url {
                            currentDirectory = url
                        }
                    }
                },
                actionTitle: "filebrowser.empty.browse".localized
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewMode == .list {
            FileListView(
                items: items,
                selectedIDs: $selectedItemIDs,
                onItemTap: handleItemTap
            )
        } else {
            FileGridView(
                items: items,
                selectedIDs: $selectedItemIDs,
                onItemTap: handleItemTap
            )
        }
    }
    
    // MARK: - Loading
    
    @MainActor
    private func loadDirectory() async {
        guard let dir = currentDirectory else {
            items = []
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let cacheKey = "\(dir.path)" as NSString
        if let cached = cache.object(forKey: cacheKey) as? [FileItem] {
            items = cached
            return
        }
        
        let loadedItems = loadDirectoryContents(dir)
        cache.setObject(loadedItems as NSArray, forKey: cacheKey)
        cache.totalCostLimit = 50
        
        items = loadedItems
    }
    
    private func loadDirectoryContents(_ url: URL) -> [FileItem] {
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
    
    // MARK: - Actions
    
    private func goUp() {
        if let dir = currentDirectory?.deletingLastPathComponent() {
            currentDirectory = dir
            cache.removeAllObjects()
        }
    }
    
    // ✅ 提取全部：由 ArchiveContentView 处理
    private func extractAll() {
        // 如果当前有打开的归档，发送提取全部通知
        if manager.currentArchive != nil {
            NotificationCenter.default.post(name: .extractAllNotification, object: nil)
        } else {
            // 没有归档时，显示提示
            manager.error = "archive.no.archive.open".localized
            manager.showAlert = true
        }
    }
    
    private func handleItemTap(_ item: FileItem) {
        if item.isDirectory {
            currentDirectory = item.url
            cache.removeAllObjects()
        } else if item.isArchive {
            manager.loadArchive(item.url, recentManager: recentManager)
        }
    }
    
    // MARK: - Drag & Drop
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        var loadedURLs: [URL] = []
        var hasError = false
        
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, error in
                defer { group.leave() }
                
                if let error = error {
                    print("⚠️ Drag drop error: \(error)")
                    hasError = true
                    return
                }
                
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    loadedURLs.append(url)
                }
            }
        }
        
        group.notify(queue: .main) {
            guard !loadedURLs.isEmpty else {
                if hasError {
                    manager.error = "filebrowser.drop.error".localized
                    manager.showAlert = true
                }
                return
            }
            
            var archives: [URL] = []
            var directories: [URL] = []
            
            for url in loadedURLs {
                let ext = url.pathExtension.lowercased()
                if ["zip", "7z", "rar", "tar", "gz", "tgz"].contains(ext) {
                    archives.append(url)
                } else {
                    var isDirectory: ObjCBool = false
                    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                       isDirectory.boolValue {
                        directories.append(url)
                    } else {
                        directories.append(url.deletingLastPathComponent())
                    }
                }
            }
            
            if let firstArchive = archives.first {
                manager.loadArchive(firstArchive, recentManager: recentManager)
            } else if let firstDir = directories.first {
                currentDirectory = firstDir
                cache.removeAllObjects()
            }
        }
        
        return true
    }
}
