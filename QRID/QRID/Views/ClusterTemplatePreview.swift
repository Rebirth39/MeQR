import SwiftUI

struct ClusterTemplatePreview<Avatar: View>: View {
    let templateStyle: ClusterTemplateStyle
    let backgroundColor: Color
    let textColor: Color
    let qrColor: Color
    let avatar: () -> Avatar

    init(
        templateStyle: ClusterTemplateStyle,
        backgroundColor: Color,
        textColor: Color,
        qrColor: Color,
        @ViewBuilder avatar: @escaping () -> Avatar
    ) {
        self.templateStyle = templateStyle
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.qrColor = qrColor
        self.avatar = avatar
    }

    var body: some View {
        HStack {
            Spacer()
            ZStack {
                switch templateStyle {
                case .standard:
                    RoundedRectangle(cornerRadius: 18)
                        .fill(backgroundColor.opacity(0.8))
                    VStack(spacing: 8) {
                        avatar()
                            .frame(width: 34, height: 34)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(textColor.opacity(0.7))
                            .frame(width: 76, height: 8)
                        Image(systemName: "qrcode")
                            .font(.system(size: 42))
                            .foregroundStyle(textColor.opacity(0.65))
                    }

                case .conventionPass:
                    RoundedRectangle(cornerRadius: 16)
                        .fill(backgroundColor.opacity(0.84))
                    VStack(spacing: 8) {
                        Capsule()
                            .fill(textColor.opacity(0.8))
                            .frame(width: 58, height: 8)
                        avatar()
                            .frame(width: 36, height: 36)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(textColor.opacity(0.72))
                            .frame(width: 86, height: 8)
                        Image(systemName: "qrcode")
                            .font(.system(size: 36))
                            .foregroundStyle(textColor.opacity(0.62))
                    }

                case .rhodesPass:
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white.opacity(0.88))
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(qrColor.opacity(0.75))
                            .frame(height: 16)
                            .overlay(alignment: .trailing) {
                                Text("#01")
                                    .font(.system(size: 7, weight: .black))
                                    .foregroundStyle(.black.opacity(0.55))
                                    .padding(.trailing, 8)
                            }
                        HStack(spacing: 6) {
                            Rectangle()
                                .fill(textColor.opacity(0.75))
                                .frame(width: 12)
                                .overlay {
                                    Text("MEQR")
                                        .font(.system(size: 6, weight: .black))
                                        .foregroundStyle(backgroundColor.opacity(0.85))
                                        .rotationEffect(.degrees(-90))
                                }
                            VStack(alignment: .leading, spacing: 7) {
                                avatar()
                                    .frame(width: 42, height: 42)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(textColor.opacity(0.72))
                                    .frame(width: 72, height: 8)
                                Image(systemName: "qrcode")
                                    .font(.system(size: 34))
                                    .foregroundStyle(qrColor.opacity(0.65))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(8)
                    }
                }
            }
            .frame(width: 150, height: 180)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.black.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
            Spacer()
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.clear)
    }
}
