//
//  DebugSettingsView.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

struct DebugSettingsView: View {
    @ObservedObject var appState: AppState
    @State private var testResult = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("developer.debug.logging.enable".localized, isOn: $appState.debugLoggingEnabled)
                    Text("developer.debug.logging.desc".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 24)
                    
                    Divider()
                    
                    Toggle("developer.debug.show.hidden".localized, isOn: $appState.showHiddenFiles)
                    Text("developer.debug.show.hidden.desc".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 24)
                    
                    Divider()
                    
                    HStack {
                        Button("developer.debug.export.logs".localized) {
                            exportLogs()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("developer.debug.clear.logs".localized) {
                            appState.devLogs.removeAll()
                            appState.addDevLog("Logs cleared", type: .info)
                        }
                        .buttonStyle(.bordered)
                        
                        Button("developer.debug.view.console".localized) {
                            openConsole()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            } label: {
                Text("developer.debug.logging".localized)
            }
            
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("developer.debug.custom.paths".localized, isOn: $appState.useCustomToolPaths)
                    
                    if appState.useCustomToolPaths {
                        CustomToolPathRow(label: "developer.debug.path.7zz".localized, path: $appState.customToolPath7zz, tool: "7zz")
                        CustomToolPathRow(label: "developer.debug.path.rar".localized, path: $appState.customToolPathRar, tool: "rar")
                        
                        Text("developer.debug.path.restart.hint".localized)
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.leading, 88)
                    }
                }
                .padding()
            } label: {
                Text("developer.debug.tool.paths".localized)
            }
            
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        // ✅ 真实测试：加载测试归档
                        Button("developer.debug.test.load".localized) {
                            appState.addDevLog("Testing archive load...", type: .info)
                            
                            let testURL = FileManager.default.homeDirectoryForCurrentUser
                                .appendingPathComponent("Desktop")
                                .appendingPathComponent("test.zip")
                            
                            if FileManager.default.fileExists(atPath: testURL.path) {
                                // 通过通知触发加载
                                NotificationCenter.default.post(
                                    name: .openArchiveNotification,
                                    object: testURL
                                )
                                appState.addDevLog("✅ Loaded test archive: \(testURL.lastPathComponent)", type: .success)
                                testResult = "Loaded: \(testURL.lastPathComponent)"
                            } else {
                                appState.addDevLog("⚠️ test.zip not found on Desktop", type: .warning)
                                testResult = "test.zip not found"
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        // ✅ 真实测试：模拟错误
                        Button("developer.debug.test.error".localized) {
                            appState.addDevLog("Testing error handling...", type: .info)
                            
                            let simulatedError = ArchiveError.commandFailed("Corrupted archive")
                            appState.addDevLog("Simulated error: \(simulatedError.localizedDescription)", type: .error)
                            testResult = "Error simulated: \(simulatedError.localizedDescription)"
                        }
                        .buttonStyle(.bordered)
                        
                        // ✅ 真实测试：检测工具
                        Button("developer.debug.test.tools".localized) {
                            let resolver = ToolPathResolver()
                            let sevenzz = resolver.resolve("7zz")
                            let rar = resolver.resolve("rar")
                            let status = "7zz: \(sevenzz ?? "not found")\nRAR: \(rar ?? "not found")"
                            appState.addDevLog("Tool paths:\n\(status)", type: .info)
                            testResult = status
                        }
                        .buttonStyle(.bordered)
                        
                        // ✅ 真实测试：开关状态
                        Button("developer.debug.test.switches".localized) {
                            let status = """
                            Parallel: \(appState.experimentalParallelExtract)
                            NewEngine: \(appState.experimentalNewExtractor)
                            FastZip: \(appState.experimentalFastZip)
                            AsyncWrite: \(appState.unstableAsyncWrite)
                            MemoryExtract: \(appState.unstableMemoryExtract)
                            """
                            appState.addDevLog("Switch status:\n\(status)", type: .info)
                            testResult = status
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    // ✅ 显示测试结果
                    if !testResult.isEmpty {
                        Text(testResult)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
                .padding()
            } label: {
                Text("developer.debug.test.operations".localized)
            }
        }
    }
    
    private func exportLogs() {
        let logText = appState.devLogs.map { "[\($0.formattedDate)] \($0.message)" }.joined(separator: "\n")
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "debug_logs.txt"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? logText.write(to: url, atomically: true, encoding: .utf8)
                appState.addDevLog("Logs exported", type: .success)
            }
        }
    }
    
    private func openConsole() {
        let script = """
        tell application "Console"
            activate
        end tell
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }
}

struct CustomToolPathRow: View {
    let label: String
    @Binding var path: String
    let tool: String
    
    var body: some View {
        HStack {
            Text(label)
                .frame(width: 80, alignment: .leading)
            TextField("/usr/local/bin/\(tool)", text: $path)
                .textFieldStyle(.roundedBorder)
            Button("developer.debug.path.browse".localized) {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                panel.allowedContentTypes = [.executable]
                panel.begin { response in
                    if response == .OK, let url = panel.url {
                        path = url.path
                    }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}
