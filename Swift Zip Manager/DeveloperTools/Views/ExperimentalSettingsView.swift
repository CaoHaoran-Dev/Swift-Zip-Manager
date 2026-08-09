//
//  ExperimentalSettingsView.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

struct ExperimentalSettingsView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("developer.experimental.parallel".localized, isOn: $appState.experimentalParallelExtract)
                    
                    Text("developer.experimental.parallel.desc".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 24)
                    
                    Divider()
                    
                    Toggle("developer.experimental.new.engine".localized, isOn: $appState.experimentalNewExtractor)
                    
                    Text("developer.experimental.new.engine.desc".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 24)
                    
                    Divider()
                    
                    Toggle("developer.experimental.fast.zip".localized, isOn: $appState.experimentalFastZip)
                    
                    Text("developer.experimental.fast.zip.desc".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 24)
                }
                .padding()
            } label: {
                Text("developer.experimental.title".localized)
            }
            
            HStack {
                Image(systemName: "info.circle")
                Text("developer.experimental.warning".localized)
                    .font(.caption)
            }
            .foregroundColor(.orange)
        }
    }
}
