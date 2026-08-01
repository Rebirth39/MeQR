# 喜劳转扩（原 MeQR）
如果你是中文互联网内ACGN爱好者，请先跳过以下的部分阅读「来自开发者的碎碎念」

## 简介 / Introduction

喜劳转扩（原 MeQR）是一款面向线下扩列和同好活动场景的二维码名片管理与展示工具。你可以将多个平台二维码归类到一张卡片中，为卡片设置名称、头像、背景、模板和标签，并通过 MeQR 交换码分享你主动选择的资料。

喜劳转扩 (formerly MeQR) is a QR profile manager designed for in-person social and fan-event scenarios. You can group multiple platform QR codes into one card, customize its profile, templates, and tags, and share selected information through a MeQR exchange code.

## 功能 / Features

- **卡片管理 / Card Management**: 将多个二维码归类到一张卡片中，支持自定义名称、介绍、头像和标签。Group multiple QR codes into one card with a custom name, description, avatar, and tags.
- **卡片模板 / Card Templates**: 支持标准卡片和明日方舟通行证风格，并可设置标签颜色。Choose between the standard card and Rhodes-pass style, with customizable tag colors.
- **二维码统一颜色 / Unified QR Color**: 在卡片级别设置所有二维码的颜色，无需逐个修改。Set one QR color for all codes on a card.
- **自定义样式 / Custom Styling**: 支持自定义背景颜色、文字颜色、卡片透明度、圆角半径，以及上传背景图片和头像。Supports custom background color, text color, card opacity, corner radius, and uploading background images and avatars.
- **背景裁剪 / Background Crop**: 上传图片后支持手势缩放和拖动裁剪，确保背景显示效果最佳。Supports gesture zoom and pan cropping after uploading an image for the best background display.
- **二维码导入 / QR Import**: 支持从已有二维码图片中识别并导入内容。Import QR content by decoding existing QR images.
- **小组件支持 / Widget Support**: 支持桌面小组件和锁屏圆形小组件，并可自定义背景与显示内容。Supports Home Screen widgets and a circular lock screen widget with configurable background and display content.
- **拖拽排序 / Drag-to-Reorder**: 调整卡片的展示顺序。Reorder cards in the app.
- **分享卡片 / Share Card**: 将卡片保存为图片到相册，方便分享给他人。Save cards as images to your photo library.
- **MeQR 交换码 / MeQR Exchange Codes**: 生成带离线备用资料的在线交换码，扫描后可读取分享资料并保存认识记录。Generate online exchange codes with an offline fallback, scan shared profiles, and save encounter records.
- **活动模式 / Event Mode**: 选择或创建线下活动，并将活动信息关联到认识记录。Select or create an event and associate it with encounter records.
- **本地备份 / Local Backup**: 数据变更后生成本地备份，便于恢复卡片资料。Create local backups after data changes for recovery.

## 平台 / Platforms

- **iOS**: 主线版本位于 `main` 分支。The main iOS version lives on the `main` branch.
- **Android**: 原生 Android 适配版本位于 `android-native` 分支的 `Android/` 目录，目前仍在早期适配中。The native Android adaptation lives in `Android/` on the `android-native` branch and is still in early adaptation.

## 技术栈 / Tech Stack

### iOS

- SwiftUI
- SwiftData（本地数据持久化 / Local data persistence）
- WidgetKit（桌面 / 锁屏小组件 / Home Screen and Lock Screen widgets）
- PhotosUI（头像和背景图片选择 / Avatar and background image selection）
- Core Image / Core Graphics（二维码生成与裁剪 / QR code generation and image cropping）

### Android

- Native Android
- Java
- ZXing Core（二维码生成 / QR code generation）
- Local JSON storage（本地数据存储 / Local data storage）

## 兼容性 / Compatibility

### iOS

- iOS 17.0+
- iPhone only

### Android

- Android 8.0+ / API 26+
- Android version is currently experimental

## 当前状态 / Current Status

- 当前版本采用本地优先的数据存储方式；卡片、二维码和认识记录主要保存在设备本地。The app is local-first; cards, QR codes, and encounter records are primarily stored on device.
- 使用在线 MeQR 交换码时，App 会将用户主动选择分享的资料上传到服务器；活动列表也会从服务器刷新。Online exchange codes upload only the profile data selected for sharing, and the event list can be refreshed from the server.
- MeQR 交换码包含精简的离线备用资料，网络不可用时仍可显示基本信息。Exchange codes include a compact offline fallback for basic information when the network is unavailable.
- iCloud 同步尚未上线；当前备份为本地备份。iCloud sync is not available; current backups are local.
- Widget Extension 已包含在项目中。The Widget Extension is included in the project.
- Android 版本正在原生适配中，和 iOS 主线分支分开维护。The Android version is being adapted natively and is maintained separately from the iOS main branch.

## 安装 / Installation

### iOS

1. 克隆仓库 / Clone the repository:
   ```bash
   git clone https://github.com/Rebirth39/MeQR.git
   ```
2. 在 Xcode 中打开 `QRID.xcodeproj`。Open `QRID.xcodeproj` in Xcode.
3. 在 **Signing & Capabilities** 中选择你的 Apple Development Team，并将 Bundle Identifier 修改为你自己的。Select your Apple Development Team in **Signing & Capabilities**, and change the Bundle Identifier to your own.
4. 如需使用小组件，请确认 App Group、Signing 与 Widget Extension 配置正确。If you want widget support, make sure App Group, signing, and the Widget Extension are configured correctly.
5. 编译并运行到真机或模拟器；完整构建验证需要 Xcode。Build and run on a physical device or simulator; full build verification requires Xcode.

### Android

Android 版本位于单独分支：

```bash
git checkout android-native
cd Android
```

然后用 Android Studio 打开 `Android/` 目录，或在配置好 Android SDK 后运行：

```bash
./gradlew assembleDebug
```

## 隐私 / Privacy
卡片、二维码和认识记录通常保存在设备本地。只有在用户主动生成在线 MeQR 交换码时，所选择的名称、介绍、头像及平台资料才会上传，用于让其他用户读取该交换码。App 不包含广告 SDK、第三方统计 SDK或跨 App 追踪。

Cards, QR codes, and encounter records are generally stored on device. When the user explicitly creates an online MeQR exchange code, the selected name, description, avatar, and platform data are uploaded so other users can retrieve that shared profile. The app contains no advertising SDKs, third-party analytics SDKs, or cross-app tracking.

Privacy Policy URL:
https://rebirth39.github.io/MeQR/privacy.html


## 作者 / Author
重生Rebirth


# 来自开发者的碎碎念
老师们好这里是重生！也是这个软件的开发者！

这个软件最开始其实是我用一周时间用 Kimi 开发出来的（笑）所以还有点 buggy，但我也在修改了

目前 iOS 版是主线，Android 原生适配也已经开始了，单独放在 `android-native` 分支里……绝对不是因为这个软件其实是为了让我能在线下扩列的时候展示用的（笑）

如果对这个项目感兴趣的话可以来扩列呀：QQID **Rebirth39** 可直搜 

感谢你读到这里:) 现在你可以上去读软件概要了
