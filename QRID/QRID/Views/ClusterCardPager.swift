import SwiftUI

struct ClusterCardPager: View {
    let clusters: [QRCluster]
    @Binding var currentPage: Int
    var onProfileSelected: (Int) -> Void
    var landscapeTabletPresentation: Bool = false

    var body: some View {
        GeometryReader { geometry in
            let landscape = UIDevice.current.userInterfaceIdiom == .pad && geometry.size.width > geometry.size.height
            let phone = UIDevice.current.userInterfaceIdiom == .phone
            TabView(selection: $currentPage) {
                ForEach(Array(clusters.enumerated()), id: \.element.id) { index, cluster in
                    ScrollView(.vertical, showsIndicators: false) {
                        let portraitTablet = UIDevice.current.userInterfaceIdiom == .pad && !landscape
                        ClusterCardView(cluster: cluster, size: landscape ? 230 : portraitTablet ? 260 : 180,
                                        containerWidth: landscape ? geometry.size.width :
                                            portraitTablet ? min(620, geometry.size.width - 48) :
                                            phone ? geometry.size.width : min(393, max(0, geometry.size.width - 32)),
                                        onProfileSelected: { profileIndex in
                            if index == currentPage {
                                onProfileSelected(profileIndex)
                            }
                        }, landscapeTabletPresentation: landscape)
                        .padding(.horizontal, phone ? 8 : 16)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, alignment: landscape || portraitTablet ? .center : .top)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .padding(.bottom, 44)
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
}
