import SwiftUI
import Combine
import Network

@MainActor final class CardTagOutbox: ObservableObject {
    struct Job: Codable, Identifiable {
        var id: String { payload["request_id"] ?? "" }
        var payload: [String: String]
        var created = Date()
        var status = "pending"
        var ticket: String?
        var attempts = 0
        var nextAttempt = Date.distantPast
    }
    static let shared = CardTagOutbox()
    @Published private(set) var jobs: [Job] = []
    private let url: URL
    private var draining = false
    private var loadError: Error?
    private var wake: Task<Void, Never>?
    private let monitor = NWPathMonitor()
    private let sender: ([String: String]) async throws -> String

    init(url: URL? = nil, monitorNetwork: Bool = true,
         sender: @escaping ([String: String]) async throws -> String = CardTagReportClient.submit) {
        self.url = url ?? URL.applicationSupportDirectory.appendingPathComponent("tag-report-outbox.json")
        self.sender = sender
        if FileManager.default.fileExists(atPath: self.url.path) {
            do {
                let saved = try JSONDecoder().decode([Job].self, from: Data(contentsOf: self.url))
                guard saved.allSatisfy({ UUID(uuidString: $0.payload["request_id"] ?? "") != nil }) else { throw CardTagReportClient.Failure.invalidResponse }
                jobs = saved.map { job in var value = job; if value.status == "sending" { value.status = "pending" }; return value }
            } catch { loadError = error }
        }
        if monitorNetwork {
            monitor.pathUpdateHandler = { [weak self] path in
                if path.status == .satisfied { Task { @MainActor in await self?.drain() } }
            }
            monitor.start(queue: DispatchQueue(label: "tag-outbox-network"))
        }
    }

    private func save(_ updated: [Job]) throws {
        if let loadError { throw loadError }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(updated).write(to: url, options: .atomic)
        jobs = updated
    }

    func enqueue(_ payload: [String: String]) throws -> String {
        guard let id = payload["request_id"], UUID(uuidString: id) != nil else { throw CardTagReportClient.Failure.invalidResponse }
        if let old = jobs.first(where: { $0.id == id }) {
            guard old.payload == payload else { throw CardTagReportClient.Failure.invalidResponse }
            return id
        }
        try save(jobs + [Job(payload: payload)])
        return id
    }

    func cancel(_ id: String) throws {
        guard jobs.first(where: { $0.id == id })?.status != "sending" else { return }
        try save(jobs.filter { $0.id != id })
    }

    func retry(_ id: String) async throws {
        var updated = jobs
        guard let i = updated.firstIndex(where: { $0.id == id }), updated[i].status != "sending", updated[i].ticket == nil else { return }
        updated[i].status = "pending"
        updated[i].nextAttempt = .distantPast
        try save(updated)
        await drain()
    }

    func drain() async {
        guard !draining else { return }
        draining = true
        wake?.cancel()
        defer { draining = false; schedule() }
        while let index = jobs.firstIndex(where: { $0.status == "pending" && $0.nextAttempt <= Date() }) {
            let id = jobs[index].id
            var updated = jobs
            updated[index].status = "sending"
            updated[index].attempts += 1
            do { try save(updated) } catch { return }
            let outcome: Result<String, Error>
            do { outcome = .success(try await sender(updated[index].payload)) }
            catch { outcome = .failure(error) }
            guard let i = jobs.firstIndex(where: { $0.id == id }) else { continue }
            updated = jobs
            switch outcome {
            case .success(let ticket):
                updated[i].status = "sent"; updated[i].ticket = ticket
            case .failure(let error):
                updated[i].status = (error as? CardTagReportClient.Failure) == .rejected ? "failed" : "pending"
                let delay: Double = (error as? CardTagReportClient.Failure) == .limited ? 600 : min(3600, 30 * pow(2, Double(min(updated[i].attempts, 7))))
                updated[i].nextAttempt = Date().addingTimeInterval(delay)
                if (error as? CardTagReportClient.Failure) == .limited {
                    for j in updated.indices where updated[j].status == "pending" {
                        updated[j].nextAttempt = max(updated[j].nextAttempt, updated[i].nextAttempt)
                    }
                }
            }
            do { try save(updated) } catch {
                // The durable sending record will recover as pending on the next launch.
                jobs[i].status = "pending"
                jobs[i].nextAttempt = Date().addingTimeInterval(60)
                return
            }
        }
    }

    private func schedule() {
        guard let date = jobs.filter({ $0.status == "pending" }).map(\.nextAttempt).min() else { return }
        let delay = max(1, date.timeIntervalSinceNow)
        wake = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            // drain cancels outstanding timers; this timer has already fired.
            self?.wake = nil
            await self?.drain()
        }
    }
}

struct CardTagOutboxView: View {
    @StateObject private var outbox = CardTagOutbox.shared
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?
    var body: some View {
        NavigationStack {
            List {
                if outbox.jobs.isEmpty { Text(L.tagQueueEmpty).foregroundStyle(.secondary) }
                ForEach(outbox.jobs.reversed()) { job in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(job.payload["tag_name"] ?? "")
                        Text(job.ticket ?? (job.status == "sending" ? L.tagSending : job.status == "failed" ? L.tagReportFailed : L.tagQueued))
                            .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        HStack {
                            if job.ticket == nil {
                                Button { Task { do { try await outbox.retry(job.id) } catch { self.error = L.tagQueueSaveFailed } } } label: { Label(L.tagRetry, systemImage: "arrow.clockwise") }
                            }
                            Spacer()
                            Button(role: .destructive) { do { try outbox.cancel(job.id) } catch { self.error = L.tagQueueSaveFailed } } label: {
                                Label(job.ticket == nil ? L.tagCancelPending : L.delete, systemImage: "trash")
                            }
                        }.buttonStyle(.borderless).disabled(job.status == "sending")
                    }
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle(L.tagOutbox).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L.done) { dismiss() } } }
            .task { await outbox.drain() }
        }
    }
}
