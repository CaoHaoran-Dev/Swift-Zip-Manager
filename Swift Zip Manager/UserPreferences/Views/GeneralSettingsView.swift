//
//  GeneralSettingsView.swift
//  Swift Zip Manager
//
//  Created by Haoran on 2026/8/9.
//

import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var languageManager: LanguageManager
    @State private var selectedLanguage: String
    
    init(languageManager: LanguageManager) {
        self.languageManager = languageManager
        self._selectedLanguage = State(initialValue: languageManager.currentLanguage)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("settings.general.title".localized)
                .font(.largeTitle)
                .bold()
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("settings.general.language".localized)
                    .font(.title3)
                    .bold()
                
                HStack {
                    Text("settings.general.display.language".localized)
                        .frame(width: 140, alignment: .leading)
                    Picker("", selection: $selectedLanguage) {
                        ForEach(languageManager.supportedLanguages, id: \.self) { code in
                            Text(languageManager.languageDisplayNames[code] ?? code)
                                .tag(code)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                    .onChange(of: selectedLanguage) { newValue in
                        if newValue != languageManager.currentLanguage {
                            languageManager.currentLanguage = newValue
                        }
                    }
                }
            }
        }
    }
}
