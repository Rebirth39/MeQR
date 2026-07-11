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
