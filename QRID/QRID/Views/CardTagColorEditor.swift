import SwiftUI

struct CardTagColorEditor: View {
    let tagInput: String
    @Binding var colorOverrides: [String: String]
    @State private var isExpanded = false

    private var tags: [String] {
        CardTagLimiter.tags(from: tagInput)
    }

    var body: some View {
        if !tags.isEmpty {
            Section {
                DisclosureGroup(L.tagColors, isExpanded: $isExpanded) {
                    ForEach(tags, id: \.self) { tag in
                        ColorPicker(selection: colorBinding(for: tag), supportsOpacity: false) {
                            HStack(spacing: 8) {
                                colorPreview(for: tag)
                                    .frame(width: 22, height: 12)
                                Text(tag)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
    }

    private func colorBinding(for tag: String) -> Binding<Color> {
        Binding {
            color(for: tag)
        } set: { newColor in
            let key = CardTagColorPalette.normalized(tag)
            if let hex = newColor.toHex() {
                colorOverrides[key] = hex
            }
        }
    }

    private func color(for tag: String) -> Color {
        Color(hex: CardTagColorPalette.colorHex(for: tag, overrides: colorOverrides))
    }

    @ViewBuilder
    private func colorPreview(for tag: String) -> some View {
        let style = CardTagColorPalette.colorStyle(for: tag, overrides: colorOverrides)
        if style.isMulticolor {
            LinearGradient(
                stops: tagGradientStops(for: style),
                startPoint: .leading,
                endPoint: .trailing
            )
            .clipShape(Capsule())
        } else {
            Capsule()
                .fill(Color(hex: style.leadingHex))
        }
    }
}

struct CardTagInputView: View {
    @Binding var text: String
    @State private var draft = ""

    private var tags: [String] {
        CardTagLimiter.tags(from: text)
    }

    private var suggestions: [String] {
        CardTagIndex.suggestions(
            for: draft,
            excluding: tags
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !tags.isEmpty {
                CardTagFlowLayout(spacing: 7, rowSpacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        CardTagPreviewChip(tag: tag) {
                            removeTag(tag)
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            HStack(spacing: 8) {
                TextField(L.tags, text: $draft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit {
                        commitDraft()
                    }
                    .onChange(of: draft) { _, newValue in
                        commitPastedLinesIfNeeded(newValue)
                    }

                Text("\(tags.count)/\(CardTagLimiter.maxTags)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
            .disabled(tags.count >= CardTagLimiter.maxTags)

            if tags.count >= CardTagLimiter.maxTags {
                Text(L.cardTagsHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !suggestions.isEmpty {
                CardTagFlowLayout(spacing: 8, rowSpacing: 6) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            applySuggestion(suggestion)
                        } label: {
                            Text(suggestion)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .foregroundStyle(.primary)
                                .background(.thinMaterial, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if tags.count < CardTagLimiter.maxTags {
                Text(L.cardTagsHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func commitDraft() {
        appendTags([draft])
        draft = ""
    }

    private func applySuggestion(_ suggestion: String) {
        appendTags([suggestion])
        draft = ""
    }

    private func commitPastedLinesIfNeeded(_ value: String) {
        let normalizedValue = value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        guard normalizedValue.contains("\n") else { return }

        var parts = normalizedValue.components(separatedBy: "\n")
        draft = parts.popLast() ?? ""
        appendTags(parts)
    }

    private func appendTags(_ rawTags: [String]) {
        var nextTags = tags
        var seen = Set(nextTags.map(CardTagIndex.normalizedKey))

        for rawTag in rawTags {
            let tag = CardTagLimiter.normalizedTag(rawTag)
            guard !tag.isEmpty else { continue }
            let key = CardTagIndex.normalizedKey(tag)
            guard !seen.contains(key), nextTags.count < CardTagLimiter.maxTags else { continue }
            nextTags.append(tag)
            seen.insert(key)
        }

        text = nextTags.joined(separator: "\n")
    }

    private func removeTag(_ tag: String) {
        let removeKey = CardTagIndex.normalizedKey(tag)
        text = tags
            .filter { CardTagIndex.normalizedKey($0) != removeKey }
            .joined(separator: "\n")
    }
}

private struct CardTagPreviewChip: View {
    let tag: String
    let onRemove: () -> Void

    var body: some View {
        let style = CardTagColorPalette.colorStyle(for: tag)
        let tagColor = Color(hex: style.leadingHex)
        HStack(spacing: 5) {
            Text(tag)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .foregroundStyle(tagColor.uiContrastColor.opacity(0.92))
        .background {
            tagBackground(for: style)
        }
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.32), lineWidth: 1)
        )
        .onTapGesture {
            onRemove()
        }
        .accessibilityLabel("\(tag), remove")
    }

    @ViewBuilder
    private func tagBackground(for style: CardTagColorStyle) -> some View {
        if style.isMulticolor {
            LinearGradient(
                stops: tagGradientStops(for: style, opacity: 0.86),
                startPoint: .leading,
                endPoint: .trailing
            )
            .clipShape(Capsule())
        } else {
            Capsule()
                .fill(Color(hex: style.leadingHex).opacity(0.86))
        }
    }
}

private func tagGradientStops(for style: CardTagColorStyle, opacity: Double = 1) -> [Gradient.Stop] {
    guard style.segmentHexes.count > 1 else { return [] }
    let segmentCount = Double(style.segmentHexes.count)

    return style.segmentHexes.enumerated().flatMap { index, hex in
        let start = Double(index) / segmentCount
        let end = Double(index + 1) / segmentCount
        let color = Color(hex: hex).opacity(opacity)
        return [
            Gradient.Stop(color: color, location: start),
            Gradient.Stop(color: color, location: end),
        ]
    }
}

struct CardTagFlowLayout: Layout {
    var spacing: CGFloat = 7
    var rowSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320
        let rows = arrangedRows(in: maxWidth, subviews: subviews)
        let width = proposal.width ?? rows.map(\.width).max() ?? 0
        let height = rows.reduce(CGFloat.zero) { total, row in
            total + row.height
        } + CGFloat(max(rows.count - 1, 0)) * rowSpacing

        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrangedRows(in: bounds.width, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for item in row.items {
                let itemBounds = CGRect(
                    x: x,
                    y: y + (row.height - item.size.height) / 2,
                    width: item.size.width,
                    height: item.size.height
                )
                subviews[item.index].place(
                    at: itemBounds.origin,
                    proposal: ProposedViewSize(itemBounds.size)
                )
                x += item.size.width + spacing
            }
            y += row.height + rowSpacing
        }
    }

    private func arrangedRows(in maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        let usableWidth = max(maxWidth, 1)

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let nextWidth = current.items.isEmpty ? size.width : current.width + spacing + size.width

            if !current.items.isEmpty, nextWidth > usableWidth {
                rows.append(current)
                current = Row()
            }

            current.items.append(Item(index: index, size: size))
            current.width = current.items.count == 1 ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
        }

        if !current.items.isEmpty {
            rows.append(current)
        }

        return rows
    }

    private struct Row {
        var items: [Item] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private struct Item {
        let index: Int
        let size: CGSize
    }
}
