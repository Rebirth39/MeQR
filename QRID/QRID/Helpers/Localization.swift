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
    static var appearance: String { tr("外观", "外觀", "外觀", "Appearance", "外観") }
    static var textColor: String { tr("文字颜色", "文字顏色", "文字顏色", "Text Color", "文字色") }
    static var qrCodeColor: String { tr("二维码颜色", "QR Code 顏色", "QR Code 顏色", "QR Code Color", "QRコードの色") }
    static var backgroundColor: String { tr("背景颜色", "背景顏色", "背景顏色", "Background Color", "背景色") }
    static var cornerRadius: String { tr("圆角", "圓角", "圓角", "Corner Radius", "角丸") }
    static var preview: String { tr("预览", "預覽", "預覽", "Preview", "プレビュー") }
    static var save: String { tr("保存", "儲存", "儲存", "Save", "保存") }

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
    static var newCluster: String { tr("新建合集", "新增合集", "新增合集", "New Cluster", "新規コレクション") }
    static var addToExistingCluster: String { tr("添加到现有合集", "加入至現有合集", "新增到現有合集", "Add to Existing Cluster", "既存のコレクションに追加") }
    static var editCluster: String { tr("编辑合集", "編輯合集", "編輯合集", "Edit Cluster", "コレクションを編集") }
    static var deleteCluster: String { tr("删除合集", "刪除合集", "刪除合集", "Delete Cluster", "コレクションを削除") }
    static var deleteClusterConfirm: String { tr("确定要删除整个合集及其所有二维码？", "確定要刪除整個合集及其中所有 QR Code？", "確定要刪除整個合集和裡面的所有 QR Code？", "Delete this cluster and all its QR codes?", "このコレクションとすべてのQRコードを削除しますか？") }
    static var deleteQRFromCluster: String { tr("删除这个二维码", "刪除這個 QR Code", "刪除這個 QR Code", "Delete This QR Code", "このQRコードを削除") }
    static var addQRToCluster: String { tr("添加二维码", "加入 QR Code", "新增 QR Code", "Add QR Code", "QRコードを追加") }
    static var clusterInfo: String { tr("合集信息", "合集資料", "合集資訊", "Cluster Info", "コレクション情報") }
    static var clusterName: String { tr("合集名称", "合集名稱", "合集名稱", "Cluster Name", "コレクション名") }
    static var sharedFieldsNote: String { tr("以下信息由合集共享，编辑请前往合集设置", "以下資料由合集共用，請到合集設定編輯", "以下資訊由合集共用，請到合集設定編輯", "Shared by cluster. Edit in cluster settings.", "以下はコレクションで共有されます。編集はコレクション設定から行ってください。") }
    static var chooseAction: String { tr("选择操作", "選擇操作", "選擇操作", "Choose Action", "操作を選択") }
    static var qrCodesInCluster: String { tr("合集中的二维码", "合集中的 QR Code", "合集中的 QR Code", "QR Codes", "QRコード") }
    static var noClustersYet: String { tr("还没有合集", "還沒有合集", "還沒有合集", "No Clusters Yet", "コレクションがまだありません") }
    static var selectCluster: String { tr("选择合集", "選擇合集", "選擇合集", "Select Cluster", "コレクションを選択") }
    static var editQRInCluster: String { tr("编辑二维码", "編輯 QR Code", "編輯 QR Code", "Edit QR Code", "QRコードを編集") }
    static var singleQRCode: String { tr("单个二维码", "單個 QR Code", "單個 QR Code", "Single QR Code", "単体QRコード") }

    // Background Image
    static var backgroundImage: String { tr("背景图片", "背景圖片", "背景圖片", "Background Image", "背景画像") }
    static var useSolidColor: String { tr("使用纯色", "使用純色", "使用純色", "Use Solid Color", "単色を使う") }
    static var useCustomImage: String { tr("使用自定义图片", "使用自訂圖片", "使用自訂圖片", "Use Custom Image", "カスタム画像を使う") }
    static var removeBackgroundImage: String { tr("移除背景图片", "移除背景圖片", "移除背景圖片", "Remove Background Image", "背景画像を削除") }
    static var cardOpacity: String { tr("卡片不透明度", "卡片不透明度", "卡片不透明度", "Card Opacity", "カードの不透明度") }
    static var customPlatformName: String { tr("平台名称", "平台名稱", "平台名稱", "Platform Name", "プラットフォーム名") }
    static var reorderClusters: String { tr("排序合集", "排序合集", "排序合集", "Reorder Clusters", "コレクションを並べ替え") }
    static var settings: String { tr("设置", "設定", "設定", "Settings", "設定") }
    static var aboutSoftware: String { tr("关于软件", "關於軟件", "關於 App", "About", "このアプリについて") }
    static var privacyPolicy: String { tr("隐私政策", "私隱政策", "隱私權政策", "Privacy Policy", "プライバシーポリシー") }
    static var contactDeveloper: String { tr("联系开发者", "聯絡開發者", "聯絡開發者", "Contact Developer", "開発者に連絡") }
    static var developerInfo: String { tr("开发者信息", "開發者資料", "開發者資訊", "Developer Info", "開発者情報") }
    static var iCloudSync: String { tr("iCloud 同步", "iCloud 同步", "iCloud 同步", "iCloud Sync", "iCloud同期") }
    static var savedToPhotos: String { tr("已保存到相册", "已儲存到相簿", "已儲存到照片", "Saved to Photos", "写真に保存しました") }
    static var couldNotSave: String { tr("无法保存", "無法儲存", "無法儲存", "Could Not Save", "保存できません") }
    static var tryAgain: String { tr("无法保存，请重试。", "無法儲存，請再試一次。", "無法儲存，請再試一次。", "Please try again.", "もう一度お試しください。") }
    static var longPressToReorder: String { tr("长按合集排序", "長按合集排序", "長按合集排序", "Long press to reorder", "長押しして並べ替え") }

    // Widget
    static var widgetSettings: String { tr("小组件设置", "小工具設定", "小工具設定", "Widget Settings", "ウィジェット設定") }
    static var widgetDisplay: String { tr("显示", "顯示", "顯示", "Display", "表示") }
    static var widgetBackground: String { tr("背景", "背景", "背景", "Background", "背景") }
    static var showQR: String { tr("显示 QR", "顯示 QR", "顯示 QR", "Show QR", "QRを表示") }
    static var useClusterBackgroundColor: String { tr("使用合集背景色", "使用合集背景色", "使用合集背景色", "Use Cluster Background", "コレクションの背景色を使う") }
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
    static var douyin: String { tr("抖音", "抖音", "抖音", "Douyin", "抖音") }
    static var weibo: String { tr("微博", "微博", "微博", "Weibo", "微博") }
}
