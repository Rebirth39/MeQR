import SwiftUI
import UIKit

// MARK: - 数据模型（严格按 richtext-spec v1：runs 数组 JSON）

struct ShareCardTextRun: Codable, Equatable {
    var t: String
    var b: Int = 0
    var i: Int = 0
    var u: Int = 0
    var c: String = ""
    var s: Double = 1.0
}

enum ShareCardRichText {
    static let basePointSize: CGFloat = 17

    /// 容错解析：纯字符串视为单 run；缺字段按默认；非法 JSON 回退纯文本。
    static func runs(from stored: String?) -> [ShareCardTextRun] {
        guard let stored, !stored.isEmpty else { return [] }
        guard let data = stored.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return [ShareCardTextRun(t: stored)]
        }
        return array.compactMap { item in
            guard let text = item["t"] as? String else { return nil }
            return ShareCardTextRun(
                t: text,
                b: (item["b"] as? Int) ?? 0,
                i: (item["i"] as? Int) ?? 0,
                u: (item["u"] as? Int) ?? 0,
                c: (item["c"] as? String) ?? "",
                s: (item["s"] as? Double) ?? 1.0
            )
        }
    }

    /// 序列化：c/s 字段写全，b/i/u 用 0/1。
    static func json(from runs: [ShareCardTextRun]) -> String {
        let array: [[String: Any]] = runs.map {
            ["t": $0.t, "b": $0.b, "i": $0.i, "u": $0.u, "c": $0.c, "s": $0.s]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: array),
              let string = String(data: data, encoding: .utf8) else { return "[]" }
        return string
    }

    // MARK: runs → 渲染（ImageRenderer 与预览同一路径）

    static func attributedString(from runs: [ShareCardTextRun], baseSize: CGFloat, baseColor: Color) -> AttributedString {
        var result = AttributedString()
        for run in runs {
            var part = AttributedString(run.t)
            var font = Font.system(size: baseSize * run.s)
            if run.b == 1 { font = font.bold() }
            if run.i == 1 { font = font.italic() }
            part.font = font
            if run.u == 1 { part.underlineStyle = .single }
            part.foregroundColor = run.c.isEmpty ? baseColor : Color(hex: run.c)
            result.append(part)
        }
        return result
    }

    // MARK: NSAttributedString ↔ runs（编辑器桥接用）

    static func nsAttributedString(from runs: [ShareCardTextRun]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for run in runs {
            result.append(NSAttributedString(string: run.t, attributes: attributes(for: run)))
        }
        return result
    }

    private static func attributes(for run: ShareCardTextRun) -> [NSAttributedString.Key: Any] {
        let size = basePointSize * run.s
        var font = UIFont.systemFont(ofSize: size)
        var traits = font.fontDescriptor.symbolicTraits
        if run.b == 1 { traits.insert(.traitBold) }
        if run.i == 1 { traits.insert(.traitItalic) }
        if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
            font = UIFont(descriptor: descriptor, size: size)
        }
        var attributes: [NSAttributedString.Key: Any] = [.font: font]
        if run.u == 1 { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        if !run.c.isEmpty {
            attributes[.foregroundColor] = UIColor(Color(hex: run.c))
        }
        return attributes
    }

    static func runs(from attributed: NSAttributedString) -> [ShareCardTextRun] {
        var result: [ShareCardTextRun] = []
        var index = 0
        let length = attributed.length
        while index < length {
            var range = NSRange()
            let attributes = attributed.attributes(at: index, effectiveRange: &range)
            var run = ShareCardTextRun(t: attributed.attributedSubstring(from: range).string)
            if let font = attributes[.font] as? UIFont {
                let traits = font.fontDescriptor.symbolicTraits
                run.b = traits.contains(.traitBold) ? 1 : 0
                run.i = traits.contains(.traitItalic) ? 1 : 0
                run.s = min(1.5, max(0.8, font.pointSize / basePointSize))
            }
            if (attributes[.underlineStyle] as? Int ?? 0) != 0 { run.u = 1 }
            if let color = attributes[.foregroundColor] as? UIColor {
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                if color.getRed(&r, green: &g, blue: &b, alpha: &a) {
                    run.c = String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
                }
            }
            if !run.t.isEmpty { result.append(run) }
            index = range.upperBound
        }
        return result
    }
}

// MARK: - 选区样式动作

enum ShareCardRichAction {
    case toggleBold, toggleItalic, toggleUnderline
    case color(String)   // "" 表示恢复默认墨色
    case scale(Double)   // 绝对倍率
}

// MARK: - UITextView 桥接（选区即时生效 WYSIWYG）

final class ShareCardTextViewBox {
    weak var view: UITextView?
}

struct ShareCardRichTextEditor: UIViewRepresentable {
    @Binding var attributed: NSAttributedString
    @Binding var selection: NSRange
    let box: ShareCardTextViewBox
    var minHeight: CGFloat = 44
    var onChange: () -> Void

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        box.view = view
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.isScrollEnabled = true
        view.font = UIFont.systemFont(ofSize: ShareCardRichText.basePointSize)
        view.textContainerInset = UIEdgeInsets(top: 6, left: 4, bottom: 6, right: 4)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.attributedText = attributed
        // 自定义 UITextView 吃不到 SwiftUI 的 keyboard toolbar，
        // 直接在键盘上方挂一个「完成」按钮方便收起键盘
        let accessory = UIToolbar(frame: CGRect(x: 0, y: 0, width: 0, height: 44))
        accessory.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: L.done, style: .done, target: view, action: #selector(UIResponder.resignFirstResponder))
        ]
        accessory.sizeToFit()
        view.inputAccessoryView = accessory
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.attributedText != attributed {
            let selected = uiView.selectedRange
            uiView.attributedText = attributed
            uiView.selectedRange = NSRange(location: min(selected.location, attributed.length), length: 0)
        }
        if uiView.selectedRange != selection {
            uiView.selectedRange = selection
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        private let parent: ShareCardRichTextEditor

        init(_ parent: ShareCardRichTextEditor) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.attributed = textView.attributedText.copy() as! NSAttributedString
            parent.onChange()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.selection = textView.selectedRange
        }
    }
}

// MARK: - 工具栏状态读取与应用（作用于 UITextView 选区）

enum ShareCardRichSelection {
    static func traits(in attributed: NSAttributedString, range: NSRange) -> (bold: Bool, italic: Bool, underline: Bool, color: String, scale: Double) {
        guard attributed.length > 0 else { return (false, false, false, "", 1.0) }
        let safe = NSRange(location: min(range.location, attributed.length - 1), length: range.length)
        var allBold = true, allItalic = true, allUnderline = true
        var color = ""
        var scale = 1.0
        attributed.enumerateAttributes(in: safe) { attributes, _, _ in
            if let font = attributes[.font] as? UIFont {
                let traits = font.fontDescriptor.symbolicTraits
                if !traits.contains(.traitBold) { allBold = false }
                if !traits.contains(.traitItalic) { allItalic = false }
                scale = min(1.5, max(0.8, font.pointSize / ShareCardRichText.basePointSize))
            }
            if (attributes[.underlineStyle] as? Int ?? 0) == 0 { allUnderline = false }
            if let value = attributes[.foregroundColor] as? UIColor {
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                if value.getRed(&r, green: &g, blue: &b, alpha: &a) {
                    color = String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
                }
            }
        }
        if safe.length == 0 {
            // 光标态：取光标前一个字符的样式
            return traits(in: attributed, range: NSRange(location: max(0, safe.location - 1), length: 1))
        }
        return (allBold, allItalic, allUnderline, color, scale)
    }

    static func apply(_ action: ShareCardRichAction, to textView: UITextView) {
        let range = textView.selectedRange
        let store = textView.textStorage
        switch action {
        case .toggleBold:
            toggleTrait(.traitBold, on: store, range: range, textView: textView)
        case .toggleItalic:
            toggleTrait(.traitItalic, on: store, range: range, textView: textView)
        case .toggleUnderline:
            let active = ShareCardRichSelection.traits(in: store, range: range).underline
            let setValue: (NSRange) -> Void = { target in
                if active { store.removeAttribute(.underlineStyle, range: target) }
                else { store.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: target) }
            }
            if range.length > 0 { setValue(range) } else {
                var typing = textView.typingAttributes
                if active { typing.removeValue(forKey: .underlineStyle) }
                else { typing[.underlineStyle] = NSUnderlineStyle.single.rawValue }
                textView.typingAttributes = typing
            }
        case .color(let hex):
            let setValue: (NSRange) -> Void = { target in
                if hex.isEmpty { store.removeAttribute(.foregroundColor, range: target) }
                else { store.addAttribute(.foregroundColor, value: UIColor(Color(hex: hex)), range: target) }
            }
            if range.length > 0 { setValue(range) } else {
                var typing = textView.typingAttributes
                if hex.isEmpty { typing.removeValue(forKey: .foregroundColor) }
                else { typing[.foregroundColor] = UIColor(Color(hex: hex)) }
                textView.typingAttributes = typing
            }
        case .scale(let ratio):
            let clamped = min(1.5, max(0.8, ratio))
            let setValue: (NSRange) -> Void = { target in
                store.enumerateAttribute(.font, in: target) { value, subrange, _ in
                    let font = (value as? UIFont) ?? UIFont.systemFont(ofSize: ShareCardRichText.basePointSize)
                    store.addAttribute(.font, value: font.withSize(ShareCardRichText.basePointSize * clamped), range: subrange)
                }
            }
            if range.length > 0 { setValue(range) } else {
                var typing = textView.typingAttributes
                let font = (typing[.font] as? UIFont) ?? UIFont.systemFont(ofSize: ShareCardRichText.basePointSize)
                typing[.font] = font.withSize(ShareCardRichText.basePointSize * clamped)
                textView.typingAttributes = typing
            }
        }
    }

    private static func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits, on store: NSTextStorage, range: NSRange, textView: UITextView) {
        let active = ShareCardRichSelection.traits(in: store, range: range).bold && trait == .traitBold
            || ShareCardRichSelection.traits(in: store, range: range).italic && trait == .traitItalic
        let mutate: (NSRange) -> Void = { target in
            store.enumerateAttribute(.font, in: target) { value, subrange, _ in
                let font = (value as? UIFont) ?? UIFont.systemFont(ofSize: ShareCardRichText.basePointSize)
                var traits = font.fontDescriptor.symbolicTraits
                if active { traits.remove(trait) } else { traits.insert(trait) }
                if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
                    store.addAttribute(.font, value: UIFont(descriptor: descriptor, size: font.pointSize), range: subrange)
                }
            }
        }
        if range.length > 0 { mutate(range) } else {
            var typing = textView.typingAttributes
            let font = (typing[.font] as? UIFont) ?? UIFont.systemFont(ofSize: ShareCardRichText.basePointSize)
            var traits = font.fontDescriptor.symbolicTraits
            if active { traits.remove(trait) } else { traits.insert(trait) }
            if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
                typing[.font] = UIFont(descriptor: descriptor, size: font.pointSize)
            }
            textView.typingAttributes = typing
        }
    }
}

// MARK: - 工具栏（B/I/U + 8 色 + 字号 −/＋）

struct ShareCardRichToolbar: View {
    let attributed: NSAttributedString
    let selection: NSRange
    let textView: () -> UITextView?
    let onAction: () -> Void

    static let palette = ["", "#EE1166", "#FF8800", "#FFCC00", "#33CC66", "#3399FF", "#7744CC", "#222222"]

    private var traits: (bold: Bool, italic: Bool, underline: Bool, color: String, scale: Double) {
        ShareCardRichSelection.traits(in: attributed, range: selection)
    }

    var body: some View {
        // 两行布局保证全部控件不裁剪（单行放不下 8 色 + 步进器）。
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                styleButton(Text("B").bold(), active: traits.bold) { apply(.toggleBold) }
                styleButton(Text("I").italic(), active: traits.italic) { apply(.toggleItalic) }
                styleButton(Text("U").underline(), active: traits.underline) { apply(.toggleUnderline) }
                Divider().frame(height: 18)
                HStack(spacing: 6) {
                    ForEach(Self.palette, id: \.self) { hex in
                        Button { apply(.color(hex)) } label: {
                            Circle()
                                .fill(hex.isEmpty ? Color(uiColor: .tertiarySystemFill) : Color(hex: hex))
                                .frame(width: 16, height: 16)
                                .overlay(Circle().stroke(traits.color == hex && !hex.isEmpty ? Color.accentColor : .clear, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack(spacing: 6) {
                Button { apply(.scale(round((traits.scale - 0.1) * 10) / 10)) } label: {
                    Image(systemName: "minus").font(.caption.bold())
                }
                Text(String(format: "%.1f", traits.scale))
                    .font(.caption.monospacedDigit())
                    .frame(width: 28)
                Button { apply(.scale(round((traits.scale + 0.1) * 10) / 10)) } label: {
                    Image(systemName: "plus").font(.caption.bold())
                }
            }
        }
        .buttonStyle(.borderless)
    }

    private func styleButton(_ label: Text, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            label
                .font(.system(size: 15))
                .frame(width: 26, height: 26)
                .background(active ? Color.accentColor.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func apply(_ action: ShareCardRichAction) {
        guard let view = textView() else { return }
        ShareCardRichSelection.apply(action, to: view)
        onAction()
    }
}
