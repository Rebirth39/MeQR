import SwiftUI

struct CardTagColorEditor: View {
    let tagInput: String
    @Binding var colorOverrides: [String: CardTagColorOverride]
    @State private var isExpanded = false
    @State private var draggedColor: (tag: String, index: Int)?
    @State private var colorDragOffset: CGFloat = 0
    @State private var colorRowHeights: [String: CGFloat] = [:]
    @State private var hexDrafts: [String: String] = [:]

    private var tags: [String] {
        CardTagLimiter.tags(from: tagInput)
    }

    var body: some View {
        if !tags.isEmpty {
            Section {
                DisclosureGroup(L.tagColors, isExpanded: $isExpanded) {
                    ForEach(tags, id: \.self) { tag in
                        tagColorRow(for: tag)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tagColorRow(for tag: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                colorPreview(for: tag)
                    .frame(width: 28, height: 14)
                Text(tag)
                    .fontWeight(textWeight(for: tag).fontWeight)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button {
                    let key = CardTagColorPalette.normalized(tag)
                    var override = colorOverrides[key] ?? CardTagColorOverride(
                        mode: CardTagColorPalette.presetMode(for: tag, overrides: colorOverrides), hexes: [])
                    override.textWeight = textWeight(for: tag).next
                    colorOverrides[key] = override
                } label: {
                    Image(systemName: "bold")
                        .font(.system(size: 14, weight: textWeight(for: tag).fontWeight))
                        .foregroundStyle(textWeight(for: tag) == .regular ? Color.secondary : Color.accentColor)
                        .frame(width: 32, height: 32)
                        .background(Color.secondary.opacity(textWeight(for: tag) == .bold ? 0.2 : 0.08), in: Circle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(L.tagTextWeight)
                .accessibilityValue(textWeightLabel(for: tag))
                .accessibilityIdentifier("tag-weight-" + tag)
                .help(textWeightLabel(for: tag))
            }

            Picker(L.tagColors, selection: presetModeBinding(for: tag)) {
                Text(L.tagColorSolid).tag(CardTagColorOverride.Mode.solid)
                if CardTagColorPalette.hasPresetSplitStyle(for: tag, overrides: colorOverrides) {
                    Text(L.tagColorMixed).tag(CardTagColorOverride.Mode.preset)
                }
                Text(L.tagColorCustom).tag(CardTagColorOverride.Mode.custom)
            }
            .pickerStyle(.segmented)

            if presetModeBinding(for: tag).wrappedValue == .custom {
                let style = CardTagColorPalette.colorStyle(for: tag, overrides: colorOverrides)
                Text(tag)
                    .font(.caption.weight(textWeight(for: tag).fontWeight))
                    .lineLimit(1).padding(.horizontal, 10).padding(.vertical, 5)
                    .modifier(CardTagInkModifier(style: style))
                    .background { colorPreview(for: tag) }
                    .accessibilityLabel(L.tagPreview + ": " + tag)
                customColorControls(for: tag)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func customColorControls(for tag: String) -> some View {
        let hexes = customHexes(for: tag)
        ForEach(hexes.indices, id: \.self) { index in
            HStack(spacing: 8) {
                CardTagColorDragHandle(identifier: "tag-color-handle-\(tag)-\(index)", onChange: { offset in
                    draggedColor = (tag, index); colorDragOffset = offset
                }, onEnd: { offset in
                    if let offset {
                            let step = (colorRowHeights["\(tag):\(index)"] ?? 36) + 8
                            let target = min(hexes.count - 1, max(0, index + Int((offset / step).rounded())))
                            moveColor(for: tag, from: index, to: target)
                    }
                    draggedColor = nil; colorDragOffset = 0
                })
                    .frame(width: 28, height: 36)
                    .accessibilityLabel(L.tagMoveColor)
                    .accessibilityIdentifier("tag-color-handle-\(tag)-\(index)")
                    .accessibilityAction(named: L.tagMoveUp) { moveColor(for: tag, from: index, to: index - 1) }
                    .accessibilityAction(named: L.tagMoveDown) { moveColor(for: tag, from: index, to: index + 1) }
                Text("\(index + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 12)
                ColorPicker("\(L.tagColor) \(index + 1)", selection: customColorBinding(for: tag, index: index), supportsOpacity: false)
                    .labelsHidden().frame(width: 32)
                TextField(L.tagHex, text: hexBinding(for: tag, index: index))
                    .font(.system(.caption, design: .monospaced)).frame(minWidth: 78)
                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                    .accessibilityIdentifier("tag-hex-\(index)")
                if hexes.count > 1 {
                    Button { removeCustomColor(for: tag, at: index) } label: {
                        Image(systemName: "minus.circle").foregroundStyle(.secondary).frame(width: 28, height: 36)
                    }.buttonStyle(.plain).accessibilityLabel(L.removeColor)
                }
            }
            .frame(minHeight: 36)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                colorRowHeights["\(tag):\(index)"] = height
            }
            .offset(y: draggedColor?.tag == tag && draggedColor?.index == index ? colorDragOffset : 0)
            .zIndex(draggedColor?.tag == tag && draggedColor?.index == index ? 1 : 0)
            if let draft = hexDrafts["\(tag):\(index)"], CardTagColorPalette.normalizedHex(draft) == nil {
                Text(L.tagInvalidHex).font(.caption).foregroundStyle(.red)
            }
        }

        if hexes.count < CardTagColorPalette.maxCustomColors {
            Button {
                addCustomColor(for: tag)
            } label: {
                Label(L.addColor, systemImage: "plus.circle")
            }
            .buttonStyle(.borderless)
        }
        if tags.count > 1 {
            Menu {
                ForEach(tags.filter { $0 != tag }, id: \.self) { target in
                    Button(target) {
                        let key = CardTagColorPalette.normalized(target)
                        storeOverride(CardTagColorOverride(mode: .custom, hexes: hexes, textWeight: colorOverrides[key]?.textWeight), key: key)
                        hexDrafts = [:]
                    }
                }
            } label: { Label(L.tagCopyPalette, systemImage: "doc.on.doc") }
        }
    }

    private func hexBinding(for tag: String, index: Int) -> Binding<String> {
        let key = "\(tag):\(index)"
        return Binding(get: {
            let colors = customHexes(for: tag)
            return hexDrafts[key] ?? (colors.indices.contains(index) ? colors[index] : "")
        }, set: { value in
            hexDrafts[key] = value
            if let hex = CardTagColorPalette.normalizedHex(value) { setCustomHex(hex, for: tag, at: index) }
        })
    }

    private func moveColor(for tag: String, from: Int, to: Int) {
        var colors = customHexes(for: tag)
        guard colors.indices.contains(from), colors.indices.contains(to), from != to else { return }
        colors.insert(colors.remove(at: from), at: to)
        let key = CardTagColorPalette.normalized(tag)
        storeOverride(CardTagColorOverride(mode: .custom, hexes: colors, textWeight: colorOverrides[key]?.textWeight), key: key)
        hexDrafts = [:]
    }

    private func presetModeBinding(for tag: String) -> Binding<CardTagColorOverride.Mode> {
        Binding {
            CardTagColorPalette.presetMode(for: tag, overrides: colorOverrides)
        } set: { newMode in
            let key = CardTagColorPalette.normalized(tag)
            storeOverride(CardTagColorOverride(mode: newMode, hexes: customHexes(for: tag), textWeight: colorOverrides[key]?.textWeight), key: key)
        }
    }

    private func customColorBinding(for tag: String, index: Int) -> Binding<Color> {
        Binding {
            let hexes = customHexes(for: tag)
            let hex = hexes.indices.contains(index) ? hexes[index] : CardTagColorPalette.fallbackHex
            return Color(hex: hex)
        } set: { newColor in
            if let hex = newColor.toHex() {
                hexDrafts.removeValue(forKey: "\(tag):\(index)")
                setCustomHex(hex, for: tag, at: index)
            }
        }
    }

    private func customHexes(for tag: String) -> [String] {
        CardTagColorPalette.customHexes(for: tag, overrides: colorOverrides)
    }

    private func textWeight(for tag: String) -> CardTagTextWeight {
        CardTagColorPalette.textWeight(for: tag, overrides: colorOverrides)
    }

    private func textWeightLabel(for tag: String) -> String {
        switch textWeight(for: tag) {
        case .regular: L.tagWeightRegular
        case .medium: L.tagWeightMedium
        case .bold: L.tagWeightBold
        }
    }

    private func setCustomHex(_ hex: String, for tag: String, at index: Int) {
        let key = CardTagColorPalette.normalized(tag)
        var hexes = customHexes(for: tag)
        while hexes.count <= index, hexes.count < CardTagColorPalette.maxCustomColors {
            hexes.append(CardTagColorPalette.fallbackHex)
        }
        guard hexes.indices.contains(index) else { return }
        hexes[index] = hex
        storeOverride(CardTagColorOverride(mode: .custom, hexes: Array(hexes.prefix(CardTagColorPalette.maxCustomColors)), textWeight: colorOverrides[key]?.textWeight), key: key)
    }

    private func addCustomColor(for tag: String) {
        let key = CardTagColorPalette.normalized(tag)
        var hexes = customHexes(for: tag)
        guard hexes.count < CardTagColorPalette.maxCustomColors else { return }
        hexes.append(hexes.last ?? CardTagColorPalette.fallbackHex)
        storeOverride(CardTagColorOverride(mode: .custom, hexes: hexes, textWeight: colorOverrides[key]?.textWeight), key: key)
    }

    private func removeCustomColor(for tag: String, at index: Int) {
        let key = CardTagColorPalette.normalized(tag)
        var hexes = customHexes(for: tag)
        guard hexes.count > 1, hexes.indices.contains(index) else { return }
        hexes.remove(at: index)
        hexDrafts = [:]
        storeOverride(CardTagColorOverride(mode: .custom, hexes: hexes, textWeight: colorOverrides[key]?.textWeight), key: key)
    }

    private func storeOverride(_ value: CardTagColorOverride, key: String) {
        var updated = value
        updated.referenceColors = colorOverrides[key]?.referenceColors
        updated.referenceSolid = colorOverrides[key]?.referenceSolid
        colorOverrides[key] = updated
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

private struct CardTagColorDragHandle: UIViewRepresentable {
    let identifier: String
    var onChange: (CGFloat) -> Void
    var onEnd: (CGFloat?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView(image: UIImage(systemName: "line.3.horizontal"))
        view.tintColor = .secondaryLabel
        view.contentMode = .center
        view.isUserInteractionEnabled = true
        view.isAccessibilityElement = true
        view.accessibilityLabel = L.tagMoveColor
        view.accessibilityIdentifier = identifier
        let gesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.drag(_:)))
        gesture.minimumPressDuration = 0.2
        view.addGestureRecognizer(gesture)
        return view
    }
    func updateUIView(_ view: UIImageView, context: Context) { context.coordinator.parent = self }
    final class Coordinator: NSObject {
        var parent: CardTagColorDragHandle
        private var startY: CGFloat = 0
        init(_ parent: CardTagColorDragHandle) { self.parent = parent }
        @objc func drag(_ gesture: UILongPressGestureRecognizer) {
            let y = gesture.location(in: gesture.view?.window).y
            switch gesture.state {
            case .began: startY = y; parent.onChange(0)
            case .changed: parent.onChange(y - startY)
            case .ended: parent.onEnd(y - startY)
            case .cancelled, .failed: parent.onEnd(nil)
            default: break
            }
        }
    }
}

struct CardTagInputView: View {
    @Binding var text: String
    var colorOverrides: [String: CardTagColorOverride] = [:]
    @StateObject private var remoteCatalog = RemoteTagCatalog.shared
    @State private var draft = ""
    @State private var suggestions: [String] = []
    @State private var showingCatalog = false
    @State private var showingInfo = false

    private var tags: [String] {
        CardTagLimiter.tags(from: text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !tags.isEmpty {
                CardTagReorderView(tags: tags, colorOverrides: colorOverrides,
                                   onReorder: { text = $0.joined(separator: "\n") }, onRemove: removeTag)
                .padding(.vertical, 2)
            }

            HStack(spacing: 8) {
                TextField(L.tagInputHint, text: $draft)
                    .font(.caption)
                    .accessibilityLabel(L.tags)
                    .accessibilityHint(L.tagInputHint)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(tags.count >= CardTagLimiter.maxTags)
                    .onSubmit {
                        commitDraft()
                    }
                    .onChange(of: draft) { _, newValue in
                        commitPastedLinesIfNeeded(newValue)
                    }

                Text("\(tags.count)/\(CardTagLimiter.maxTags)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)

                Button {
                    showingCatalog = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L.browseTagLibrary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))

            if tags.count >= CardTagLimiter.maxTags {
                Text(L.cardTagsHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            applySuggestion(suggestion)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion).font(.subheadline)
                                    if let entry = RemoteTagCatalogSnapshot.entry(matchingNormalizedKey: CardTagIndex.normalizedKey(suggestion)) {
                                        Text(RemoteTagCatalogSnapshot.subtitle(for: entry, language: AppSettings.shared.resolvedLanguage))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "plus.circle").foregroundStyle(.secondary)
                            }.padding(.vertical, 8).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if remoteCatalog.isLoading && suggestions.isEmpty {
                HStack(spacing: 7) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L.tagCatalogLoading)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if remoteCatalog.errorMessage != nil && suggestions.isEmpty {
                Text(L.tagCatalogRetry)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !remoteCatalog.revision.isEmpty {
                Button { showingInfo = true } label: {
                    Label("\(remoteCatalog.sourceName) · \(remoteCatalog.revision)", systemImage: "info.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            if tags.count < CardTagLimiter.maxTags {
                Text(L.cardTagsHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            await remoteCatalog.refreshIfNeeded()
        }
        .task(id: draft) {
            guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                suggestions = []
                return
            }
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            suggestions = CardTagIndex.suggestions(for: draft, excluding: tags)
        }
        .sheet(isPresented: $showingCatalog) {
            CardTagCatalogBrowser(text: $text, colorOverrides: colorOverrides)
        }
        .sheet(isPresented: $showingInfo) { CardTagCatalogInfoView() }
    }

    private func commitDraft() {
        appendTags([draft])
        draft = ""
        suggestions = []
    }

    private func applySuggestion(_ suggestion: String) {
        appendTags([suggestion])
        draft = ""
        suggestions = []
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
        var seen = Set(nextTags.map(CardTagIndex.selectionKey))

        for rawTag in rawTags {
            let tag = CardTagLimiter.normalizedTag(rawTag)
            guard !tag.isEmpty else { continue }
            let key = CardTagIndex.selectionKey(tag)
            guard !seen.contains(key), nextTags.count < CardTagLimiter.maxTags else { continue }
            nextTags.append(tag)
            CardTagUsageStore.shared.record(tag)
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
