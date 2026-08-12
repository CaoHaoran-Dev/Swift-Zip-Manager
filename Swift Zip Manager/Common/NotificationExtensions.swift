//
//  NotificationExtensions.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

// Common/NotificationExtensions.swift

import Foundation

extension Notification.Name {
    // 应用内通知
    static let languageChanged = Notification.Name("languageChangedNotification")
    static let openArchive = Notification.Name("openArchiveNotification")
    static let showOpenPanel = Notification.Name("showOpenPanelNotification")
    static let showHelp = Notification.Name("showHelpNotification")
    static let checkForUpdates = Notification.Name("checkForUpdatesNotification")
    static let reloadFileList = Notification.Name("reloadFileList")
    static let parallelExtractionChanged = Notification.Name("parallelExtractionChanged")
    static let newExtractorChanged = Notification.Name("newExtractorChanged")
    static let asyncWriteChanged = Notification.Name("asyncWriteChanged")
    static let developerSettingsChanged = Notification.Name("developerSettingsChanged")
    static let developerSettingsReset = Notification.Name("developerSettingsReset")
    
    // 操作通知
    static let checkForUpdatesNotification = Notification.Name("checkForUpdatesNotification")
    static let openArchiveNotification = Notification.Name("openArchiveNotification")
    static let showOpenPanelNotification = Notification.Name("showOpenPanelNotification")
    static let showHelpNotification = Notification.Name("showHelpNotification")
    static let extractSelectedNotification = Notification.Name("extractSelectedNotification")
    static let extractAllNotification = Notification.Name("extractAllNotification")
    static let deleteSelectedNotification = Notification.Name("deleteSelectedNotification")
    static let showInFinderNotification = Notification.Name("showInFinderNotification")
    
    // ✅ 新增：密码弹窗通知
    static let showPasswordDialogNotification = Notification.Name("showPasswordDialogNotification")
}
