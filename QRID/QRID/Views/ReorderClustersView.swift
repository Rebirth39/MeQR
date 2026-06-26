import SwiftUI
import SwiftData

struct ReorderClustersView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \QRCluster.sortOrder, order: .forward) private var clusters: [QRCluster]
    @State private var saveError: String?
    @State private var showSaveError = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(clusters) { cluster in
                        HStack(spacing: 12) {
                            if let data = cluster.avatarImageData,
                               let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 36, height: 36)
                                    .clipShape(Circle())
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(Color.primary.opacity(0.1))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(cluster.name)
                                .font(.body)
                            Spacer()
                        }
                    }
                    .onMove(perform: move)
                } footer: {
                    Text(L.tr("长按合集排序", "Long press to reorder"))
                        .font(.caption)
                }
            }
            .navigationTitle(L.reorderClusters)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.done) { dismiss() }
                }
            }
            .alert("Could Not Save", isPresented: $showSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "Please try again.")
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        var reordered = clusters
        let previousSortOrders = Dictionary(uniqueKeysWithValues: clusters.map { ($0.id, $0.sortOrder) })
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, cluster) in reordered.enumerated() {
            cluster.sortOrder = index
        }
        do {
            try modelContext.save()
            WidgetDataHelper.sync(clusters: clusters)
            BackupManager.writeAutoBackup(clusters: clusters)
        } catch {
            for cluster in reordered {
                if let previousSortOrder = previousSortOrders[cluster.id] {
                    cluster.sortOrder = previousSortOrder
                }
            }
            modelContext.rollback()
            saveError = error.localizedDescription
            showSaveError = true
        }
    }
}
