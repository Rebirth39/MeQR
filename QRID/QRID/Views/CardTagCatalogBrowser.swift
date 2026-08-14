import SwiftUI

struct CardTagCatalogBrowser: View {
    @Binding var text: String
    var colorOverrides: [String: CardTagColorOverride] = [:]

    @Environment(\.dismiss) private var dismiss
    @StateObject private var remoteCatalog = RemoteTagCatalog.shared
    @State private var query = ""

    private var language: AppLanguage { AppSettings.shared.resolvedLanguage }
    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var searchResults: [RemoteTagEntry] {
        CardTagIndex.searchEntries(for: trimmedQuery)
    }

    var body: some View {
        NavigationStack {
            Group {
                if trimmedQuery.isEmpty {
                    categoryList
                } else if searchResults.isEmpty, !remoteCatalog.isLoading {
                    ContentUnavailableView.search(text: trimmedQuery)
                } else {
                    tagList(searchResults)
                }
            }
            .navigationTitle(L.tagLibrary)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: L.searchTags)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.done) { dismiss() }
                }
            }
        }
        .task {
            await remoteCatalog.refreshIfNeeded()
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
                    } actions: {
                        Button(L.tagCatalogRetry) {
                            Task { await remoteCatalog.refresh() }
                        }
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
                                entry: entry,
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
                entry: entry,
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

    var body: some View {
        List(CardTagIndex.entries(in: category)) { entry in
            CardTagCatalogRow(
                entry: entry,
                text: $text,
                colorOverrides: colorOverrides
            )
        }
        .navigationTitle(category.displayName(for: language))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CardTagCatalogRow: View {
    let entry: RemoteTagEntry
    @Binding var text: String
    var colorOverrides: [String: CardTagColorOverride]

    private var language: AppLanguage { AppSettings.shared.resolvedLanguage }
    private var displayName: String { entry.names.value(for: language) }
    private var tags: [String] { CardTagLimiter.tags(from: text) }
    private var isSelected: Bool {
        let key = CardTagIndex.normalizedKey(displayName)
        return tags.contains { CardTagIndex.normalizedKey($0) == key }
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

                Text(displayName)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canAdd)
    }

    private func toggleSelection() {
        let selectedKey = CardTagIndex.normalizedKey(displayName)
        var nextTags = tags
        if isSelected {
            nextTags.removeAll { CardTagIndex.normalizedKey($0) == selectedKey }
        } else if nextTags.count < CardTagLimiter.maxTags {
            nextTags.append(displayName)
        }
        text = nextTags.joined(separator: "\n")
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
