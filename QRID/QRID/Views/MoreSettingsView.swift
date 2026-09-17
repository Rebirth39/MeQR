import SwiftUI

struct MoreSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appSettings) private var settings
    @AppStorage(OnboardingStorage.completionKey) private var hasCompletedOnboarding = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        LanguageSettingsView()
                    } label: {
                        HStack {
                            Label(L.languageSelection, systemImage: "globe")
                            Spacer()
                            Text(settings.selectedLanguage.displayName)
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text(L.languageRestartNotice)
                        .font(.footnote)
                }

                Section {
                    NavigationLink { ProfileSyncView() } label: {
                        Label(L.syncTitle, systemImage: "arrow.triangle.2.circlepath")
                    }
                    NavigationLink { AnnouncementHistoryView() } label: {
                        Label("历史通知", systemImage: "bell.and.waves.left.and.right")
                    }
                    Button {
                        hasCompletedOnboarding = false
                        dismiss()
                    } label: {
                        Label(OnboardingCopy.replayGuide, systemImage: "sparkles.rectangle.stack")
                    }

                    NavigationLink {
                        AboutView()
                    } label: {
                        Label(L.aboutSoftware, systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle(L.moreSettings)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.done) { dismiss() }
                }
            }
        }
    }
}

struct AnnouncementHistoryView: View {
    @EnvironmentObject private var manager: AnnouncementManager
    var body: some View {
        List(manager.history) { item in
            Link(destination: item.url) {
                VStack(alignment: .leading, spacing: 5) { Text(item.title).font(.headline); Text(item.summary).font(.subheadline).foregroundStyle(.secondary) }
            }
        }.navigationTitle("历史通知").navigationBarTitleDisplayMode(.inline)
    }
}

struct LanguageSettingsView: View {
    @Environment(\.appSettings) private var settings
    @State private var selectedLanguage = AppSettings.shared.selectedLanguage

    var body: some View {
        List {
            Section {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        selectedLanguage = language
                        settings.selectedLanguage = language
                    } label: {
                        HStack {
                            Text(language.displayName)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedLanguage == language {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text(L.languageRestartNotice)
                    .font(.footnote)
            }
        }
        .navigationTitle(L.languageSelection)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedLanguage = settings.selectedLanguage
        }
    }
}
