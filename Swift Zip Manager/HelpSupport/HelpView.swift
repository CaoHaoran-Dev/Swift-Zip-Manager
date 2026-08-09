//
//  HelpView.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) var dismiss
    @State private var search = ""
    
    let helpItems = [
        ("help.item.open.archive", ["help.item.open.archive.desc1", "help.item.open.archive.desc2"]),
        ("help.item.new.archive", ["help.item.new.archive.desc1", "help.item.new.archive.desc2"]),
        ("help.item.extract", ["help.item.extract.desc1", "help.item.extract.desc2"]),
        ("help.item.modify", ["help.item.modify.desc1", "help.item.modify.desc2"]),
        ("help.item.settings", ["help.item.settings.desc1", "help.item.settings.desc2"]),
        ("help.item.shortcuts", ["help.item.shortcuts.desc1", "help.item.shortcuts.desc2", "help.item.shortcuts.desc3", "help.item.shortcuts.desc4"])
    ]
    
    var filtered: [(String, [String])] {
        if search.isEmpty {
            return helpItems.map { ($0.0.localized, $0.1.map { $0.localized }) }
        }
        return helpItems.compactMap { item in
            let title = item.0.localized
            let descs = item.1.map { $0.localized }
            let allText = ([title] + descs).joined()
            if allText.localizedCaseInsensitiveContains(search) {
                return (title, descs)
            }
            return nil
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("help.title".localized)
                    .font(.largeTitle)
                    .bold()
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 15)
            
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("help.search.placeholder".localized, text: $search)
                    .textFieldStyle(.plain)
                if !search.isEmpty {
                    Button(action: { search = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.bottom, 15)
            
            Divider()
                .padding(.bottom, 15)
            
            ScrollView {
                if filtered.isEmpty {
                    emptyState
                } else {
                    helpContent
                }
            }
            
            Divider()
                .padding(.top, 10)
            
            HStack {
                Text(String(format: "settings.about.version".localized, Bundle.main.appVersion))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 16)
                Spacer()
            }
            .padding(.vertical, 12)
        }
        .frame(minWidth: 550, minHeight: 550)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(String(format: "help.search.empty".localized, search))
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding()
    }
    
    @ViewBuilder
    private var helpContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(filtered.indices, id: \.self) { index in
                let item = filtered[index]
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.0)
                        .font(.headline)
                        .padding(.leading, 12)
                    
                    ForEach(item.1, id: \.self) { line in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.accentColor)
                            Text(line)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 28)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }
}
