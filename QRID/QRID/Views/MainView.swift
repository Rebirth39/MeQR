import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \QRProfile.createdAt, order: .reverse) private var profiles: [QRProfile]
    @State private var currentPage = 0
    @State private var showingAdd = false
    @State private var editingProfile: QRProfile?
    @State private var showingDeleteAlert = false
    @State private var profileToDelete: QRProfile?

    var body: some View {
        NavigationStack {
            Group {
                if profiles.isEmpty {
                    emptyState
                } else {
                    pagerContent
                }
            }
            .navigationTitle("QR ID")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if !profiles.isEmpty {
                        Button {
                            editingProfile = profiles[currentPage]
                        } label: {
                            Image(systemName: "pencil")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddProfileView()
            }
            .sheet(item: $editingProfile) { profile in
                EditProfileView(profile: profile)
            }
        }
    }

    private var pagerContent: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
                    QRCodeCardView(profile: profile)
                        .tag(index)
                        .contextMenu {
                            Button {
                                editingProfile = profile
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                profileToDelete = profile
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .animation(.easeInOut, value: currentPage)

            if profiles.count > 1 {
                Text("\(currentPage + 1) of \(profiles.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
        .padding(.top, 20)
        .alert("Delete Profile", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let profile = profileToDelete {
                    deleteProfile(profile)
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(profileToDelete?.name ?? "")\"?")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "qrcode")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("No QR Codes Yet")
                    .font(.title2.bold())
                Text("Add your first social media QR code to get started.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showingAdd = true
            } label: {
                Label("Add QR Code", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
    }

    private func deleteProfile(_ profile: QRProfile) {
        let wasLast = currentPage == profiles.count - 1 && profiles.count > 1
        modelContext.delete(profile)
        if wasLast {
            currentPage = max(0, currentPage - 1)
        } else if currentPage >= profiles.count - 1 {
            currentPage = max(0, profiles.count - 2)
        }
    }
}
