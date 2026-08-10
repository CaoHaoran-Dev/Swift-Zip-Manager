//
//  UpdateAlertView.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

struct UpdateAlertView: View {
    let update: UpdateChecker.UpdateInfo
    let onDownload: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            Text("settings.updates.new.available.title".localized)
                .font(.headline)
            
            Text("Build \(update.buildNumber)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if update.isPrerelease {
                Text("settings.updates.beta".localized)
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            ScrollView {
                Text(update.body)
                    .font(.caption)
                    .padding()
            }
            .frame(height: 100)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
            .cornerRadius(8)
            
            Divider()
            
            HStack(spacing: 20) {
                Button("settings.updates.new.available.later".localized) {
                    onDismiss()
                }
                .buttonStyle(.bordered)
                
                Button("settings.updates.new.available.download".localized) {
                    onDownload()
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 400, height: 380)
    }
}
