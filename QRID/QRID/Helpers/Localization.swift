import Foundation

struct L {
    static func tr(_ zh: String, _ en: String) -> String {
        AppSettings.shared.isChinese ? zh : en
    }

    // MainView
    static var qrID: String { tr("喜劳转扩", "喜劳转扩") }
    static var noQRCodesYet: String { tr("还没有二维码", "No QR Codes Yet") }
    static var addFirstQR: String { tr("添加你的第一个社交二维码开始使用", "Add your first social media QR code to get started.") }
    static var addQRCode: String { tr("添加二维码", "Add QR Code") }
    static var deleteProfile: String { tr("删除名片", "Delete Profile") }
    static var deleteConfirm: String { tr("确定要删除", "Are you sure you want to delete") }
    static var cancel: String { tr("取消", "Cancel") }
    static var delete: String { tr("删除", "Delete") }
    static var done: String { tr("完成", "Done") }

    // Add/Edit Profile
    static var newQRCode: String { tr("新建二维码", "New QR Code") }
    static var editQRCode: String { tr("编辑二维码", "Edit QR Code") }
    static var qrSource: String { tr("二维码来源", "QR Source") }
    static var generateFromText: String { tr("从文本生成", "Generate from Text") }
    static var importQRImage: String { tr("导入二维码图片", "Import QR Image") }
    static var selectQRImage: String { tr("选择二维码图片", "Select QR Image") }
    static var changeQRImage: String { tr("更换二维码图片", "Change QR Image") }
    static var urlOrText: String { tr("URL 或文本", "URL or text to encode") }
    static var avatar: String { tr("头像", "Avatar") }
    static var chooseAvatar: String { tr("选择头像", "Choose Avatar") }
    static var changeAvatar: String { tr("更换头像", "Change Avatar") }
    static var replaceFromQRImage: String { tr("从二维码图片替换", "Replace from QR Image") }
    static var details: String { tr("详情", "Details") }
    static var profileName: String { tr("名片名称", "Profile Name") }
    static var subtitleInfo: String { tr("副标题 / 信息（可选）", "Subtitle / Info (optional)") }
    static var platform: String { tr("平台", "Platform") }
    static var appearance: String { tr("外观", "Appearance") }
    static var textColor: String { tr("文字颜色", "Text Color") }
    static var qrCodeColor: String { tr("二维码颜色", "QR Code Color") }
    static var backgroundColor: String { tr("背景颜色", "Background Color") }
    static var cornerRadius: String { tr("圆角", "Corner Radius") }
    static var preview: String { tr("预览", "Preview") }
    static var save: String { tr("保存", "Save") }

    // Crop View
    static var cropAvatar: String { tr("裁剪头像", "Crop Avatar") }
    static var cropBackground: String { tr("裁剪背景", "Crop Background") }
    static var pinchToZoom: String { tr("双指缩放，拖动调整", "Pinch to zoom, drag to move") }
    static var choose: String { tr("选择", "Choose") }
    static var couldNotDecodeQR: String { tr("无法识别二维码", "Could Not Decode QR") }
    static var noQRFound: String { tr("图片中没有找到二维码", "No QR code found in this image.") }
    static var invalidImage: String { tr("无法处理图片", "Could not process the image.") }
    static var decodingQR: String { tr("正在识别二维码...", "Decoding QR...") }

    // Language
    static var language: String { tr("语言", "Language") }
    static var chinese: String { tr("中文", "Chinese") }
    static var english: String { tr("English", "English") }

    // Cluster
    static var newCluster: String { tr("新建合集", "New Cluster") }
    static var addToExistingCluster: String { tr("添加到现有合集", "Add to Existing Cluster") }
    static var editCluster: String { tr("编辑合集", "Edit Cluster") }
    static var deleteCluster: String { tr("删除合集", "Delete Cluster") }
    static var deleteClusterConfirm: String { tr("确定要删除整个合集及其所有二维码？", "Delete this cluster and all its QR codes?") }
    static var deleteQRFromCluster: String { tr("删除这个二维码", "Delete This QR Code") }
    static var addQRToCluster: String { tr("添加二维码", "Add QR Code") }
    static var clusterInfo: String { tr("合集信息", "Cluster Info") }
    static var clusterName: String { tr("合集名称", "Cluster Name") }
    static var sharedFieldsNote: String { tr("以下信息由合集共享，编辑请前往合集设置", "Shared by cluster. Edit in cluster settings.") }
    static var chooseAction: String { tr("选择操作", "Choose Action") }
    static var qrCodesInCluster: String { tr("合集中的二维码", "QR Codes") }
    static var noClustersYet: String { tr("还没有合集", "No Clusters Yet") }
    static var selectCluster: String { tr("选择合集", "Select Cluster") }
    static var editQRInCluster: String { tr("编辑二维码", "Edit QR Code") }
    static var singleQRCode: String { tr("单个二维码", "Single QR Code") }

    // Background Image
    static var backgroundImage: String { tr("背景图片", "Background Image") }
    static var useSolidColor: String { tr("使用纯色", "Use Solid Color") }
    static var useCustomImage: String { tr("使用自定义图片", "Use Custom Image") }
    static var removeBackgroundImage: String { tr("移除背景图片", "Remove Background Image") }
    static var cardOpacity: String { tr("卡片不透明度", "Card Opacity") }
    static var customPlatformName: String { tr("平台名称", "Platform Name") }
    static var reorderClusters: String { tr("排序合集", "Reorder Clusters") }
    static var settings: String { tr("设置", "Settings") }
    static var iCloudSync: String { tr("iCloud 同步", "iCloud Sync") }
    static var savedToPhotos: String { tr("已保存到相册", "Saved to Photos") }

    // Widget
    static var widgetSettings: String { tr("小组件设置", "Widget Settings") }
    static var widgetDisplay: String { tr("显示", "Display") }
    static var widgetBackground: String { tr("背景", "Background") }
    static var showQR: String { tr("显示 QR", "Show QR") }
    static var useClusterBackgroundColor: String { tr("使用合集背景色", "Use Cluster Background") }
    static var useCustomBackground: String { tr("使用自定义背景", "Use Custom Background") }
    static var selectBackgroundImage: String { tr("选择背景图", "Select Background Image") }
    static var removeBackground: String { tr("移除背景", "Remove Background") }
    static var opacity: String { tr("不透明度", "Opacity") }
}
