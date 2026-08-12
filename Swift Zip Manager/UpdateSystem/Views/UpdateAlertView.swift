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
            
            HStack(spacing: 8) {
                Text("Build \(update.buildNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if update.isPrerelease {
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("settings.updates.beta".localized)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            // ✅ 手动渲染 Markdown
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(parsedMarkdown, id: \.id) { block in
                        renderBlock(block)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 140)
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
        .frame(width: 460, height: 430)
    }
    
    // MARK: - Markdown 解析
    
    struct MarkdownBlock: Identifiable {
        let id = UUID()
        let type: BlockType
        let content: String
        let level: Int // 标题级别
        
        enum BlockType {
            case heading
            case listItem
            case paragraph
            case separator
        }
    }
    
    var parsedMarkdown: [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = update.body.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty { continue }
            
            // 标题: ## 或 ###
            if trimmed.hasPrefix("## ") {
                let content = String(trimmed.dropFirst(3))
                blocks.append(MarkdownBlock(type: .heading, content: content, level: 2))
            } else if trimmed.hasPrefix("### ") {
                let content = String(trimmed.dropFirst(4))
                blocks.append(MarkdownBlock(type: .heading, content: content, level: 3))
            }
            // 列表项: - 或 *
            else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let content = String(trimmed.dropFirst(2))
                blocks.append(MarkdownBlock(type: .listItem, content: content, level: 0))
            }
            // 分隔线: ---
            else if trimmed == "---" {
                blocks.append(MarkdownBlock(type: .separator, content: "", level: 0))
            }
            // 普通段落
            else {
                blocks.append(MarkdownBlock(type: .paragraph, content: trimmed, level: 0))
            }
        }
        
        return blocks
    }
    
    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block.type {
        case .heading:
            Text(block.content)
                .font(.headline)
                .bold()
                .padding(.top, 8)
                .padding(.bottom, 2)
            
        case .listItem:
            HStack(alignment: .top, spacing: 6) {
                Text("•")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                Text(renderInlineMarkdown(block.content))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 4)
            
        case .paragraph:
            Text(renderInlineMarkdown(block.content))
                .font(.caption)
                .foregroundColor(.secondary)
            
        case .separator:
            Divider()
                .padding(.vertical, 4)
        }
    }
    
    // MARK: - 行内 Markdown 渲染（粗体、斜体、代码）
    
    private func renderInlineMarkdown(_ text: String) -> AttributedString {
        _ = AttributedString(text)
        
        // 解析 **粗体**
        let boldPattern = try? NSRegularExpression(pattern: "\\*\\*(.*?)\\*\\*", options: [])
        if let matches = boldPattern?.matches(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length)) {
            for match in matches.reversed() {
                let range = match.range(at: 1)
                let boldText = (text as NSString).substring(with: range)
                let attributedBold = AttributedString(boldText)
                var boldAttr = attributedBold
                boldAttr.font = .caption.bold()
                // 替换
                _ = match.range(at: 0)
                // 简单方式：用 AttributedString 替换
            }
        }
        
        // 简单实现：只处理粗体
        let parts = text.components(separatedBy: "**")
        var attributed = AttributedString()
        
        for (index, part) in parts.enumerated() {
            if index % 2 == 1 {
                // 粗体部分
                var boldPart = AttributedString(part)
                boldPart.font = .caption.bold()
                attributed.append(boldPart)
            } else {
                attributed.append(AttributedString(part))
            }
        }
        
        return attributed
    }
}
