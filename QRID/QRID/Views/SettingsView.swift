import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.appSettings) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \QRCluster.sortOrder) private var clusters: [QRCluster]

    @State private var shareFileURL: URL?
    @State private var showShareSheet = false
    @State private var showDocumentPicker = false
    @State private var showImportResult = false
    @State private var importSuccess = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        exportBackup()
                    } label: {
                        Label("导出备份", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showDocumentPicker = true
                    } label: {
                        Label("从备份恢复", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("数据备份")
                } footer: {
                    Text("备份文件会保存为 JSON，包含所有合集、二维码、头像和背景图片。建议定期导出到文件或 iCloud。")
                        .font(.caption)
                }

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
            .sheet(isPresented: $showShareSheet) {
                if let url = shareFileURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker { url in
                    let didAccess = url.startAccessingSecurityScopedResource()
                    defer {
                        if didAccess {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    importSuccess = BackupManager.importBackup(from: url, modelContext: modelContext)
                    showImportResult = true
                }
            }
            .alert("恢复结果", isPresented: $showImportResult) {
                Button("确定") { }
            } message: {
                Text(importSuccess ? "备份恢复成功。" : "恢复失败，请检查备份文件格式。")
            }
        }
    }

    private func exportBackup() {
        guard let url = BackupManager.exportBackup(clusters: clusters) else { return }
        shareFileURL = url
        showShareSheet = true
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.json])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}
