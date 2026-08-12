//
//  ArchiveEntryRow.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

struct ArchiveEntryRow: View {
    let entry: ArchiveEntry
    let isSelected: Bool
    let onExtract: (ArchiveEntry) -> Void
    let onDelete: (ArchiveEntry) -> Void
    let onExtractAll: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: entry.isDirectory ? "folder" : "doc")
                .foregroundColor(entry.isDirectory ? .yellow : .blue)
            Text(entry.name)
            Spacer()
            Text(entry.formattedSize)  // ✅ 修复：size → formattedSize
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Extract") { onExtract(entry) }
            if !entry.isDirectory {
                Button("Delete") { onDelete(entry) }
            }
            Divider()
            Button("Extract All") { onExtractAll() }
        }
    }
}
