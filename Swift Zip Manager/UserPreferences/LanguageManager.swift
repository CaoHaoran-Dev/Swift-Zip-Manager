//
//  LanguageManager.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

class LanguageManager: ObservableObject {
    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set([currentLanguage], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
            Bundle.setLanguage(currentLanguage)
            NotificationCenter.default.post(name: .languageChanged, object: nil)
        }
    }
    
    let supportedLanguages = ["en", "zh-Hans", "zh-Hant"]
    
    /// ✅ 修复：使用 NSLocale 获取本地化名称
    var languageDisplayNames: [String: String] {
        var result: [String: String] = [:]
        for code in supportedLanguages {
            // ✅ 使用 NSLocale 的 displayName 方法
            let nsLocale = NSLocale(localeIdentifier: NSLocale.current.identifier)
            let displayName = nsLocale.displayName(forKey: .identifier, value: code) ?? code
            result[code] = displayName
        }
        return result
    }
    
    init() {
        if let lang = UserDefaults.standard.array(forKey: "AppleLanguages")?.first as? String {
            let supported = ["en", "zh-Hans", "zh-Hant"]
            if supported.contains(lang) {
                currentLanguage = lang
            } else {
                currentLanguage = "en"
            }
        } else {
            let systemLang = Locale.current.language.languageCode?.identifier ?? "en"
            currentLanguage = supportedLanguages.contains(systemLang) ? systemLang : "en"
        }
        
        Bundle.setLanguage(currentLanguage)
    }
    
    func localizedString(_ key: String, comment: String = "") -> String {
        return Bundle.localizedString(forKey: key, value: nil, table: nil)
    }
    
    func localizedString(_ key: String, arguments: [CVarArg], comment: String = "") -> String {
        let format = Bundle.localizedString(forKey: key, value: nil, table: nil)
        return String(format: format, arguments: arguments)
    }
}

extension Bundle {
    private static var bundleKey: UInt8 = 0
    
    static var currentBundle: Bundle? {
        get { return objc_getAssociatedObject(self, &bundleKey) as? Bundle }
        set { objc_setAssociatedObject(self, &bundleKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    static func setLanguage(_ language: String) {
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            currentBundle = Bundle.main
            return
        }
        currentBundle = bundle
    }
    
    static func localizedString(forKey key: String, value: String?, table: String?) -> String {
        if let bundle = currentBundle {
            let result = bundle.localizedString(forKey: key, value: value, table: table)
            if result == key {
                return Bundle.main.localizedString(forKey: key, value: key, table: table)
            }
            return result
        }
        return Bundle.main.localizedString(forKey: key, value: key, table: table)
    }
}

extension String {
    var localized: String {
        return Bundle.localizedString(forKey: self, value: nil, table: nil)
    }
    
    func localized(with arguments: CVarArg...) -> String {
        let format = Bundle.localizedString(forKey: self, value: nil, table: nil)
        return String(format: format, arguments: arguments)
    }
}

extension LanguageManager {
    var bundle: Bundle {
        return Bundle.currentBundle ?? Bundle.main
    }
}

extension View {
    func localizedString(_ key: String) -> String {
        return Bundle.localizedString(forKey: key, value: nil, table: nil)
    }
}
