import SwiftUI

struct EncounterPreviewView: View {
    let profile: MeQRExchangeProfile

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = EncounterStore.shared
    @State private var saved = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    encounterHeader(
                        name: profile.name,
                        subtitle: profile.subtitle,
                        avatarBase64: profile.avatarJPEGBase64,
                        backgroundBase64: profile.backgroundJPEGBase64
                    )
                }

                Section(L.platformsFromMeQR) {
                    ForEach(profile.profiles) { platform in
                        platformRow(platform)
                    }
                }
            }
            .navigationTitle(L.meqrProfileFound)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saved ? L.saved : L.saveEncounter) {
                        store.add(profile)
                        saved = true
                        dismiss()
                    }
                    .disabled(saved)
                }
            }
        }
    }
}

struct EncountersView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = EncounterStore.shared
    @State private var searchText = ""

    private var filteredRecords: [EncounterRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return store.records }
        return store.records.filter { record in
            record.name.lowercased().contains(query)
                || record.subtitle.lowercased().contains(query)
                || record.note.lowercased().contains(query)
                || record.tags.contains { $0.lowercased().contains(query) }
                || record.profiles.contains { $0.platformName.lowercased().contains(query) || $0.qrContent.lowercased().contains(query) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredRecords.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? L.noEncountersYet : L.noSearchResults,
                        systemImage: "person.2.crop.square.stack",
                        description: Text(searchText.isEmpty ? L.noEncountersHint : L.tryAnotherSearch)
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredRecords) { record in
                        NavigationLink {
                            EncounterDetailView(record: record)
                        } label: {
                            encounterListRow(record)
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
            .searchable(text: $searchText, prompt: L.searchEncounters)
            .navigationTitle(L.encounters)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.done) { dismiss() }
                }
            }
        }
    }

    private func delete(_ offsets: IndexSet) {
        for offset in offsets {
            store.delete(filteredRecords[offset])
        }
    }

    private func encounterListRow(_ record: EncounterRecord) -> some View {
        HStack(spacing: 12) {
            avatar(base64: record.avatarJPEGBase64)
                .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text(record.name)
                    .font(.headline)
                Text(record.subtitle.isEmpty ? platformSummary(record.profiles) : record.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if !record.tags.isEmpty {
                    Text(record.tags.map { "#\($0)" }.joined(separator: " "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 3)
    }
}

struct EncounterDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = EncounterStore.shared

    @State private var record: EncounterRecord
    @State private var tagsText: String

    init(record: EncounterRecord) {
        _record = State(initialValue: record)
        _tagsText = State(initialValue: record.tags.joined(separator: " "))
    }

    var body: some View {
        List {
            Section {
                encounterHeader(
                    name: record.name,
                    subtitle: record.subtitle,
                    avatarBase64: record.avatarJPEGBase64,
                    backgroundBase64: record.backgroundJPEGBase64
                )
            }

            Section(L.encounterInfo) {
                LabeledContent(L.metAt, value: record.metAt.formatted(date: .abbreviated, time: .shortened))
                TextField(L.note, text: $record.note, axis: .vertical)
                    .lineLimit(2...6)
                TextField(L.tags, text: $tagsText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section(L.platformsFromMeQR) {
                ForEach(record.profiles) { platform in
                    platformRow(platform)
                }
            }
        }
        .navigationTitle(record.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(L.save) { save() }
            }
        }
    }

    private func save() {
        record.tags = tagsText
            .split(whereSeparator: { $0 == " " || $0 == "," || $0 == "，" || $0 == "#" })
            .map(String.init)
        store.update(record)
        dismiss()
    }
}

@ViewBuilder
private func encounterHeader(name: String, subtitle: String, avatarBase64: String?, backgroundBase64: String?) -> some View {
    ZStack(alignment: .bottomLeading) {
        if let backgroundBase64,
           let data = Data(base64Encoded: backgroundBase64),
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 150)
                .clipped()
        } else {
            LinearGradient(
                colors: [Color.primary.opacity(0.08), Color.primary.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        HStack(spacing: 14) {
            avatar(base64: avatarBase64)
                .frame(width: 62, height: 62)
                .shadow(color: .black.opacity(0.16), radius: 10, y: 4)

            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .font(.title3.bold())
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .padding(.vertical, 6)
}

@ViewBuilder
private func avatar(base64: String?) -> some View {
    if let base64,
       let data = Data(base64Encoded: base64),
       let image = UIImage(data: data) {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .clipShape(Circle())
    } else {
        ZStack {
            Circle().fill(Color.primary.opacity(0.1))
            Image(systemName: "person.fill")
                .foregroundStyle(.secondary)
        }
    }
}

@ViewBuilder
private func platformRow(_ platform: MeQRExchangePlatform) -> some View {
    let row = PlatformContentRow(platform: platform)
    if let url = platform.openURL {
        Link(destination: url) {
            row
        }
        .buttonStyle(.plain)
    } else {
        row
    }
}

private func platformSummary(_ platforms: [MeQRExchangePlatform]) -> String {
    platforms.map(\.platformName).prefix(3).joined(separator: " / ")
}

private struct PlatformContentRow: View {
    let platform: MeQRExchangePlatform

    var body: some View {
        HStack(spacing: 12) {
            platformQRCode
                .frame(width: 54, height: 54)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 12).fill(.white))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: (Platform(rawValue: platform.platformType) ?? .custom).iconName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(platform.platformName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Text(platform.qrContent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if platform.openURL != nil {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var platformQRCode: some View {
        if let image = QRCodeGenerator.generate(
            from: platform.qrContent,
            foreground: .black,
            background: .white,
            correctionLevel: "M"
        ) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
        } else {
            Image(systemName: "qrcode")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
        }
    }
}

private extension MeQRExchangePlatform {
    var openURL: URL? {
        let trimmed = qrContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https", "qq", "mqq", "weixin", "wechat", "line", "instagram", "discord", "reddit"].contains(scheme) else {
            return nil
        }
        return url
    }
}
