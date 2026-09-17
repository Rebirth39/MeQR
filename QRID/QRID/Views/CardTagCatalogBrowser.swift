import SwiftUI

struct CardTagCatalogBrowser: View {
    @Binding var text: String
    var colorOverrides: [String: CardTagColorOverride] = [:]

    @Environment(\.dismiss) private var dismiss
    @StateObject private var remoteCatalog = RemoteTagCatalog.shared
    @State private var query = ""
    @StateObject private var usage = CardTagUsageStore.shared
    @State private var mode = 0
    @State private var showingInfo = false
    @State private var clearingHistory = false
    @State private var requestingTag = false
    @State private var showingOutbox = false

    private var language: AppLanguage { AppSettings.shared.resolvedLanguage }
    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var searchResults: [RemoteTagEntry] {
        CardTagIndex.searchEntries(for: trimmedQuery)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker(L.tagLibrary, selection: $mode) {
                    Text(L.tagAll).tag(0)
                    Text(L.tagRecent).tag(1)
                    Text(L.tagFrequent).tag(2)
                    Text(L.tagFavorites).tag(3)
                }
                .pickerStyle(.segmented)
                .padding()
                if mode != 0 {
                    historyList
                } else if trimmedQuery.isEmpty {
                    categoryList
                } else if searchResults.isEmpty, !remoteCatalog.isLoading {
                    VStack {
                        ContentUnavailableView.search(text: trimmedQuery)
                        Button(L.tagRequestNew) { requestingTag = true }.padding(.bottom)
                    }
                } else {
                    tagList(searchResults)
                }
            }
            .navigationTitle(L.tagLibrary)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: L.searchTags)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingInfo = true } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel(L.tagCatalogInfo)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { requestingTag = true } label: { Image(systemName: "square.and.pencil") }.accessibilityLabel(L.tagRequestNew)
                    Button { showingOutbox = true } label: { Image(systemName: "tray") }.accessibilityLabel(L.tagOutbox)
                    Button(L.done) { dismiss() }
                }
            }
        }
        .task {
            await remoteCatalog.refreshIfNeeded()
        }
        .sheet(isPresented: $showingInfo) { CardTagCatalogInfoView() }
        .sheet(isPresented: $requestingTag) { CardTagReportView(tag: trimmedQuery, isNewTag: true) }
        .sheet(isPresented: $showingOutbox) { CardTagOutboxView() }
        .confirmationDialog(L.tagClearHistory, isPresented: $clearingHistory, titleVisibility: .visible) {
            Button(L.tagClearHistory, role: .destructive) { usage.clear() }
        }
    }

    private var historyList: some View {
        let records = (mode == 3 ? usage.favorites : usage.sorted(frequent: mode == 2)).filter {
            trimmedQuery.isEmpty || CardTagIndex.normalizedKey(usage.displayName(for: $0))
                .contains(CardTagIndex.normalizedKey(trimmedQuery))
        }
        return List {
            if records.isEmpty {
                Text(trimmedQuery.isEmpty ? L.tagHistoryEmpty : L.noTagResults)
                    .foregroundStyle(.secondary)
            }
            ForEach(records) { record in
                CardTagCatalogRow(tag: usage.displayName(for: record), text: $text, colorOverrides: colorOverrides)
            }
            if mode != 3 && !usage.records.isEmpty {
                Button(L.tagClearHistory, role: .destructive) { clearingHistory = true }
            }
        }
    }

    @ViewBuilder
    private var categoryList: some View {
        if CardTagIndex.categories.isEmpty {
            VStack(spacing: 12) {
                if remoteCatalog.isLoading {
                    ProgressView()
                    Text(L.tagCatalogLoading)
                        .foregroundStyle(.secondary)
                } else {
                    ContentUnavailableView {
                        Label(L.tagLibrary, systemImage: "tag")
                    } description: {
                        Text(L.tagCatalogRetry)
                    }
                }
            }
        } else {
            List {
                Section(L.browseByIP) {
                    ForEach(CardTagIndex.categories) { category in
                        let entries = CardTagIndex.entries(in: category)
                        if let entry = entries.first, entries.count == 1 {
                            CardTagCatalogRow(
                                tag: entry.names.value(for: language),
                                text: $text,
                                colorOverrides: colorOverrides
                            )
                        } else {
                            NavigationLink {
                                CardTagCategoryView(
                                    category: category,
                                    text: $text,
                                    colorOverrides: colorOverrides
                                )
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "square.stack.3d.up")
                                        .foregroundStyle(.tint)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(category.displayName(for: language))
                                            .foregroundStyle(.primary)
                                        Text(L.tagsAvailable(entries.count))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }
        }
    }

    private func tagList(_ entries: [RemoteTagEntry]) -> some View {
        List(entries) { entry in
            CardTagCatalogRow(
                tag: entry.names.value(for: language),
                text: $text,
                colorOverrides: colorOverrides
            )
        }
    }
}

private struct CardTagCategoryView: View {
    let category: RemoteTagCategory
    @Binding var text: String
    var colorOverrides: [String: CardTagColorOverride]

    private var language: AppLanguage { AppSettings.shared.resolvedLanguage }

    private var sections: [(String, [RemoteTagEntry])] {
        let entries = CardTagIndex.entries(in: category)
        let groups = RemoteTagCatalogSnapshot.groups(in: category.id)
        if !groups.isEmpty {
            // Sections follow the online groups order; ungrouped works stay on top.
            var built: [(String, [RemoteTagEntry])] = []
            let ungrouped = entries.filter { entry in !groups.contains { group in group.ranges.contains { $0.contains(entry.id) } } }
            if !ungrouped.isEmpty { built.append(("", ungrouped)) }
            var assigned = Set<String>()
            for group in groups {
                let members = entries.filter { entry in !assigned.contains(entry.id) && group.ranges.contains { $0.contains(entry.id) } }
                assigned.formUnion(members.map(\.id))
                if !members.isEmpty { built.append((group.names.value(for: language), members)) }
            }
            return built
        }
        let grouped = Dictionary(grouping: entries) { entry in
            entry.parentID.flatMap { RemoteTagCatalogSnapshot.entry(id: $0)?.names.value(for: language) } ?? ""
        }
        let rank: (String) -> Int = { key in if key.isEmpty { return -1 }; let k = key.lowercased(); if k.contains("leo") { return 0 }; if k.contains("more more") || k.contains("mmj") { return 1 }; if k.contains("wonderlands") || k.contains("wxs") { return 2 }; if k.contains("vivid") || k.contains("vbs") { return 3 }; if k.contains("nightcord") || k.contains("25") { return 4 }; return 99 }
        let keys = grouped.keys.sorted { rank($0) == rank($1) ? $0 < $1 : rank($0) < rank($1) }
        return keys.map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        List { ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
            Section(section.0.isEmpty ? category.displayName(for: language) : "— \(section.0) —") {
                ForEach(section.1) { entry in CardTagCatalogRow(tag: entry.names.value(for: language), text: $text, colorOverrides: colorOverrides) }
            }
        }}
        .navigationTitle(category.displayName(for: language))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CardTagCatalogRow: View {
    let tag: String
    @Binding var text: String
    var colorOverrides: [String: CardTagColorOverride]
    @StateObject private var usage = CardTagUsageStore.shared

    private var language: AppLanguage { AppSettings.shared.resolvedLanguage }
    private var displayName: String { tag }
    private var tags: [String] { CardTagLimiter.tags(from: text) }
    private var isSelected: Bool {
        let key = CardTagIndex.selectionKey(displayName)
        return tags.contains { CardTagIndex.selectionKey($0) == key }
    }
    private var canAdd: Bool { isSelected || tags.count < CardTagLimiter.maxTags }

    var body: some View {
        Button(action: toggleSelection) {
            HStack(spacing: 12) {
                CardTagCatalogSwatch(
                    style: CardTagColorPalette.colorStyle(
                        for: displayName,
                        overrides: colorOverrides
                    )
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName).foregroundStyle(.primary)
                    if let entry = RemoteTagCatalogSnapshot.entry(matchingNormalizedKey: CardTagIndex.normalizedKey(tag)) {
                        Text(RemoteTagCatalogSnapshot.subtitle(for: entry, language: language))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                if usage.isFavorite(tag) { Image(systemName: "star.fill").font(.caption).foregroundStyle(.orange) }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(canAdd ? 1 : 0.45)
        .modifier(CardTagReportMenu(tag: tag))
    }

    private func toggleSelection() {
        let selectedKey = CardTagIndex.selectionKey(displayName)
        var nextTags = tags
        if isSelected {
            nextTags.removeAll { CardTagIndex.selectionKey($0) == selectedKey }
        } else if nextTags.count < CardTagLimiter.maxTags {
            nextTags.append(displayName)
            CardTagUsageStore.shared.record(displayName)
        }
        text = nextTags.joined(separator: "\n")
    }
}

struct CardTagCatalogInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var catalog = RemoteTagCatalog.shared

    var body: some View {
        NavigationStack {
            List {
                Section(L.tagCatalogInfo) {
                    LabeledContent(L.versionBuild, value: catalog.revision.isEmpty ? "-" : catalog.revision)
                    LabeledContent(L.tagSource, value: catalog.sourceName)
                    if let status = catalog.statusMessage {
                        Text(status).font(.caption).foregroundStyle(.secondary)
                    }
                    Text(L.tagsAvailable(RemoteTagCatalogSnapshot.value().count))
                        .foregroundStyle(.secondary)
                }
                Section(L.tagCatalogChanges) {
                    if catalog.changelog.isEmpty {
                        Text(L.tagCatalogNoChanges).foregroundStyle(.secondary)
                    }
                    ForEach(catalog.changelog) { change in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(change.revision).font(.headline)
                            Text(change.date).font(.caption).foregroundStyle(.secondary)
                            Text(change.summary.value(for: AppSettings.shared.resolvedLanguage))
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(L.tagCatalogInfo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { Task { await catalog.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                        .disabled(catalog.isLoading)
                        .accessibilityLabel(L.tagCatalogRefresh)
                }
                ToolbarItem(placement: .confirmationAction) { Button(L.done) { dismiss() } }
            }
        }
        .task { await catalog.refreshIfNeeded() }
    }
}

private struct CardTagCatalogSwatch: View {
    let style: CardTagColorStyle

    var body: some View {
        Group {
            if style.isMulticolor {
                LinearGradient(
                    stops: catalogGradientStops,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            } else {
                Color(hex: style.leadingHex)
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1))
    }

    private var catalogGradientStops: [Gradient.Stop] {
        let count = Double(style.segmentHexes.count)
        return style.segmentHexes.enumerated().flatMap { index, hex in
            let start = Double(index) / count
            let end = Double(index + 1) / count
            return [
                Gradient.Stop(color: Color(hex: hex), location: start),
                Gradient.Stop(color: Color(hex: hex), location: end),
            ]
        }
    }
}
