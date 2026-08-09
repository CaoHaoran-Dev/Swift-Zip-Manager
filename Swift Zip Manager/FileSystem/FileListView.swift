//
//  FileListView.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

struct FileListView: View {
    let items: [FileItem]
    let onItemTap: (FileItem) -> Void
    
    @State private var selectedItemIDs = Set<UUID>()
    
    var body: some View {
        Table(items, selection: $selectedItemIDs) {
            TableColumn("Name") { item in
                FileListItemRow(item: item, onTap: { onItemTap(item) })
            }
            TableColumn("Size", value: \.sizeFormatted).width(100)
            TableColumn("Modified", value: \.dateFormatted).width(150)
        }
        .tableStyle(.inset)
    }
}

struct FileListItemRow: View {
    let item: FileItem
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: item.icon)
                .foregroundColor(item.iconColor)
            Text(item.name)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .contextMenu { FileItemContextMenu(item: item) }
    }
}

struct FileItemContextMenu: View {
    let item: FileItem
    
    var body: some View {
        if item.isDirectory {
            Button("Open") {
                NotificationCenter.default.post(name: .openArchiveNotification, object: item.url)
            }
        } else if item.isArchive {
            Button("Open Archive") {
                NotificationCenter.default.post(name: .openArchiveNotification, object: item.url)
            }
        }
        Button("Show in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([item.url])
        }
    }
}

extension FileItem {
    var icon: String {
        if isDirectory { return "folder" }
        if isArchive { return "doc.zipper" }
        return "doc"
    }
    
    var iconColor: Color {
        if isDirectory { return .blue }
        if isArchive { return .blue }
        return .secondary
    }
}
