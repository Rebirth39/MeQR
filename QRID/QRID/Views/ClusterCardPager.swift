import SwiftUI

struct ClusterCardPager: View {
    let clusters: [QRCluster]
    @Binding var currentPage: Int
    var onProfileSelected: (Int) -> Void
    var landscapeTabletPresentation: Bool = false
    var profileSelections: Binding<[UUID: UUID]>? = nil
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let regularWidth = horizontalSizeClass == .regular
            // Size classes can remain regular in a narrow iPad window.
            let expanded = regularWidth && width >= 800 && width > height
            let spacious = width >= 520
            let cardSize = expanded ? 230 : min(260, max(180, width * 0.46))
            let cardContainerWidth = expanded
                ? width
                : spacious
                    ? min(620, max(0, width - 48))
                    : width
            let horizontalPadding: CGFloat = spacious ? 16 : 8
            TabView(selection: $currentPage) {
                ForEach(Array(clusters.enumerated()), id: \.element.id) { index, cluster in
                    ScrollView(.vertical) {
                        ClusterCardView(cluster: cluster, size: cardSize,
                                        containerWidth: cardContainerWidth,
                                        onProfileSelected: { profileIndex in
                            if index == currentPage {
                                onProfileSelected(profileIndex)
                            }
                        }, landscapeTabletPresentation: expanded,
                                        profileSelection: selection(for: cluster.id))
                        .padding(.horizontal, horizontalPadding)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .padding(.bottom, clusters.count > 1 ? 44 : 0)
            .overlay(alignment: .bottom) {
                if clusters.count > 1 {
                    HStack(spacing: 8) {
                        ForEach(clusters.indices, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.white : Color.white.opacity(0.5))
                                .frame(width: 8, height: 8)
                                .scaleEffect(index == currentPage ? 1.2 : 1)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.35), in: Capsule())
                    .padding(.bottom, 12)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(currentPage + 1) / \(clusters.count)")
                }
            }
        }
    }

    private func selection(for clusterID: UUID) -> Binding<UUID?>? {
        guard let profileSelections else { return nil }
        return Binding(
            get: { profileSelections.wrappedValue[clusterID] },
            set: { profileSelections.wrappedValue[clusterID] = $0 }
        )
    }
}
