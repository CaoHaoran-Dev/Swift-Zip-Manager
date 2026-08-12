//
//  FileBrowserToolbar.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

struct FileBrowserToolbar: View {
    @Binding var viewMode: FileBrowserView.ViewMode
    let onGoUp: () -> Void
    let onExtractAll: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onGoUp) {
                Image(systemName: "arrow.up")
            }
            .buttonStyle(.plain)
            .help("Go Up")
            
            Spacer()
            
            Picker("", selection: $viewMode) {
                ForEach(FileBrowserView.ViewMode.allCases, id: \.self) { mode in
                    Image(systemName: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 80)
            
            // ✅ 始终显示 "Extract All" 按钮
            Button(action: onExtractAll) {
                Label("archive.extract.all".localized, systemImage: "tray.and.arrow.down")            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
    }
}
