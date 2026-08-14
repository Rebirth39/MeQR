import SwiftUI
import SwiftData
import PhotosUI

enum OnboardingStorage {
    static let completionKey = "meqr_onboarding_profile_v1_completed"
}

enum OnboardingCopy {
    static var welcomeTitle: String { L.tr("先做一张属于你自己的二维码卡片。", "先做一張屬於你自己的 QR Code 卡片。", "先做一張屬於你自己的 QR Code 卡片。", "Let's make a QR card that feels like you.", "あなたらしいQRカードを作りましょう。") }
    static var welcomeBody: String { L.tr("头像、昵称、二维码和喜欢的颜色，我们一步一步来。大约两分钟，之后随时都能修改。", "頭像、暱稱、QR Code 和喜歡的顏色，我們一步一步來。大約兩分鐘，之後隨時都能修改。", "頭像、暱稱、QR Code 和喜歡的顏色，我們一步一步來。大約兩分鐘，之後隨時都能修改。", "Avatar, name, QR code, and your colors. We'll do it one step at a time, and you can edit everything later.", "アイコン、名前、QRコード、好きな色を順番に設定します。あとからいつでも変更できます。") }
    static var existingBody: String { L.tr("新的建档引导已经准备好了。你可以体验一次，也可以直接回到现有卡片。", "新的建檔引導已經準備好了。你可以體驗一次，也可以直接回到現有卡片。", "新的建檔引導已經準備好了。你可以體驗一次，也可以直接回到現有卡片。", "The new setup guide is ready. Try it once or return to your existing cards.", "新しい作成ガイドを用意しました。試すことも、既存のカードへ戻ることもできます。") }
    static var start: String { L.tr("开始建档", "開始建檔", "開始建立", "Start My Card", "カードを作る") }
    static var tryGuide: String { L.tr("体验建档引导", "體驗建檔引導", "體驗建立引導", "Try the Setup Guide", "作成ガイドを試す") }
    static var later: String { L.tr("稍后再说", "稍後再說", "稍後再說", "Maybe Later", "あとで") }
    static var keepCards: String { L.tr("回到现有卡片", "回到現有卡片", "回到現有卡片", "Keep My Existing Cards", "既存のカードへ戻る") }
    static var back: String { L.tr("上一步", "上一步", "上一步", "Back", "戻る") }
    static var continueButton: String { L.tr("继续", "繼續", "繼續", "Continue", "続ける") }
    static var createCard: String { L.tr("创建我的卡片", "建立我的卡片", "建立我的卡片", "Create My Card", "カードを作成") }
    static var enterApp: String { L.tr("进入喜劳转扩", "進入喜勞轉擴", "進入喜勞轉擴", "Enter MeQR", "喜劳转扩を始める") }
    static var step: String { L.tr("建档进度", "建檔進度", "建立進度", "Setup progress", "作成の進捗") }
    static var identityTitle: String { L.tr("见面时，先让别人认出你。", "見面時，先讓別人認出你。", "見面時，先讓別人認出你。", "Help people recognize you first.", "まず、あなたを覚えてもらいましょう。") }
    static var identityBody: String { L.tr("昵称是必填项。头像和介绍可以先留空，之后再慢慢补。", "暱稱是必填項。頭像和介紹可以先留空，之後再慢慢補。", "暱稱是必填項。頭像和介紹可以先留空，之後再慢慢補。", "Your display name is required. Avatar and intro can wait until later.", "表示名は必須です。アイコンと紹介文はあとから追加できます。") }
    static var nickname: String { L.tr("大家怎么称呼你？", "大家怎麼稱呼你？", "大家怎麼稱呼你？", "What should people call you?", "なんと呼ばれたいですか？") }
    static var intro: String { L.tr("简单介绍一下自己（可选）", "簡單介紹一下自己（可選）", "簡單介紹一下自己（選填）", "A short intro (optional)", "短い自己紹介（任意）") }
    static var qrTitle: String { L.tr("放进第一个二维码。", "放進第一個 QR Code。", "放進第一個 QR Code。", "Add your first QR code.", "最初のQRコードを追加しましょう。") }
    static var qrBody: String { L.tr("可以直接从相册识别，也可以粘贴链接或文本生成。", "可以直接從相簿識別，也可以貼上連結或文字產生。", "可以直接從照片辨識，也可以貼上連結或文字產生。", "Import one from Photos, or generate it from a link or text.", "写真から読み込むか、リンクやテキストから作成できます。") }
    static var recognized: String { L.tr("二维码已识别", "QR Code 已識別", "QR Code 已辨識", "QR code recognized", "QRコードを読み取りました") }
    static var appearanceTitle: String { L.tr("现在，让它看起来像你。", "現在，讓它看起來像你。", "現在，讓它看起來像你。", "Now make it look like you.", "あなたらしい見た目にしましょう。") }
    static var appearanceBody: String { L.tr("选择模板、背景与颜色。保持高对比度会让二维码更容易扫描。", "選擇模板、背景與顏色。保持高對比度會讓 QR Code 更容易掃描。", "選擇模板、背景與顏色。保持高對比度會讓 QR Code 更容易掃描。", "Choose a template, background, and colors. Strong contrast keeps your QR code easy to scan.", "テンプレート、背景、色を選びましょう。コントラストが高いほど読み取りやすくなります。") }
    static var backgroundPhoto: String { L.tr("背景图片", "背景圖片", "背景圖片", "Background Photo", "背景画像") }
    static var tagsTitle: String { L.tr("用标签，说清楚你喜欢什么。", "用標籤，說清楚你喜歡什麼。", "用標籤，說清楚你喜歡什麼。", "Use tags to show what you love.", "タグで「好き」を伝えましょう。") }
    static var tagsBody: String { L.tr("作品、角色、社团或者兴趣都可以。输入后按回车添加，最多 10 个。", "作品、角色、社團或者興趣都可以。輸入後按 Return 加入，最多 10 個。", "作品、角色、社團或者興趣都可以。輸入後按 Return 新增，最多 10 個。", "Add series, characters, circles, or hobbies. Press Return to add up to 10.", "作品、キャラクター、サークル、趣味などを最大10個追加できます。") }
    static var optional: String { L.tr("这一步可以跳过", "這一步可以跳過", "這一步可以跳過", "This step is optional", "このステップはスキップできます") }
    static var suggestions: String { L.tr("可以先试试", "可以先試試", "可以先試試", "Try one of these", "おすすめ") }
    static var previewTitle: String { L.tr("确认一下，你的第一张卡片。", "確認一下，你的第一張卡片。", "確認一下，你的第一張卡片。", "Meet your first card.", "最初のカードを確認しましょう。") }
    static var previewBody: String { L.tr("创建后会保存在这台设备上。所有内容都可以继续编辑。", "建立後會儲存在這台裝置上。所有內容都可以繼續編輯。", "建立後會儲存在這台裝置上。所有內容都可以繼續編輯。", "It will be stored on this device, and every detail remains editable.", "この端末に保存され、すべてあとから編集できます。") }
    static var completeTitle: String { L.tr("你的卡片，准备好了。", "你的卡片，準備好了。", "你的卡片，準備好了。", "Your card is ready.", "カードができました。") }
    static var completeBody: String { L.tr("下次见面时，直接把它拿出来就好。接下来还可以添加更多平台和小组件。", "下次見面時，直接把它拿出來就好。接下來還可以加入更多平台和小工具。", "下次見面時，直接把它拿出來就好。接下來還可以新增更多平台和小工具。", "Bring it up the next time you meet someone. You can add more platforms and widgets next.", "次に誰かと会うとき、そのまま見せられます。ほかのプラットフォームやウィジェットも追加できます。") }
    static var replayGuide: String { L.tr("重新体验建档引导", "重新體驗建檔引導", "重新體驗建立引導", "Replay Setup Guide", "作成ガイドをもう一度見る") }
    static var nameRequired: String { L.tr("先写一个昵称，再继续。", "先寫一個暱稱，再繼續。", "先寫一個暱稱，再繼續。", "Add a display name to continue.", "続けるには表示名を入力してください。") }
    static var qrRequired: String { L.tr("先添加一个可以使用的二维码。", "先加入一個可以使用的 QR Code。", "先新增一個可以使用的 QR Code。", "Add a working QR code to continue.", "続けるにはQRコードを追加してください。") }
    static var saveFailed: String { L.tr("卡片没能保存，请再试一次。", "卡片未能儲存，請再試一次。", "卡片未能儲存，請再試一次。", "The card could not be saved. Please try again.", "カードを保存できませんでした。もう一度お試しください。") }
}

private enum OnboardingStep: Int, CaseIterable {
    case welcome
    case identity
    case qr
    case appearance
    case tags
    case preview
    case complete

    static var setupSteps: [OnboardingStep] {
        [.identity, .qr, .appearance, .tags, .preview]
    }
}

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appSettings) private var settings
    @Query(sort: \QRCluster.sortOrder, order: .forward) private var clusters: [QRCluster]

    let hasExistingCards: Bool
    let onFinish: () -> Void
    let onSkip: () -> Void

    @State private var step: OnboardingStep = .welcome
    @State private var name = ""
    @State private var subtitle = ""
    @State private var avatarImage: UIImage?
    @State private var rawAvatarImage: CroppableImage?
    @State private var avatarPhotosItem: PhotosPickerItem?

    @State private var isGenerated = false
    @State private var qrContent = ""
    @State private var importedQRImage: UIImage?
    @State private var qrPhotosItem: PhotosPickerItem?
    @State private var platformType = Platform.custom.rawValue
    @State private var customPlatformName = ""
    @State private var isDecoding = false

    @State private var templateStyle: ClusterTemplateStyle = .standard
    @State private var backgroundColor = Color.white
    @State private var textColor = Color.black
    @State private var qrColor = Color.black
    @State private var backgroundImage: UIImage?
    @State private var rawBackgroundImage: CroppableImage?
    @State private var backgroundPhotosItem: PhotosPickerItem?
    @State private var rhodesBannerImage: UIImage?
    @State private var rawRhodesBannerImage: CroppableImage?
    @State private var rhodesBannerPhotosItem: PhotosPickerItem?
    @State private var tagInput = ""

    @FocusState private var isSubtitleFocused: Bool

    @State private var validationMessage: String?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var isSaving = false

    private let accent = Color(hex: "#39C5BB")
    private let pink = Color(hex: "#FF4D8D")

    var body: some View {
        ZStack {
            ambientBackground

            if step == .welcome {
                welcomeView
                    .transition(stepTransition)
            } else if step == .complete {
                completeView
                    .transition(stepTransition)
            } else {
                setupView
                    .transition(stepTransition)
            }
        }
        .tint(accent)
        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86), value: step)
        .onChange(of: qrPhotosItem) { _, item in
            guard let item else { return }
            Task { await decodeImportedQR(item) }
        }
        .onChange(of: avatarPhotosItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    rawAvatarImage = CroppableImage(image: image)
                }
            }
        }
        .onChange(of: backgroundPhotosItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    rawBackgroundImage = CroppableImage(image: image)
                }
            }
        }
        .onChange(of: rhodesBannerPhotosItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    rawRhodesBannerImage = CroppableImage(image: image)
                }
            }
        }
        .fullScreenCover(item: $rawAvatarImage) { item in
            AvatarCropView(
                sourceImage: item.image,
                onDone: { image in
                    avatarImage = image
                    rawAvatarImage = nil
                },
                onCancel: { rawAvatarImage = nil }
            )
        }
        .fullScreenCover(item: $rawBackgroundImage) { item in
            BackgroundCropView(
                sourceImage: item.image,
                onDone: { image in
                    backgroundImage = image
                    rawBackgroundImage = nil
                },
                onCancel: { rawBackgroundImage = nil }
            )
        }
        .fullScreenCover(item: $rawRhodesBannerImage) { item in
            BackgroundCropView(
                sourceImage: item.image,
                cropAspectRatio: 16.0 / 9.0,
                onDone: { image in
                    rhodesBannerImage = image
                    rawRhodesBannerImage = nil
                },
                onCancel: { rawRhodesBannerImage = nil }
            )
        }
        .alert(L.couldNotSave, isPresented: $showError) {
            Button(L.ok, role: .cancel) {}
        } message: {
            Text(errorMessage ?? OnboardingCopy.saveFailed)
        }
    }

    private var stepTransition: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    /// Soft ambient glows behind everything — keeps the background alive
    /// without fighting the content, in both light and dark mode.
    private var ambientBackground: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)

            Circle()
                .fill(accent.opacity(0.32))
                .frame(width: 430, height: 430)
                .blur(radius: 130)
                .offset(x: -150, y: -290)

            Circle()
                .fill(pink.opacity(0.24))
                .frame(width: 380, height: 380)
                .blur(radius: 130)
                .offset(x: 180, y: -90)

            Circle()
                .fill(Color(hex: "#3381B0").opacity(0.20))
                .frame(width: 360, height: 360)
                .blur(radius: 140)
                .offset(x: -110, y: 360)
        }
        .ignoresSafeArea()
    }

    private var welcomeView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    onboardingMark
                    Spacer()
                    Text("MEQR · FIRST CARD")
                        .font(.caption2.weight(.black))
                        .tracking(1.2)
                        .foregroundStyle(.secondary)
                    onboardingLanguageMenu
                }

                Spacer(minLength: 64)

                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.9), accent.opacity(0.45)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 260)
                        .rotationEffect(.degrees(-5))
                        .offset(x: -8, y: 8)
                        .opacity(0.5)
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [pink.opacity(0.85), Color(hex: "#FFB84D").opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 260)
                        .rotationEffect(.degrees(4))
                        .offset(x: 9, y: 4)
                        .opacity(0.35)
                    welcomeCard
                        .padding(22)
                }
                .padding(.horizontal, 6)

                Text(OnboardingCopy.welcomeTitle)
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .tracking(0)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 52)

                Text(hasExistingCards ? OnboardingCopy.existingBody : OnboardingCopy.welcomeBody)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineSpacing(5)
                    .padding(.top, 16)

                Button {
                    move(to: .identity)
                } label: {
                    HStack(spacing: 9) {
                        Text(hasExistingCards ? OnboardingCopy.tryGuide : OnboardingCopy.start)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(OnboardingPrimaryButtonStyle(color: .black))
                .padding(.top, 36)

                Button(hasExistingCards ? OnboardingCopy.keepCards : OnboardingCopy.later) {
                    onSkip()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 28)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private var setupView: some View {
        VStack(spacing: 0) {
            setupHeader

            ScrollViewReader { proxy in
                ScrollView {
                    Group {
                        switch step {
                        case .identity:
                            identityStep
                        case .qr:
                            qrStep
                        case .appearance:
                            appearanceStep
                        case .tags:
                            tagsStep
                        case .preview:
                            previewStep
                        case .welcome, .complete:
                            EmptyView()
                        }
                    }
                    .id(step)
                    .padding(.horizontal, 28)
                    .padding(.top, 30)
                    .padding(.bottom, 130)
                    .frame(maxWidth: 620)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: step) { _, newStep in
                    proxy.scrollTo(newStep, anchor: .top)
                }
                .onChange(of: isSubtitleFocused) { _, isFocused in
                    guard isFocused else { return }
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo("onboarding-intro-field", anchor: .center)
                    }
                }
                .onChange(of: subtitle) { _, _ in
                    guard isSubtitleFocused else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("onboarding-intro-field", anchor: .center)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            setupActions
        }
        .overlay {
            if isDecoding || isSaving {
                ProgressView(isSaving ? L.save : L.decodingQR)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 18)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.12), radius: 22, y: 10)
            }
        }
    }

    private var setupHeader: some View {
        VStack(spacing: 14) {
            HStack {
                onboardingMark
                Spacer()
                Text("\(currentSetupIndex + 1) / \(OnboardingStep.setupSteps.count)")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(OnboardingCopy.step)
            }

            HStack(spacing: 7) {
                ForEach(OnboardingStep.setupSteps, id: \.rawValue) { item in
                    Capsule()
                        .fill(item.rawValue <= step.rawValue ? accent : Color.secondary.opacity(0.17))
                        .frame(maxWidth: item == step ? 42 : .infinity)
                        .frame(height: 6)
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: step)
        }
        .padding(.horizontal, 28)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    private var setupActions: some View {
        VStack(spacing: 9) {
            if let validationMessage {
                Text(validationMessage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 12) {
                Button {
                    moveBackward()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.bold))
                        .frame(width: 48, height: 50)
                }
                .buttonStyle(.plain)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityLabel(OnboardingCopy.back)

                Button {
                    advance()
                } label: {
                    HStack(spacing: 9) {
                        Text(step == .preview ? OnboardingCopy.createCard : OnboardingCopy.continueButton)
                        Image(systemName: step == .preview ? "checkmark" : "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(OnboardingPrimaryButtonStyle(color: .black))
                .disabled(isSaving || isDecoding)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }

    private var identityStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            stepTitle(OnboardingCopy.identityTitle, body: OnboardingCopy.identityBody, number: "01", color: accent)

            HStack(spacing: 20) {
                avatarPreview
                    .frame(width: 92, height: 92)
                    .overlay(Circle().stroke(.white, lineWidth: 4))
                    .shadow(color: .black.opacity(0.12), radius: 14, y: 6)

                PhotosPicker(selection: $avatarPhotosItem, matching: .images) {
                    Label(avatarImage == nil ? L.chooseAvatar : L.changeAvatar, systemImage: "photo.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(OnboardingCopy.nickname)
                    .font(.subheadline.weight(.bold))
                TextField("Miku39", text: $name)
                    .textInputAutocapitalization(.words)
                    .onChange(of: name) { _, _ in validationMessage = nil }
                    .onboardingField()
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(OnboardingCopy.intro)
                    .font(.subheadline.weight(.bold))
                TextField(L.subtitleInfo, text: $subtitle, axis: .vertical)
                    .lineLimit(3...5)
                    .focused($isSubtitleFocused)
                    .id("onboarding-intro-field")
                    .onboardingField()
            }
        }
    }

    private var qrStep: some View {
        VStack(alignment: .leading, spacing: 26) {
            stepTitle(OnboardingCopy.qrTitle, body: OnboardingCopy.qrBody, number: "02", color: pink)

            Picker(L.qrSource, selection: $isGenerated) {
                Text(L.importQRImage).tag(false)
                Text(L.generateFromText).tag(true)
            }
            .pickerStyle(.segmented)

            if isGenerated {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L.urlOrText)
                        .font(.subheadline.weight(.bold))
                    TextField(L.urlOrText, text: $qrContent, axis: .vertical)
                        .lineLimit(3...5)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: qrContent) { _, newValue in
                            validationMessage = nil
                            if let detected = Platform.detect(from: newValue) {
                                platformType = detected.rawValue
                            }
                        }
                        .onboardingField()
                }
            } else {
                PhotosPicker(selection: $qrPhotosItem, matching: .images) {
                    VStack(spacing: 14) {
                        if let importedQRImage {
                            Image(uiImage: importedQRImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            Label(OnboardingCopy.recognized, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(accent)
                        } else {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 42, weight: .medium))
                                .foregroundStyle(pink)
                            Text(L.selectQRImage)
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 210)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [7]))
                            .foregroundStyle(Color.secondary.opacity(0.3))
                    )
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(L.platform)
                    .font(.subheadline.weight(.bold))
                Picker(L.platform, selection: $platformType) {
                    platformOptions(Platform.commonPlatforms)
                    platformOptions(Platform.socialPlatforms)
                    platformOptions(Platform.professionalPlatforms)
                    Label(Platform.custom.displayName, systemImage: Platform.custom.iconName)
                        .tag(Platform.custom.rawValue)
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

                if platformType == Platform.custom.rawValue {
                    TextField(L.customPlatformName, text: $customPlatformName)
                        .onboardingField()
                }
            }
        }
    }

    private var appearanceStep: some View {
        VStack(alignment: .leading, spacing: 26) {
            stepTitle(OnboardingCopy.appearanceTitle, body: OnboardingCopy.appearanceBody, number: "03", color: .blue)

            Picker(L.cardTemplate, selection: $templateStyle) {
                ForEach(ClusterTemplateStyle.selectableCases) { style in
                    Label(style.displayName, systemImage: style.iconName)
                        .tag(style)
                }
            }
            .pickerStyle(.segmented)

            draftCardPreview(compact: true)

            VStack(spacing: 0) {
                ColorPicker(L.backgroundColor, selection: $backgroundColor, supportsOpacity: false)
                    .padding(16)
                Divider().padding(.leading, 16)
                ColorPicker(L.textColor, selection: $textColor, supportsOpacity: false)
                    .padding(16)
                Divider().padding(.leading, 16)
                ColorPicker(L.qrCodeColor, selection: $qrColor, supportsOpacity: false)
                    .padding(16)
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))

            PhotosPicker(selection: $backgroundPhotosItem, matching: .images) {
                HStack {
                    Label(backgroundImage == nil ? OnboardingCopy.backgroundPhoto : L.changeBackgroundImage, systemImage: "photo.fill")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            }

            if backgroundImage != nil {
                Button(L.removeBackgroundImage, role: .destructive) {
                    backgroundImage = nil
                    backgroundPhotosItem = nil
                }
                .font(.subheadline.weight(.semibold))
            }

            if templateStyle == .rhodesPass {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.landscape")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(accent)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(rhodesBannerImage == nil ? L.passBannerImage : L.changePassBannerImage)
                                .font(.headline)
                            Text(L.passBannerHint)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }

                    PhotosPicker(selection: $rhodesBannerPhotosItem, matching: .images) {
                        HStack {
                            Label(
                                rhodesBannerImage == nil ? L.passBannerImage : L.changePassBannerImage,
                                systemImage: "photo.badge.plus"
                            )
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .foregroundStyle(accent)
                        .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                    }

                    if let rhodesBannerImage {
                        Image(uiImage: rhodesBannerImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .aspectRatio(16.0 / 9.0, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        Button(L.removePassBanner, role: .destructive) {
                            self.rhodesBannerImage = nil
                            rhodesBannerPhotosItem = nil
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(16)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(accent.opacity(rhodesBannerImage == nil ? 0.48 : 0.18), lineWidth: 1)
                )
            }
        }
    }

    private var tagsStep: some View {
        VStack(alignment: .leading, spacing: 26) {
            stepTitle(OnboardingCopy.tagsTitle, body: OnboardingCopy.tagsBody, number: "04", color: .orange)

            Text(OnboardingCopy.optional)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.1), in: Capsule())

            CardTagInputView(text: $tagInput)
                .padding(16)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 12) {
                Text(OnboardingCopy.suggestions)
                    .font(.subheadline.weight(.bold))
                CardTagFlowLayout(spacing: 8, rowSpacing: 8) {
                    ForEach(suggestedTags, id: \.self) { tag in
                        Button {
                            toggleSuggestedTag(tag)
                        } label: {
                            OnboardingTagChip(tag: tag, isSelected: selectedTags.contains(tag))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var previewStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            stepTitle(OnboardingCopy.previewTitle, body: OnboardingCopy.previewBody, number: "05", color: accent)
            draftCardPreview(compact: false)

            VStack(spacing: 0) {
                summaryRow(icon: "person.fill", title: name, detail: subtitle.isEmpty ? L.subtitleInfo : subtitle)
                Divider().padding(.leading, 52)
                summaryRow(icon: selectedPlatform.iconName, title: previewPlatformName, detail: L.singleQRCode)
                if !selectedTags.isEmpty {
                    Divider().padding(.leading, 52)
                    summaryRow(icon: "tag.fill", title: selectedTags.joined(separator: " · "), detail: L.tags)
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var completeView: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 76)

                ZStack {
                    Circle()
                        .fill(accent.opacity(0.30))
                        .frame(width: 170, height: 170)
                        .blur(radius: 26)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [accent, Color(hex: "#3381B0")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 108, height: 108)
                        .shadow(color: accent.opacity(0.45), radius: 22, y: 10)
                    Image(systemName: "checkmark")
                        .font(.system(size: 44, weight: .black))
                        .foregroundStyle(.white)
                }

                Text(OnboardingCopy.completeTitle)
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.top, 34)

                Text(OnboardingCopy.completeBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.top, 16)

                draftCardPreview(compact: true)
                    .padding(.top, 38)

                Button {
                    onFinish()
                } label: {
                    HStack {
                        Text(OnboardingCopy.enterApp)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(OnboardingPrimaryButtonStyle(color: .black))
                .padding(.top, 40)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 30)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private var onboardingMark: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent, Color(hex: "#3381B0")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                    .shadow(color: accent.opacity(0.4), radius: 8, y: 3)
                Image(systemName: "qrcode")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(L.qrID)
                .font(.headline.weight(.black))
        }
    }

    private var onboardingLanguageMenu: some View {
        Menu {
            ForEach(AppLanguage.allCases) { language in
                Button {
                    settings.selectedLanguage = language
                } label: {
                    if settings.selectedLanguage == language {
                        Label(language.displayName, systemImage: "checkmark")
                    } else {
                        Text(language.displayName)
                    }
                }
            }
        } label: {
            Image(systemName: "globe")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(.thinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L.languageSelection)
    }

    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 18) {
                avatarPreview
                    .frame(width: 74, height: 74)
                VStack(alignment: .leading, spacing: 8) {
                    Text(name.isEmpty ? "Miku39" : name)
                        .font(.title2.weight(.black))
                        .foregroundStyle(.black)
                    Text("QR PROFILE · 2026")
                        .font(.caption2.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(.black.opacity(0.58))
                }
                Spacer(minLength: 0)
                Image(systemName: "qrcode")
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(.black)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(L.previewSampleTags, id: \.self) { tag in
                        let tagColor = Color(hex: CardTagColorPalette.colorHex(for: tag))
                        Text(tag)
                            .font(.caption2.weight(.bold))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 5)
                            .foregroundStyle(tagColor.uiContrastColor)
                            .background(tagColor, in: Capsule())
                    }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 210)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.16), radius: 26, y: 14)
    }

    @ViewBuilder
    private var avatarPreview: some View {
        if let avatarImage {
            Image(uiImage: avatarImage)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        } else {
            ZStack {
                Circle().fill(accent.opacity(0.18))
                Image(systemName: "person.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(accent)
            }
        }
    }

    private func stepTitle(_ title: String, body: String, number: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(number)
                .font(.caption.weight(.black))
                .foregroundStyle(color)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(color.opacity(0.12), in: Capsule())
            Text(title)
                .font(.system(size: 34, weight: .black, design: .rounded))
                .tracking(0)
                .fixedSize(horizontal: false, vertical: true)
            Text(body)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
    }

    private func draftCardPreview(compact: Bool) -> some View {
        let cluster = makeDraftPreviewCluster()
        let stageHeight: CGFloat = if templateStyle == .rhodesPass {
            compact ? 430 : 500
        } else {
            compact ? 310 : 380
        }

        return GeometryReader { geometry in
            ZStack {
                if let backgroundImage {
                    Image(uiImage: backgroundImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    backgroundColor
                }

                ClusterCardView(
                    cluster: cluster,
                    size: templateStyle == .rhodesPass ? 180 : 150,
                    containerWidth: geometry.size.width
                )
                .frame(height: stageHeight - 34)
                .padding(.vertical, 17)
            }
            .frame(width: geometry.size.width, height: stageHeight)
            .clipped()
        }
        .frame(height: stageHeight)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 20, y: 10)
    }

    private func makeDraftPreviewCluster() -> QRCluster {
        let qrColorHex = qrColor.toHex() ?? "#000000"
        let tags = CardTagLimiter.tags(from: tagInput)
        let cluster = QRCluster(
            name: name.isEmpty ? OnboardingCopy.nickname : name,
            subtitle: subtitle,
            avatarImageData: avatarImage?.jpegData(compressionQuality: 0.9),
            backgroundImageData: backgroundImage?.jpegData(compressionQuality: 0.9),
            backgroundColorHex: backgroundColor.toHex() ?? "#FFFFFF",
            textColorHex: textColor.toHex() ?? "#000000",
            qrColorHex: qrColorHex,
            templateStyleRawValue: templateStyle.rawValue,
            rhodesBannerImageData: templateStyle == .rhodesPass
                ? rhodesBannerImage?.jpegData(compressionQuality: 0.9)
                : nil,
            tagListRawValue: CardTagLimiter.normalizedRawValue(tagInput),
            tagColorOverridesRawValue: CardTagColorPalette.rawValue(from: [:], tags: tags),
            cornerRadius: templateStyle == .rhodesPass ? 12 : 16,
            cardOpacity: 0.76,
            sortOrder: 0
        )
        let resolvedPlatform = Platform.resolvedSelection(
            platformType: platformType,
            customPlatformName: customPlatformName
        )
        let profile = QRProfile(
            platformType: resolvedPlatform.platformType,
            qrContent: qrContent.isEmpty ? "https://meqrcode.cn" : qrContent,
            foregroundColorHex: qrColorHex,
            customPlatformName: resolvedPlatform.customPlatformName,
            cluster: cluster
        )
        profile.attach(to: cluster)
        cluster.profiles = [profile]
        return cluster
    }

    private func standardDraftCardPreview(compact: Bool) -> some View {
        ZStack {
            if let backgroundImage {
                Image(uiImage: backgroundImage)
                    .resizable()
                    .scaledToFill()
            } else {
                backgroundColor
            }

            Color.black.opacity(backgroundImage == nil ? 0 : 0.18)

            VStack(spacing: compact ? 12 : 18) {
                HStack(spacing: 13) {
                    avatarPreview
                        .frame(width: compact ? 52 : 68, height: compact ? 52 : 68)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(name.isEmpty ? OnboardingCopy.nickname : name)
                            .font(compact ? .headline.weight(.black) : .title2.weight(.black))
                            .foregroundStyle(textColor)
                            .lineLimit(1)
                        Text(subtitle.isEmpty ? previewPlatformName : subtitle)
                            .font(.caption)
                            .foregroundStyle(textColor.opacity(0.72))
                            .lineLimit(2)
                    }
                    Spacer()
                }

                HStack(alignment: .bottom, spacing: 16) {
                    if !selectedTags.isEmpty {
                        CardTagFlowLayout(spacing: 5, rowSpacing: 5) {
                            ForEach(selectedTags.prefix(compact ? 3 : 6), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 5)
                                    .foregroundStyle(Color(hex: CardTagColorPalette.colorHex(for: tag)).uiContrastColor)
                                    .background(Color(hex: CardTagColorPalette.colorHex(for: tag)), in: Capsule())
                            }
                        }
                    } else {
                        Text(previewPlatformName.uppercased())
                            .font(.caption2.weight(.black))
                            .tracking(0.8)
                            .foregroundStyle(textColor.opacity(0.66))
                    }
                    Spacer(minLength: 8)
                    previewQR
                        .frame(width: compact ? 76 : 104, height: compact ? 76 : 104)
                        .padding(7)
                        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(compact ? 20 : 24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: compact ? 230 : 320)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(textColor.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 20, y: 10)
    }

    private func rhodesDraftCardPreview(compact: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Rectangle().fill(qrColor.opacity(0.82))
                Rectangle().fill(textColor.opacity(0.82))
                Rectangle().fill(backgroundColor.opacity(0.92))
            }
            .frame(height: compact ? 18 : 24)
            .overlay(alignment: .trailing) {
                Text("#01")
                    .font(.system(size: compact ? 9 : 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.62))
                    .padding(.trailing, 12)
            }

            HStack(spacing: 0) {
                rhodesDraftSideRail(compact: compact)

                VStack(alignment: .leading, spacing: compact ? 8 : 12) {
                    rhodesDraftHero(compact: compact)

                    HStack(alignment: .top, spacing: compact ? 8 : 12) {
                        previewQR
                            .frame(width: compact ? 68 : 100, height: compact ? 68 : 100)
                            .padding(compact ? 5 : 7)
                            .background(.white, in: RoundedRectangle(cornerRadius: 9))
                            .overlay(
                                RoundedRectangle(cornerRadius: 9)
                                    .stroke(.black.opacity(0.12), lineWidth: 1)
                            )

                        VStack(alignment: .leading, spacing: 7) {
                            Text(L.passLabel.uppercased())
                                .font(.system(size: compact ? 9 : 11, weight: .black, design: .monospaced))
                                .foregroundStyle(textColor.opacity(0.58))
                            Label(previewPlatformName, systemImage: selectedPlatform.iconName)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(textColor)
                                .lineLimit(2)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(compact ? 9 : 12)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: compact ? 230 : 320)
        .background(.white.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.85), lineWidth: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(textColor.opacity(0.18), lineWidth: 1)
                .padding(-6)
        )
        .shadow(color: .black.opacity(0.16), radius: 20, y: 10)
        .padding(7)
    }

    private func rhodesDraftSideRail(compact: Bool) -> some View {
        ZStack {
            Rectangle().fill(textColor.opacity(0.88))

            VStack(spacing: compact ? 7 : 10) {
                Text("MEQR")
                    .font(.system(size: compact ? 12 : 16, weight: .black))
                    .rotationEffect(.degrees(-90))
                    .frame(width: compact ? 42 : 58, height: compact ? 42 : 58)

                HStack(alignment: .bottom, spacing: 1.5) {
                    ForEach(0..<10, id: \.self) { index in
                        Rectangle()
                            .fill(.white.opacity(index.isMultiple(of: 3) ? 0.92 : 0.62))
                            .frame(width: index.isMultiple(of: 4) ? 3 : 1.5)
                    }
                }
                .frame(width: compact ? 24 : 32, height: compact ? 48 : 72)

                Text(rhodesPreviewDate)
                    .font(.system(size: compact ? 10 : 14, weight: .black, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .lineSpacing(-2)
            }
            .foregroundStyle(.white.opacity(0.9))
        }
        .frame(width: compact ? 38 : 50)
        .frame(maxHeight: .infinity)
        .clipped()
    }

    private func rhodesDraftHero(compact: Bool) -> some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let backgroundImage {
                    Image(uiImage: backgroundImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        backgroundColor
                        LinearGradient(
                            colors: [textColor.opacity(0.2), backgroundColor.opacity(0.1), qrColor.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
            }

            HStack(spacing: compact ? 8 : 10) {
                avatarPreview
                    .frame(width: compact ? 38 : 48, height: compact ? 38 : 48)
                    .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 2))

                VStack(alignment: .leading, spacing: 2) {
                    Text(name.isEmpty ? OnboardingCopy.nickname : name)
                        .font(compact ? .subheadline.weight(.black) : .title3.weight(.black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(subtitle.isEmpty ? L.passLabel : subtitle)
                        .font(.system(size: compact ? 8 : 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.84))
                        .lineLimit(1)
                }
            }
            .padding(compact ? 8 : 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [.clear, .black.opacity(0.58)], startPoint: .top, endPoint: .bottom)
            )
        }
        .frame(height: compact ? 82 : 132)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.black.opacity(0.08), lineWidth: 1)
        )
    }

    private var rhodesPreviewDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM\ndd"
        return formatter.string(from: Date())
    }

    @ViewBuilder
    private var previewQR: some View {
        if !qrContent.isEmpty,
           let image = QRCodeGenerator.generate(from: qrContent, foreground: qrColor, background: backgroundColor) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
        } else {
            Image(systemName: "qrcode")
                .resizable()
                .scaledToFit()
                .foregroundStyle(qrColor)
        }
    }

    private func summaryRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
    }

    @ViewBuilder
    private func platformOptions(_ platforms: [Platform]) -> some View {
        ForEach(platforms) { platform in
            Label(platform.displayName, systemImage: platform.iconName)
                .tag(platform.rawValue)
        }
    }

    private var selectedPlatform: Platform {
        Platform(rawValue: platformType) ?? .custom
    }

    private var previewPlatformName: String {
        let customName = customPlatformName.trimmingCharacters(in: .whitespacesAndNewlines)
        return selectedPlatform == .custom && !customName.isEmpty ? customName : selectedPlatform.displayName
    }

    private var selectedTags: [String] {
        CardTagLimiter.tags(from: tagInput)
    }

    private var suggestedTags: [String] {
        CardTagIndex.featuredSuggestions()
    }

    private var currentSetupIndex: Int {
        OnboardingStep.setupSteps.firstIndex(of: step) ?? 0
    }

    private func toggleSuggestedTag(_ tag: String) {
        var tags = selectedTags
        if let index = tags.firstIndex(where: { CardTagIndex.normalizedKey($0) == CardTagIndex.normalizedKey(tag) }) {
            tags.remove(at: index)
        } else if tags.count < CardTagLimiter.maxTags {
            tags.append(CardTagLimiter.normalizedTag(tag))
        }
        tagInput = tags.joined(separator: "\n")
    }

    private func move(to newStep: OnboardingStep) {
        validationMessage = nil
        step = newStep
    }

    private func moveBackward() {
        guard let index = OnboardingStep.setupSteps.firstIndex(of: step), index > 0 else {
            move(to: .welcome)
            return
        }
        move(to: OnboardingStep.setupSteps[index - 1])
    }

    private func advance() {
        validationMessage = nil

        switch step {
        case .identity:
            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                validationMessage = OnboardingCopy.nameRequired
                return
            }
            move(to: .qr)
        case .qr:
            guard !qrContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                validationMessage = OnboardingCopy.qrRequired
                return
            }
            move(to: .appearance)
        case .appearance:
            move(to: .tags)
        case .tags:
            move(to: .preview)
        case .preview:
            saveCard()
        case .welcome, .complete:
            break
        }
    }

    @MainActor
    private func decodeImportedQR(_ item: PhotosPickerItem) async {
        isDecoding = true
        defer { isDecoding = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                throw QRCodeGenerator.QRDecodeError.invalidImage
            }
            let decoded = try await QRCodeGenerator.decode(from: image)
            importedQRImage = image
            qrContent = decoded
            validationMessage = nil
            if let detected = Platform.detect(from: decoded) {
                platformType = detected.rawValue
            }
        } catch {
            importedQRImage = nil
            qrContent = ""
            errorMessage = (error as? QRCodeGenerator.QRDecodeError)?.errorDescription ?? error.localizedDescription
            showError = true
        }
    }

    private func saveCard() {
        guard !isSaving else { return }
        isSaving = true

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedQR = qrContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedPlatform = Platform.resolvedSelection(
            platformType: platformType,
            customPlatformName: customPlatformName
        )
        let qrColorHex = qrColor.toHex() ?? "#000000"
        let tags = CardTagLimiter.tags(from: tagInput)
        let cluster = QRCluster(
            name: trimmedName,
            subtitle: subtitle.trimmingCharacters(in: .whitespacesAndNewlines),
            avatarImageData: avatarImage?.jpegData(compressionQuality: 0.9),
            backgroundImageData: backgroundImage?.jpegData(compressionQuality: 0.9),
            backgroundColorHex: backgroundColor.toHex() ?? "#FFFFFF",
            textColorHex: textColor.toHex() ?? "#000000",
            qrColorHex: qrColorHex,
            templateStyleRawValue: templateStyle.rawValue,
            rhodesBannerImageData: templateStyle == .rhodesPass
                ? rhodesBannerImage?.jpegData(compressionQuality: 0.9)
                : nil,
            tagListRawValue: CardTagLimiter.normalizedRawValue(tagInput),
            tagColorOverridesRawValue: CardTagColorPalette.rawValue(from: [:], tags: tags),
            cornerRadius: templateStyle == .rhodesPass ? 12 : 16,
            sortOrder: (clusters.map(\.sortOrder).max() ?? -1) + 1
        )
        let profile = QRProfile(
            platformType: resolvedPlatform.platformType,
            qrContent: trimmedQR,
            foregroundColorHex: qrColorHex,
            customPlatformName: resolvedPlatform.customPlatformName,
            cluster: cluster
        )
        profile.attach(to: cluster)
        modelContext.insert(cluster)
        modelContext.insert(profile)

        do {
            try modelContext.save()
            try MigrationManager.performClusterMigrationIfNeeded(context: modelContext)
            let persistedClusters = try modelContext.fetch(FetchDescriptor<QRCluster>(
                sortBy: [SortDescriptor(\QRCluster.sortOrder, order: .forward)]
            ))
            WidgetDataHelper.sync(clusters: persistedClusters)
            BackupManager.writeAutoBackup(clusters: persistedClusters)
            isSaving = false
            move(to: .complete)
        } catch {
            modelContext.rollback()
            isSaving = false
            errorMessage = "\(OnboardingCopy.saveFailed)\n\(error.localizedDescription)"
            showError = true
        }
    }
}

private struct OnboardingTagChip: View {
    let tag: String
    let isSelected: Bool

    var body: some View {
        let color = Color(hex: CardTagColorPalette.colorHex(for: tag))
        HStack(spacing: 6) {
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.black))
            }
            Text(tag)
                .lineLimit(1)
        }
        .font(.caption.weight(.bold))
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .foregroundStyle(isSelected ? color.uiContrastColor : Color.primary)
        .background(isSelected ? color : Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
        .overlay(Capsule().stroke(color.opacity(isSelected ? 0 : 0.4), lineWidth: 1))
    }
}

private struct OnboardingPrimaryButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .frame(minHeight: 54)
            .padding(.horizontal, 18)
            .background(color.opacity(configuration.isPressed ? 0.78 : 1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: color.opacity(0.28), radius: 14, y: 7)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private extension View {
    func onboardingField() -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            )
    }
}
