import Foundation

@MainActor
enum AppActivity {
    static func report(clusters: [QRCluster]) async {
        var bindings: [ActivityBinding] = []
        do {
            for cluster in clusters {
                if let binding = try ProfileSync.binding(cluster.id) {
                    bindings.append(ActivityBinding(profileID: binding.profileId, token: binding.token))
                }
            }
        } catch { return }
        await ActivityReporter.shared.report(bindings: bindings)
    }
}
