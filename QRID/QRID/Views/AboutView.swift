import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "喜劳转扩"
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private let websiteURL = URL(string: "https://meqrcode.cn/")!
    private let supportURL = URL(string: "https://support.meqrcode.cn/")!
    private let privacyPolicyURL = URL(string: "https://meqrcode.cn/privacy.html")!
    private let icpFilingURL = URL(string: "https://beian.miit.gov.cn/")!
    private let mailURL = URL(string: "mailto:lucas_and_miku@icloud.com")!
    private let qqURL = URL(string: "https://qm.qq.com/q/ErpPGQuaAi")!


    var body: some View {
        NavigationStack {
            Form {
         
                Section {
                    VStack(spacing: 12) {
                        Image("AboutAppIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 88, height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))

                        Text(appName)
                            .font(.title2.bold())

                        Text("\(L.versionBuild) \(version) (\(L.build) \(build))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
                .listRowBackground(Color.clear)

                Section {
                    Link(destination: supportURL) {
                        HStack {
                            Image(systemName: "questionmark.bubble")
                                .foregroundStyle(.primary)
                            Text(OnboardingCopy.openSupport)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        openWebsite()
                    } label: {
                        HStack {
                            Image(systemName: "link")
                                .foregroundStyle(.primary)
                            Text(L.website)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text(L.websiteFooter)
                }

                Section {
                    Link(destination: privacyPolicyURL) {
                        HStack {
                            Image(systemName: "hand.raised")
                                .foregroundStyle(.primary)
                            Text(L.privacyPolicy)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Link(destination: icpFilingURL) {
                        HStack {
                            Image(systemName: "checkmark.shield")
                                .foregroundStyle(.primary)
                            Text(L.icpFiling)
                            Spacer()
                            Text("粤ICP备2026097629号-2A")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text(L.privacyFooter)
                }

                Section(L.contactDeveloper) {
                    Link(destination: mailURL) {
                        HStack {
                            Text(L.email)
                            Spacer()
                            Text("lucas_and_miku@icloud.com")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Link(destination: qqURL) {
                        HStack {
                            Text("QID")
                            Spacer()
                            Text("Rebirth39")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("重生Rebirth")
                            .font(.system(size: 17, weight: .bold))
                        Text(L.developerStudent)
                            .font(.system(size: 15))
                        (Text(L.developerMadeForFun) + Text(" ") + Text(L.developerUnexpected).strikethrough())
                            .font(.system(size: 13.5))
                            .foregroundColor(.gray)
                        Text(L.developerHope)
                            .font(.system(size: 13.5))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(L.developerIntro)
                }
            }
            .navigationTitle(L.aboutSoftware)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.done) { dismiss() }
                }
            }
        }
    }

    private func openWebsite() {
        UIApplication.shared.open(websiteURL)
    }
}
