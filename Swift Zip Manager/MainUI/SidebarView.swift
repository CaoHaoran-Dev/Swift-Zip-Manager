//
//  SidebarView.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI
import UniformTypeIdentifiers

struct SidebarRow: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    let color: Color?
    
    init(icon: String, title: String, isSelected: Bool, color: Color? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.isSelected = isSelected
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .frame(width: 24)
                    .foregroundColor(color ?? (isSelected ? .accentColor : .secondary))
                Text(title)
                    .foregroundColor(isSelected ? .accentColor : .primary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var languageManager: LanguageManager  // ✅ 添加
    @ObservedObject var manager: ArchiveManager
    @ObservedObject var recentManager: RecentFilesManager
    @Binding var currentDirectory: URL?
    @State private var selectedSidebarItem: String? = "home"
    
    private func getLocalizedName(for url: URL) -> String {
        if let values = try? url.resourceValues(forKeys: [.localizedNameKey]) {
            return values.localizedName ?? url.lastPathComponent
        }
        return url.lastPathComponent
    }
    
    var body: some View {
        List {
            Section("sidebar.quick.actions".localized) {
                SidebarRow(icon: "doc.badge.plus", title: "sidebar.new.archive".localized, isSelected: false, color: .blue) {
                    appState.showNewArchive = true
                }
                SidebarRow(icon: "folder", title: "sidebar.open.archive".localized, isSelected: false, color: .blue) {
                    openArchive()
                }
            }
            
            Section("sidebar.locations".localized) {
                if let url = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
                    SidebarRow(icon: "desktopcomputer", title: getLocalizedName(for: url), isSelected: selectedSidebarItem == "desktop", color: .blue) {
                        currentDirectory = url
                        manager.currentArchive = nil
                        selectedSidebarItem = "desktop"
                    }
                }
                
                if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    SidebarRow(icon: "folder", title: getLocalizedName(for: url), isSelected: selectedSidebarItem == "documents", color: .blue) {
                        currentDirectory = url
                        manager.currentArchive = nil
                        selectedSidebarItem = "documents"
                    }
                }
                
                if let url = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
                    SidebarRow(icon: "arrow.down.circle", title: getLocalizedName(for: url), isSelected: selectedSidebarItem == "downloads", color: .blue) {
                        currentDirectory = url
                        manager.currentArchive = nil
                        selectedSidebarItem = "downloads"
                    }
                }
                
                let homeURL = FileManager.default.homeDirectoryForCurrentUser
                SidebarRow(icon: "house", title: getLocalizedName(for: homeURL), isSelected: selectedSidebarItem == "home", color: .blue) {
                    currentDirectory = homeURL
                    manager.currentArchive = nil
                    selectedSidebarItem = "home"
                }
            }
            
            Section("sidebar.volumes".localized) {
                ForEach(getVolumes(), id: \.url) { volume in
                    SidebarRow(icon: "externaldrive", title: volume.name, isSelected: selectedSidebarItem == volume.url.path, color: .gray) {
                        currentDirectory = volume.url
                        manager.currentArchive = nil
                        selectedSidebarItem = volume.url.path
                    }
                }
            }
            
            if !recentManager.recentFiles.isEmpty {
                Section("sidebar.recent".localized) {
                    ForEach(recentManager.recentFiles.prefix(10), id: \.self) { file in
                        Button(action: {
                            manager.loadArchive(file.url, recentManager: recentManager)
                            selectedSidebarItem = nil
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.zipper")
                                    .frame(width: 24)
                                    .foregroundColor(.blue)
                                Text(file.name)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Remove") {
                                if let index = recentManager.recentFiles.firstIndex(where: { $0.id == file.id }) {
                                    recentManager.remove(at: IndexSet(integer: index))
                                }
                            }
                        }
                    }
                    
                    if recentManager.recentFiles.count > 10 {
                        Button("sidebar.clear.all".localized) {
                            recentManager.clear()
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                }
                .id(recentManager.recentFiles.count)
            }
            
            // ✅ 设置按钮 - 使用 appState.showSettings = true
            Section {
                SidebarRow(icon: "gear", title: "sidebar.settings".localized, isSelected: false, color: .gray) {
                    print("🔧 Settings button tapped in SidebarView")
                    appState.showSettings = true
                }
            }
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 220, maxWidth: 280)
    }
    
    func getVolumes() -> [(url: URL, name: String)] {
        let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeNameKey], options: .skipHiddenVolumes) ?? []
        return volumes.compactMap { url in
            let name = (try? url.resourceValues(forKeys: [.volumeNameKey]).volumeName) ?? url.lastPathComponent
            return (url: url, name: name)
        }
    }
    
    func openArchive() {
        let panel = NSOpenPanel()
        var contentTypes: [UTType] = []
        
        if let zip = UTType(filenameExtension: "zip") { contentTypes.append(zip) }
        if let sevenZ = UTType(filenameExtension: "7z") { contentTypes.append(sevenZ) }
        if let rar = UTType(filenameExtension: "rar") { contentTypes.append(rar) }
        if let tar = UTType(filenameExtension: "tar") { contentTypes.append(tar) }
        if let gz = UTType(filenameExtension: "gz") { contentTypes.append(gz) }
        if let tgz = UTType(filenameExtension: "tgz") { contentTypes.append(tgz) }
        
        panel.allowedContentTypes = contentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "sidebar.open.archive".localized
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                manager.loadArchive(url, recentManager: recentManager)
                selectedSidebarItem = nil
            }
        }
    }
}
