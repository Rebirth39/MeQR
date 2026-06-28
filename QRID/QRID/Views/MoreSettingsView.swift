import SwiftUI

struct MoreSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appSettings) private var settings

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
