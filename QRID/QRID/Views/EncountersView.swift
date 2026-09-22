import SwiftUI

struct EncounterPreviewView: View {
    let profile: MeQRExchangeProfile
    var sessionID: String? = nil
    var localProfile: MeQRExchangeProfile? = nil

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = EncounterStore.shared
    @ObservedObject private var eventStore = EventStore.shared
    @State private var saved = false
    @State private var selectedPlatformIndex = 0

    private var textColor: Color { Color(hex: profile.textColorHex ?? "#000000") }
    private var backgroundColor: Color { Color(hex: profile.backgroundColorHex ?? "#FFFFFF") }
    private var qrColor: Color { Color(hex: profile.qrColorHex ?? "#000000") }

    private var currentPlatform: MeQRExchangePlatform? {
        profile.profiles[safe: selectedPlatformIndex]
    }

    private var hasCustomBackground: Bool {
        profile.backgroundJPEGBase64 != nil
    }

    var body: some View {
        NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        card
                        if sessionID == nil || localProfile == nil {
                            Text(L.encounterLocalOnly)
                                .font(.footnote)
                                .foregroundStyle(textColor)
                        }
                        saveButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            .background {
                GeometryReader { geometry in
                    background
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
                .ignoresSafeArea()
            }
            .navigationTitle(L.meqrProfileFound)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(textColor.isDarkForUI ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel) { dismiss() }
                }
            }
        }
        .interactiveDismissDisabled()
        .alert(L.encounterSaveFailed, isPresented: Binding(
            get: { store.persistenceErrorMessage != nil },
            set: { if !$0 { store.persistenceErrorMessage = nil } }
        )) {
            Button(L.ok, role: .cancel) {}
        }
    }

    @ViewBuilder
    private var background: some View {
        if let data = profile.backgroundJPEGBase64.flatMap({ Data(base64Encoded: $0) }),
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            backgroundColor
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    avatar
                        .frame(width: 56, height: 56)

                    Text(profile.name)
                        .font(.headline.bold())
                        .foregroundStyle(textColor)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("encounter-preview-name")
                }
                .frame(width: 88, alignment: .leading)

                if !profile.subtitle.isEmpty {
                    Rectangle()
                        .fill(textColor.opacity(0.3))
                        .frame(width: 1)
                        .padding(.vertical, 4)
                }

                if !profile.subtitle.isEmpty {
                    Text(profile.subtitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(textColor.opacity(0.8))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            if let data = profile.bannerJPEGBase64.flatMap({ Data(base64Encoded: $0) }),
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 110)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            if let currentPlatform {
                platformQRCode(for: currentPlatform)
                    .padding(12)
                    .frame(width: min(260, UIScreen.main.bounds.width * 0.58), height: min(260, UIScreen.main.bounds.width * 0.58))
                    .padding(12)
                    .background(.white, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(textColor.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if profile.profiles.count > 1 {
                platformPicker
            }

            if let currentPlatform, QRLinkPolicy.webURL(currentPlatform.qrContent) != nil {
                openPlatformButton(currentPlatform)
            }

            if let activeEvent = eventStore.activeEvent {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text(activeEvent.title)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundStyle(textColor.opacity(0.72))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(0.5), in: Capsule())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(backgroundColor.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(.white.opacity(0.5), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var avatar: some View {
        if let data = profile.avatarJPEGBase64.flatMap({ Data(base64Encoded: $0) }),
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        } else {
            ZStack {
                Circle().fill(textColor.opacity(0.15))
                Image(systemName: "person.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(textColor.opacity(0.6))
            }
        }
    }

    @ViewBuilder
    private func platformQRCode(for platform: MeQRExchangePlatform) -> some View {
        let baseImage = hasCustomBackground
            ? QRCodeGenerator.generateTransparent(from: platform.qrContent, foreground: qrColor)
            : QRCodeGenerator.generate(from: platform.qrContent, foreground: qrColor, background: .white)
        let uiImage = hasCustomBackground
            ? baseImage.flatMap(QRCodeGenerator.trimQuietZoneForDisplay)
            : baseImage
        if let uiImage {
            Image(uiImage: uiImage)
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

    private var platformPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(profile.profiles.enumerated()), id: \.element.id) { index, platform in
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedPlatformIndex = index
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: (Platform(rawValue: platform.platformType) ?? .custom).iconName)
                                .font(.caption)
                            Text(platform.platformName)
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(index == selectedPlatformIndex
                                    ? qrColor
                                    : Color.white.opacity(0.55))
                        )
                        .foregroundStyle(index == selectedPlatformIndex
                            ? qrColor.uiContrastColor
                            : textColor)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func openPlatformButton(_ platform: MeQRExchangePlatform) -> some View {
        if QRLinkPolicy.webURL(platform.qrContent) != nil {
            EncounterPlatformLink(content: platform.qrContent) {
                Label(L.platformsFromMeQR + " · " + platform.platformName, systemImage: "arrow.up.forward.app")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
            }
            .buttonStyle(.bordered)
            .tint(textColor)
        }
    }

    private var saveButton: some View {
        Button {
            store.saveScannedProfile(profile, event: eventStore.activeEvent,
                                     sessionID: sessionID, peerProfile: localProfile)
            guard store.persistenceErrorMessage == nil else { return }
            Task { await store.syncConfirmations() }
            saved = true
            dismiss()
        } label: {
            Label(saved ? L.saved : L.saveEncounter, systemImage: saved ? "checkmark" : "person.badge.plus")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
        }
        .buttonStyle(.borderedProminent)
        .clipShape(Capsule())
        .disabled(saved)
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
                || (record.displayEventTitle).lowercased().contains(query)
                || (record.displayEventVenue).lowercased().contains(query)
                || record.profiles.contains { $0.platformName.lowercased().contains(query) || $0.qrContent.lowercased().contains(query) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if store.pendingConfirmationCount > 0 {
                    Section {
                        HStack {
                            Label(L.encounterConfirmationsPending(store.pendingConfirmationCount), systemImage: "arrow.triangle.2.circlepath")
                            Spacer()
                            Button {
                                Task { await store.syncConfirmations() }
                            } label: { Image(systemName: "arrow.clockwise") }
                            .accessibilityLabel(L.tryAgain)
                            .disabled(store.isConfirming)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                if store.pendingSessionCount > 0 {
                    Section {
                        Label(
                            L.encounterWaitingForPeer(store.pendingSessionCount),
                            systemImage: "clock.arrow.circlepath"
                        )
                        .foregroundStyle(.secondary)
                    }
                }
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
                                Text(eventStore.activeEvent?.displayTitle ?? L.noActiveEvent)
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
            .refreshable {
                await store.syncPendingSessions()
            }
            .task {
                await store.syncPendingSessions()
            }
            .searchable(text: $searchText, prompt: L.searchEncounters)
            .alert(L.encounterSaveFailed, isPresented: Binding(
                get: { store.persistenceErrorMessage != nil },
                set: { if !$0 { store.persistenceErrorMessage = nil } }
            )) {
                Button(L.ok, role: .cancel) {}
            }
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
                if !record.displayEventTitle.isEmpty {
                    Label(record.displayEventTitle, systemImage: "calendar")
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
                if !record.displayEventTitle.isEmpty {
                    LabeledContent(L.eventName, value: record.displayEventTitle)
                }
                if !record.displayEventVenue.isEmpty {
                    LabeledContent(L.eventVenue, value: record.displayEventVenue)
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
        .alert(L.encounterSaveFailed, isPresented: Binding(
            get: { store.persistenceErrorMessage != nil },
            set: { if !$0 { store.persistenceErrorMessage = nil } }
        )) {
            Button(L.ok, role: .cancel) {}
        }
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
        guard store.persistenceErrorMessage == nil else { return }
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
                        Text(event.displayTitle)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text([event.dateSummary, event.displayVenue].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !event.displayDetails.isEmpty {
                            Text(event.displayDetails)
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
                    if let appleMapsURL = appleMapsURL(for: event) {
                        Button {
                            openURL(appleMapsURL)
                        } label: {
                            Label(L.appleMaps, systemImage: "map")
                        }
                        .buttonStyle(.bordered)
                    }

                    if canOpenAmap, let amapURL = amapURL(for: event) {
                        Button {
                            openURL(amapURL)
                        } label: {
                            Label(L.amap, systemImage: "location")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }

    private func deleteEvents(_ offsets: IndexSet) {
        for offset in offsets where eventStore.events.indices.contains(offset) {
            let event = eventStore.events[offset]
            eventStore.deleteCustomEvent(event)
        }
    }

    private func appleMapsURL(for event: MeQREvent) -> URL? {
        var components = URLComponents(string: "https://maps.apple.com/")
        if let latitude = event.latitude, let longitude = event.longitude {
            components?.queryItems = [
                URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"),
                URLQueryItem(name: "q", value: event.title)
            ]
        } else {
            components?.queryItems = [URLQueryItem(name: "q", value: event.navigationQuery)]
        }
        return components?.url
    }

    private var canOpenAmap: Bool {
        guard let url = URL(string: "iosamap://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    private func amapURL(for event: MeQREvent) -> URL? {
        var components = URLComponents()
        components.scheme = "iosamap"
        if let latitude = event.latitude, let longitude = event.longitude {
            components.host = "path"
            components.queryItems = [
                URLQueryItem(name: "sourceApplication", value: "MeQR"),
                URLQueryItem(name: "dlat", value: String(latitude)),
                URLQueryItem(name: "dlon", value: String(longitude)),
                URLQueryItem(name: "dname", value: event.title),
                URLQueryItem(name: "dev", value: "0"),
                URLQueryItem(name: "t", value: "0")
            ]
        } else {
            components.host = "poi"
            components.queryItems = [
                URLQueryItem(name: "sourceApplication", value: "MeQR"),
                URLQueryItem(name: "keywords", value: event.navigationQuery)
            ]
        }
        return components.url
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
    ReviewedPlatformRow(platform: platform)
}

private struct ReviewedPlatformRow: View {
    let platform: MeQRExchangePlatform
    var body: some View {
        EncounterPlatformLink(content: platform.qrContent) {
            PlatformContentRow(platform: platform)
        }
        .buttonStyle(.plain)
    }
}

private struct EncounterPlatformLink<Label: View>: View {
    let content: String
    @ViewBuilder let label: () -> Label
    @State private var reviewing = false
    @State private var openingURL: URL?
    @State private var errorMessage: String?
    @Environment(\.openURL) private var openURL
    var body: some View {
        Button {
            if QRLinkPolicy.platformDestination(content) != nil, let url = QRLinkPolicy.webURL(content) {
                openingURL = url
            } else {
                reviewing = true
            }
        } label: {
            label()
        }
        .disabled(openingURL != nil)
        .task(id: openingURL) {
            guard let url = openingURL, let destination = QRLinkPolicy.platformDestination(url.absoluteString) else { return }
            let error = await MeQRScannerView.openTrustedDestination(url, destination: destination)
            guard !Task.isCancelled else { return }
            openingURL = nil
            errorMessage = error
        }
        .onDisappear { openingURL = nil }
        .sheet(isPresented: $reviewing) {
            QRLinkReviewView(content: content) { openURL($0) }
        }
        .alert(L.qrOpen, isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button(L.ok, role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? L.qrAppOpenFailed)
        }
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

            if QRLinkPolicy.webURL(platform.qrContent) != nil {
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
