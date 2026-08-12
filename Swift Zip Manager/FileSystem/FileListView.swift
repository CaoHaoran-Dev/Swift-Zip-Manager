//
//  FileListView.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

struct FileListView: View {
    let items: [FileItem]
    @Binding var selectedIDs: Set<UUID>
    let onItemTap: (FileItem) -> Void
    
    var body: some View {
        Table(items, selection: $selectedIDs) {
            TableColumn("filelist.column.name".localized) { item in
                FileListItemRow(
                    item: item,
                    onTap: { onItemTap(item) }
                )
            }
            TableColumn("filelist.column.size".localized, value: \.sizeFormatted).width(100)
            TableColumn("filelist.column.modified".localized, value: \.dateFormatted).width(150)
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
            Button("filelist.context.open".localized) {
                NotificationCenter.default.post(name: .openArchiveNotification, object: item.url)
            }
        } else if item.isArchive {
            Button("filelist.context.open.archive".localized) {
                NotificationCenter.default.post(name: .openArchiveNotification, object: item.url)
            }
        }
        Button("filelist.context.show.finder".localized) {
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
