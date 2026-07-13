import Foundation

struct L {
    static func tr(_ zhHans: String, _ zhHantHK: String, _ zhHantTW: String, _ en: String, _ ja: String) -> String {
        switch AppSettings.shared.resolvedLanguage {
        case .system, .en:
            return en
        case .zhHans:
            return zhHans
        case .zhHantHK:
            return zhHantHK
        case .zhHantTW:
            return zhHantTW
        case .ja:
            return ja
        }
    }

    static func tr(_ zh: String, _ en: String) -> String {
        tr(zh, zh, zh, en, en)
    }

    // MainView
    static var qrID: String { "喜劳转扩" }
    static var noQRCodesYet: String { tr("还没有二维码", "還沒有 QR Code", "還沒有 QR Code", "No QR Codes Yet", "QRコードがまだありません") }
    static var addFirstQR: String { tr("添加你的第一个社交二维码开始使用", "加入你的第一個社交 QR Code 開始使用", "加入你的第一個社群 QR Code 開始使用", "Add your first social QR code to get started.", "最初のSNS用QRコードを追加して始めましょう。") }
    static var addQRCode: String { tr("添加二维码", "加入 QR Code", "新增 QR Code", "Add QR Code", "QRコードを追加") }
    static var deleteProfile: String { tr("删除名片", "刪除名片", "刪除名片", "Delete Profile", "プロフィールを削除") }
    static var deleteConfirm: String { tr("确定要删除", "確定要刪除", "確定要刪除", "Are you sure you want to delete", "削除しますか") }
    static var cancel: String { tr("取消", "取消", "取消", "Cancel", "キャンセル") }
    static var delete: String { tr("删除", "刪除", "刪除", "Delete", "削除") }
    static var done: String { tr("完成", "完成", "完成", "Done", "完了") }
    static var ok: String { tr("好", "好", "好", "OK", "OK") }
    static var moreSettings: String { tr("更多设置", "更多設定", "更多設定", "More Settings", "その他の設定") }
    static var meqrProfileCode: String { tr("MeQR 交换码", "MeQR 交換碼", "MeQR 交換碼", "MeQR Profile Code", "MeQR 交換コード") }
    static var scanMeQRCode: String { tr("扫 MeQR 交换码", "掃 MeQR 交換碼", "掃描 MeQR 交換碼", "Scan MeQR Code", "MeQRコードをスキャン") }
    static var encounters: String { tr("认识记录", "認識記錄", "認識紀錄", "Encounters", "出会った人") }
    static var events: String { tr("线下活动", "線下活動", "線下活動", "Events", "イベント") }

    // Add/Edit Profile
    static var newQRCode: String { tr("新建二维码", "新增 QR Code", "新增 QR Code", "New QR Code", "新規QRコード") }
    static var editQRCode: String { tr("编辑二维码", "編輯 QR Code", "編輯 QR Code", "Edit QR Code", "QRコードを編集") }
    static var qrSource: String { tr("二维码来源", "QR Code 來源", "QR Code 來源", "QR Source", "QRコードの入力元") }
    static var generateFromText: String { tr("从文本生成", "由文字生成", "從文字產生", "Generate from Text", "テキストから生成") }
    static var importQRImage: String { tr("导入二维码图片", "匯入 QR Code 圖片", "匯入 QR Code 圖片", "Import QR Image", "QR画像を読み込む") }
    static var selectQRImage: String { tr("选择二维码图片", "選擇 QR Code 圖片", "選擇 QR Code 圖片", "Select QR Image", "QR画像を選択") }
    static var changeQRImage: String { tr("更换二维码图片", "更換 QR Code 圖片", "更換 QR Code 圖片", "Change QR Image", "QR画像を変更") }
    static var urlOrText: String { tr("URL 或文本", "URL 或文字", "URL 或文字", "URL or text to encode", "URLまたはテキスト") }
    static var avatar: String { tr("头像", "頭像", "頭像", "Avatar", "アイコン") }
    static var chooseAvatar: String { tr("选择头像", "選擇頭像", "選擇頭像", "Choose Avatar", "アイコンを選択") }
    static var changeAvatar: String { tr("更换头像", "更換頭像", "更換頭像", "Change Avatar", "アイコンを変更") }
    static var replaceFromQRImage: String { tr("从二维码图片替换", "由 QR Code 圖片替換", "從 QR Code 圖片替換", "Replace from QR Image", "QR画像から置き換え") }
    static var details: String { tr("详情", "詳情", "詳細資料", "Details", "詳細") }
    static var profileName: String { tr("名片名称", "名片名稱", "名片名稱", "Profile Name", "プロフィール名") }
    static var subtitleInfo: String { tr("副标题 / 信息（可选）", "副標題 / 資料（可選）", "副標題 / 資訊（選填）", "Subtitle / Info (optional)", "サブタイトル / 情報（任意）") }
    static var platform: String { tr("平台", "平台", "平台", "Platform", "プラットフォーム") }
    static var commonPlatforms: String { tr("常用软件", "常用軟件", "常用 App", "Common Apps", "よく使うアプリ") }
    static var socialPlatforms: String { tr("社交", "社交", "社群", "Social", "ソーシャル") }
    static var professionalPlatforms: String { tr("职业", "職業", "職業", "Professional", "仕事") }
    static var appearance: String { tr("外观", "外觀", "外觀", "Appearance", "外観") }
    static var textColor: String { tr("文字颜色", "文字顏色", "文字顏色", "Text Color", "文字色") }
    static var qrCodeColor: String { tr("二维码颜色", "QR Code 顏色", "QR Code 顏色", "QR Code Color", "QRコードの色") }
    static var backgroundColor: String { tr("背景颜色", "背景顏色", "背景顏色", "Background Color", "背景色") }
    static var cornerRadius: String { tr("圆角", "圓角", "圓角", "Corner Radius", "角丸") }
    static var preview: String { tr("预览", "預覽", "預覽", "Preview", "プレビュー") }
    static var save: String { tr("保存", "儲存", "儲存", "Save", "保存") }
    static var cardTemplate: String { tr("卡片模板", "卡片模板", "卡片模板", "Card Template", "カードテンプレート") }
    static var templateStandard: String { tr("标准", "標準", "標準", "Standard", "標準") }
    static var templateConventionPass: String { tr("漫展通行证", "漫展通行證", "漫展通行證", "Convention Pass", "イベントパス") }
    static var templateRhodesPass: String { tr("明日方舟通行证", "明日方舟通行證", "明日方舟通行證", "Arknights Pass", "アークナイツパス") }
    static var passLabel: String { tr("通行证", "通行證", "通行證", "Pass", "パス") }
    static var passSubtitleLabel: String { tr("通行证短标签", "通行證短標籤", "通行證短標籤", "Pass Short Label", "パス短いラベル") }
    static var passSubtitleHint: String { tr("显示在名字下面，最多 10 个汉字。", "顯示在名字下面，最多 10 個漢字。", "顯示在名字下面，最多 10 個漢字。", "Shown under the name. Up to 10 CJK characters.", "名前の下に表示します。漢字10文字まで。") }
    static var templateHint: String { tr("模板会改变名片排版；颜色、头像、背景图仍然可以自己调。", "模板會改變名片排版；顏色、頭像、背景圖仍然可以自己調。", "模板會改變名片排版；顏色、頭像、背景圖仍然可以自己調。", "Templates change the card layout. Colors, avatar, and background remain editable.", "テンプレートはレイアウトを変更します。色、アイコン、背景は編集できます。") }
    static var passBannerImage: String { tr("横版头图", "橫版頭圖", "橫版頭圖", "Landscape Header Image", "横長ヘッダー画像") }
    static var changePassBannerImage: String { tr("更换横版头图", "更換橫版頭圖", "更換橫版頭圖", "Change Landscape Header", "横長ヘッダーを変更") }
    static var passBannerHint: String { tr("通行证可以单独选择一张横版头图做卡片 banner；背景图仍然可以用竖版图。", "通行證可以單獨選擇一張橫版頭圖做卡片 banner；背景圖仍然可以用豎版圖。", "通行證可以單獨選擇一張橫版頭圖做卡片 banner；背景圖仍然可以用直式圖。", "Pass can use a separate landscape header while the main background stays portrait.", "パスでは横長ヘッダー画像を別に選べます。背景は縦長のままで使えます。") }
    static var removePassBanner: String { tr("移除横版头图", "移除橫版頭圖", "移除橫版頭圖", "Remove Landscape Header", "横長ヘッダーを削除") }

    // Crop View
    static var cropAvatar: String { tr("裁剪头像", "裁剪頭像", "裁剪頭像", "Crop Avatar", "アイコンを切り抜き") }
    static var cropBackground: String { tr("裁剪背景", "裁剪背景", "裁剪背景", "Crop Background", "背景を切り抜き") }
    static var pinchToZoom: String { tr("双指缩放，拖动调整", "雙指縮放，拖動調整", "雙指縮放，拖曳調整", "Pinch to zoom, drag to move", "ピンチで拡大、ドラッグで移動") }
    static var choose: String { tr("选择", "選擇", "選擇", "Choose", "選択") }
    static var couldNotDecodeQR: String { tr("无法识别二维码", "無法識別 QR Code", "無法辨識 QR Code", "Could Not Decode QR", "QRコードを読み取れません") }
    static var noQRFound: String { tr("图片中没有找到二维码", "圖片中找不到 QR Code", "圖片中找不到 QR Code", "No QR code found in this image.", "画像内にQRコードが見つかりません。") }
    static var invalidImage: String { tr("无法处理图片", "無法處理圖片", "無法處理圖片", "Could not process the image.", "画像を処理できません。") }
    static var decodingQR: String { tr("正在识别二维码...", "正在識別 QR Code...", "正在辨識 QR Code...", "Decoding QR...", "QRコードを読み取り中...") }

    // Language
    static var language: String { tr("语言", "語言", "語言", "Language", "言語") }
    static var languageSelection: String { tr("语言选择", "語言選擇", "語言選擇", "Language", "言語選択") }
    static var followSystem: String { tr("跟随系统", "跟隨系統", "跟隨系統", "Follow System", "システムに合わせる") }
    static var languageRestartNotice: String { tr("部分新语言资源可能需要重启软件才能生效", "部分新語言資源可能需要重新啟動軟件才能生效", "部分新語言資源可能需要重新啟動軟體才能生效", "Some new language resources may require restarting the app to take effect.", "一部の新しい言語リソースは、アプリの再起動後に反映される場合があります。") }
    static var chinese: String { tr("中文", "中文", "中文", "Chinese", "中国語") }
    static var english: String { tr("English", "English", "English", "English", "英語") }

    // Cluster
    static var newCluster: String { tr("新建卡片", "新增卡片", "新增卡片", "New Card", "新規カード") }
    static var addToExistingCluster: String { tr("添加到现有卡片", "加入至現有卡片", "新增到現有卡片", "Add to Existing Card", "既存のカードに追加") }
    static var editCluster: String { tr("编辑卡片", "編輯卡片", "編輯卡片", "Edit Card", "カードを編集") }
    static var deleteCluster: String { tr("删除卡片", "刪除卡片", "刪除卡片", "Delete Card", "カードを削除") }
    static var deleteClusterConfirm: String { tr("确定要删除整张卡片及其所有二维码？", "確定要刪除整張卡片及其中所有 QR Code？", "確定要刪除整張卡片和裡面的所有 QR Code？", "Delete this card and all its QR codes?", "このカードとすべてのQRコードを削除しますか？") }
    static var deleteQRFromCluster: String { tr("删除这个二维码", "刪除這個 QR Code", "刪除這個 QR Code", "Delete This QR Code", "このQRコードを削除") }
    static var addQRToCluster: String { tr("添加二维码", "加入 QR Code", "新增 QR Code", "Add QR Code", "QRコードを追加") }
    static var clusterInfo: String { tr("卡片信息", "卡片資料", "卡片資訊", "Card Info", "カード情報") }
    static var clusterName: String { tr("卡片名称", "卡片名稱", "卡片名稱", "Card Name", "カード名") }
    static var sharedFieldsNote: String { tr("以下信息由卡片共享，编辑请前往卡片设置", "以下資料由卡片共用，請到卡片設定編輯", "以下資訊由卡片共用，請到卡片設定編輯", "Shared by card. Edit in card settings.", "以下はカードで共有されます。編集はカード設定から行ってください。") }
    static var chooseAction: String { tr("选择操作", "選擇操作", "選擇操作", "Choose Action", "操作を選択") }
    static var qrCodesInCluster: String { tr("卡片中的二维码", "卡片中的 QR Code", "卡片中的 QR Code", "QR Codes", "QRコード") }
    static var noClustersYet: String { tr("还没有卡片", "還沒有卡片", "還沒有卡片", "No Cards Yet", "カードがまだありません") }
    static var selectCluster: String { tr("选择卡片", "選擇卡片", "選擇卡片", "Select Card", "カードを選択") }
    static var editQRInCluster: String { tr("编辑二维码", "編輯 QR Code", "編輯 QR Code", "Edit QR Code", "QRコードを編集") }
    static var singleQRCode: String { tr("单个二维码", "單個 QR Code", "單個 QR Code", "Single QR Code", "単体QRコード") }

    // Background Image
    static var backgroundImage: String { tr("背景图片", "背景圖片", "背景圖片", "Background Image", "背景画像") }
    static var useSolidColor: String { tr("使用纯色", "使用純色", "使用純色", "Use Solid Color", "単色を使う") }
    static var useCustomImage: String { tr("使用自定义图片", "使用自訂圖片", "使用自訂圖片", "Use Custom Image", "カスタム画像を使う") }
    static var removeBackgroundImage: String { tr("移除背景图片", "移除背景圖片", "移除背景圖片", "Remove Background Image", "背景画像を削除") }
    static var cardOpacity: String { tr("卡片不透明度", "卡片不透明度", "卡片不透明度", "Card Opacity", "カードの不透明度") }
    static var customPlatformName: String { tr("平台名称", "平台名稱", "平台名稱", "Platform Name", "プラットフォーム名") }
    static var reorderClusters: String { tr("排序卡片", "排序卡片", "排序卡片", "Reorder Cards", "カードを並べ替え") }
    static var settings: String { tr("设置", "設定", "設定", "Settings", "設定") }
    static var aboutSoftware: String { tr("关于软件", "關於軟件", "關於 App", "About", "このアプリについて") }
    static var privacyPolicy: String { tr("隐私政策", "私隱政策", "隱私權政策", "Privacy Policy (English)", "プライバシーポリシー（英語）") }
    static var contactDeveloper: String { tr("联系开发者", "聯絡開發者", "聯絡開發者", "Contact Developer", "開発者に連絡") }
    static var developerInfo: String { tr("开发者信息", "開發者資料", "開發者資訊", "Developer Info", "開発者情報") }
    static var savedToPhotos: String { tr("已保存到相册", "已儲存到相簿", "已儲存到照片", "Saved to Photos", "写真に保存しました") }
    static var saveMeQRCode: String { tr("保存交换码到相册", "儲存交換碼到相簿", "儲存交換碼到照片", "Save Code to Photos", "交換コードを写真に保存") }
    static var meqrCodeHint: String { tr("对方用 MeQR 扫这个码，就能看到你的这张扩列卡并保存为认识记录。", "對方用 MeQR 掃這個碼，就能看到你的這張擴列卡並儲存為認識記錄。", "對方用 MeQR 掃描這個碼，就能看到你的這張擴列卡並儲存為認識紀錄。", "Someone can scan this with MeQR to save your profile as an encounter.", "相手がMeQRでこのコードを読み取ると、あなたのプロフィールを記録できます。") }
    static var meqrCodeSettings: String { tr("交换码设置", "交換碼設定", "交換碼設定", "Code Settings", "交換コード設定") }
    static var meqrCodeUploading: String { tr("正在生成交换码...", "正在產生交換碼...", "正在產生交換碼...", "Preparing code...", "交換コードを準備中...") }
    static var meqrCodeLocalReady: String { tr("本地交换码：不会上传资料，扫码直接读取。", "本地交換碼：不會上傳資料，掃碼直接讀取。", "本地交換碼：不會上傳資料，掃碼直接讀取。", "Local code: no upload, scan to read directly.", "ローカルコード：アップロードせず、スキャンして直接読み取ります。") }
    static var meqrCodeOnlineReady: String { tr("在线交换码：已上传到 MeQR 云端，离线备用码也已写入。", "線上交換碼：已上傳到 MeQR 雲端，離線備用碼也已寫入。", "線上交換碼：已上傳到 MeQR 雲端，離線備用碼也已寫入。", "Online code: uploaded to MeQR Cloud with an offline backup.", "オンラインコード：MeQRクラウドにアップロードし、オフライン予備も含めました。") }
    static func meqrCodeUploadFailed(_ reason: String) -> String { tr("上传失败，已使用本地备用码。\(reason)", "上傳失敗，已使用本地備用碼。\(reason)", "上傳失敗，已使用本地備用碼。\(reason)", "Upload failed; using the local backup code. \(reason)", "アップロードに失敗したため、ローカル予備コードを使います。\(reason)") }
    static var meqrCodeStillPreparing: String { tr("交换码还在生成，等它一下。", "交換碼還在產生，等它一下。", "交換碼還在產生，等它一下。", "The code is still being prepared.", "交換コードを準備中です。") }
    static var exchangeCardIntro: String { tr("展示文案", "展示文案", "展示文案", "Display Intro", "表示テキスト") }
    static var exchangeCardIntroHint: String { tr("显示在交换码页面和名片里，最多 25 个汉字；英文数字按半个汉字算。", "顯示在交換碼頁面和名片裡，最多 25 個漢字；英文數字按半個漢字算。", "顯示在交換碼頁面和名片裡，最多 25 個漢字；英文數字按半個漢字算。", "Shown on the exchange page and profile card. Up to 25 CJK characters; Latin letters count as half.", "交換コード画面とプロフィールに表示します。漢字25文字まで、英数字は半分換算。") }
    static var includedPlatforms: String { tr("塞进交换码的平台", "放入交換碼的平台", "放進交換碼的平台", "Included Platforms", "交換コードに入れる平台") }
    static var offlineFallbackPlatform: String { tr("离线备用平台", "離線備用平台", "離線備用平台", "Offline Backup Platform", "オフライン予備平台") }
    static var offlineFallbackPlatformHint: String { tr("没网的时候只保这个平台，加上昵称和 25 个字以内的介绍。", "無網時只保留這個平台，加上暱稱和 25 字以內的介紹。", "沒網時只保留這個平台，加上暱稱和 25 字以內的介紹。", "When offline, MeQR keeps only this platform plus your name and a short intro.", "オフライン時は、この平台と名前、短い紹介だけを残します。") }
    static var chooseAtLeastThreePlatforms: String { tr("至少保留 3 个平台，这样扫出来不会太空。", "至少保留 3 個平台，掃出來才不會太空。", "至少保留 3 個平台，掃出來才不會太空。", "Keep at least 3 platforms so the card does not look empty.", "最低3個は入れておくと、カードが空っぽに見えません。") }
    static var chooseUpToThreePlatforms: String { tr("最多塞 3 个平台，不然这个码会胖到扫不动。", "最多放 3 個平台，不然這個碼會太胖不好掃。", "最多放 3 個平台，不然這個碼會太胖不好掃。", "Pick up to 3 platforms so the code stays scannable.", "読み取りやすくするため、最大3個まで選べます。") }
    static func meqrIncludedPlatforms(_ count: Int, _ names: String) -> String {
        if names.isEmpty {
            return tr("当前没有可交换的平台", "目前沒有可交換的平台", "目前沒有可交換的平台", "No platforms are included yet.", "共有できる平台がまだありません。")
        }
        return tr(
            "当前交换 \(count) 个：\(names)",
            "目前交換 \(count) 個：\(names)",
            "目前交換 \(count) 個：\(names)",
            "Sharing \(count): \(names)",
            "\(count)個を共有：\(names)"
        )
    }
    static var scanMeQRHint: String { tr("扫描对方的 MeQR 交换码", "掃描對方的 MeQR 交換碼", "掃描對方的 MeQR 交換碼", "Scan someone's MeQR profile code.", "相手のMeQR交換コードをスキャン") }
    static var importMeQRFromPhoto: String { tr("从相册导入", "從相簿匯入", "從照片匯入", "Import from Photos", "写真から読み込む") }
    static var meqrProfileFound: String { tr("发现 MeQR 名片", "發現 MeQR 名片", "發現 MeQR 名片", "MeQR Profile Found", "MeQRプロフィールを検出") }
    static var saveEncounter: String { tr("保存记录", "儲存記錄", "儲存紀錄", "Save Encounter", "記録を保存") }
    static var saved: String { tr("已保存", "已儲存", "已儲存", "Saved", "保存済み") }
    static var platformsFromMeQR: String { tr("交换的平台", "交換的平台", "交換的平台", "Shared Platforms", "共有された平台") }
    static var activeEvent: String { tr("当前活动", "目前活動", "目前活動", "Active Event", "現在のイベント") }
    static var noActiveEvent: String { tr("不绑定活动", "不綁定活動", "不綁定活動", "No Active Event", "イベントなし") }
    static var noActiveEventHint: String { tr("扫码保存时只记录时间，不归到具体展子。", "掃碼儲存時只記錄時間，不歸到具體展子。", "掃描儲存時只記錄時間，不歸到具體活動。", "New scans will not be attached to an event.", "新しい記録をイベントに紐づけません。") }
    static var chooseEventForEncounter: String { tr("选择展会后，新的认识记录会自动归档到这里。", "選擇展會後，新的認識記錄會自動歸檔到這裡。", "選擇活動後，新的認識紀錄會自動歸檔到這裡。", "Choose an event to file new encounters there.", "イベントを選ぶと新しい記録をそこに保存します。") }
    static var eventName: String { tr("活动名称", "活動名稱", "活動名稱", "Event Name", "イベント名") }
    static var eventVenue: String { tr("地点", "地點", "地點", "Venue", "会場") }
    static var eventAddress: String { tr("地址", "地址", "地址", "Address", "住所") }
    static var eventDate: String { tr("时间", "時間", "時間", "Date", "日時") }
    static var eventDetails: String { tr("活动信息", "活動資訊", "活動資訊", "Details", "詳細") }
    static var eventInfo: String { tr("活动信息", "活動資訊", "活動資訊", "Event Info", "イベント情報") }
    static var customEvent: String { tr("自定义活动", "自訂活動", "自訂活動", "Custom Event", "カスタムイベント") }
    static var loadingEvents: String { tr("正在拉取服务器上的近期展会...", "正在拉取伺服器上的近期展會...", "正在拉取伺服器上的近期活動...", "Loading recent events from the server...", "サーバーから最近のイベントを読み込み中...") }
    static var eventsFooter: String { tr("服务器列表可以人工维护；Only 展或小聚会可以用右上角加号手动添加。", "伺服器列表可以人工維護；Only 展或小聚會可以用右上角加號手動加入。", "伺服器列表可以人工維護；Only 場或小聚會可以用右上角加號手動新增。", "Server events can be curated manually. Use plus for small custom events.", "サーバー側のイベント一覧を手動管理できます。小規模イベントは追加できます。") }
    static var appleMaps: String { tr("Apple 地图", "Apple 地圖", "Apple 地圖", "Apple Maps", "Appleマップ") }
    static var amap: String { tr("高德", "高德", "高德", "Amap", "高德") }
    static var noEncountersYet: String { tr("还没有认识记录", "還沒有認識記錄", "還沒有認識紀錄", "No Encounters Yet", "記録はまだありません") }
    static var noEncountersHint: String { tr("扫对方的 MeQR 交换码之后，会出现在这里。", "掃對方的 MeQR 交換碼之後，會出現在這裡。", "掃描對方的 MeQR 交換碼之後，會出現在這裡。", "People you save from MeQR codes will appear here.", "MeQRコードから保存した人がここに表示されます。") }
    static var searchEncounters: String { tr("搜索昵称、备注、标签", "搜尋暱稱、備註、標籤", "搜尋暱稱、備註、標籤", "Search names, notes, tags", "名前、メモ、タグを検索") }
    static var noSearchResults: String { tr("没有搜索结果", "沒有搜尋結果", "沒有搜尋結果", "No Results", "結果がありません") }
    static var tryAnotherSearch: String { tr("换个关键词试试。", "換個關鍵字試試。", "換個關鍵字試試。", "Try another search.", "別のキーワードを試してください。") }
    static var encounterInfo: String { tr("记录信息", "記錄資料", "紀錄資訊", "Encounter Info", "記録情報") }
    static var metAt: String { tr("认识时间", "認識時間", "認識時間", "Met At", "会った日時") }
    static var note: String { tr("备注", "備註", "備註", "Note", "メモ") }
    static var tags: String { tr("标签", "標籤", "標籤", "Tags", "タグ") }
    static var tagColors: String { tr("标签颜色", "標籤顏色", "標籤顏色", "Tag Colors", "タグの色") }
    static var tagColor: String { tr("颜色", "顏色", "顏色", "Color", "色") }
    static var tagColorMixed: String { tr("拼色", "拼色", "拼色", "Mixed", "多色") }
    static var tagColorSolid: String { tr("纯色", "純色", "純色", "Solid", "単色") }
    static var tagColorPresetLocked: String { tr("已使用内置颜色", "已使用內建顏色", "已使用內建顏色", "Using preset color", "プリセット色を使用中") }
    static var addColor: String { tr("增加颜色", "增加顏色", "新增顏色", "Add Color", "色を追加") }
    static var removeColor: String { tr("移除颜色", "移除顏色", "移除顏色", "Remove Color", "色を削除") }
    static var cardTagsHint: String { tr("输入后按回车添加，最多 10 个；会显示在通行证背面。", "輸入後按 Return 加入，最多 10 個；會顯示在通行證背面。", "輸入後按 Return 新增，最多 10 個；會顯示在通行證背面。", "Press Return to add. Up to 10 tags, shown on the pass back.", "入力後Returnで追加。最大10個、パス裏面に表示します。") }
    static var followStatus: String { tr("互关状态 / 返图进度", "互關狀態 / 返圖進度", "互關狀態 / 返圖進度", "Follow / photo status", "フォロー・返礼状況") }
    static var needsPhotoReturn: String { tr("需要返图", "需要返圖", "需要返圖", "Needs photo return", "写真返却が必要") }
    static var exchangedFreebie: String { tr("交换过无料", "交換過無料", "交換過無料配布", "Freebie exchanged", "無配交換済み") }
    static var notMeQRProfileCode: String { tr("这不是有效的 MeQR 交换码。", "這不是有效的 MeQR 交換碼。", "這不是有效的 MeQR 交換碼。", "This is not a valid MeQR profile code.", "有効なMeQR交換コードではありません。") }
    static var photoPermissionNeeded: String { tr("需要相册权限才能保存图片。", "需要相簿權限才能儲存圖片。", "需要照片權限才能儲存圖片。", "Photo permission is needed to save the image.", "画像を保存するには写真へのアクセスが必要です。") }
    static var cameraPermissionNeeded: String { tr("需要相机权限才能扫描 MeQR 交换码。", "需要相機權限才能掃描 MeQR 交換碼。", "需要相機權限才能掃描 MeQR 交換碼。", "Camera permission is needed to scan MeQR codes.", "MeQRコードをスキャンするにはカメラへのアクセスが必要です。") }
    static var couldNotSave: String { tr("无法保存", "無法儲存", "無法儲存", "Could Not Save", "保存できません") }
    static var tryAgain: String { tr("无法保存，请重试。", "無法儲存，請再試一次。", "無法儲存，請再試一次。", "Please try again.", "もう一度お試しください。") }
    static var longPressToReorder: String { tr("长按卡片排序", "長按卡片排序", "長按卡片排序", "Long press to reorder", "長押しして並べ替え") }

    // Widget
    static var widgetSettings: String { tr("小组件设置", "小工具設定", "小工具設定", "Widget Settings", "ウィジェット設定") }
    static var widgetDisplay: String { tr("显示", "顯示", "顯示", "Display", "表示") }
    static var widgetBackground: String { tr("背景", "背景", "背景", "Background", "背景") }
    static var showQR: String { tr("显示 QR", "顯示 QR", "顯示 QR", "Show QR", "QRを表示") }
    static var useClusterBackgroundColor: String { tr("使用卡片背景色", "使用卡片背景色", "使用卡片背景色", "Use Card Background", "カードの背景色を使う") }
    static var useCustomBackground: String { tr("使用自定义背景", "使用自訂背景", "使用自訂背景", "Use Custom Background", "カスタム背景を使う") }
    static var selectBackgroundImage: String { tr("选择背景图", "選擇背景圖", "選擇背景圖", "Select Background Image", "背景画像を選択") }
    static var changeBackgroundImage: String { tr("更换背景图", "更換背景圖", "更換背景圖", "Change Background Image", "背景画像を変更") }
    static var removeBackground: String { tr("移除背景", "移除背景", "移除背景", "Remove Background", "背景を削除") }
    static var opacity: String { tr("不透明度", "不透明度", "不透明度", "Opacity", "不透明度") }
    static var widgetPreview: String { tr("Widget 预览", "Widget 預覽", "Widget 預覽", "Widget Preview", "ウィジェットプレビュー") }
    static var widgetBackgroundPosition: String { tr("背景位置", "背景位置", "背景位置", "Background Position", "背景位置") }
    static var widgetSize: String { tr("尺寸", "尺寸", "尺寸", "Size", "サイズ") }
    static var widgetSmall: String { tr("小号", "小型", "小型", "Small", "小") }
    static var widgetMedium: String { tr("中号", "中型", "中型", "Medium", "中") }
    static var widgetLarge: String { tr("大号", "大型", "大型", "Large", "大") }
    static var horizontal: String { tr("水平", "水平", "水平", "Horizontal", "横") }
    static var vertical: String { tr("垂直", "垂直", "垂直", "Vertical", "縦") }

    // About
    static var versionBuild: String { tr("版本", "版本", "版本", "Version", "バージョン") }
    static var build: String { tr("构建", "構建", "建置", "Build", "ビルド") }
    static var githubProjectPage: String { tr("GitHub 项目页面", "GitHub 項目頁面", "GitHub 專案頁面", "GitHub Project", "GitHubプロジェクト") }
    static var githubFooter: String { tr("如果想看更多的软件介绍的话点一下上面的按钮可以跳到GitHub页面w", "如果想看更多軟件介紹，可以點上面的按鈕跳到 GitHub 頁面w", "如果想看更多 App 介紹，可以點上面的按鈕跳到 GitHub 頁面w", "Tap the button above to open the GitHub page for more app info.", "上のボタンからGitHubページを開けます。") }
    static var privacyFooter: String { tr("这个链接会跳到 GitHub 上公开放着的隐私政策页面。", "這個連結會跳到 GitHub 上公開放着的私隱政策頁面。", "這個連結會開啟 GitHub 上公開放置的隱私權政策頁面。", "This link opens the public privacy policy page on GitHub.", "このリンクはGitHub上の公開プライバシーポリシーを開きます。") }
    static var email: String { tr("邮箱", "電郵", "電子郵件", "Email", "メール") }
    static var developerIntro: String { tr("开发者介绍", "開發者介紹", "開發者介紹", "Developer Intro", "開発者紹介") }
    static var developerStudent: String { tr("目前高中就读 初⚪︎未来重度依赖（）", "目前高中就讀 初⚪︎未來重度依賴（）", "目前高中就讀 初⚪︎未來重度依賴（）", "High school student, heavily dependent on Hat⚪︎ne Miku.", "高校生です。初⚪︎ミクにかなり依存しています。") }
    static var developerMadeForFun: String { tr("抱着玩一下的心态开发了这款软件", "抱着玩一下的心態開發了這款軟件", "抱著玩一下的心態開發了這款 App", "I started this app just for fun", "遊び半分でこのアプリを作り始めました") }
    static var developerUnexpected: String { tr("没想到后面功能越加越多", "沒想到後面功能越加越多", "沒想到後來功能越加越多", "then somehow kept adding more features", "気づいたら機能がどんどん増えていました") }
    static var developerHope: String { tr("希望大家喜欢:)", "希望大家喜歡:)", "希望大家喜歡:)", "Hope you like it :)", "気に入ってもらえたらうれしいです :)") }

    // Platform names
    static var wechat: String { tr("微信", "微信", "微信", "WeChat", "WeChat") }
    static var twitter: String { tr("X (推特)", "X (Twitter)", "X (Twitter)", "X (Twitter)", "X（Twitter）") }
    static var emailPlatform: String { tr("邮箱", "電郵", "電子郵件", "Email", "メール") }
    static var phone: String { tr("电话", "電話", "電話", "Phone", "電話") }
    static var custom: String { tr("自定义", "自訂", "自訂", "Custom", "カスタム") }
    static var xiaohongshu: String { tr("小红书", "小紅書", "小紅書", "Xiaohongshu", "小紅書") }
    static var bilibili: String { tr("B站", "B站", "B站", "Bilibili", "Bilibili") }
    static var douyinTikTok: String { tr("抖音", "抖音", "TikTok", "TikTok", "TikTok") }
    static var weibo: String { tr("微博", "微博", "微博", "Weibo", "微博") }
}
