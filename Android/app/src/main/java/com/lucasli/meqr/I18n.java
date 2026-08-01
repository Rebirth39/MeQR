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
        put("save", "保存", "儲存", "儲存", "Save", "保存");
        put("done", "完成", "完成", "完成", "Done", "完了");
        put("ok", "好", "好", "好", "OK", "OK");
        put("share", "分享", "分享", "分享", "Share", "共有");
        put("meqrProfileCode", "MeQR 交换码", "MeQR 交換碼", "MeQR 交換碼", "MeQR Profile Code", "MeQR 交換コード");
        put("saveMeQrCode", "保存交换码到相册", "儲存交換碼到相簿", "儲存交換碼到照片", "Save Code to Photos", "交換コードを写真に保存");
        put("meqrCodeHint", "对方用 MeQR 扫这个码，就能看到你的这张扩列卡。", "對方用 MeQR 掃這個碼，就能看到你的這張擴列卡。", "對方用 MeQR 掃描這個碼，就能看到你的這張擴列卡。", "Someone can scan this with MeQR to read your profile.", "相手がMeQRでこのコードを読み取ると、あなたのプロフィールを表示できます。");
        put("meqrLocalReady", "本地交换码：不会上传资料，扫码直接读取。", "本地交換碼：不會上傳資料，掃碼直接讀取。", "本地交換碼：不會上傳資料，掃碼直接讀取。", "Local code: no upload, scan to read directly.", "ローカルコード：アップロードせず、スキャンして直接読み取ります。");
        put("meqrPreparingOnline", "正在生成在线交换码…", "正在產生線上交換碼…", "正在產生線上交換碼…", "Creating online exchange code…", "オンライン交換コードを作成中…");
        put("meqrOnlineReady", "在线交换码已生成；没网时会用离线内容兜底。", "線上交換碼已產生；無網時會用離線內容備用。", "線上交換碼已產生；沒網時會用離線內容備用。", "Online code ready, with offline fallback inside.", "オンラインコード作成済み。オフライン時の予備情報も入っています。");
        put("meqrOnlineFallback", "在线生成失败，已切换成本地离线交换码。", "線上產生失敗，已切換成本地離線交換碼。", "線上產生失敗，已切換成本地離線交換碼。", "Online upload failed; using the local offline code.", "オンライン作成に失敗したため、ローカルのオフラインコードを使用します。");
        put("meqrCodeFailed", "交换码生成失败", "交換碼產生失敗", "交換碼產生失敗", "Could not create MeQR code.", "交換コードを作成できません。");
        put("saved", "已保存到相册", "已儲存到相簿", "已儲存到照片", "Saved to Photos", "写真に保存しました");
        put("saveFailed", "无法保存，请重试。", "無法儲存，請再試一次。", "無法儲存，請再試一次。", "Please try again.", "もう一度お試しください。");
        put("emptyTitle", "还没有二维码", "還沒有 QR Code", "還沒有 QR Code", "No QR Codes Yet", "QRコードがまだありません");
        put("emptyBody", "添加你的第一个社交二维码开始使用", "加入你的第一個社交 QR Code 開始使用", "加入你的第一個社群 QR Code 開始使用", "Add your first social QR code to get started.", "最初のSNS用QRコードを追加して始めましょう。");
        put("newProfile", "新建 Profile", "新增 Profile", "新增 Profile", "New Profile", "新規プロフィール");
        put("editProfile", "编辑 Profile", "編輯 Profile", "編輯 Profile", "Edit Profile", "プロフィールを編集");
        put("profileName", "Profile 名称", "Profile 名稱", "Profile 名稱", "Profile Name", "プロフィール名");
        put("bio", "介绍", "介紹", "介紹", "Bio / Intro", "紹介");
        put("viewBack", "查看介绍", "查看介紹", "查看介紹", "View Intro", "紹介を見る");
        put("viewFront", "返回正面", "返回正面", "返回正面", "View Front", "表面に戻る");
        put("bioEmpty", "还没有填写介绍", "尚未填寫介紹", "尚未填寫介紹", "No introduction yet", "紹介はまだありません");
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
        put("preview", "预览", "預覽", "預覽", "Preview", "プレビュー");
        put("template", "卡片模板", "卡片模板", "卡片模板", "Card Template", "カードテンプレート");
        put("standardTemplate", "标准卡片", "標準卡片", "標準卡片", "Standard", "スタンダード");
        put("rhodesTemplate", "明日方舟通行证", "明日方舟通行證", "明日方舟通行證", "Rhodes Pass", "ロドス通行証");
        put("platformCards", "平台卡片", "平台卡片", "平台卡片", "Platform Cards", "プラットフォームカード");
        put("addPlatform", "添加平台", "加入平台", "新增平台", "Add Platform", "プラットフォームを追加");
        put("importQrImage", "从图片识别二维码", "從圖片識別 QR Code", "從圖片辨識 QR Code", "Import QR Image", "QR画像を読み込む");
        put("qrDecodeFailed", "没有识别到二维码", "未能識別 QR Code", "無法辨識 QR Code", "No QR code found", "QRコードを認識できませんでした");
        put("tags", "标签", "標籤", "標籤", "Tags", "タグ");
        put("tagsHint", "每行一个，最多 10 个", "每行一個，最多 10 個", "每行一個，最多 10 個", "One per line, up to 10", "1行に1つ、最大10個");
        put("setupWelcome", "从一张属于你的扩列卡开始", "從一張屬於你的擴列卡開始", "從一張屬於你的擴列卡開始", "Start with a card that is yours", "自分だけのカードから始めよう");
        put("setupWelcomeBody", "我们会逐步完成昵称、二维码、外观与标签。完成前不会保存任何草稿。", "我們會逐步完成暱稱、QR Code、外觀與標籤。完成前不會儲存任何草稿。", "我們會逐步完成暱稱、QR Code、外觀與標籤。完成前不會儲存任何草稿。", "Set up your identity, QR codes, appearance, and tags step by step. Nothing is saved until you finish.", "名前、QRコード、外観、タグを順番に設定します。完了するまで下書きは保存されません。");
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
        put("setupEnter", "进入喜劳转扩", "進入喜勞轉擴", "進入喜勞轉擴", "Enter MeQR", "喜劳转扩を始める");
        put("continue", "继续", "繼續", "繼續", "Continue", "続ける");
        put("back", "返回", "返回", "返回", "Back", "戻る");
        put("finishSetup", "完成建档", "完成建檔", "完成建檔", "Finish Setup", "設定を完了");
        put("replaySetup", "重新体验首次建档", "重新體驗首次建檔", "重新體驗首次建檔", "Replay Setup Guide", "初回設定をやり直す");
        put("nameRequired", "请先填写昵称", "請先填寫暱稱", "請先填寫暱稱", "Please enter a name", "名前を入力してください");
        put("reorder", "排序", "排序", "排序", "Reorder", "並べ替え");
        put("moveUp", "上移", "上移", "上移", "Move Up", "上へ");
        put("moveDown", "下移", "下移", "下移", "Move Down", "下へ");
        put("deleteConfirm", "确定要删除这个 Profile？", "確定要刪除這個 Profile？", "確定要刪除這個 Profile？", "Delete this profile?", "このプロフィールを削除しますか？");
        put("settings", "更多设置", "更多設定", "更多設定", "More Settings", "その他の設定");
        put("language", "语言", "語言", "語言", "Language", "言語");
        put("followSystem", "跟随系统", "跟隨系統", "跟隨系統", "Follow System", "システムに合わせる");
        put("restartNotice", "部分新语言资源可能需要重启软件才能生效", "部分新語言資源可能需要重新啟動軟件才能生效", "部分新語言資源可能需要重新啟動軟體才能生效", "Some new language resources may require restarting the app to take effect.", "一部の新しい言語リソースは、アプリの再起動後に反映される場合があります。");
        put("about", "关于软件", "關於軟件", "關於 App", "About", "このアプリについて");
        put("privacy", "隐私政策", "私隱政策", "隱私權政策", "Privacy Policy (English)", "プライバシーポリシー（英語）");
        put("version", "版本", "版本", "版本", "Version", "バージョン");
        put("github", "GitHub 项目页面", "GitHub 項目頁面", "GitHub 專案頁面", "GitHub Project", "GitHubプロジェクト");
        put("contact", "联系开发者", "聯絡開發者", "聯絡開發者", "Contact Developer", "開発者に連絡");
        put("developerIntro", "开发者介绍", "開發者介紹", "開發者介紹", "Developer Intro", "開発者紹介");
        put("developerStudent", "目前高中就读 初⚪︎未来重度依赖（）", "目前高中就讀 初⚪︎未來重度依賴（）", "目前高中就讀 初⚪︎未來重度依賴（）", "High school student, heavily dependent on Hat⚪︎ne Miku.", "高校生です。初⚪︎ミクにかなり依存しています。");
        put("developerMadeForFun", "抱着玩一下的心态开发了这款软件", "抱着玩一下的心態開發了這款軟件", "抱著玩一下的心態開發了這款 App", "I started this app just for fun", "遊び半分でこのアプリを作り始めました");
        put("developerUnexpected", "没想到后面功能越加越多", "沒想到後面功能越加越多", "沒想到後來功能越加越多", "then somehow kept adding more features", "気づいたら機能がどんどん増えていました");
        put("developerHope", "希望大家喜欢:)", "希望大家喜歡:)", "希望大家喜歡:)", "Hope you like it :)", "気に入ってもらえたらうれしいです :)");
        put("scanMeQr", "扫描 MeQR 交换码", "掃描 MeQR 交換碼", "掃描 MeQR 交換碼", "Scan MeQR Code", "MeQRコードをスキャン");
        put("scanMeQrHint", "对准二维码，自动识别 MeQR 交换码", "對準 QR Code，自動辨識 MeQR 交換碼", "對準 QR Code，自動辨識 MeQR 交換碼", "Point the camera at a MeQR code to scan it", "カメラをMeQRコードに向けてください");
        put("importFromPhoto", "从相册导入", "從相簿匯入", "從相簿匯入", "Import from Photos", "写真から読み込む");
        put("couldNotDecode", "无法识别这个二维码", "無法辨識這個 QR Code", "無法辨識這個 QR Code", "Could not read this QR code", "このQRコードを読み取れません");
        put("notMeQrCode", "这不是 MeQR 交换码", "這不是 MeQR 交換碼", "這不是 MeQR 交換碼", "This is not a MeQR profile code", "これはMeQR交換コードではありません");
        put("cameraPermissionNeeded", "需要相机权限才能扫码", "需要相機權限才能掃碼", "需要相機權限才能掃碼", "Camera permission is required to scan", "スキャンにはカメラ権限が必要です");
        put("meqrProfileFound", "发现 MeQR 名片", "發現 MeQR 名片", "發現 MeQR 名片", "MeQR Profile Found", "MeQRプロフィールを検出");
        put("saveEncounter", "保存到认识记录", "儲存到認識記錄", "儲存到認識記錄", "Save Encounter", "認識記録に保存");
        put("savedEncounter", "已保存到认识记录", "已儲存到認識記錄", "已儲存到認識記錄", "Saved to Encounters", "認識記録に保存しました");
        put("encounters", "认识记录", "認識記錄", "認識記錄", "Encounters", "認識記録");
        put("noEncounters", "还没有认识记录", "還沒有認識記錄", "還沒有認識記錄", "No Encounters Yet", "認識記録はまだありません");
        put("noEncountersHint", "扫描交换码后，把对方保存到这里。", "掃描交換碼後，把對方儲存在這裡。", "掃描交換碼後，把對方儲存在這裡。", "Scan a MeQR code and save the person here.", "交換コードを読み取ると、ここに相手を保存できます。");
        put("unknownContact", "未命名联系人", "未命名聯絡人", "未命名聯絡人", "Unknown Contact", "名前未設定の相手");
        put("platformsFromMeQr", "来自 MeQR 的平台", "來自 MeQR 的平台", "來自 MeQR 的平台", "Platforms from MeQR", "MeQRからのプラットフォーム");
        put("openLink", "打开链接", "開啟連結", "開啟連結", "Open Link", "リンクを開く");
        put("activeEvent", "当前活动", "目前活動", "目前活動", "Active Event", "現在のイベント");
        put("noActiveEvent", "未选择活动", "未選擇活動", "未選擇活動", "No Active Event", "イベント未選択");
        put("events", "活动", "活動", "活動", "Events", "イベント");
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
        put("deleteEncounterConfirm", "确定删除这条认识记录？删除后无法恢复。", "確定刪除這條認識記錄？刪除後無法復原。", "確定刪除這條認識記錄？刪除後無法復原。", "Delete this encounter? This cannot be undone.", "この認識記録を削除しますか？元に戻せません。");
        put("tagColors", "标签配色", "標籤配色", "標籤配色", "Tag Colors", "タグの色");
        put("tagColorsHint", "输入标签后，可在这里为每个标签单独配色", "輸入標籤後，可在這裡為每個標籤單獨配色", "輸入標籤後，可在這裡為每個標籤單獨配色", "Add tags above, then customize each tag color here", "タグを追加すると、ここで個別の色を設定できます");
        put("tagLibrary", "从 Tag 库添加", "從 Tag 庫加入", "從 Tag 庫新增", "Add from Tag Library", "Tagライブラリから追加");
        put("searchTags", "搜索作品、组合或角色", "搜尋作品、組合或角色", "搜尋作品、組合或角色", "Search series, groups, or characters", "作品・ユニット・キャラクターを検索");
        put("tagLibraryHint", "点按即可添加，支持中英日名称与常用简称", "點按即可加入，支援中英日名稱與常用簡稱", "點按即可新增，支援中英日名稱與常用簡稱", "Tap to add. Names and common aliases are searchable.", "タップで追加。名前と略称で検索できます。");
        put("tagLimitReached", "最多添加 10 个 Tag", "最多加入 10 個 Tag", "最多新增 10 個 Tag", "Up to 10 tags", "Tagは最大10個です");
        put("editTagColors", "编辑拼色", "編輯拼色", "編輯拼色", "Edit Colors", "配色を編集");
        put("solidColor", "纯色", "純色", "純色", "Solid", "単色");
        put("mixedColor", "拼色", "拼色", "拼色", "Mixed", "多色");
        put("builtInMix", "恢复内置拼色", "恢復內建拼色", "恢復內建拼色", "Restore Built-in Mix", "プリセット配色に戻す");
        put("addColor", "增加颜色", "增加顏色", "增加顏色", "Add Color", "色を追加");
        put("color", "颜色", "顏色", "顏色", "Color", "色");
        put("choosePresetColor", "选择预设颜色", "選擇預設顏色", "選擇預設顏色", "Choose Preset Color", "プリセット色を選択");
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
        put("twitter", "X (推特)", "X (Twitter)", "X (Twitter)", "X (Twitter)", "X（Twitter）");
        put("email", "邮箱", "電郵", "電子郵件", "Email", "メール");
        put("phone", "电话", "電話", "電話", "Phone", "電話");
        put("custom", "自定义", "自訂", "自訂", "Custom", "カスタム");
        put("xiaohongshu", "小红书", "小紅書", "小紅書", "Xiaohongshu", "小紅書");
        put("bilibili", "B站", "B站", "B站", "Bilibili", "Bilibili");
        put("douyinTikTok", "抖音", "抖音", "TikTok", "TikTok", "TikTok");
        put("weibo", "微博", "微博", "微博", "Weibo", "微博");
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

    String languageMode() {
        return preferences.getString("language", ZH_HANS);
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
