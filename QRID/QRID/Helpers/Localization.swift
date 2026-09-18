import Foundation

struct L {
    static var tagKindWork: String { tr("作品", "作品", "作品", "Work", "作品") }
    static var tagKindCharacter: String { tr("角色", "角色", "角色", "Character", "キャラクター") }
    static var tagKindGroup: String { tr("组合", "組合", "組合", "Group", "グループ") }
    static var tagKindRating: String { tr("等级", "等級", "等級", "Rating", "レーティング") }
    static var tagFavorites: String { tr("收藏", "收藏", "收藏", "Favorites", "お気に入り") }
    static var tagFavorite: String { tr("收藏 Tag", "收藏 Tag", "收藏 Tag", "Favorite Tag", "お気に入りに追加") }
    static var tagUnfavorite: String { tr("取消收藏", "取消收藏", "取消收藏", "Remove Favorite", "お気に入りから削除") }
    static var tagRequestNew: String { tr("申请收录 Tag", "申請收錄 Tag", "申請收錄 Tag", "Request a Tag", "タグの追加を申請") }
    static var tagRequestName: String { tr("角色 / Tag 名称", "角色 / Tag 名稱", "角色 / Tag 名稱", "Character / Tag Name", "キャラクター・タグ名") }
    static var tagRequestIP: String { tr("所属作品 / IP", "所屬作品 / IP", "所屬作品 / IP", "Work / IP", "作品名") }
    static var tagRequestColors: String { tr("建议配色（选填）", "建議配色（選填）", "建議配色（選填）", "Suggested Colors (Optional)", "希望する配色（任意）") }
    static var tagRequestSource: String { tr("参考链接（选填）", "參考連結（選填）", "參考連結（選填）", "Reference URL (Optional)", "参考URL（任意）") }
    static var tagOutbox: String { tr("上报记录", "回報紀錄", "回報紀錄", "Report Outbox", "報告履歴") }
    static var tagQueued: String { tr("待提交", "待提交", "待提交", "Pending", "送信待ち") }
    static var tagSending: String { tr("正在提交", "正在提交", "正在提交", "Sending", "送信中") }
    static var tagRetry: String { tr("重试", "重試", "重試", "Retry", "再試行") }
    static var tagQueueSaved: String { tr("已保存，等待提交", "已儲存，等待提交", "已儲存，等待提交", "Saved, Pending Submission", "保存済み・送信待ち") }
    static var tagQueueEmpty: String { tr("暂无上报记录", "暫無回報紀錄", "暫無回報紀錄", "No Reports", "報告はありません") }
    static var tagCancelPending: String { tr("取消待提交上报", "取消待提交回報", "取消待提交回報", "Cancel Pending Report", "送信待ちの報告を取り消す") }
    static var tagQueueSaveFailed: String { tr("无法保存上报，请保留表单并重试。", "無法儲存回報，請保留表單並重試。", "無法儲存回報，請保留表單並重試。", "Could not save the report. Keep the form open and retry.", "報告を保存できません。フォームを閉じずに再試行してください。") }
    static var tagCopyPalette: String { tr("复制配色到…", "複製配色到…", "複製配色到…", "Copy Colors To…", "配色のコピー先…") }
    static var tagHex: String { tr("HEX 色值", "HEX 色值", "HEX 色值", "HEX Color", "HEXカラー") }
    static var tagInvalidHex: String { tr("请输入有效的六位 HEX 色值", "請輸入有效的六位 HEX 色值", "請輸入有效的六位 HEX 色值", "Enter a valid six-digit HEX color", "6桁の有効なHEXカラーを入力してください") }
    static var tagMoveColor: String { tr("调整色段顺序", "調整色段順序", "調整色段順序", "Reorder Color", "色の順番を変更") }
    static var tagPreview: String { tr("预览", "預覽", "預覽", "Preview", "プレビュー") }
    static var qrReviewTitle: String { tr("确认二维码内容", "確認 QR Code 內容", "確認 QR Code 內容", "Review QR Content", "QRコードの内容を確認") }
    static var qrDestination: String { tr("目标域名", "目標網域", "目標網域", "Destination Host", "アクセス先ドメイン") }
    static var qrOpen: String { tr("继续打开", "繼續開啟", "繼續開啟", "Continue", "開く") }
    static var qrReviewWarning: String { tr("请核对完整网址。域名识别不能保证链接安全；非 HTTPS 链接可能不安全。", "請核對完整網址。網域識別不能保證連結安全；非 HTTPS 連結可能不安全。", "請核對完整網址。網域識別不能保證連結安全；非 HTTPS 連結可能不安全。", "Check the full URL. Recognizing a host does not guarantee safety; non-HTTPS links may be unsafe.", "URL全体を確認してください。ドメインの識別は安全性を保証しません。HTTPS以外のリンクには注意してください。") }
    static var qrFormatWarning: String { tr("内容与所选平台的常用链接格式不符，请核对。仍可按原内容保存。", "內容與所選平台的常用連結格式不符，請核對。仍可按原內容儲存。", "內容與所選平台的常用連結格式不符，請核對。仍可按原內容儲存。", "This does not match the selected platform's usual link format. Check it before saving; the original content can still be saved.", "選択したサービスの一般的なリンク形式と異なります。確認してください。元の内容のまま保存できます。") }
    static var qrDestinationWarning: String { tr("这是 HTTP 或 IP 地址链接，请确认目标是否可信。", "這是 HTTP 或 IP 位址連結，請確認目標是否可信。", "這是 HTTP 或 IP 位址連結，請確認目標是否可信。", "This link uses HTTP or an IP address. Verify the destination.", "HTTPまたはIPアドレスのリンクです。アクセス先を確認してください。") }
    static var qrOfficialImportHint: String { tr("请从对应 App 的个人二维码页面保存图片后导入；单独填写账号不会生成官方加好友链接。", "請從對應 App 的個人 QR Code 頁面儲存圖片後匯入；單獨填寫帳號不會產生官方加好友連結。", "請從對應 App 的個人 QR Code 頁面儲存圖片後匯入；單獨填寫帳號不會產生官方加好友連結。", "Import an image saved from the app's personal QR code page. An account ID alone cannot generate its official add-contact link.", "各アプリの個人QRコード画面から画像を保存して読み込んでください。アカウントIDだけでは公式の友だち追加リンクを生成できません。") }
    static var tagReport: String { tr("上报 Tag 问题", "回報 Tag 問題", "回報 Tag 問題", "Report Tag Issue", "タグの問題を報告") }
    static var tagReportReason: String { tr("问题类型", "問題類型", "問題類型", "Issue Type", "問題の種類") }
    static var tagReportName: String { tr("名称或翻译", "名稱或翻譯", "名稱或翻譯", "Name or Translation", "名前・翻訳") }
    static var tagReportColor: String { tr("配色错误", "配色錯誤", "配色錯誤", "Incorrect Colors", "配色の誤り") }
    static var tagReportDuplicate: String { tr("重复 Tag", "重複 Tag", "重複 Tag", "Duplicate Tag", "タグの重複") }
    static var tagReportOther: String { tr("其他问题", "其他問題", "其他問題", "Other Issue", "その他") }
    static var tagReportDescription: String { tr("问题描述", "問題描述", "問題描述", "Description", "問題の詳細") }
    static var tagReportContact: String { tr("联系方式（选填）", "聯絡方式（選填）", "聯絡方式（選填）", "Contact (Optional)", "連絡先（任意）") }
    static var tagReportSubmit: String { tr("提交", "提交", "送出", "Submit", "送信") }
    static var tagReportSent: String { tr("已提交", "已提交", "已送出", "Submitted", "送信済み") }
    static var tagReportTicket: String { tr("工单号", "工單編號", "工單編號", "Ticket ID", "受付番号") }
    static var tagReportFailed: String { tr("未能确认提交结果，请重试。当前内容已保留。", "未能確認提交結果，請重試。目前內容已保留。", "未能確認送出結果，請重試。目前內容已保留。", "Could not confirm submission. Your text is retained; please retry.", "送信結果を確認できませんでした。入力内容は保持されています。再試行してください。") }
    static var tagReportLimited: String { tr("提交过于频繁，请稍后重试。", "提交過於頻繁，請稍後重試。", "送出過於頻繁，請稍後重試。", "Too many submissions. Please try again later.", "送信回数が多すぎます。しばらくしてから再試行してください。") }
    static var tagReportDiscard: String { tr("放弃本次上报？", "放棄本次回報？", "放棄本次回報？", "Discard This Report?", "報告を破棄しますか？") }
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
    static var addFirstQR: String { tr("添加你的第一个社交二维码，开始使用", "加入你的第一個社交 QR Code，開始使用", "加入你的第一個社群 QR Code，開始使用", "Add your first social QR code to get started.", "最初のSNS用QRコードを追加して始めましょう。") }
    static var addQRCode: String { tr("添加二维码", "加入 QR Code", "新增 QR Code", "Add QR Code", "QRコードを追加") }
    static var deleteProfile: String { tr("删除名片", "刪除名片", "刪除名片", "Delete Profile", "プロフィールを削除") }
    static var deleteConfirm: String { tr("确定要删除", "確定要刪除", "確定要刪除", "Are you sure you want to delete", "削除しますか") }
    static func deleteConfirm(_ name: String) -> String { tr("确定要删除 \"\(name)\" 吗？", "確定要刪除 \"\(name)\" 嗎？", "確定要刪除 \"\(name)\" 嗎？", "Are you sure you want to delete \"\(name)\"?", "\"\(name)\"を削除しますか？") }
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
    static var languageRestartNotice: String { tr("部分新语言内容可能需要重启软件才能生效", "部分新語言內容可能需要重新啟動軟件才能生效", "部分新語言內容可能需要重新啟動軟體才能生效", "Some new language resources may require restarting the app to take effect.", "一部の新しい言語リソースは、アプリの再起動後に反映される場合があります。") }
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
    static var sharedFieldsNote: String { tr("这些信息由卡片共享，想改的话去卡片设置", "這些資料由卡片共用，想改的話去卡片設定", "這些資訊由卡片共用，想改的話去卡片設定", "Shared by card. Edit in card settings.", "以下はカードで共有されます。編集はカード設定から行ってください。") }
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
    static var icpFiling: String { tr("备案信息", "備案資訊", "備案資訊", "ICP Filing", "ICP备案") }
    static var contactDeveloper: String { tr("联系开发者", "聯絡開發者", "聯絡開發者", "Contact Developer", "開発者に連絡") }
    static var developerInfo: String { tr("开发者信息", "開發者資料", "開發者資訊", "Developer Info", "開発者情報") }
    static var savedToPhotos: String { tr("已保存到相册", "已儲存到相簿", "已儲存到照片", "Saved to Photos", "写真に保存しました") }
    static var saveMeQRCode: String { tr("保存交换码到相册", "儲存交換碼到相簿", "儲存交換碼到照片", "Save Code to Photos", "交換コードを写真に保存") }
    static var meqrCodeHint: String { tr("对方用 MeQR 扫这个码，就能看到你的这张扩列卡并保存为认识记录。", "對方用 MeQR 掃這個碼，就能看到你的這張擴列卡並儲存為認識記錄。", "對方用 MeQR 掃描這個碼，就能看到你的這張擴列卡並儲存為認識紀錄。", "Someone can scan this with MeQR to save your profile as an encounter.", "相手がMeQRでこのコードを読み取ると、あなたのプロフィールを記録できます。") }
    static var meqrCodeSettings: String { tr("交换码设置", "交換碼設定", "交換碼設定", "Code Settings", "交換コード設定") }
    static var meqrCodeUploading: String { tr("交换码已保存，可离线扫描；正在同步在线资料…", "交換碼已儲存，可離線掃描；正在同步線上資料…", "交換碼已儲存，可離線掃描；正在同步線上資料…", "Code saved and available offline. Syncing online details…", "コードを保存しました。オフラインで読み取れます。オンライン情報を同期中…") }
    static var meqrCodeLocalReady: String { tr("本地交换码：不会上传资料，扫码直接读取。", "本地交換碼：不會上傳資料，掃碼直接讀取。", "本地交換碼：不會上傳資料，掃碼直接讀取。", "Local code: no upload, scan to read directly.", "ローカルコード：アップロードせず、スキャンして直接読み取ります。") }
    static var meqrCodeOnlineReady: String { tr("交换码已保存，在线与离线使用同一码。", "交換碼已儲存，線上與離線使用同一碼。", "交換碼已儲存，線上與離線使用同一碼。", "Code saved. The same code works online and offline.", "保存済みの同じコードをオンラインでもオフラインでも使えます。") }
    static func meqrCodeUploadFailed(_ reason: String) -> String { tr("交换码已保存，离线可用；在线资料暂未同步，下次打开会重试。", "交換碼已儲存，離線可用；線上資料暫未同步，下次開啟會重試。", "交換碼已儲存，離線可用；線上資料暫未同步，下次開啟會重試。", "Code saved and available offline. Online sync will retry next time you open it.", "コードは保存済みでオフラインでも使えます。次に開くとオンライン同期を再試行します。") }
    static var meqrCodeStillPreparing: String { tr("交换码还在生成，等它一下。", "交換碼還在產生，等它一下。", "交換碼還在產生，等它一下。", "The code is still being prepared.", "交換コードを準備中です。") }
    static var exchangeCardIntro: String { tr("展示文案", "展示文案", "展示文案", "Display Intro", "表示テキスト") }
    static var exchangeCardIntroHint: String { tr("显示在交换码页面和名片里，最多 25 个汉字；英文数字按半个汉字算。", "顯示在交換碼頁面和名片裡，最多 25 個漢字；英文數字按半個漢字算。", "顯示在交換碼頁面和名片裡，最多 25 個漢字；英文數字按半個漢字算。", "Shown on the exchange page and profile card. Up to 25 CJK characters; Latin letters count as half.", "交換コード画面とプロフィールに表示します。漢字25文字まで、英数字は半分換算。") }
    static var includedPlatforms: String { tr("塞进交换码的平台", "放入交換碼的平台", "放進交換碼的平台", "Included Platforms", "交換コードに入れるプラットフォーム") }
    static var offlineFallbackPlatform: String { tr("离线备用平台", "離線備用平台", "離線備用平台", "Offline Backup Platform", "オフライン予備プラットフォーム") }
    static var offlineFallbackPlatformHint: String { tr("没网的时候只保留这个平台，加上昵称和 25 个字以内的介绍。", "無網時只保留這個平台，加上暱稱和 25 字以內的介紹。", "沒網時只保留這個平台，加上暱稱和 25 字以內的介紹。", "When offline, MeQR keeps only this platform plus your name and a short intro.", "オフライン時は、このプラットフォームと名前、短い紹介だけを残します。") }
    static var chooseAtLeastThreePlatforms: String { tr("至少保留 3 个平台，这样扫出来不会太空。", "至少保留 3 個平台，掃出來才不會太空。", "至少保留 3 個平台，掃出來才不會太空。", "Keep at least 3 platforms so the card does not look empty.", "最低3個は入れておくと、カードが空っぽに見えません。") }
    static var chooseUpToThreePlatforms: String { tr("最多塞 3 个平台，不然这个码会胖到扫不动。", "最多放 3 個平台，不然這個碼會太胖不好掃。", "最多放 3 個平台，不然這個碼會太胖不好掃。", "Pick up to 3 platforms so the code stays scannable.", "読み取りやすくするため、最大3個まで選べます。") }
    static func meqrIncludedPlatforms(_ count: Int, _ names: String) -> String {
        if names.isEmpty {
            return tr("当前没有可交换的平台", "目前沒有可交換的平台", "目前沒有可交換的平台", "No platforms are included yet.", "共有できるプラットフォームがまだありません。")
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
    static var myExchangeCode: String { tr("我的交换码", "我的交換碼", "我的交換碼", "My Exchange Code", "交換コード") }
    static var wechatNotInstalled: String { tr("未安装微信，无法打开扫一扫", "未安裝微信，無法打開掃一掃", "未安裝微信，無法開啟掃一掃", "WeChat is not installed.", "WeChatがインストールされていません。") }
    static var meqrProfileFound: String { tr("发现 MeQR 名片", "發現 MeQR 名片", "發現 MeQR 名片", "MeQR Profile Found", "MeQRプロフィールを検出") }
    static var saveEncounter: String { tr("保存记录", "儲存記錄", "儲存紀錄", "Save Encounter", "記録を保存") }
    static var qrAppOpenFailed: String { tr("无法打开对应 App，请确认已安装并重试。", "無法開啟對應 App，請確認已安裝並重試。", "無法開啟對應 App，請確認已安裝並重試。", "Unable to open the app. Check that it is installed and try again.", "アプリを開けません。インストール済みか確認して再試行してください。") }
    static var saved: String { tr("已保存", "已儲存", "已儲存", "Saved", "保存済み") }
    static var platformsFromMeQR: String { tr("交换的平台", "交換的平台", "交換的平台", "Shared Platforms", "共有されたプラットフォーム") }
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
    static func encounterWaitingForPeer(_ count: Int) -> String { tr("等待对方确认的认识记录：\(count)", "等待對方確認的認識記錄：\(count)", "等待對方確認的認識紀錄：\(count)", "Waiting for peer confirmation: \(count)", "相手の確認待ち：\(count)") }
    static func encounterConfirmationsPending(_ count: Int) -> String { tr("交换确认待发送：\(count)", "交換確認待傳送：\(count)", "交換確認待傳送：\(count)", "Exchange confirmations pending: \(count)", "交換確認の送信待ち：\(count)") }
    static var encounterLocalOnly: String { tr("仅保存到本机，无法向对方回传资料。", "僅儲存到本機，無法向對方回傳資料。", "僅儲存到本機，無法向對方回傳資料。", "Saved on this device only; your profile cannot be sent back.", "この端末にのみ保存され、相手にプロフィールは送信されません。") }
    static var encounterInfo: String { tr("记录信息", "記錄資料", "紀錄資訊", "Encounter Info", "記録情報") }
    static var metAt: String { tr("认识时间", "認識時間", "認識時間", "Met At", "会った日時") }
    static var note: String { tr("备注", "備註", "備註", "Note", "メモ") }
    static var tags: String { tr("标签", "標籤", "標籤", "Tags", "タグ") }
    static var tagInputHint: String { tr("搜索或自定义 tag，或从右侧列表选择 →", "搜尋或自訂 tag，或從右側清單選擇 →", "搜尋或自訂 tag，或從右側清單選擇 →", "Search or create a tag, or choose from the list →", "タグを検索・作成、または右の一覧から選択 →") }
    static var tagColors: String { tr("标签颜色", "標籤顏色", "標籤顏色", "Tag Colors", "タグの色") }
    static var tagColor: String { tr("颜色", "顏色", "顏色", "Color", "色") }
    static var tagColorMixed: String { tr("拼色", "拼色", "拼色", "Mixed", "多色") }
    static var tagColorCustom: String { tr("自定义", "自訂", "自訂", "Custom", "カスタム") }
    static var tagTextWeight: String { tr("标签字重", "標籤字重", "標籤字重", "Tag font weight", "タグの文字の太さ") }
    static var tagWeightRegular: String { tr("常规", "一般", "一般", "Regular", "標準") }
    static var tagWeightMedium: String { tr("半粗", "半粗", "半粗", "Semibold", "セミボールド") }
    static var tagWeightBold: String { tr("特粗", "特粗", "特粗", "Heavy", "極太") }
    static var tagColorSolid: String { tr("纯色", "純色", "純色", "Solid", "単色") }
    static var tagColorPresetLocked: String { tr("已使用内置颜色", "已使用內建顏色", "已使用內建顏色", "Using preset color", "プリセット色を使用中") }
    static var addColor: String { tr("增加颜色", "增加顏色", "新增顏色", "Add Color", "色を追加") }
    static var removeColor: String { tr("移除颜色", "移除顏色", "移除顏色", "Remove Color", "色を削除") }
    static var cardTagsHint: String { tr("输入后按回车添加，最多 10 个；会显示在通行证背面。", "輸入後按 Return 加入，最多 10 個；會顯示在通行證背面。", "輸入後按 Return 新增，最多 10 個；會顯示在通行證背面。", "Press Return to add. Up to 10 tags, shown on the pass back.", "入力後Returnで追加。最大10個、パス裏面に表示します。") }
    static var tagCatalogLoading: String { tr("正在载入 Tag 库", "正在載入 Tag 庫", "正在載入 Tag 庫", "Loading Tag library", "Tagライブラリを読み込み中") }
    static var tagCatalogRetry: String { tr("Tag 库载入失败，点按重试", "Tag 庫載入失敗，點按重試", "Tag 庫載入失敗，點按重試", "Tag library unavailable. Tap to retry.", "Tagライブラリを読み込めません。タップして再試行") }
    static var tagCatalogSource: String { tr("App 内置库", "App 內建庫", "App 內建庫", "Bundled library", "アプリ内蔵ライブラリ") }
    static var tagCatalogRemote: String { tr("线上 Tag 库", "線上 Tag 庫", "線上 Tag 庫", "Online library", "オンラインライブラリ") }
    static var tagCatalogCache: String { tr("线上库缓存", "線上庫快取", "線上庫快取", "Cached online library", "オンラインライブラリのキャッシュ") }
    static var tagCatalogMaintenance: String { tr("线上库维护中，暂用本地数据", "線上庫維護中，暫用本機資料", "線上庫維護中，暫用本機資料", "Online library under maintenance; using local data", "オンラインライブラリはメンテナンス中のため、端末内のデータを使用しています") }
    static var tagCatalogFallback: String { tr("线上库暂时无法连接，已保留本地数据", "暫時無法連接線上庫，已保留本機資料", "暫時無法連線至線上庫，已保留本機資料", "Online library unavailable; local data retained", "オンラインライブラリに接続できないため、端末内のデータを保持しています") }
    static var tagCatalogRefresh: String { tr("刷新 Tag 库", "重新整理 Tag 庫", "重新整理 Tag 庫", "Refresh library", "ライブラリを更新") }
    static var tagMoveUp: String { tr("上移", "上移", "上移", "Move up", "上へ") }
    static var tagMoveDown: String { tr("下移", "下移", "下移", "Move down", "下へ") }
    static var tagCatalogInfo: String { tr("Tag 库信息", "Tag 庫資訊", "Tag 庫資訊", "Library information", "ライブラリ情報") }
    static var tagCatalogChanges: String { tr("变更日志", "變更日誌", "更新記錄", "Changelog", "更新履歴") }
    static var tagCatalogNoChanges: String { tr("此版本未附带变更记录", "此版本未附帶變更記錄", "此版本未附帶更新記錄", "No changelog included in this version", "このバージョンに更新履歴はありません") }
    static var tagOrder: String { tr("Tag 排序", "Tag 排序", "Tag 排序", "Reorder tags", "Tagの並べ替え") }
    static var tagRecent: String { tr("最近", "最近", "最近", "Recent", "最近") }
    static var tagFrequent: String { tr("常用", "常用", "常用", "Frequent", "よく使う") }
    static var tagAll: String { tr("全部", "全部", "全部", "All", "すべて") }
    static var tagHistoryEmpty: String { tr("暂无使用记录", "暫無使用記錄", "尚無使用記錄", "No usage history yet", "使用履歴はまだありません") }
    static var tagClearHistory: String { tr("清空使用记录", "清空使用記錄", "清除使用記錄", "Clear usage history", "使用履歴を消去") }
    static var tagSource: String { tr("来源", "來源", "來源", "Source", "提供元") }
    static var tagLibrary: String { tr("Tag 库", "Tag 庫", "Tag 庫", "Tag Library", "Tagライブラリ") }
    static var browseTagLibrary: String { tr("浏览 Tag 库", "瀏覽 Tag 庫", "瀏覽 Tag 庫", "Browse Tag Library", "Tagライブラリを見る") }
    static var searchTags: String { tr("搜索所有 IP 和 Tag", "搜尋所有 IP 和 Tag", "搜尋所有 IP 和 Tag", "Search all IPs and tags", "作品・Tagを検索") }
    static var browseByIP: String { tr("按 IP 浏览", "按 IP 瀏覽", "依 IP 瀏覽", "Browse by IP", "作品別に見る") }
    static func tagsAvailable(_ count: Int) -> String { tr("\(count) 个 Tag", "\(count) 個 Tag", "\(count) 個 Tag", "\(count) tags", "\(count)件のTag") }
    static var noTagResults: String { tr("没有找到 Tag", "找不到 Tag", "找不到 Tag", "No Tags Found", "Tagが見つかりません") }
    static var followStatus: String { tr("互关状态 / 返图进度", "互關狀態 / 返圖進度", "互關狀態 / 返圖進度", "Follow / photo status", "フォロー・返礼状況") }
    static var needsPhotoReturn: String { tr("需要返图", "需要返圖", "需要返圖", "Needs photo return", "写真返却が必要") }
    static var exchangedFreebie: String { tr("交换过无料", "交換過無料", "交換過無料配布", "Freebie exchanged", "無配交換済み") }
    static var notMeQRProfileCode: String { tr("这不是有效的 MeQR 交换码。", "這不是有效的 MeQR 交換碼。", "這不是有效的 MeQR 交換碼。", "This is not a valid MeQR profile code.", "有効なMeQR交換コードではありません。") }
    static var photoPermissionNeeded: String { tr("需要相册权限才能保存图片。", "需要相簿權限才能儲存圖片。", "需要照片權限才能儲存圖片。", "Photo permission is needed to save the image.", "画像を保存するには写真へのアクセスが必要です。") }
    static var cameraPermissionNeeded: String { tr("需要相机权限才能扫描 MeQR 交换码。", "需要相機權限才能掃描 MeQR 交換碼。", "需要相機權限才能掃描 MeQR 交換碼。", "Camera permission is needed to scan MeQR codes.", "MeQRコードをスキャンするにはカメラへのアクセスが必要です。") }
    static var couldNotSave: String { tr("无法保存", "無法儲存", "無法儲存", "Could Not Save", "保存できません") }
    static var tryAgain: String { tr("无法保存，请重试。", "無法儲存，請再試一次。", "無法儲存，請再試一次。", "Please try again.", "もう一度お試しください。") }
    static var enterCardName: String { tr("请输入卡片名称。", "請輸入卡片名稱。", "請輸入卡片名稱。", "Please enter a card name.", "カード名を入力してください。") }
    static var enterQRContent: String { tr("请输入二维码内容。", "請輸入 QR Code 內容。", "請輸入 QR Code 內容。", "Please enter the QR code content.", "QRコードの内容を入力してください。") }
    static func saveFailedWithReason(_ reason: String) -> String { tr("保存失败：\(reason)", "儲存失敗：\(reason)", "儲存失敗：\(reason)", "Save failed: \(reason)", "保存に失敗しました：\(reason)") }
    static func exchangeIntroUsage(_ count: String) -> String { tr("\(count) / 25 汉字", "\(count) / 25 漢字", "\(count) / 25 漢字", "\(count) / 25 CJK characters", "\(count) / 25 文字") }
    static var previewSampleTags: [String] {
        switch AppSettings.shared.resolvedLanguage {
        case .system, .en:
            return ["Hatsune Miku", "Convention", "Photography"]
        case .zhHans:
            return ["初音未来", "漫展", "摄影"]
        case .zhHantHK:
            return ["初音未來", "漫展", "攝影"]
        case .zhHantTW:
            return ["初音未來", "漫展", "攝影"]
        case .ja:
            return ["初音ミク", "即売会", "写真"]
        }
    }
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
    static var website: String { tr("跳转官网", "前往官網", "前往官網", "Open Website", "公式サイトを開く") }
    static var websiteFooter: String { tr("点击上面的按钮可以前往 MeQR 官网。", "點擊上面的按鈕可以前往 MeQR 官網。", "點擊上面的按鈕可以前往 MeQR 官網。", "Tap the button above to open the MeQR website.", "上のボタンからMeQR公式サイトを開けます。") }
    static var privacyFooter: String { tr("这个链接会跳到官网的隐私政策页面。", "這個連結會跳到官網的私隱政策頁面。", "這個連結會開啟官網的隱私權政策頁面。", "This link opens the privacy policy on the MeQR website.", "このリンクはMeQR公式サイトのプライバシーポリシーを開きます。") }
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

    // Legal & Sync — shared
    static var legalImportantUpdate: String { tr("重要更新", "重要更新", "重要更新", "Important Update", "重要なお知らせ") }
    static var legalReadAndAgree: String { tr("我已阅读并同意", "我已閱讀並同意", "我已閱讀並同意", "I have read and agree", "内容を確認し、同意します") }

    // 启动守则弹窗（用户使用守则）
    static var termsUpdateTitle: String { tr("我们更新了「用户使用守则」", "我們更新了「用戶使用守則」", "我們更新了「使用者守則」", "We've updated our Terms of Use", "利用規約を更新しました") }
    static var termsUpdateBody: String { tr("请阅读更新后的使用守则。多设备同步需你主动开启，开启后所选卡片资料和图片会上传到同步服务器。", "請閱讀更新後的使用守則。多設備同步需你主動開啟，開啟後所選卡片資料和圖片會上傳到同步伺服器。", "請閱讀更新後的使用者守則。多裝置同步需你主動開啟，開啟後所選卡片資料和圖片會上傳到同步伺服器。", "Please review the updated Terms of Use. Multi-device sync is opt-in; once enabled, the selected card data and images are uploaded to the sync server.", "更新後の利用規約をご確認ください。複数端末同期は任意で、有効にすると選択したカードのデータと画像が同期サーバーにアップロードされます。") }
    static var termsViewFull: String { tr("查看完整的用户使用守则", "查看完整的用戶使用守則", "查看完整的使用者守則", "View the full Terms of Use", "利用規約の全文を見る") }

    // 同步页隐私弹窗（隐私政策）
    static var privacySyncTitle: String { tr("多设备同步与隐私政策", "多設備同步與私隱政策", "多裝置同步與隱私權政策", "Multi-Device Sync & Privacy Policy", "複数端末同期とプライバシーポリシー") }
    static var privacySyncBody: String { tr("开启同步前请阅读隐私政策。同步会把你所选卡片和图片上传到 MeQR 服务器，传输使用 HTTPS，但不是端到端加密。", "開啟同步前請閱讀私隱政策。同步會把你所選卡片和圖片上傳到 MeQR 伺服器，傳輸使用 HTTPS，但不是端到端加密。", "開啟同步前請閱讀隱私權政策。同步會把你所選卡片和圖片上傳到 MeQR 伺服器，傳輸使用 HTTPS，但不是端對端加密。", "Please review the Privacy Policy before enabling sync. Syncing uploads your selected card and images to the MeQR server over HTTPS, but it is not end-to-end encrypted.", "同期を有効にする前にプライバシーポリシーをご確認ください。同期は選択したカードと画像をMeQRサーバーにアップロードします。通信はHTTPSですが、エンドツーエンド暗号化ではありません。") }
    static var privacyViewFull: String { tr("查看完整的隐私政策", "查看完整的私隱政策", "查看完整的隱私權政策", "View the full Privacy Policy", "プライバシーポリシーの全文を見る") }

    // 多设备同步主界面
    static var syncTitle: String { tr("多设备同步", "多設備同步", "多裝置同步", "Multi-Device Sync", "複数端末同期") }
    static var syncIntro1: String { tr("在多台手机上使用同一张卡片，包含二维码、Tag、头像、背景和头图。修改后请在本机点“立即同步”，再到另一台手机点一次。", "在多台手機上使用同一張卡片，包含 QR Code、Tag、頭像、背景和頭圖。修改後請在本機點「立即同步」，再到另一台手機點一次。", "在多台手機上使用同一張卡片，包含 QR Code、Tag、頭像、背景和頭圖。修改後請在本機點「立即同步」，再到另一台手機點一次。", "Use the same card on multiple phones, including QR codes, tags, avatar, background, and banner. After editing, tap “Sync Now” here, then tap it again on the other phone.", "複数のスマートフォンで同じカード（QRコード、タグ、アイコン、背景、ヘッダー）を利用できます。編集後はこの端末で「今すぐ同期」をタップし、もう一方の端末でもう一度タップしてください。") }
    static var syncIntro2: String { tr("开启后，所选卡片和图片会存储在 MeQR 服务器。绑定码与公开交换码分开；只有经主设备确认的手机才能同步。每张卡片最多五台设备。", "開啟後，所選卡片和圖片會儲存在 MeQR 伺服器。綁定碼與公開交換碼分開；只有經主設備確認的手機才能同步。每張卡片最多五台設備。", "開啟後，所選卡片和圖片會儲存在 MeQR 伺服器。綁定碼與公開交換碼分開；只有經主裝置確認的手機才能同步。每張卡片最多五台裝置。", "Once enabled, the selected card and images are stored on the MeQR server. Binding codes are separate from public exchange codes; only phones approved by the owner device can sync. Each card supports up to five devices.", "有効にすると、選択したカードと画像がMeQRサーバーに保存されます。バインドコードは公開交換コードとは別で、所有者端末が承認したスマートフォンのみが同期できます。1枚のカードにつき最大5台までです。") }
    static var syncIntro3: String { tr("同步传输使用 HTTPS，但不是端到端加密；服务器会保存可读取的资料。请只上传你愿意存入云端的内容。", "同步傳輸使用 HTTPS，但不是端到端加密；伺服器會保存可讀取的資料。請只上傳你願意存入雲端的內容。", "同步傳輸使用 HTTPS，但不是端對端加密；伺服器會保存可讀取的資料。請只上傳你願意存入雲端的內容。", "Sync transfers use HTTPS but are not end-to-end encrypted; the server stores readable data. Only upload content you are comfortable storing in the cloud.", "同期はHTTPSを使用しますがエンドツーエンド暗号化ではありません。サーバーは読み取り可能なデータを保存します。クラウドに保存してもよい内容だけをアップロードしてください。") }
    static var syncLocalCards: String { tr("本机卡片", "本機卡片", "本機卡片", "Cards on This Device", "この端末のカード") }
    static var syncSelectCard: String { tr("选择卡片", "選擇卡片", "選擇卡片", "Select Card", "カードを選択") }
    static var syncSelectPlaceholder: String { tr("请选择", "請選擇", "請選擇", "Select", "選択してください") }
    static var syncRoleOwner: String { tr("主设备", "主設備", "主裝置", "Owner", "所有者端末") }
    static var syncRoleBound: String { tr("已绑定", "已綁定", "已綁定", "Bound", "バインド済み") }
    static var syncCloudVersion: String { tr("云端版本", "雲端版本", "雲端版本", "Cloud Version", "クラウドバージョン") }
    static var syncNow: String { tr("立即同步", "立即同步", "立即同步", "Sync Now", "今すぐ同期") }
    static var syncRefreshDevices: String { tr("刷新设备列表", "重新整理設備列表", "重新整理裝置列表", "Refresh Devices", "端末一覧を更新") }
    static var syncGenerateCode: String { tr("生成绑定码（10 分钟有效）", "生成綁定碼（10 分鐘有效）", "生成綁定碼（10 分鐘有效）", "Generate Binding Code (valid 10 min)", "バインドコードを生成（10分間有効）") }
    static var syncCopyCode: String { tr("复制绑定码", "複製綁定碼", "複製綁定碼", "Copy Binding Code", "バインドコードをコピー") }
    static var syncCopied: String { tr("已复制，请交给你自己的另一台手机", "已複製，請交給你自己的另一台手機", "已複製，請交給你自己的另一台手機", "Copied. Send it to your other phone.", "コピーしました。もう一方の端末で入力してください。") }
    static var syncStopOwner: String { tr("删除云端资料并停止同步", "刪除雲端資料並停止同步", "刪除雲端資料並停止同步", "Delete Cloud Data & Stop Sync", "クラウドデータを削除して同期を停止") }
    static var syncUnbind: String { tr("解除本机绑定", "解除本機綁定", "解除本機綁定", "Unbind This Device", "この端末のバインドを解除") }
    static var syncClearCredential: String { tr("清除本机同步凭证", "清除本機同步憑證", "清除本機同步憑證", "Clear Local Sync Credential", "この端末の同期資格情報を消去") }
    static var syncEnable: String { tr("将此卡片开启云端同步", "將此卡片開啟雲端同步", "將此卡片開啟雲端同步", "Enable Cloud Sync for This Card", "このカードのクラウド同期を有効にする") }
    static var syncBoundDevices: String { tr("已绑定设备", "已綁定設備", "已綁定裝置", "Bound Devices", "バインド済み端末") }
    static var syncThisDevice: String { tr("（本机）", "（本機）", "（本機）", "(this device)", "（この端末）") }
    static var syncRemove: String { tr("移除", "移除", "移除", "Remove", "削除") }
    static var syncPendingDevices: String { tr("待确认设备 · 请核对设备名称", "待確認設備 · 請核對設備名稱", "待確認裝置 · 請核對裝置名稱", "Pending Devices · Verify the device name", "承認待ちの端末 · 端末名を確認してください") }
    static func syncAllow(_ name: String) -> String { tr("允许 \(name) 加入", "允許 \(name) 加入", "允許 \(name) 加入", "Allow \(name) to Join", "\(name) の参加を許可") }
    static var syncAllowed: String { tr("已允许，请在新手机上检查确认结果", "已允許，請在新手機上檢查確認結果", "已允許，請在新手機上檢查確認結果", "Approved. Check the result on the new phone.", "承認しました。新しい端末で結果を確認してください。") }
    static var syncJoinSection: String { tr("从另一台手机加入", "從另一台手機加入", "從另一台手機加入", "Join from Another Phone", "別の端末から参加") }
    static var syncJoinPlaceholder: String { "XXXX-XXXX-XXXX-XXXX" }
    static var syncApplyJoin: String { tr("申请加入", "申請加入", "申請加入", "Request to Join", "参加を申請") }
    static var syncCheckJoin: String { tr("检查主设备确认结果", "檢查主設備確認結果", "檢查主裝置確認結果", "Check Approval Result", "所有者端末の承認結果を確認") }
    static var syncCancelJoin: String { tr("取消本机申请", "取消本機申請", "取消本機申請", "Cancel This Request", "この端末の申請をキャンセル") }
    static var syncJoinHint: String { tr("加入会新增一张卡片，不覆盖本机已有卡片。申请后，请在主设备刷新设备列表并确认。取消本机申请不会撤销已获确认的设备，请由主设备移除。", "加入會新增一張卡片，不覆蓋本機已有卡片。申請後，請在主設備重新整理設備列表並確認。取消本機申請不會撤銷已獲確認的設備，請由主設備移除。", "加入會新增一張卡片，不覆蓋本機已有卡片。申請後，請在主裝置重新整理裝置列表並確認。取消本機申請不會撤銷已獲確認的裝置，請由主裝置移除。", "Joining adds a new card without overwriting existing cards. After requesting, refresh the device list on the owner device to approve. Canceling your request does not revoke an already-approved device; remove it from the owner device instead.", "参加すると新しいカードが追加され、既存のカードは上書きされません。申請後は所有者端末で端末一覧を更新して承認してください。申請のキャンセルは承認済み端末を取り消しません。所有者端末から削除してください。") }
    static var syncSyncing: String { tr("正在同步…", "正在同步…", "正在同步…", "Syncing…", "同期中…") }
    static var syncDone: String { tr("同步完成", "同步完成", "同步完成", "Sync Complete", "同期が完了しました") }
    static var syncEnabled: String { tr("已开启同步，可以生成绑定码了", "已開啟同步，可以生成綁定碼了", "已開啟同步，可以生成綁定碼了", "Sync enabled. You can now generate a binding code.", "同期を有効にしました。バインドコードを生成できます。") }
    static var syncWaitingOwner: String { tr("等待主设备确认。请在主设备刷新设备列表。", "等待主設備確認。請在主設備重新整理設備列表。", "等待主裝置確認。請在主裝置重新整理裝置列表。", "Waiting for owner approval. Refresh the device list on the owner device.", "所有者端末の承認待ちです。所有者端末で端末一覧を更新してください。") }
    static var syncJoined: String { tr("已加入，卡片和图片已下载", "已加入，卡片和圖片已下載", "已加入，卡片和圖片已下載", "Joined. Card and images downloaded.", "参加しました。カードと画像をダウンロードしました。") }
    static var syncStopped: String { tr("已停止同步，本机卡片已保留", "已停止同步，本機卡片已保留", "已停止同步，本機卡片已保留", "Sync stopped. Cards on this device are kept.", "同期を停止しました。この端末のカードは保持されています。") }
    static var syncStoppedLocal: String { tr("本机已停止同步", "本機已停止同步", "本機已停止同步", "Sync stopped on this device", "この端末の同期を停止しました") }

    // 同步冲突/确认弹窗
    static var syncConflictTitle: String { tr("两台设备都有修改", "兩台設備都有修改", "兩台裝置都有修改", "Both Devices Have Changes", "両方の端末で変更があります") }
    static var syncConflictLocal: String { tr("用本机版本更新云端", "用本機版本更新雲端", "用本機版本更新雲端", "Keep Local & Update Cloud", "ローカルを保持してクラウドを更新") }
    static var syncConflictRemote: String { tr("使用云端版本覆盖本机", "使用雲端版本覆蓋本機", "使用雲端版本覆蓋本機", "Use Cloud & Overwrite Local", "クラウドを使用してローカルを上書き") }
    static var syncConflictLater: String { tr("暂不处理", "暫不處理", "暫不處理", "Not Now", "後で") }
    static var syncConflictMessage: String { tr("被覆盖的修改不会合并。需要保留两份时，请先备份本机卡片。", "被覆蓋的修改不會合併。需要保留兩份時，請先備份本機卡片。", "被覆蓋的修改不會合併。需要保留兩份時，請先備份本機卡片。", "Overwritten changes are not merged. If you need to keep both, back up the local card first.", "上書きされる変更は統合されません。両方を残す必要がある場合は、先にローカルのカードをバックアップしてください。") }
    static var syncDisconnectTitle: String { tr("停止同步？", "停止同步？", "停止同步？", "Stop Sync?", "同期を停止しますか？") }
    static var syncDisconnectOwner: String { tr("删除云端资料", "刪除雲端資料", "刪除雲端資料", "Delete Cloud Data", "クラウドデータを削除") }
    static var syncDisconnectMember: String { tr("解除绑定", "解除綁定", "解除綁定", "Unbind", "バインド解除") }
    static var syncDisconnectMessage: String { tr("本机卡片会保留。删除云端资料后，所有设备都将停止同步；其他手机已经下载的副本仍会保留。", "本機卡片會保留。刪除雲端資料後，所有設備都將停止同步；其他手機已經下載的副本仍會保留。", "本機卡片會保留。刪除雲端資料後，所有裝置都將停止同步；其他手機已經下載的副本仍會保留。", "Cards on this device are kept. Deleting cloud data stops sync for all devices; copies already downloaded on other phones remain.", "この端末のカードは保持されます。クラウドデータを削除すると全端末の同期が停止します。他の端末にダウンロード済みのコピーは残ります。") }
    static var syncClearTitle: String { tr("清除本机凭证？", "清除本機憑證？", "清除本機憑證？", "Clear Local Credential?", "この端末の資格情報を消去しますか？") }
    static var syncClearAction: String { tr("清除凭证", "清除憑證", "清除憑證", "Clear Credential", "資格情報を消去") }
    static var syncClearMessage: String { tr("此操作不删除云端资料，不撤销其他设备。主设备清除凭证后会失去云端管理权限，请优先使用上方的停止同步。", "此操作不刪除雲端資料，不撤銷其他設備。主設備清除憑證後會失去雲端管理權限，請優先使用上方的停止同步。", "此操作不刪除雲端資料，不撤銷其他裝置。主裝置清除憑證後會失去雲端管理權限，請優先使用上方的停止同步。", "This does not delete cloud data or revoke other devices. Clearing the owner credential removes cloud management access; prefer “Stop Sync” above.", "この操作はクラウドデータを削除せず、他の端末も取り消しません。所有者端末で資格情報を消去するとクラウド管理権限を失います。上記の「同期を停止」を優先してください。") }

    // 同步错误串
    static var syncErrToken: String { tr("无法生成设备凭证", "無法生成設備憑證", "無法生成裝置憑證", "Could not generate a device credential.", "端末の資格情報を生成できませんでした。") }
    static var syncErrReadCredential: String { tr("无法读取同步凭证，请解锁手机后重试", "無法讀取同步憑證，請解鎖手機後重試", "無法讀取同步憑證，請解鎖手機後重試", "Could not read the sync credential. Unlock your phone and retry.", "同期資格情報を読み取れません。端末のロックを解除して再試行してください。") }
    static var syncErrSaveCredential: String { tr("无法保存同步凭证", "無法儲存同步憑證", "無法儲存同步憑證", "Could not save the sync credential.", "同期資格情報を保存できませんでした。") }
    static var syncErrUpdateCredential: String { tr("无法更新同步凭证", "無法更新同步憑證", "無法更新同步憑證", "Could not update the sync credential.", "同期資格情報を更新できませんでした。") }
    static func syncErrUnavailable(_ code: Int) -> String { tr("同步服务暂时不可用（\(code)）", "同步服務暫時不可用（\(code)）", "同步服務暫時不可用（\(code)）", "Sync service unavailable (\(code)).", "同期サービスは現在利用できません（\(code)）。") }
    static var syncErrResponseLarge: String { tr("同步响应过大", "同步回應過大", "同步回應過大", "Sync response too large.", "同期レスポンスが大きすぎます。") }
    static func syncErrImageRead(_ kind: String) -> String {
        let zhHans = kind == "avatar" ? "头像" : kind == "background" ? "背景" : "头图"
        let zhHantHK = kind == "avatar" ? "頭像" : kind == "background" ? "背景" : "頭圖"
        let zhHantTW = kind == "avatar" ? "頭像" : kind == "background" ? "背景" : "橫幅"
        let en = kind == "avatar" ? "avatar" : kind == "background" ? "background" : "banner"
        let ja = kind == "avatar" ? "プロフィール" : kind == "background" ? "背景" : "バナー"
        return tr("无法读取\(zhHans)图片", "無法讀取\(zhHantHK)圖片", "無法讀取\(zhHantTW)圖片", "Could not read the \(en) image.", "\(ja)画像を読み取れませんでした。")
    }
    static var syncErrInvalidRequest: String { tr("同步请求无效，请检查资料后重试", "同步請求無效，請檢查資料後重試", "同步請求無效，請檢查資料後重試", "The sync request is invalid. Check the card data and try again.", "同期リクエストが無効です。カードの内容を確認して再試行してください。") }
    static var syncErrAuthorization: String { tr("同步授权已失效，请重新绑定设备", "同步授權已失效，請重新綁定裝置", "同步授權已失效，請重新綁定裝置", "Sync authorization has expired. Bind this device again.", "同期の認証が無効です。この端末をもう一度バインドしてください。") }
    static var syncErrNotFound: String { tr("同步资料不存在，请重新绑定", "同步資料不存在，請重新綁定", "同步資料不存在，請重新綁定", "The synced data was not found. Bind this device again.", "同期データが見つかりません。もう一度バインドしてください。") }
    static var syncErrJoinExpired: String { tr("绑定申请已失效，请重新申请", "綁定申請已失效，請重新申請", "綁定申請已失效，請重新申請", "The binding request expired. Request access again.", "バインド申請の期限が切れています。もう一度申請してください。") }
    static var syncErrImageLarge: String { tr("图片过大，请先调整图片", "圖片過大，請先調整圖片", "圖片過大，請先調整圖片", "Image too large. Resize it first.", "画像が大きすぎます。先にサイズを調整してください。") }
    static var syncErrUploadVerify: String { tr("上传图片校验失败", "上傳圖片校驗失敗", "上傳圖片校驗失敗", "Image upload verification failed.", "画像アップロードの検証に失敗しました。") }
    static var syncErrFormatUnsupported: String { tr("同步资料格式不支持", "同步資料格式不支援", "同步資料格式不支援", "Unsupported sync data format.", "同期データの形式がサポートされていません。") }
    static var syncErrImageVerify: String { tr("图片校验失败，未修改本地资料", "圖片校驗失敗，未修改本地資料", "圖片校驗失敗，未修改本地資料", "Image verification failed; local data unchanged.", "画像の検証に失敗しました。ローカルデータは変更されていません。") }
    static var syncErrConflict: String { tr("两台设备都修改了资料。请选择保留本机版本或使用云端版本；使用云端前可先复制本地卡片。", "兩台設備都修改了資料。請選擇保留本機版本或使用雲端版本；使用雲端前可先複製本地卡片。", "兩台裝置都修改了資料。請選擇保留本機版本或使用雲端版本；使用雲端前可先複製本地卡片。", "Both devices changed the data. Choose to keep the local version or use the cloud version; copy the local card before using the cloud version.", "両方の端末でデータが変更されています。ローカル版を保持するかクラウド版を使用するかを選択してください。クラウド版を使用する前にローカルのカードをコピーしてください。") }
    static var syncErrDeviceIncomplete: String { tr("同步服务返回的设备信息不完整", "同步服務返回的設備資訊不完整", "同步服務返回的裝置資訊不完整", "The sync service returned incomplete device information.", "同期サービスが返した端末情報が不完全です。") }
    static var syncErrInvalidCode: String { tr("请输入 XXXX-XXXX-XXXX-XXXX 格式的绑定码", "請輸入 XXXX-XXXX-XXXX-XXXX 格式的綁定碼", "請輸入 XXXX-XXXX-XXXX-XXXX 格式的綁定碼", "Enter a binding code in XXXX-XXXX-XXXX-XXXX format.", "XXXX-XXXX-XXXX-XXXX 形式のバインドコードを入力してください。") }
    static var syncErrJoinCorrupt: String { tr("本机加入信息已损坏，请重新申请", "本機加入資訊已損壞，請重新申請", "本機加入資訊已損壞，請重新申請", "This device's join data is corrupted. Request again.", "この端末の参加情報が破損しています。再度申請してください。") }

    // 同步撤销 alert
    static var syncRevokedTitle: String { tr("同步已被主设备移除", "同步已被主設備移除", "同步已被主裝置移除", "Sync Removed by Owner", "所有者端末により同期が解除されました") }
    static var syncRevokedMessage: String { tr("主设备已取消本机的同步权限，本机上对应的同步卡片已自动删除。", "主設備已取消本機的同步權限，本機上對應的同步卡片已自動刪除。", "主裝置已取消本機的同步權限，本機上對應的同步卡片已自動刪除。", "The owner device revoked this device's sync access. The corresponding synced cards on this device were removed.", "所有者端末がこの端末の同期権限を取り消しました。この端末上の対応する同期カードは削除されました。") }

    // 删除同步卡片保护（MainView）
    static var deleteStopSyncFirst: String { tr("请先在“更多设置 → 多设备同步”中停止此卡片的同步，再删除本机卡片。", "請先在「更多設定 → 多設備同步」中停止此卡片的同步，再刪除本機卡片。", "請先在「更多設定 → 多裝置同步」中停止此卡片的同步，再刪除本機卡片。", "Stop sync for this card in “More Settings → Multi-Device Sync” before deleting it.", "このカードを削除する前に、「その他の設定 → 複数端末同期」で同期を停止してください。") }

    // 引导页快捷入口
    static var onboardingSyncEntry: String { tr("使用同步码，从另一台手机快速开始", "使用同步碼，從另一台手機快速開始", "使用同步碼，從另一台手機快速開始", "Start quickly from another phone with a sync code", "同期コードを使って別の端末からすばやく始める") }
}
