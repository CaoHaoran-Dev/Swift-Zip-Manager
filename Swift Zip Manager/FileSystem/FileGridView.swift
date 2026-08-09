//
//  FileGridView.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

struct FileGridView: View {
    let items: [FileItem]
    let onItemTap: (FileItem) -> Void
    
    @State private var selectedItemIDs = Set<UUID>()
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 20) {
                ForEach(items) { item in
                    FileGridItem(
                        item: item,
                        isSelected: selectedItemIDs.contains(item.id)
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
        VStack {
            Image(systemName: item.icon)
                .font(.system(size: 40))
                .foregroundColor(item.iconColor)
            Text(item.name)
                .font(.caption)
                .lineLimit(1)
            if !item.isDirectory {
                Text(item.sizeFormatted)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 90)
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(8)
    }
}
