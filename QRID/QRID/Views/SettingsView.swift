import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink("关于软件") {
                        AboutView()
                    }
                }
            }
            .navigationTitle(L.settings)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.done) { dismiss() }
                }
            }
        }
    }
}
