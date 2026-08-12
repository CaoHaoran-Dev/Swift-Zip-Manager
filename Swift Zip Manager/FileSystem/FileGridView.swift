//
//  FileGridView.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

struct FileGridView: View {
    let items: [FileItem]
    @Binding var selectedIDs: Set<UUID>
    let onItemTap: (FileItem) -> Void
    
    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items) { item in
                    FileGridItem(
                        item: item,
                        isSelected: selectedIDs.contains(item.id)
                    )
                    .onTapGesture { onItemTap(item) }
                    .contextMenu { FileItemContextMenu(item: item) }
                }
            }
            .padding()
        }
    }
}

struct FileGridItem: View {
    let item: FileItem
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: item.icon)
                .font(.system(size: 40))
                .foregroundColor(item.iconColor)
            Text(item.name)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
            if !item.isDirectory {
                Text(item.sizeFormatted)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 90)
        .padding(10)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}
