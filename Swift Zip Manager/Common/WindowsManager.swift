//
//  WindowManager.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

//
//  WindowManager.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

class WindowManager: ObservableObject {
    static let shared = WindowManager()
    
    private var settingsWindow: NSWindow?
    private var helpWindow: NSWindow?
    private var settingsDelegate: WindowDelegate?  // ✅ 强引用持有 delegate
    private var helpDelegate: WindowDelegate?      // ✅ 强引用持有 delegate
    
    // MARK: - Settings Window
    func openSettings(appState: AppState, languageManager: LanguageManager) {
        print("🔧 WindowManager: openSettings called")
        
        // 如果窗口已存在且可见，前置显示
        if let existingWindow = settingsWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }
        
        let toolInstaller = ToolInstaller()
        
        let hostingController = NSHostingController(
            rootView: SettingsContainerView(
                appState: appState,
                languageManager: languageManager,
                toolInstaller: toolInstaller
            )
            .frame(minWidth: 750, minHeight: 550)
        )
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Settings"
        window.setContentSize(NSSize(width: 750, height: 550))
        window.minSize = NSSize(width: 600, height: 400)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false
        window.center()
        
        // ✅ 创建 delegate 并强引用持有
        let delegate = WindowDelegate { [weak appState, weak self] in
            print("🔧 Settings window closed")
            appState?.showSettings = false
            self?.settingsWindow = nil
            self?.settingsDelegate = nil  // ✅ 释放 delegate
        }
        window.delegate = delegate
        settingsDelegate = delegate  // ✅ 强引用保存
        
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        
        // 重置 appState 的 showSettings 状态，防止多次触发
        DispatchQueue.main.async {
            appState.showSettings = false
        }
        
        print("🔧 Settings window created and shown")
    }
    
    // MARK: - Help Window
    func openHelp(appState: AppState) {
        print("📖 WindowManager: openHelp called")
        
        // 如果窗口已存在且可见，前置显示
        if let existingWindow = helpWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }
        
        let hostingController = NSHostingController(
            rootView: HelpView()
                .frame(minWidth: 550, minHeight: 550)
        )
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Help"
        window.setContentSize(NSSize(width: 550, height: 550))
        window.minSize = NSSize(width: 400, height: 400)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false
        window.center()
        
        // ✅ 创建 delegate 并强引用持有
        let delegate = WindowDelegate { [weak appState, weak self] in
            print("📖 Help window closed")
            appState?.showHelp = false
            self?.helpWindow = nil
            self?.helpDelegate = nil  // ✅ 释放 delegate
        }
        window.delegate = delegate
        helpDelegate = delegate  // ✅ 强引用保存
        
        helpWindow = window
        window.makeKeyAndOrderFront(nil)
        
        // 重置 appState 的 showHelp 状态，防止多次触发
        DispatchQueue.main.async {
            appState.showHelp = false
        }
        
        print("📖 Help window created and shown")
    }
}

// MARK: - Window Delegate Helper
class WindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void
    
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init()
    }
    
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
