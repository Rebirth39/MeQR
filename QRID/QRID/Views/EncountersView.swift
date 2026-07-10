import SwiftUI

struct EncounterPreviewView: View {
    let profile: MeQRExchangeProfile

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = EncounterStore.shared
    @ObservedObject private var eventStore = EventStore.shared
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

                if let activeEvent = eventStore.activeEvent {
                    Section(L.activeEvent) {
                        LabeledContent(L.eventName, value: activeEvent.title)
                        if !activeEvent.venue.isEmpty {
                            LabeledContent(L.eventVenue, value: activeEvent.venue)
                        }
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
                        store.add(profile, event: eventStore.activeEvent)
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
    @ObservedObject private var eventStore = EventStore.shared
    @State private var searchText = ""
    @State private var showingEvents = false

    private var filteredRecords: [EncounterRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return store.records }
        return store.records.filter { record in
            record.name.lowercased().contains(query)
                || record.subtitle.lowercased().contains(query)
                || record.note.lowercased().contains(query)
                || record.tags.contains { $0.lowercased().contains(query) }
                || (record.eventTitle ?? "").lowercased().contains(query)
                || (record.eventVenue ?? "").lowercased().contains(query)
                || record.profiles.contains { $0.platformName.lowercased().contains(query) || $0.qrContent.lowercased().contains(query) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showingEvents = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.tint)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(eventStore.activeEvent?.title ?? L.noActiveEvent)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(eventStore.activeEvent?.dateSummary ?? L.chooseEventForEncounter)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

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
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingEvents = true
                    } label: {
                        Image(systemName: "calendar")
                    }
                    .accessibilityLabel(L.events)
                }
            }
            .sheet(isPresented: $showingEvents) {
                EventCenterView()
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
                if let eventTitle = record.eventTitle, !eventTitle.isEmpty {
                    Label(eventTitle, systemImage: "calendar")
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
    @State private var followStatus: String

    init(record: EncounterRecord) {
        _record = State(initialValue: record)
        _tagsText = State(initialValue: record.tags.joined(separator: " "))
        _followStatus = State(initialValue: record.followStatus ?? "")
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
                if let eventTitle = record.eventTitle, !eventTitle.isEmpty {
                    LabeledContent(L.eventName, value: eventTitle)
                }
                if let eventVenue = record.eventVenue, !eventVenue.isEmpty {
                    LabeledContent(L.eventVenue, value: eventVenue)
                }
                TextField(L.note, text: $record.note, axis: .vertical)
                    .lineLimit(2...6)
                TextField(L.tags, text: $tagsText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField(L.followStatus, text: $followStatus)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Toggle(L.needsPhotoReturn, isOn: Binding(
                    get: { record.needsPhotoReturn ?? false },
                    set: { record.needsPhotoReturn = $0 }
                ))
                Toggle(L.exchangedFreebie, isOn: Binding(
                    get: { record.exchangedFreebie ?? false },
                    set: { record.exchangedFreebie = $0 }
                ))
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
        record.followStatus = followStatus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : followStatus
        store.update(record)
        dismiss()
    }
}

struct EventCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @ObservedObject private var eventStore = EventStore.shared
    @State private var showingCustomEvent = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        eventStore.setActiveEvent(nil)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L.noActiveEvent)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(L.noActiveEventHint)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if eventStore.activeEventID == nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                Section {
                    ForEach(eventStore.events) { event in
                        eventRow(event)
                    }
                    .onDelete(perform: deleteEvents)
                } header: {
                    Text(L.events)
                } footer: {
                    if eventStore.isRefreshing {
                        Text(L.loadingEvents)
                    } else if let refreshError = eventStore.refreshError {
                        Text(refreshError)
                    } else {
                        Text(L.eventsFooter)
                    }
                }
            }
            .navigationTitle(L.events)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.done) { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        Task { await eventStore.refreshRemoteEvents() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(eventStore.isRefreshing)

                    Button {
                        showingCustomEvent = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                if eventStore.events.isEmpty {
                    await eventStore.refreshRemoteEvents()
                }
            }
            .sheet(isPresented: $showingCustomEvent) {
                CustomEventView()
            }
        }
    }

    private func eventRow(_ event: MeQREvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                eventStore.setActiveEvent(event)
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: event.isCustom ? "mappin.and.ellipse" : "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.tint)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text([event.dateSummary, event.venue].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !event.details.isEmpty {
                            Text(event.details)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }
                    Spacer()
                    if eventStore.activeEventID == event.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.tint)
                    }
                }
            }
            .buttonStyle(.plain)

            if !event.navigationQuery.isEmpty {
                HStack(spacing: 10) {
                    Button {
                        openURL(appleMapsURL(for: event))
                    } label: {
                        Label(L.appleMaps, systemImage: "map")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        openURL(amapURL(for: event))
                    } label: {
                        Label(L.amap, systemImage: "location")
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }

    private func deleteEvents(_ offsets: IndexSet) {
        for offset in offsets {
            let event = eventStore.events[offset]
            eventStore.deleteCustomEvent(event)
        }
    }

    private func appleMapsURL(for event: MeQREvent) -> URL {
        if let latitude = event.latitude, let longitude = event.longitude {
            return URL(string: "http://maps.apple.com/?ll=\(latitude),\(longitude)&q=\(event.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? event.title)")!
        }
        let query = event.navigationQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? event.navigationQuery
        return URL(string: "http://maps.apple.com/?q=\(query)")!
    }

    private func amapURL(for event: MeQREvent) -> URL {
        let name = event.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? event.title
        if let latitude = event.latitude, let longitude = event.longitude {
            return URL(string: "iosamap://path?sourceApplication=MeQR&dlat=\(latitude)&dlon=\(longitude)&dname=\(name)&dev=0&t=0")!
        }
        let query = event.navigationQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? event.navigationQuery
        return URL(string: "iosamap://poi?sourceApplication=MeQR&keywords=\(query)")!
    }
}

private struct CustomEventView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var eventStore = EventStore.shared
    @State private var title = ""
    @State private var venue = ""
    @State private var address = ""
    @State private var date = Date()
    @State private var details = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(L.eventInfo) {
                    TextField(L.eventName, text: $title)
                    TextField(L.eventVenue, text: $venue)
                    TextField(L.eventAddress, text: $address, axis: .vertical)
                        .lineLimit(1...3)
                    DatePicker(L.eventDate, selection: $date, displayedComponents: [.date, .hourAndMinute])
                    TextField(L.eventDetails, text: $details, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(L.customEvent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.save) {
                        eventStore.addCustomEvent(title: title, venue: venue, address: address, date: date, details: details)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
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
