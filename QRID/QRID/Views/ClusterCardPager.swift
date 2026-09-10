import SwiftUI

struct ClusterCardPager: View {
    let clusters: [QRCluster]
    @Binding var currentPage: Int
    var onProfileSelected: (Int) -> Void

    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $currentPage) {
                ForEach(Array(clusters.enumerated()), id: \.element.id) { index, cluster in
                    ScrollView(.vertical, showsIndicators: false) {
                        ClusterCardView(cluster: cluster, size: 180, containerWidth: geometry.size.width) { profileIndex in
                            if index == currentPage {
                                onProfileSelected(profileIndex)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, alignment: .top)
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
