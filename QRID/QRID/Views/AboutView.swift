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

    private let githubURL = URL(string: "https://github.com/Rebirth39/MeQR")!


    var body: some View {
        NavigationStack {
            Form {
         
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 64))
                            .foregroundStyle(.primary)

                        Text(appName)
                            .font(.title2.bold())

                        Text("Version \(version) (Build \(build))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
                .listRowBackground(Color.clear)

                Section {
                    Button {
                        openGitHub()
                    } label: {
                        HStack {
                            Image(systemName: "link")
                                .foregroundStyle(.primary)
                            Text("GitHub 项目页面")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("如果想看更多的软件介绍的话点一下上面的按钮可以跳到GitHub页面w")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("重生Rebirth")
                            .font(.system(size: 17, weight: .bold))
                        Text("目前高中就读 初⚪︎未来重度依赖（）")
                            .font(.system(size: 15))
                        (Text("抱着玩一下的心态开发了这款软件") + Text("没想到后面功能越加越多").strikethrough())
                            .font(.system(size: 13.5))
                            .foregroundColor(.gray)
                        Text("希望大家喜欢:)")
                            .font(.system(size: 13.5))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("开发者介绍")
                }
            }
            .navigationTitle("关于软件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.done) { dismiss() }
                }
            }
        }
    }

    private func openGitHub() {
        UIApplication.shared.open(githubURL)
    }
}
