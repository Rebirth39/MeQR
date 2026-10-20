package com.lucasli.meqr;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.LocaleList;

import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

final class I18n {
    static final String SYSTEM = "system";
    static final String ZH_HANS = "zh-Hans";
    static final String ZH_HANT_HK = "zh-Hant-HK";
    static final String ZH_HANT_TW = "zh-Hant-TW";
    static final String EN = "en";
    static final String JA = "ja";

    private final SharedPreferences preferences;
    private final Map<String, String[]> values = new HashMap<>();

    I18n(Context context) {
        preferences = context.getSharedPreferences("settings", Context.MODE_PRIVATE);
        put("appName", "喜劳转扩", "喜勞轉擴", "喜勞轉擴", "MeQR", "MeQR");
        put("add", "添加", "加入", "新增", "Add", "追加");
        put("cardCount", "%d 张卡片", "%d 張卡片", "%d 張卡片", "%d Cards", "カード %d 枚");
        put("edit", "编辑", "編輯", "編輯", "Edit", "編集");
        put("delete", "删除", "刪除", "刪除", "Delete", "削除");
        put("cancel", "取消", "取消", "取消", "Cancel", "キャンセル");
        put("discardDraft", "放弃未保存的修改？", "放棄未儲存的修改？", "放棄未儲存的修改？", "Discard unsaved changes?", "未保存の変更を破棄しますか？");
        put("cardList", "卡片列表", "卡片列表", "卡片列表", "Card List", "カード一覧");
        put("qrReviewTitle", "打开二维码链接？", "開啟 QR Code 連結？", "開啟 QR Code 連結？", "Open QR Link?", "QRリンクを開きますか？");
        put("qrReviewWarning", "请核对下方完整内容和域名，确认来源可信后再打开。", "請核對下方完整內容及網域，確認來源可信後再開啟。", "請核對下方完整內容及網域，確認來源可信後再開啟。", "Check the full content and domain below. Open only if you trust the source.", "内容とドメインを確認し、信頼できる場合のみ開いてください。");
        put("qrFormatWarning", "内容与所选平台的常用链接格式不符。请核对，仍可保留原始内容。", "內容與所選平台的常用連結格式不符。請核對，仍可保留原始內容。", "內容與所選平台的常用連結格式不符。請核對，仍可保留原始內容。", "This does not match the platform's usual link format. Check it; original content can still be saved.", "選択したプラットフォームの一般的なリンク形式と異なります。元の内容は保存できます。");
        put("qrDestinationWarning", "此链接使用未加密连接或 IP 地址，请核对目的地。", "此連結使用未加密連線或 IP 位址，請核對目的地。", "此連結使用未加密連線或 IP 位址，請核對目的地。", "This link uses an unencrypted connection or an IP address. Check the destination.", "暗号化されていない接続またはIPアドレスです。接続先を確認してください。");
        put("qrOfficialImportHint", "QQ / 微信请优先导入 App 内的官方个人二维码；账号数字不等于加好友链接。", "QQ / 微信請優先匯入 App 內的官方個人 QR Code；帳號數字不等於加好友連結。", "QQ / 微信請優先匯入 App 內的官方個人 QR Code；帳號數字不等於加好友連結。", "For QQ / WeChat, import the official personal QR code. An account number is not an add-friend link.", "QQ / WeChatは公式アプリの個人QRコードを読み込んでください。アカウント番号は友だち追加リンクではありません。");
        put("tagReport", "上报 Tag 问题", "回報 Tag 問題", "回報 Tag 問題", "Report Tag Issue", "タグの問題を報告");
        put("tagReportName", "名称或翻译", "名稱或翻譯", "名稱或翻譯", "Name or Translation", "名前・翻訳");
        put("tagReportColor", "配色错误", "配色錯誤", "配色錯誤", "Incorrect Colors", "配色の誤り");
        put("tagReportDuplicate", "重复 Tag", "重複 Tag", "重複 Tag", "Duplicate Tag", "タグの重複");
        put("tagReportOther", "其他问题", "其他問題", "其他問題", "Other Issue", "その他");
        put("tagReportDescription", "问题描述", "問題描述", "問題描述", "Description", "問題の詳細");
        put("tagReportContact", "联系方式（选填）", "聯絡方式（選填）", "聯絡方式（選填）", "Contact (Optional)", "連絡先（任意）");
        put("tagReportIncludeSupportCode", "同时发送支持码", "同時傳送支持碼", "同時傳送支援碼", "Include support code", "サポートコードも送信");
        put("tagReportIncludeSupportCodeHint", "选择“是”后会自动获取支持码并绑定本次工单；关闭后不会发送设备标识或支持码。", "選擇「是」後會自動取得支持碼並綁定本次工單；關閉後不會傳送裝置識別碼或支持碼。", "選擇「是」後會自動取得支援碼並綁定本次工單；關閉後不會傳送裝置識別碼或支援碼。", "When enabled, the app fetches a support code and binds this ticket. When disabled, no device ID or support code is sent.", "オンにするとサポートコードを取得してこのチケットに紐付けます。オフの場合、デバイスIDとコードは送信しません。");
        put("tagReportSubmit", "提交", "提交", "送出", "Submit", "送信");
        put("tagReportSent", "已提交", "已提交", "已送出", "Submitted", "送信済み");
        put("tagReportFailed", "未能确认提交结果，请重试。当前内容已保留。", "未能確認提交結果，請重試。目前內容已保留。", "未能確認送出結果，請重試。目前內容已保留。", "Could not confirm submission. Your text is retained; please retry.", "送信結果を確認できませんでした。入力内容は保持されています。再試行してください。");
        put("tagReportLimited", "提交过于频繁，请稍后重试。", "提交過於頻繁，請稍後重試。", "送出過於頻繁，請稍後重試。", "Too many submissions. Please try again later.", "送信回数が多すぎます。しばらくしてから再試行してください。");
        put("tagReportDiscard", "放弃本次上报？", "放棄本次回報？", "放棄本次回報？", "Discard This Report?", "報告を破棄しますか？");
        put("save", "保存", "儲存", "儲存", "Save", "保存");
        put("done", "完成", "完成", "完成", "Done", "完了");
        put("contactDeveloper", "联系开发者", "聯絡開發者", "聯絡開發者", "Contact Developer", "開発者に連絡");
        put("ok", "好", "好", "好", "OK", "OK");
        put("meqrProfileCode", "MeQR 交换码", "MeQR 交換碼", "MeQR 交換碼", "MeQR Profile Code", "MeQR 交換コード");
        put("meqrCodeSettings", "交换码设置", "交換碼設定", "交換碼設定", "Exchange Code Settings", "交換コード設定");
        put("meqrShortIntroduction", "离线短介绍（最多两行、25字）", "離線短介紹（最多兩行、25字）", "離線短介紹（最多兩行、25字）", "Offline short introduction (2 lines, 25 characters)", "オフライン用の短い紹介（2行・25文字まで）");
        put("meqrOnlinePlatforms", "在线交换的平台（最多 3 个）", "線上交換的平台（最多 3 個）", "線上交換的平台（最多 3 個）", "Online exchange platforms (up to 3)", "オンライン交換先（最大3件）");
        put("meqrOfflinePlatform", "离线交换的平台", "離線交換的平台", "離線交換的平台", "Offline exchange platform", "オフライン交換先");
        put("meqrSelectUpToThree", "在线交换最多选择 3 个平台", "線上交換最多選擇 3 個平台", "線上交換最多選擇 3 個平台", "Choose up to 3 online platforms", "オンライン交換先は最大3件です");
        put("meqrSelectOnePlatform", "请至少选择 1 个在线平台", "請至少選擇 1 個線上平台", "請至少選擇 1 個線上平台", "Choose at least 1 online platform", "オンライン交換先を1件以上選択してください");
        put("meqrSelectOfflinePlatform", "请选择一个已启用的平台用于离线交换", "請選擇一個已啟用的平台用於離線交換", "請選擇一個已啟用的平台用於離線交換", "Choose an enabled platform for offline exchange", "有効な交換先をオフライン用に選択してください");
        put("saveMeQrCode", "保存交换码到相册", "儲存交換碼到相簿", "儲存交換碼到照片", "Save Code to Photos", "交換コードを写真に保存");
        put("meqrCodeHint", "对方用 MeQR 扫这个码，就能看到你的这张扩列卡。", "對方用 MeQR 掃這個碼，就能看到你的這張擴列卡。", "對方用 MeQR 掃描這個碼，就能看到你的這張擴列卡。", "Someone can scan this with MeQR to read your profile.", "相手がMeQRでこのコードを読み取ると、あなたのプロフィールを表示できます。");
        put("meqrLocalReady", "本地交换码：不会上传资料，扫码直接读取。", "本地交換碼：不會上傳資料，掃碼直接讀取。", "本地交換碼：不會上傳資料，掃碼直接讀取。", "Local code: no upload, scan to read directly.", "ローカルコード：アップロードせず、スキャンして直接読み取ります。");
        put("meqrPreparingOnline", "交换码已保存，可离线扫描；正在同步在线资料…", "交換碼已儲存，可離線掃描；正在同步線上資料…", "交換碼已儲存，可離線掃描；正在同步線上資料…", "Code saved and available offline. Syncing online details…", "コードを保存しました。オフラインで読み取れます。オンライン情報を同期中…");
        put("meqrOnlineReady", "交换码已保存，在线与离线使用同一码。", "交換碼已儲存，線上與離線使用同一碼。", "交換碼已儲存，線上與離線使用同一碼。", "Code saved. The same code works online and offline.", "保存済みの同じコードをオンラインでもオフラインでも使えます。");
        put("meqrOnlineFallback", "交换码已保存，离线可用；在线资料暂未同步，下次打开会重试。", "交換碼已儲存，離線可用；線上資料暫未同步，下次開啟會重試。", "交換碼已儲存，離線可用；線上資料暫未同步，下次開啟會重試。", "Code saved and available offline. Online sync will retry next time you open it.", "コードは保存済みでオフラインでも使えます。次に開くとオンライン同期を再試行します。");
        put("meqrCodeFailed", "交换码生成失败", "交換碼產生失敗", "交換碼產生失敗", "Could not create MeQR code.", "交換コードを作成できません。");
        put("saved", "已保存到相册", "已儲存到相簿", "已儲存到照片", "Saved to Photos", "写真に保存しました");
        put("saveFailed", "无法保存，请重试。", "無法儲存，請再試一次。", "無法儲存，請再試一次。", "Please try again.", "もう一度お試しください。");
        put("dataLoadFailed", "卡片数据无法读取，已保留原文件以防覆盖。请通过“备份/恢复”或联系开发者处理。", "卡片資料無法讀取，已保留原檔以防覆蓋。請透過「備份/還原」或聯絡開發者處理。", "卡片資料無法讀取，已保留原檔以防覆蓋。請透過「備份/還原」或聯絡開發者處理。", "Card data could not be read; the original file was kept to avoid overwriting it. Use Backup/Restore or contact the developer.", "カードデータを読み込めませんでした。上書きを防ぐため元のファイルを保持しています。バックアップ/復元を使うか、開発者に連絡してください。");
        put("deleteStopSyncFirst", "请先在“更多设置 → 多设备同步”中停止此卡片的同步，再删除本机卡片。", "請先在「更多設定 → 多裝置同步」中停止此卡片的同步，再刪除本機卡片。", "請先在「更多設定 → 多裝置同步」中停止此卡片的同步，再刪除本機卡片。", "Stop this card's sync in More Settings → Multi-Device Sync before deleting the local card.", "このカードの同期を「その他の設定 → マルチデバイス同期」で停止してから、端末内のカードを削除してください。");
        put("deleteSyncStateUnavailable", "无法读取同步状态，请稍后重试。", "無法讀取同步狀態，請稍後再試。", "無法讀取同步狀態，請稍後再試。", "Could not read sync status. Please try again later.", "同期状態を読み取れませんでした。しばらくしてから再試行してください。");
        put("emptyTitle", "还没有卡片", "還沒有卡片", "還沒有卡片", "No Cards Yet", "カードがまだありません");
        put("emptyBody", "创建你的第一张卡片，开始吧", "建立你的第一張卡片，開始吧", "建立你的第一張卡片，開始吧", "Create your first card to get started.", "最初のカードを作って始めましょう。");
        put("newProfile", "新建卡片", "新增卡片", "新增卡片", "New Card", "新規カード");
        put("editProfile", "编辑卡片", "編輯卡片", "編輯卡片", "Edit Card", "カードを編集");
        put("profileName", "卡片名称", "卡片名稱", "卡片名稱", "Card Name", "カード名");
        put("discardChanges", "放弃修改", "放棄修改", "放棄修改", "Discard Changes", "変更を破棄");
        put("bio", "介绍", "介紹", "介紹", "Bio / Intro", "紹介");
        put("viewBack", "查看介绍", "查看介紹", "查看介紹", "View Intro", "紹介を見る");
        put("viewFront", "返回正面", "返回正面", "返回正面", "View Front", "表面に戻る");
        put("bioEmpty", "还没有填写介绍", "尚未填寫介紹", "尚未填寫介紹", "No introduction yet", "紹介はまだありません");
        put("viewFullBio", "点击查看完整介绍", "點擊查看完整介紹", "點擊查看完整介紹", "Tap to read the full introduction", "タップして紹介の全文を読む");
        put("bioDisplayHint", "长介绍会缩小字号或显示省略号；点击卡片背面的介绍可查看全文。", "長介紹會縮小字號或顯示省略號；點擊卡片背面的介紹可查看全文。", "長介紹會縮小字號或顯示省略號；點擊卡片背面的介紹可查看全文。", "Long introductions use smaller text or an ellipsis. Tap the introduction on the back to read it in full.", "長い紹介は文字を縮小、または省略表示します。カード裏面の紹介をタップすると全文を読めます。");
        put("qrContent", "二维码内容", "QR Code 內容", "QR Code 內容", "QR Content", "QRコード内容");
        put("platform", "平台", "平台", "平台", "Platform", "プラットフォーム");
        put("commonPlatforms", "常用软件", "常用軟件", "常用 App", "Common Apps", "よく使うアプリ");
        put("socialPlatforms", "社交", "社交", "社群", "Social", "ソーシャル");
        put("professionalPlatforms", "职业", "職業", "職業", "Professional", "仕事");
        put("customPlatform", "平台名称", "平台名稱", "平台名稱", "Platform Name", "プラットフォーム名");
        put("avatar", "头像", "頭像", "頭像", "Avatar", "アイコン");
        put("backgroundImage", "背景图", "背景圖", "背景圖", "Background Image", "背景画像");
        put("chooseImage", "选择图片", "選擇圖片", "選擇圖片", "Choose Image", "画像を選択");
        put("removeImage", "移除图片", "移除圖片", "移除圖片", "Remove Image", "画像を削除");
        put("appearance", "外观", "外觀", "外觀", "Appearance", "外観");
        put("textColor", "文字颜色", "文字顏色", "文字顏色", "Text Color", "文字色");
        put("qrColor", "二维码颜色", "QR Code 顏色", "QR Code 顏色", "QR Code Color", "QRコードの色");
        put("backgroundColor", "背景颜色", "背景顏色", "背景顏色", "Background Color", "背景色");
        put("borderColor", "边框颜色", "邊框顏色", "邊框顏色", "Border Color", "枠線色");
        put("cornerRadius", "圆角", "圓角", "圓角", "Corner Radius", "角丸");
        put("opacity", "卡片不透明度", "卡片不透明度", "卡片不透明度", "Card Opacity", "カードの不透明度");
        put("glassEffect", "毛玻璃背景", "毛玻璃背景", "毛玻璃背景", "Frosted Glass", "すりガラス背景");
        put("glassEffectHint", "用背景图/头图模糊作为卡片底，仅通行证模板可用。", "用背景圖/頭圖模糊作為卡片底，僅通行證模板可用。", "用背景圖/頭圖模糊作為卡片底，僅通行證模板可用。", "Blur the banner/background image behind the card. Rhodes Pass only.", "バナー/背景画像をぼかしてカードの背景にします。ロドス通行証のみ。");
        put("preview", "预览", "預覽", "預覽", "Preview", "プレビュー");
        put("template", "卡片模板", "卡片模板", "卡片模板", "Card Template", "カードテンプレート");
        put("standardTemplate", "标准卡片", "標準卡片", "標準卡片", "Standard", "スタンダード");
        put("rhodesTemplate", "明日方舟通行证", "明日方舟通行證", "明日方舟通行證", "Rhodes Pass", "ロドス通行証");
        put("passSubtitleLabel", "通行证短标签", "通行證短標籤", "通行證短標籤", "Pass Short Label", "パス短いラベル");
        put("passSubtitleHint", "显示在名字下面，最多 10 个汉字。", "顯示在名字下面，最多 10 個漢字。", "顯示在名字下面，最多 10 個漢字。", "Shown under the name. Up to 10 CJK characters.", "名前の下に表示します。漢字10文字まで。");
        put("passLabel", "通行证", "通行證", "通行證", "Pass", "パス");
        put("platformCards", "平台卡片", "平台卡片", "平台卡片", "Platform Cards", "プラットフォームカード");
        put("addPlatform", "添加平台", "加入平台", "新增平台", "Add Platform", "プラットフォームを追加");
        put("importQrImage", "从图片识别二维码", "從圖片識別 QR Code", "從圖片辨識 QR Code", "Import QR Image", "QR画像を読み込む");
        put("qrDecodeFailed", "没有识别到二维码", "未能識別 QR Code", "無法辨識 QR Code", "No QR code found", "QRコードを認識できませんでした");
        put("tags", "标签", "標籤", "標籤", "Tags", "タグ");
        put("tagTextWeight", "字重", "字重", "字重", "Text weight", "文字の太さ");
        put("tagWeightRegular", "常规", "標準", "標準", "Regular", "標準");
        put("tagWeightSemibold", "半粗", "半粗", "半粗", "Semibold", "中太");
        put("tagWeightHeavy", "特粗", "特粗", "特粗", "Heavy", "極太");
        put("tagOrder", "Tag 排序", "Tag 排序", "Tag 排序", "Reorder tags", "Tagの並べ替え");
        put("tagRecent", "最近", "最近", "最近", "Recent", "最近");
        put("tagKindWork", "作品", "作品", "作品", "Work", "作品");
        put("tagKindCharacter", "角色", "角色", "角色", "Character", "キャラクター");
        put("tagKindGroup", "组合", "組合", "組合", "Group", "グループ");
        put("tagKindRating", "等级", "等級", "等級", "Rating", "レーティング");
        put("tagFavorites", "收藏", "收藏", "收藏", "Favorites", "お気に入り");
        put("tagFavorite", "收藏 Tag", "收藏 Tag", "收藏 Tag", "Favorite Tag", "お気に入りに追加");
        put("tagUnfavorite", "取消收藏", "取消收藏", "取消收藏", "Remove Favorite", "お気に入りから削除");
        put("tagRequestNew", "申请收录 Tag", "申請收錄 Tag", "申請收錄 Tag", "Request a Tag", "タグの追加を申請");
        put("tagRequestName", "角色 / Tag 名称", "角色 / Tag 名稱", "角色 / Tag 名稱", "Character / Tag Name", "キャラクター・タグ名");
        put("tagRequestIP", "所属作品 / IP", "所屬作品 / IP", "所屬作品 / IP", "Work / IP", "作品名");
        put("tagRequestColors", "建议配色（选填）", "建議配色（選填）", "建議配色（選填）", "Suggested Colors (Optional)", "希望する配色（任意）");
        put("tagRequestSource", "参考链接（选填）", "參考連結（選填）", "參考連結（選填）", "Reference URL (Optional)", "参考URL（任意）");
        put("tagOutbox", "上报记录", "回報紀錄", "回報紀錄", "Report Outbox", "報告履歴");
        put("tagQueued", "待提交", "待提交", "待提交", "Pending", "送信待ち");
        put("tagSending", "正在提交", "正在提交", "正在提交", "Sending", "送信中");
        put("tagRetry", "重试", "重試", "重試", "Retry", "再試行");
        put("tagQueueSaved", "已保存，等待提交", "已儲存，等待提交", "已儲存，等待提交", "Saved, Pending Submission", "保存済み・送信待ち");
        put("tagQueueEmpty", "暂无上报记录", "暫無回報紀錄", "暫無回報紀錄", "No Reports", "報告はありません");
        put("tagCancelPending", "取消待提交上报", "取消待提交回報", "取消待提交回報", "Cancel Pending Report", "送信待ちの報告を取り消す");
        put("tagQueueSaveFailed", "无法保存上报，请保留表单并重试。", "無法儲存回報，請保留表單並重試。", "無法儲存回報，請保留表單並重試。", "Could not save the report. Keep the form open and retry.", "報告を保存できません。フォームを閉じずに再試行してください。");
        put("tagCopyPalette", "复制配色到…", "複製配色到…", "複製配色到…", "Copy Colors To…", "配色のコピー先…");
        put("tagHex", "HEX 色值", "HEX 色值", "HEX 色值", "HEX Color", "HEXカラー");
        put("tagInvalidHex", "请输入有效的六位 HEX 色值", "請輸入有效的六位 HEX 色值", "請輸入有效的六位 HEX 色值", "Enter a valid six-digit HEX color", "6桁の有効なHEXカラーを入力してください");
        put("tagMoveColor", "调整色段顺序", "調整色段順序", "調整色段順序", "Reorder Color", "色の順番を変更");
        put("tagMoveUp", "向前移动", "向前移動", "向前移動", "Move Earlier", "前へ移動");
        put("tagMoveDown", "向后移动", "向後移動", "向後移動", "Move Later", "後ろへ移動");
        put("tagPreview", "预览", "預覽", "預覽", "Preview", "プレビュー");
        put("tagFrequent", "常用", "常用", "常用", "Frequent", "よく使う");
        put("tagAll", "全部", "全部", "全部", "All", "すべて");
        put("tagHistoryEmpty", "暂无使用记录", "暫無使用記錄", "尚無使用記錄", "No usage history yet", "使用履歴はまだありません");
        put("tagClearHistory", "清空使用记录", "清空使用記錄", "清除使用記錄", "Clear usage history", "使用履歴を消去");
        put("tagCatalogSource", "App 内置库", "App 內建庫", "App 內建庫", "Bundled library", "アプリ内蔵ライブラリ");
        put("tagCatalogRemote", "线上 Tag 库", "線上 Tag 庫", "線上 Tag 庫", "Online library", "オンラインライブラリ");
        put("tagCatalogCache", "线上库缓存", "線上庫快取", "線上庫快取", "Cached online library", "オンラインライブラリのキャッシュ");
        put("tagCatalogMaintenance", "线上库维护中，暂用本地数据", "線上庫維護中，暫用本機資料", "線上庫維護中，暫用本機資料", "Online library under maintenance; using local data", "オンラインライブラリはメンテナンス中のため、端末内のデータを使用しています");
        put("tagCatalogFallback", "线上库暂时无法连接，已保留本地数据", "暫時無法連接線上庫，已保留本機資料", "暫時無法連線至線上庫，已保留本機資料", "Online library unavailable; local data retained", "オンラインライブラリに接続できないため、端末内のデータを保持しています");
        put("tagCatalogInfo", "Tag 库信息", "Tag 庫資訊", "Tag 庫資訊", "Library information", "ライブラリ情報");
        put("tagCatalogChanges", "变更日志", "變更日誌", "更新記錄", "Changelog", "更新履歴");
        put("tagCatalogNoChanges", "此版本未附带变更记录", "此版本未附帶變更記錄", "此版本未附帶更新記錄", "No changelog included in this version", "このバージョンに更新履歴はありません");
        put("tagsHint", "搜索或自定义 tag，或从右侧列表选择 →", "搜尋或自訂 tag，或從右側清單選擇 →", "搜尋或自訂 tag，或從右側清單選擇 →", "Search or create a tag, or choose from the list →", "タグを検索・作成、または右の一覧から選択 →");
        put("setupWelcome", "从一张属于你的扩列卡开始", "從一張屬於你的擴列卡開始", "從一張屬於你的擴列卡開始", "Start with a card that is yours", "自分だけのカードから始めよう");
        put("setupWelcomeBody", "我们会逐步完成昵称、二维码、外观与标签。", "我們會逐步完成暱稱、QR Code、外觀與標籤。", "我們會逐步完成暱稱、QR Code、外觀與標籤。", "Set up your identity, QR codes, appearance, and tags step by step.", "名前、QRコード、外観、タグを順番に設定します。");
        put("setupEyebrow", "MEQR · FIRST CARD", "MEQR · FIRST CARD", "MEQR · FIRST CARD", "MEQR · FIRST CARD", "MEQR · FIRST CARD");
        put("setupStart", "开始建档", "開始建檔", "開始建立", "Start My Card", "カードを作る");
        put("setupProgress", "建档进度", "建檔進度", "建立進度", "Setup progress", "作成の進捗");
        put("setupIdentity", "先介绍一下你自己", "先介紹一下你自己", "先介紹一下你自己", "Introduce yourself", "まず自己紹介");
        put("setupIdentityBody", "昵称是必填项。头像和介绍可以先留空，之后随时都能修改。", "暱稱是必填項。頭像和介紹可以先留空，之後隨時都能修改。", "暱稱是必填項。頭像和介紹可以先留空，之後隨時都能修改。", "Your display name is required. Avatar and intro can be added later.", "表示名は必須です。アイコンと紹介文はあとから追加できます。");
        put("setupQr", "添加第一个平台", "加入第一個平台", "新增第一個平台", "Add your first platform", "最初のプラットフォーム");
        put("setupQrBody", "从相册识别二维码，或者粘贴链接与文本生成。", "從相簿辨識 QR Code，或者貼上連結與文字產生。", "從照片辨識 QR Code，或者貼上連結與文字產生。", "Import a QR image, or generate one from a link or text.", "画像から読み込むか、リンクやテキストから作成できます。");
        put("setupAppearance", "选择卡片的样子", "選擇卡片的樣子", "選擇卡片的樣子", "Choose your card style", "カードのスタイルを選ぶ");
        put("setupAppearanceBody", "选择模板、背景和颜色。清晰的对比度会让二维码更容易扫描。", "選擇模板、背景和顏色。清晰的對比度會讓 QR Code 更容易掃描。", "選擇模板、背景和顏色。清晰的對比度會讓 QR Code 更容易掃描。", "Choose a template, background, and colors. Strong contrast keeps QR codes easy to scan.", "テンプレート、背景、色を選びます。高いコントラストで読み取りやすくなります。");
        put("setupTags", "用标签找到同好", "用標籤找到同好", "用標籤找到同好", "Add tags people recognize", "タグで仲間を見つける");
        put("setupTagsBody", "作品、角色、社团或兴趣都可以。这一步也可以先跳过。", "作品、角色、社團或興趣都可以。這一步也可以先跳過。", "作品、角色、社團或興趣都可以。這一步也可以先跳過。", "Add series, characters, circles, or hobbies. You can also skip this step.", "作品、キャラクター、サークル、趣味など。あとで追加しても構いません。");
        put("setupFinal", "这是你的第一张卡", "這是你的第一張卡", "這是你的第一張卡", "Your first card is ready", "最初のカードが完成");
        put("setupFinalBody", "确认后会保存在这台设备上，所有内容之后都能继续编辑。", "確認後會儲存在這台裝置上，所有內容之後都能繼續編輯。", "確認後會儲存在這台裝置上，所有內容之後都能繼續編輯。", "It will be saved on this device, and every detail remains editable.", "この端末に保存され、すべてあとから編集できます。");
        put("setupComplete", "你的卡片，准备好了。", "你的卡片，準備好了。", "你的卡片，準備好了。", "Your card is ready.", "カードができました。");
        put("setupCompleteBody", "下次见面时，直接把它拿出来就好。接下来还可以添加更多平台。", "下次見面時，直接把它拿出來就好。接下來還可以加入更多平台。", "下次見面時，直接把它拿出來就好。接下來還可以新增更多平台。", "Bring it up the next time you meet someone. You can add more platforms next.", "次に誰かと会うとき、そのまま見せられます。ほかのプラットフォームも追加できます。");
        put("setupEnter", "进入喜劳转扩", "進入喜勞轉擴", "進入喜勞轉擴", "Enter MeQR", "MeQRを始める");
        put("supportTitle", "需要帮忙？", "需要幫忙？", "需要協助？", "Need help?", "お困りですか？");
        put("supportBody", "支持中心有常见问题和使用说明。之后也可以从“关于软件”打开。", "支援中心有常見問題和使用說明。之後也可以從「關於軟件」開啟。", "支援中心有常見問題和使用說明。之後也可以從「關於 App」開啟。", "The support center has answers to common questions and guides. You can also open it later from About.", "サポートセンターで、よくある質問と使い方を確認できます。あとから「このアプリについて」でも開けます。");
        put("openSupport", "打开支持中心", "開啟支援中心", "開啟支援中心", "Open Support Center", "サポートセンターを開く");
        put("continue", "继续", "繼續", "繼續", "Continue", "続ける");
        put("back", "返回", "返回", "返回", "Back", "戻る");
        put("previousPage", "上一页", "上一頁", "上一頁", "Previous", "前へ");
        put("nextPage", "下一页", "下一頁", "下一頁", "Next", "次へ");
        put("finishSetup", "完成建档", "完成建檔", "完成建檔", "Finish Setup", "設定を完了");
        put("replaySetup", "重新体验首次建档", "重新體驗首次建檔", "重新體驗首次建檔", "Replay Setup Guide", "初回設定をやり直す");
        put("nameRequired", "请先填写昵称", "請先填寫暱稱", "請先填寫暱稱", "Please enter a name", "名前を入力してください");
        put("reorder", "排序", "排序", "排序", "Reorder", "並べ替え");
        put("moveUp", "上移", "上移", "上移", "Move Up", "上へ");
        put("moveDown", "下移", "下移", "下移", "Move Down", "下へ");
        put("deleteConfirm", "确定要删除这个 Profile？", "確定要刪除這個 Profile？", "確定要刪除這個 Profile？", "Delete this profile?", "このプロフィールを削除しますか？");
        put("settings", "更多设置", "更多設定", "更多設定", "More Settings", "その他の設定");
        put("mainActions", "快捷操作", "快捷操作", "快捷操作", "Quick Actions", "クイック操作");
        put("settingsActions", "常用功能", "常用功能", "常用功能", "Quick Actions", "クイック操作");
        put("settingsGeneral", "偏好与支持", "偏好與支援", "偏好與支援", "Preferences & Support", "設定とサポート");
        put("settingsData", "数据", "資料", "資料", "Data", "データ");
        put("language", "语言", "語言", "語言", "Language", "言語");
        put("followSystem", "跟随系统", "跟隨系統", "跟隨系統", "Follow System", "システムに合わせる");
        put("theme", "主题", "主題", "主題", "Theme", "テーマ");
        put("themeLight", "浅色", "淺色", "淺色", "Light", "ライト");
        put("themeDark", "深色", "深色", "深色", "Dark", "ダーク");
        put("checkUpdates", "检查更新", "檢查更新", "檢查更新", "Check for Updates", "アップデートを確認");
        put("updateAvailable", "发现新版本", "發現新版本", "發現新版本", "Update Available", "新しいバージョンがあります");
        put("updateNow", "在 App 内更新", "在 App 內更新", "在 App 內更新", "Update in App", "アプリ内で更新");
        put("later", "稍后", "稍後", "稍後", "Later", "あとで");
        put("alreadyLatest", "已经是最新版本", "已經是最新版本", "已經是最新版本", "You already have the latest version", "最新バージョンです");
        put("updateCheckFailed", "暂时无法检查更新", "暫時無法檢查更新", "暫時無法檢查更新", "Could not check for updates", "アップデートを確認できませんでした");
        put("downloadingUpdate", "正在下载更新，完成后会打开系统安装界面", "正在下載更新，完成後會開啟系統安裝畫面", "正在下載更新，完成後會開啟系統安裝畫面", "Downloading the update. Android will ask before installing.", "更新をダウンロード中。完了後にAndroidのインストール画面を開きます");
        put("updateDownloadFailed", "更新下载失败，请稍后重试", "更新下載失敗，請稍後再試", "更新下載失敗，請稍後再試", "Update download failed. Try again later.", "更新のダウンロードに失敗しました");
        put("updateVerificationFailed", "更新包校验失败，已停止安装", "更新包驗證失敗，已停止安裝", "更新包驗證失敗，已停止安裝", "The update package failed verification and was not opened.", "更新パッケージの検証に失敗したため、インストールを中止しました");
        put("allowInstallUpdates", "请允许喜劳转扩安装更新，返回后会继续", "請允許喜勞轉擴安裝更新，返回後會繼續", "請允許喜勞轉擴安裝更新，返回後會繼續", "Allow MeQR to install updates, then return to continue.", "MeQRによる更新のインストールを許可してから戻ってください");
        put("about", "关于软件", "關於軟件", "關於 App", "About", "このアプリについて");
        put("privacy", "隐私政策", "私隱政策", "隱私權政策", "Privacy Policy (English)", "プライバシーポリシー（英語）");
        put("version", "版本", "版本", "版本", "Version", "バージョン");
        put("website", "跳转官网", "前往官網", "前往官網", "Open Website", "公式サイトを開く");
        put("contact", "联系开发者", "聯絡開發者", "聯絡開發者", "Contact Developer", "開発者に連絡");
        put("developerIntro", "开发者介绍", "開發者介紹", "開發者介紹", "Developer Intro", "開発者紹介");
        put("developerStudent", "目前高中就读 初音未来重度依赖", "目前高中就讀 初音未來重度依賴", "目前高中就讀 初音未來重度依賴", "High school student, heavily dependent on Hatsune Miku.", "高校生です。初音ミクにかなり依存しています。");
        put("developerMadeForFun", "抱着玩一下的心态开发了这款软件", "抱着玩一下的心態開發了這款軟件", "抱著玩一下的心態開發了這款 App", "I started this app just for fun", "遊び半分でこのアプリを作り始めました");
        put("developerUnexpected", "没想到后面功能越加越多", "沒想到後面功能越加越多", "沒想到後來功能越加越多", "then somehow kept adding more features", "気づいたら機能がどんどん増えていました");
        put("developerHope", "希望大家喜欢:)", "希望大家喜歡:)", "希望大家喜歡:)", "Hope you like it :)", "気に入ってもらえたらうれしいです :)");
        put("scanMeQr", "扫描 MeQR 交换码", "掃描 MeQR 交換碼", "掃描 MeQR 交換碼", "Scan MeQR Code", "MeQRコードをスキャン");
        put("scanMeQrHint", "对准二维码，自动识别 MeQR 交换码", "對準 QR Code，自動辨識 MeQR 交換碼", "對準 QR Code，自動辨識 MeQR 交換碼", "Point the camera at a MeQR code to scan it", "カメラをMeQRコードに向けてください");
        put("importFromPhoto", "从相册导入", "從相簿匯入", "從相簿匯入", "Import from Photos", "写真から読み込む");
        put("couldNotDecode", "无法识别这个二维码", "無法辨識這個 QR Code", "無法辨識這個 QR Code", "Could not read this QR code", "このQRコードを読み取れません");
        put("notMeQrCode", "这不是 MeQR 交换码", "這不是 MeQR 交換碼", "這不是 MeQR 交換碼", "This is not a MeQR profile code", "これはMeQR交換コードではありません");
        put("cameraPermissionNeeded", "需要相机权限才能扫码", "需要相機權限才能掃碼", "需要相機權限才能掃碼", "Camera permission is required to scan", "スキャンにはカメラ権限が必要です");
        put("meqrProfileFound", "发现 MeQR 卡片", "發現 MeQR 卡片", "發現 MeQR 卡片", "MeQR Card Found", "MeQRカードを検出");
        put("saveEncounter", "保存到认识记录", "儲存到認識記錄", "儲存到認識記錄", "Save Encounter", "出会いの記録に保存");
        put("savedEncounter", "已保存到认识记录", "已儲存到認識記錄", "已儲存到認識記錄", "Saved to Encounters", "出会いの記録に保存しました");
        put("encounters", "认识记录", "認識記錄", "認識記錄", "Encounters", "出会いの記録");
        put("noEncounters", "还没有认识记录", "還沒有認識記錄", "還沒有認識記錄", "No Encounters Yet", "出会いの記録はまだありません");
        put("noEncountersHint", "扫描交换码后，把对方保存到这里。", "掃描交換碼後，把對方儲存在這裡。", "掃描交換碼後，把對方儲存在這裡。", "Scan a MeQR code and save the person here.", "交換コードを読み取ると、ここに相手を保存できます。");
        put("encounterWaiting", "等待对方确认的认识记录，打开页面时会自动同步。", "等待對方確認的認識記錄，開啟頁面時會自動同步。", "等待對方確認的認識記錄，開啟頁面時會自動同步。", "Waiting for encounter confirmations; this page syncs when opened.", "相手の確認待ちです。このページを開くと同期します。");
        put("unknownContact", "未命名联系人", "未命名聯絡人", "未命名聯絡人", "Unknown Contact", "名前未設定の相手");
        put("platformsFromMeQr", "来自 MeQR 的平台", "來自 MeQR 的平台", "來自 MeQR 的平台", "Platforms from MeQR", "MeQRからのプラットフォーム");
        put("openLink", "打开链接", "開啟連結", "開啟連結", "Open Link", "リンクを開く");
        put("activeEvent", "当前活动", "目前活動", "目前活動", "Active Event", "現在のイベント");
        put("noActiveEvent", "未选择活动", "未選擇活動", "未選擇活動", "No Active Event", "イベント未選択");
        put("events", "活动", "活動", "活動", "Events", "イベント");
        put("defaultEventTitle", "自定义线下扩列", "自訂線下擴列", "自訂線下擴列", "Custom Offline Meetup", "カスタム対面オフ会");
        put("defaultEventVenue", "现场", "現場", "現場", "On-site", "現地");
        put("addEvent", "添加活动", "新增活動", "新增活動", "Add Event", "イベントを追加");
        put("eventTitle", "活动名称", "活動名稱", "活動名稱", "Event Title", "イベント名");
        put("eventVenue", "地点", "地點", "地點", "Venue", "会場");
        put("eventDetails", "详情", "詳情", "詳情", "Details", "詳細");
        put("encounterInfo", "记录信息", "記錄資訊", "記錄資訊", "Record Info", "記録情報");
        put("note", "备注", "備註", "備註", "Note", "メモ");
        put("followStatus", "跟进状态", "跟進狀態", "跟進狀態", "Follow-up", "フォロー状況");
        put("needsPhotoReturn", "需要返图", "需要返圖", "需要返圖", "Photo Return Needed", "返図が必要");
        put("exchangedFreebie", "交换了无料", "交換了無料", "交換了無料", "Exchanged Freebies", "無料交換した");
        put("on", "已开启", "已開啟", "已開啟", "On", "オン");
        put("off", "未开启", "未開啟", "未開啟", "Off", "オフ");
        put("deleteEncounter", "删除这条记录", "刪除這條記錄", "刪除這條記錄", "Delete Record", "この記録を削除");
        put("deleteEncounterConfirm", "确定删除这条认识记录？删除后无法恢复。", "確定刪除這條認識記錄？刪除後無法復原。", "確定刪除這條認識記錄？刪除後無法復原。", "Delete this encounter? This cannot be undone.", "この出会いの記録を削除しますか？元に戻せません。");
        put("tagColors", "标签配色", "標籤配色", "標籤配色", "Tag Colors", "タグの色");
        put("tagPairHint", "将两个世界计划角色标签拖到一起，即可组成 CP/CB 标签；拖动的角色在左。", "將兩個世界計畫角色標籤拖到一起，即可組成 CP/CB 標籤；拖動的角色在左。", "將兩個世界計畫角色標籤拖到一起，即可組成 CP/CB 標籤；拖動的角色在左。", "Drag one Project Sekai character tag onto another to create a CP/CB tag. The dragged character goes on the left.", "プロセカのキャラクタータグを別のキャラクタータグに重ねると、CP/CB タグになります。ドラッグしたキャラクターが左側になります。");
        put("tagPairTitle", "这是 CP 还是 CB？", "這是 CP 還是 CB？", "這是 CP 還是 CB？", "CP or CB?", "CP と CB、どちらにしますか？");
        put("tagPairSwap", "交换左右位", "交換左右位", "交換左右位", "Swap sides", "左右を入れ替える");
        put("tagPairConflict", "已有同名组合标签，请先移除或调整。", "已有同名組合標籤，請先移除或調整。", "已有同名組合標籤，請先移除或調整。", "A tag with this name or pairing already exists.", "同名または同じ組み合わせのタグがすでにあります。");
        put("tagColorsHint", "输入标签后，可在这里为每个标签单独配色", "輸入標籤後，可在這裡為每個標籤單獨配色", "輸入標籤後，可在這裡為每個標籤單獨配色", "Add tags above, then customize each tag color here", "タグを追加すると、ここで個別の色を設定できます");
        put("tagLibrary", "从 Tag 库添加", "從 Tag 庫加入", "從 Tag 庫新增", "Add from Tag Library", "Tagライブラリから追加");
        put("searchTags", "搜索作品、组合或角色", "搜尋作品、組合或角色", "搜尋作品、組合或角色", "Search series, groups, or characters", "作品・ユニット・キャラクターを検索");
        put("tagLibraryHint", "点按即可添加，支持中英日名称与常用简称", "點按即可加入，支援中英日名稱與常用簡稱", "點按即可新增，支援中英日名稱與常用簡稱", "Tap to add. Names and common aliases are searchable.", "タップで追加。名前と略称で検索できます。");
        put("tagCatalogLoading", "正在载入 Tag 库", "正在載入 Tag 庫", "正在載入 Tag 庫", "Loading Tag library", "Tagライブラリを読み込み中");
        put("noTagResults", "没有找到 Tag", "找不到 Tag", "找不到 Tag", "No tags found", "Tagが見つかりません");
        put("tagCatalogRetry", "Tag 库载入失败，点按重试", "Tag 庫載入失敗，點按重試", "Tag 庫載入失敗，點按重試", "Tag library unavailable. Tap to retry.", "Tagライブラリを読み込めません。タップして再試行");
        put("tagLimitReached", "最多添加 15 个 Tag", "最多加入 15 個 Tag", "最多新增 15 個 Tag", "Up to 15 tags", "Tagは最大15個です");
        put("tagSuggestions", "可以先试试", "可以先試試", "可以先試試", "Try one of these", "おすすめ");
        put("tagCategories", "浏览分类", "瀏覽分類", "瀏覽分類", "Browse categories", "カテゴリを閲覧");
        put("editTagColors", "编辑拼色", "編輯拼色", "編輯拼色", "Edit Colors", "配色を編集");
        put("solidColor", "纯色", "純色", "純色", "Solid", "単色");
        put("mixedColor", "拼色", "拼色", "拼色", "Mixed", "多色");
        put("customColor", "自定义", "自訂", "自訂", "Custom", "カスタム");
        put("presetColor", "预设", "預設", "預設", "Preset", "プリセット");
        put("builtInMix", "恢复内置拼色", "恢復內建拼色", "恢復內建拼色", "Restore Built-in Mix", "プリセット配色に戻す");
        put("addColor", "增加颜色", "增加顏色", "增加顏色", "Add Color", "色を追加");
        put("color", "颜色", "顏色", "顏色", "Color", "色");
        put("choosePresetColor", "选择预设颜色", "選擇預設顏色", "選擇預設顏色", "Choose Preset Color", "プリセット色を選択");
        put("pickColor", "选择颜色", "選擇顏色", "選擇顏色", "Choose Color", "色を選択");
        put("presets", "预设", "預設", "預設", "Presets", "プリセット");
        put("bannerImage", "横版头图", "橫版頭圖", "橫版頭圖", "Banner Image", "横長ヘッダー画像");
        put("backupData", "备份全部数据", "備份全部資料", "備份全部資料", "Backup All Data", "全データをバックアップ");
        put("restoreData", "恢复数据", "還原資料", "還原資料", "Restore Data", "データを復元");
        put("restore", "恢复", "還原", "還原", "Restore", "復元");
        put("restoreConfirm", "恢复会覆盖当前所有卡片数据，确定继续？", "還原會覆蓋目前所有卡片資料，確定繼續？", "還原會覆蓋目前所有卡片資料，確定繼續？", "Restore will replace all current card data. Continue?", "復元すると現在のカードデータがすべて上書きされます。続行しますか？");
        put("backupDone", "备份已导出", "備份已匯出", "備份已匯出", "Backup exported", "バックアップを書き出しました");
        put("backupFailed", "导出失败，请重试", "匯出失敗，請重試", "匯出失敗，請重試", "Export failed. Try again.", "書き出しに失敗しました。もう一度お試しください");
        put("restoreDone", "数据已恢复", "資料已還原", "資料已還原", "Data restored", "データを復元しました");
        put("restoreFailed", "无法识别这个备份文件", "無法辨識這個備份檔", "無法辨識這個備份檔", "Could not read this backup file", "このバックアップを読み取れません");
        put("wechat", "微信", "微信", "微信", "WeChat", "WeChat");
        put("icpFiling", "备案信息", "備案資訊", "備案資訊", "ICP Filing", "ICP备案");
        put("wechatNotInstalled", "未安装微信", "未安裝微信", "未安裝微信", "WeChat is not installed", "WeChatがインストールされていません");
        put("twitter", "X (推特)", "X (Twitter)", "X (Twitter)", "X (Twitter)", "X（Twitter）");
        put("email", "邮箱", "電郵", "電子郵件", "Email", "メール");
        put("phone", "电话", "電話", "電話", "Phone", "電話");
        put("custom", "自定义", "自訂", "自訂", "Custom", "カスタム");
        put("xiaohongshu", "小红书", "小紅書", "小紅書", "Xiaohongshu", "小紅書");
        put("bilibili", "B站", "B站", "B站", "Bilibili", "Bilibili");
        put("douyinTikTok", "抖音", "抖音", "TikTok", "TikTok", "TikTok");
        put("weibo", "微博", "微博", "微博", "Weibo", "微博");

        // 同步 / 法律
        put("syncTitle", "多设备同步", "多設備同步", "多裝置同步", "Multi-Device Sync", "複数端末同期");
        put("syncSettingsSubtitle", "同步卡片、头像、背景和头图", "同步卡片、頭像、背景和頭圖", "同步卡片、頭像、背景和頭圖", "Sync cards, avatar, background, and banner", "カード、アイコン、背景、ヘッダーを同期");
        put("syncPrivacyTitle", "同步功能隐私说明", "同步功能私隱說明", "同步功能隱私權說明", "Sync Privacy Notice", "同期のプライバシーについて");
        put("syncPrivacyBody", "开启同步后，你选择的卡片文字、二维码内容、Tag、外观设置及头像/背景/头图会通过 HTTPS 上传并保存在同步服务器。当前未启用端到端加密，请只上传愿意存入服务器的资料。", "開啟同步後，你選擇的卡片文字、QR Code 內容、Tag、外觀設定及頭像/背景/頭圖會透過 HTTPS 上傳並儲存在同步伺服器。目前未啟用端到端加密，請只上傳願意存入伺服器的資料。", "開啟同步後，你選擇的卡片文字、QR Code 內容、Tag、外觀設定及頭像/背景/頭圖會透過 HTTPS 上傳並儲存在同步伺服器。目前未啟用端到端加密，請只上傳願意存入伺服器的資料。", "Once sync is enabled, your chosen card text, QR content, tags, appearance settings, and avatar/background/banner are uploaded over HTTPS and stored on the sync server. End-to-end encryption is not currently enabled; only upload content you are comfortable storing on the server.", "同期を有効にすると、選択したカードの文字、QRコード、タグ、外観設定、アイコン/背景/ヘッダーがHTTPSでアップロードされ、同期サーバーに保存されます。現在エンドツーエンド暗号化は無効です。サーバーに保存してもよい内容だけをアップロードしてください。");
        put("syncPrivacyAgree", "我已阅读并继续", "我已閱讀並繼續", "我已閱讀並繼續", "I've read and continue", "確認して続行");
        put("viewFullPolicy", "查看完整政策", "查看完整政策", "查看完整政策", "View Full Policy", "ポリシー全文を見る");
        put("legalImportantUpdate", "重要更新", "重要更新", "重要更新", "Important Update", "重要なお知らせ");
        put("legalReadAndAgree", "我已阅读并同意", "我已閱讀並同意", "我已閱讀並同意", "I have read and agree", "内容を確認し、同意します");
        put("legalUpdateBody", "我们已经在近期更新了「隐私政策」和「用户使用守则」。请阅读更新内容。多设备同步会在你主动开启后，将所选卡片资料和图片上传到同步服务器。", "我們已經在近期更新了「私隱政策」和「用戶使用守則」。請閱讀更新內容。多設備同步會在你主動開啟後，將所選卡片資料和圖片上傳到同步伺服器。", "我們已經在近期更新了「隱私權政策」和「使用者守則」。請閱讀更新內容。多裝置同步會在你主動開啟後，將所選卡片資料和圖片上傳到同步伺服器。", "We recently updated the Privacy Policy and Terms of Use. Please review them. Multi-device sync uploads your selected card data and images to the sync server only after you enable it.", "「プライバシーポリシー」と「利用規約」を更新しました。内容をご確認ください。複数端末同期は有効にした場合のみ、選択したカードのデータと画像を同期サーバーにアップロードします。");
        put("syncIntro1", "同步所选卡片的二维码、Tag、头像、背景和头图。修改后请在本机点“立即同步”，再到另一台手机点一次。", "同步所選卡片的 QR Code、Tag、頭像、背景和頭圖。修改後請在本機點「立即同步」，再到另一台手機點一次。", "同步所選卡片的 QR Code、Tag、頭像、背景和頭圖。修改後請在本機點「立即同步」，再到另一台手機點一次。", "Sync the selected card's QR codes, tags, avatar, background, and banner. After editing, tap “Sync Now” here, then tap it again on the other phone.", "選択したカードのQRコード、タグ、アイコン、背景、ヘッダーを同期します。編集後はこの端末で「今すぐ同期」をタップし、もう一方の端末でもう一度タップしてください。");
        put("syncIntro2", "开启后，卡片和图片会存储在 MeQR 服务器。绑定码与公开交换码分开，加入需主设备确认。每张卡片最多五台设备。", "開啟後，卡片和圖片會儲存在 MeQR 伺服器。綁定碼與公開交換碼分開，加入需主設備確認。每張卡片最多五台設備。", "開啟後，卡片和圖片會儲存在 MeQR 伺服器。綁定碼與公開交換碼分開，加入需主裝置確認。每張卡片最多五台裝置。", "Once enabled, cards and images are stored on the MeQR server. Binding codes are separate from public exchange codes; joining requires the owner device's approval. Each card supports up to five devices.", "有効にすると、カードと画像がMeQRサーバーに保存されます。バインドコードは公開交換コードとは別で、参加には所有者端末の承認が必要です。1枚のカードにつき最大5台までです。");
        put("syncIntro3", "同步传输使用 HTTPS，但不是端到端加密；服务器会保存可读取的资料。请只上传你愿意存入云端的内容。", "同步傳輸使用 HTTPS，但不是端到端加密；伺服器會保存可讀取的資料。請只上傳你願意存入雲端的內容。", "同步傳輸使用 HTTPS，但不是端對端加密；伺服器會保存可讀取的資料。請只上傳你願意存入雲端的內容。", "Sync transfers use HTTPS but are not end-to-end encrypted; the server stores readable data. Only upload content you are comfortable storing in the cloud.", "同期はHTTPSを使用しますがエンドツーエンド暗号化ではありません。サーバーは読み取り可能なデータを保存します。クラウドに保存してもよい内容だけをアップロードしてください。");
        put("syncSyncing", "正在同步…", "正在同步…", "正在同步…", "Syncing…", "同期中…");
        put("syncLocalCards", "本机卡片", "本機卡片", "本機卡片", "Cards on This Device", "この端末のカード");
        put("syncEnable", "将此卡片开启云端同步", "將此卡片開啟雲端同步", "將此卡片開啟雲端同步", "Enable Cloud Sync for This Card", "このカードのクラウド同期を有効にする");
        put("syncRoleOwner", "主设备", "主設備", "主裝置", "Owner", "所有者端末");
        put("syncRoleBound", "已绑定", "已綁定", "已綁定", "Bound", "バインド済み");
        put("syncCloudVersion", "云端版本", "雲端版本", "雲端版本", "Cloud Version", "クラウドバージョン");
        put("syncNow", "立即同步", "立即同步", "立即同步", "Sync Now", "今すぐ同期");
        put("syncRefreshDevices", "刷新设备列表", "重新整理設備列表", "重新整理裝置列表", "Refresh Devices", "端末一覧を更新");
        put("syncGenerateCode", "生成绑定码（10 分钟有效）", "生成綁定碼（10 分鐘有效）", "生成綁定碼（10 分鐘有效）", "Generate Binding Code (valid 10 min)", "バインドコードを生成（10分間有効）");
        put("syncCopyCode", "复制绑定码", "複製綁定碼", "複製綁定碼", "Copy Binding Code", "バインドコードをコピー");
        put("meqrBindingCode", "MeQR 绑定码", "MeQR 綁定碼", "MeQR 綁定碼", "MeQR Binding Code", "MeQRバインドコード");
        put("syncCopied", "已复制，请交给你自己的另一台手机", "已複製，請交給你自己的另一台手機", "已複製，請交給你自己的另一台手機", "Copied. Send it to your other phone.", "コピーしました。もう一方の端末で入力してください。");
        put("syncStopSection", "停止同步", "停止同步", "停止同步", "Stop Sync", "同期を停止");
        put("syncStopOwner", "删除云端资料并停止同步", "刪除雲端資料並停止同步", "刪除雲端資料並停止同步", "Delete Cloud Data & Stop Sync", "クラウドデータを削除して同期を停止");
        put("syncUnbind", "解除本机绑定", "解除本機綁定", "解除本機綁定", "Unbind This Device", "この端末のバインドを解除");
        put("syncDisconnectTitle", "停止同步？", "停止同步？", "停止同步？", "Stop Sync?", "同期を停止しますか？");
        put("syncDisconnectMessage", "本机卡片会保留。删除云端资料后所有设备停止同步，其他手机已经下载的副本仍会保留。", "本機卡片會保留。刪除雲端資料後所有設備停止同步，其他手機已經下載的副本仍會保留。", "本機卡片會保留。刪除雲端資料後所有裝置停止同步，其他手機已經下載的副本仍會保留。", "Cards on this device are kept. Deleting cloud data stops sync for all devices; copies already downloaded on other phones remain.", "この端末のカードは保持されます。クラウドデータを削除すると全端末の同期が停止します。他の端末にダウンロード済みのコピーは残ります。");
        put("syncStopped", "已停止同步，本机卡片已保留", "已停止同步，本機卡片已保留", "已停止同步，本機卡片已保留", "Sync stopped. Cards on this device are kept.", "同期を停止しました。この端末のカードは保持されています。");
        put("syncClearCredential", "清除本机同步凭证", "清除本機同步憑證", "清除本機同步憑證", "Clear Local Sync Credential", "この端末の同期資格情報を消去");
        put("syncClearTitle", "清除本机凭证？", "清除本機憑證？", "清除本機憑證？", "Clear Local Credential?", "この端末の資格情報を消去しますか？");
        put("syncClearMessage", "此操作不删除云端资料，不撤销其他设备。请优先使用上方的停止同步。", "此操作不刪除雲端資料，不撤銷其他設備。請優先使用上方的停止同步。", "此操作不刪除雲端資料，不撤銷其他裝置。請優先使用上方的停止同步。", "This does not delete cloud data or revoke other devices. Prefer “Stop Sync” above.", "この操作はクラウドデータを削除せず、他の端末も取り消しません。上記の「同期を停止」を優先してください。");
        put("syncClearAction", "清除", "清除", "清除", "Clear", "消去");
        put("syncBoundDevices", "已绑定设备", "已綁定設備", "已綁定裝置", "Bound Devices", "バインド済み端末");
        put("syncThisDevice", "（本机）", "（本機）", "（本機）", "(this device)", "（この端末）");
        put("syncRemove", "移除", "移除", "移除", "Remove", "削除");
        put("syncPendingDevices", "待确认 · 请核对设备名称", "待確認 · 請核對設備名稱", "待確認 · 請核對裝置名稱", "Pending · Verify the device name", "承認待ち · 端末名を確認してください");
        put("syncAllowName", "允许 %s 加入", "允許 %s 加入", "允許 %s 加入", "Allow %s to Join", "%s の参加を許可");
        put("syncAllowed", "已允许，请在新手机上检查确认结果", "已允許，請在新手機上檢查確認結果", "已允許，請在新手機上檢查確認結果", "Approved. Check the result on the new phone.", "承認しました。新しい端末で結果を確認してください。");
        put("syncJoinSection", "从另一台手机加入", "從另一台手機加入", "從另一台手機加入", "Join from Another Phone", "別の端末から参加");
        put("syncApplyJoin", "申请加入", "申請加入", "申請加入", "Request to Join", "参加を申請");
        put("syncCheckJoin", "检查主设备确认结果", "檢查主設備確認結果", "檢查主裝置確認結果", "Check Approval Result", "所有者端末の承認結果を確認");
        put("syncCancelJoin", "取消本机申请", "取消本機申請", "取消本機申請", "Cancel This Request", "この端末の申請をキャンセル");
        put("syncJoinCancelled", "已取消本机申请。如主设备已确认，请在主设备移除该设备。", "已取消本機申請。如主設備已確認，請在主設備移除該設備。", "已取消本機申請。如主裝置已確認，請在主裝置移除該裝置。", "This request was cancelled. If the owner already approved it, remove the device on the owner device.", "この端末の申請をキャンセルしました。所有者端末で既に承認されている場合は、所有者端末でその端末を削除してください。");
        put("syncJoinHint", "加入会新增一张卡片，不覆盖本机已有卡片。申请后，请在主设备刷新设备列表并确认。", "加入會新增一張卡片，不覆蓋本機已有卡片。申請後，請在主設備重新整理設備列表並確認。", "加入會新增一張卡片，不覆蓋本機已有卡片。申請後，請在主裝置重新整理裝置列表並確認。", "Joining adds a new card without overwriting existing cards. After requesting, refresh the device list on the owner device to approve.", "参加すると新しいカードが追加され、既存のカードは上書きされません。申請後は所有者端末で端末一覧を更新して承認してください。");
        put("syncDone", "同步完成", "同步完成", "同步完成", "Sync Complete", "同期が完了しました");
        put("syncEnabled", "已开启同步，可以生成绑定码了", "已開啟同步，可以生成綁定碼了", "已開啟同步，可以生成綁定碼了", "Sync enabled. You can now generate a binding code.", "同期を有効にしました。バインドコードを生成できます。");
        put("syncWaitingOwner", "等待主设备确认。请在主设备刷新设备列表。", "等待主設備確認。請在主設備重新整理設備列表。", "等待主裝置確認。請在主裝置重新整理裝置列表。", "Waiting for owner approval. Refresh the device list on the owner device.", "所有者端末の承認待ちです。所有者端末で端末一覧を更新してください。");
        put("syncJoined", "已加入，卡片和图片已下载", "已加入，卡片和圖片已下載", "已加入，卡片和圖片已下載", "Joined. Card and images downloaded.", "参加しました。カードと画像をダウンロードしました。");

        // 同步冲突
        put("syncConflictTitle", "两台设备都有修改", "兩台設備都有修改", "兩台裝置都有修改", "Both Devices Have Changes", "両方の端末で変更があります");
        put("syncConflictMessage", "被覆盖的修改不会合并。需要保留两份时，请先备份本机卡片。", "被覆蓋的修改不會合併。需要保留兩份時，請先備份本機卡片。", "被覆蓋的修改不會合併。需要保留兩份時，請先備份本機卡片。", "Overwritten changes are not merged. If you need to keep both, back up the local card first.", "上書きされる変更は統合されません。両方を残す必要がある場合は、先にローカルのカードをバックアップしてください。");
        put("syncConflictLater", "暂不处理", "暫不處理", "暫不處理", "Not Now", "後で");
        put("syncConflictLocal", "保留本机", "保留本機", "保留本機", "Keep Local", "ローカルを保持");
        put("syncConflictRemote", "使用云端", "使用雲端", "使用雲端", "Use Cloud", "クラウドを使用");

        // 同步错误
        put("syncErrNotEnabled", "请先开启同步", "請先開啟同步", "請先開啟同步", "Enable sync first.", "先に同期を有効にしてください。");
        put("syncErrCredentialCorrupt", "同步凭证损坏", "同步憑證損壞", "同步憑證損壞", "Sync credential is corrupted.", "同期資格情報が破損しています。");
        put("syncErrUnavailable", "同步服务暂时不可用（%s）", "同步服務暫時不可用（%s）", "同步服務暫時不可用（%s）", "Sync service unavailable (%s).", "同期サービスは現在利用できません（%s）。");
        put("syncErrResponseLarge", "同步响应过大", "同步回應過大", "同步回應過大", "Sync response too large.", "同期レスポンスが大きすぎます。");
        put("syncErrImageRead", "无法读取图片", "無法讀取圖片", "無法讀取圖片", "Could not read the image.", "画像を読み取れませんでした。");
        put("syncErrImageLarge", "图片过大，请先调整图片", "圖片過大，請先調整圖片", "圖片過大，請先調整圖片", "Image too large. Resize it first.", "画像が大きすぎます。先にサイズを調整してください。");
        put("syncErrImageMemory", "图片过大，内存不足，请调整图片后重试", "圖片過大，記憶體不足，請調整圖片後重試", "圖片過大，記憶體不足，請調整圖片後重試", "Image too large; not enough memory. Resize the image and try again.", "画像が大きすぎてメモリが不足しています。サイズを調整して再試行してください。");
        put("syncErrUploadVerify", "图片上传校验失败", "圖片上傳校驗失敗", "圖片上傳校驗失敗", "Image upload verification failed.", "画像アップロードの検証に失敗しました。");
        put("syncErrFormatUnsupported", "同步资料格式不支持", "同步資料格式不支援", "同步資料格式不支援", "Unsupported sync data format.", "同期データの形式がサポートされていません。");
        put("syncErrImageVerify", "图片校验失败，未修改本地资料", "圖片校驗失敗，未修改本地資料", "圖片校驗失敗，未修改本地資料", "Image verification failed; local data unchanged.", "画像の検証に失敗しました。ローカルデータは変更されていません。");
        put("syncErrInvalidCode", "请输入 16 位绑定码（每 4 位一组）", "請輸入 16 位綁定碼（每 4 位一組）", "請輸入 16 位綁定碼（每 4 位一組）", "Enter a 16-character binding code (4 per group).", "16桁のバインドコードを入力してください（4桁ごと）。");
        put("syncErrAuthorization", "同步授权已失效，请重新绑定设备", "同步授權已失效，請重新綁定裝置", "同步授權已失效，請重新綁定裝置", "Sync authorization has expired. Bind this device again.", "同期の認証が無効です。この端末をもう一度バインドしてください。");
        put("syncErrNotFound", "同步资料不存在，请重新绑定", "同步資料不存在，請重新綁定", "同步資料不存在，請重新綁定", "The synced data was not found. Bind this device again.", "同期データが見つかりません。もう一度バインドしてください。");
        put("syncErrImageIdInvalid", "图片编号无效", "圖片編號無效", "圖片編號無效", "Invalid image ID.", "画像IDが無効です。");

        // 公告
        put("announcementLoadFailed", "公告加载失败", "公告載入失敗", "公告載入失敗", "Couldn't Load Announcement", "お知らせを読み込めませんでした");
        put("announcementLoadFailedHint", "请检查网络连接后重试。", "請檢查網絡連線後重試。", "請檢查網路連線後重試。", "Check your connection and try again.", "接続を確認してもう一度お試しください。");
        put("retry", "重试", "重試", "重試", "Retry", "再試行");

        // 我的工单 / 支持码
        put("myTickets", "我的工单", "我的工單", "我的工單", "My Tickets", "マイチケット");
        put("myTicketsSubtitle", "查看提交进度与开发团队回复", "查看提交進度與開發團隊回覆", "查看提交進度與開發團隊回覆", "Track submissions and developer replies", "送信した報告の進捗と開発チームの返信");
        put("supportCode", "支持码", "支持碼", "支持碼", "Support Code", "サポートコード");
        put("supportCodeIs", "支持码：%s", "支持碼：%s", "支持碼：%s", "Support code: %s", "サポートコード：%s");
        put("supportCodeAssigned", "您的支持码：%s\n此码已绑定该工单；你的新支持码已自动更新，可在「我的工单」查看。", "您的支持碼：%s\n此碼已綁定該工單；你的新支持碼已自動更新，可在「我的工單」查看。", "您的支持碼：%s\n此碼已綁定該工單；你的新支援碼已自動更新，可在「我的工單」查看。", "Your support code: %s\nThis code is now bound to the ticket. A new code was issued automatically — see My Tickets.", "サポートコード：%s\nこのコードはこのチケットに紐付け済みです。新しいコードが自動発行されました。「マイチケット」で確認できます。");
        put("ticketAnonymousHint", "本次提交未绑定支持码，无法在 App 内查询进展或补充资料；可凭工单编号到网页 report.meqrcode.cn/track 查询。", "本次提交未綁定支持碼，無法在 App 內查詢進展或補充資料；可憑工單編號到網頁 report.meqrcode.cn/track 查詢。", "本次提交未綁定支援碼，無法在 App 內查詢進展或補充資訊；可憑工單編號到網頁 report.meqrcode.cn/track 查詢。", "This submission has no support code, so it can't be tracked or updated in the app. Use the ticket number at report.meqrcode.cn/track instead.", "今回の送信はサポートコードに紐付いていないため、App内での進捗確認・追加送信はできません。チケット番号で report.meqrcode.cn/track から確認してください。");
        put("ticketAttachmentTooLarge", "照片或视频超过 50 MB 上限，未上传", "照片或影片超過 50 MB 上限，未上傳", "照片或影片超過 50 MB 上限，未上傳", "Photos and videos are limited to 50 MB; nothing was uploaded.", "写真・動画は50MBまでです。アップロードされていません。");
        put("copy", "复制", "複製", "複製", "Copy", "コピー");
        put("copied", "已复制", "已複製", "已複製", "Copied", "コピーしました");
        put("ticketBlankCode", "本机支持码", "本機支持碼", "本機支持碼", "Your Support Code", "この端末のサポートコード");
        put("ticketBlankCodeHint", "在官网查询页输入此码可查工单；提交工单时会自动绑定。", "在官網查詢頁輸入此碼可查工單；提交工單時會自動綁定。", "在官網查詢頁輸入此碼可查工單；提交工單時會自動綁定。", "Enter this code on the website's status page. It's bound automatically when you submit a ticket.", "公式サイトの照会ページで入力できます。報告を送信すると自動で紐付けされます。");
        put("ticketsLoading", "载入中…", "載入中…", "載入中…", "Loading…", "読み込み中…");
        put("ticketsEmpty", "这台设备还没有工单", "這台裝置還沒有工單", "這台裝置還沒有工單", "No tickets from this device yet", "この端末からのチケットはまだありません");
        put("ticketsLoadFailed", "工单载入失败，点按重试", "工單載入失敗，點按重試", "工單載入失敗，點按重試", "Couldn't load tickets. Tap to retry.", "チケットを読み込めません。タップして再試行");
        put("ticketRefresh", "刷新", "重新整理", "重新整理", "Refresh", "更新");
        put("ticketStatusOpen", "待处理", "待處理", "待處理", "Open", "未対応");
        put("ticketStatusProcessing", "处理中", "處理中", "處理中", "Processing", "対応中");
        put("ticketStatusResolved", "已解决", "已解決", "已解決", "Resolved", "解決済み");
        put("ticketStatusClosed", "已关闭", "已關閉", "已關閉", "Closed", "完了");
        put("ticketNeedsInfo", "需要补充信息", "需要補充資料", "需要補充資訊", "Info Needed", "追加情報が必要");
        put("ticketNeedsInfoHint", "开发团队需要你补充信息后才能继续处理，请直接在下方提交。", "開發團隊需要你補充資料後才能繼續處理，請直接在下方提交。", "開發團隊需要你補充資訊後才能繼續處理，請直接在下方提交。", "The team needs more info to proceed. Submit it directly below.", "対応には追加情報が必要です。下のフォームから直接送信してください。");
        put("ticketMyMessages", "我提交的补充", "我提交的補充", "我提交的補充", "My additional information", "送信した補足情報");
        put("ticketAddInfoPlaceholder", "补充说明（2000字以内）", "補充說明（2000字以內）", "補充說明（2000字以內）", "Additional details (max 2,000 characters)", "補足説明（2000文字以内）");
        put("ticketSend", "提交补充", "提交補充", "提交補充", "Send", "送信");
        put("ticketSent", "补充资料已提交", "補充資料已提交", "補充資料已提交", "Additional information sent", "補足情報を送信しました");
        put("ticketSendFailed", "提交失败，请稍后重试", "提交失敗，請稍後重試", "提交失敗，請稍後重試", "Couldn't send. Try again later.", "送信できません。後でもう一度お試しください。");
        put("ticketAddFile", "添加照片或视频", "加入照片或影片", "加入照片或影片", "Add photo or video", "写真または動画を追加");
        put("ticketAttachmentFailed", "照片或视频上传失败，请重试", "照片或影片上傳失敗，請重試", "照片或影片上傳失敗，請重試", "Couldn't upload the photo or video. Try again.", "写真または動画をアップロードできませんでした。もう一度お試しください。");
        put("ticketReply", "开发团队回复", "開發團隊回覆", "開發團隊回覆", "Developer Reply", "開発チームからの返信");
        put("ticketNoReply", "暂无回复", "暫無回覆", "暫無回覆", "No reply yet", "返信はまだありません");
        put("ticketIdLabel", "工单号：%s", "工單號：%s", "工單號：%s", "Ticket: %s", "チケット番号：%s");
        put("ticketSubmittedAt", "提交时间：%s", "提交時間：%s", "提交時間：%s", "Submitted: %s", "送信日時：%s");
        put("ticketUpdatedAt", "更新时间：%s", "更新時間：%s", "更新時間：%s", "Updated: %s", "更新日時：%s");
        put("ticketNeedsInfoBanner", "%d 个工单需要你补充信息，点击查看", "%d 個工單需要你補充資料，點按查看", "%d 個工單需要你補充資訊，點按查看", "%d ticket(s) need more info — tap to view", "%d 件のチケットが追加情報を求めています。タップして確認");
        put("ticketUpdatedBanner", "%d 个工单状态已更新，点击查看", "%d 個工單狀態已更新，點按查看", "%d 個工單狀態已更新，點按查看", "%d ticket(s) updated — tap to view", "%d 件のチケットが更新されました。タップして確認");
    }

    String t(String key) {
        String[] translations = values.get(key);
        if (translations == null) {
            return key;
        }
        switch (resolvedLanguage()) {
            case ZH_HANT_HK:
                return translations[1];
            case ZH_HANT_TW:
                return translations[2];
            case EN:
                return translations[3];
            case JA:
                return translations[4];
            case ZH_HANS:
            default:
                return translations[0];
        }
    }

    String tf(String key, Object... args) {
        return String.format(Locale.getDefault(), t(key), args);
    }

    String languageMode() {
        return preferences.getString("language", SYSTEM);
    }

    void setLanguageMode(String mode) {
        preferences.edit().putString("language", mode).apply();
    }

    String resolvedLanguage() {
        String mode = languageMode();
        if (!SYSTEM.equals(mode)) {
            return mode;
        }
        LocaleList locales = LocaleList.getDefault();
        for (int i = 0; i < locales.size(); i++) {
            String supported = supportedLocale(locales.get(i));
            if (supported != null) {
                return supported;
            }
        }
        return EN;
    }

    String languageDisplayName(String mode) {
        switch (mode) {
            case SYSTEM:
                return t("followSystem");
            case ZH_HANS:
                return "简体中文";
            case ZH_HANT_HK:
                return "繁體中文（香港）";
            case ZH_HANT_TW:
                return "繁體中文（台灣）";
            case EN:
                return "English";
            case JA:
                return "日本語";
            default:
                return mode;
        }
    }

    private String supportedLocale(Locale locale) {
        String language = locale.getLanguage();
        if ("ja".equals(language)) {
            return JA;
        }
        if ("en".equals(language)) {
            return EN;
        }
        if ("zh".equals(language)) {
            String script = locale.getScript();
            String country = locale.getCountry();
            if ("Hans".equalsIgnoreCase(script)) {
                return ZH_HANS;
            }
            if ("Hant".equalsIgnoreCase(script)) {
                return "TW".equalsIgnoreCase(country) ? ZH_HANT_TW : ZH_HANT_HK;
            }
            if ("TW".equalsIgnoreCase(country)) {
                return ZH_HANT_TW;
            }
            if ("HK".equalsIgnoreCase(country) || "MO".equalsIgnoreCase(country)) {
                return ZH_HANT_HK;
            }
            return ZH_HANS;
        }
        return null;
    }

    private void put(String key, String zhHans, String zhHantHk, String zhHantTw, String en, String ja) {
        values.put(key, new String[]{zhHans, zhHantHk, zhHantTw, en, ja});
    }
}
