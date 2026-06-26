# 喜劳转扩（原 MeQR）
如果你是中文互联网内ACGN爱好者，请先跳过以下的部分阅读「来自开发者的碎碎念」

## 简介 / Introduction

喜劳转扩（原 MeQR）是一款 iOS 应用，帮助你管理和展示多个二维码。你可以将多个二维码归类到一个合集（Cluster）中，每个合集都有独立的名称、头像、背景和样式。无论是社交账号、支付码还是其他二维码，都可以一站式管理。

喜劳转扩 (formerly MeQR) is an iOS app that helps you manage and display multiple QR codes. You can group multiple QR codes into a single cluster, each with its own name, avatar, background, and style. Whether it's social media accounts, payment codes, or other QR codes, you can manage them all in one place.

## 功能 / Features

- **合集管理 / Cluster Management**: 将多个二维码归类到一个合集中，支持自定义名称、副标题和头像。Group multiple QR codes into a single cluster with custom name, subtitle, and avatar.
- **二维码统一颜色 / Unified QR Color**: 在合集级别设置所有二维码的颜色，无需逐个修改。Set a unified color for all QR codes at the cluster level without modifying each one individually.
- **自定义样式 / Custom Styling**: 支持自定义背景颜色、文字颜色、卡片透明度、圆角半径，以及上传背景图片和头像。Supports custom background color, text color, card opacity, corner radius, and uploading background images and avatars.
- **背景裁剪 / Background Crop**: 上传图片后支持手势缩放和拖动裁剪，确保背景显示效果最佳。Supports gesture zoom and pan cropping after uploading an image for the best background display.
- **拖拽排序 / Drag-to-Reorder**: 长按合集卡片，拖拽调整合集的展示顺序。Long-press a cluster card to drag and reorder clusters.
- **分享卡片 / Share Card**: 将合集卡片保存为图片到相册，方便分享给他人。Save cluster cards as images to your photo library for easy sharing.

## 技术栈 / Tech Stack

- SwiftUI
- SwiftData（本地数据持久化 / Local data persistence）
- PhotosUI（头像和背景图片选择 / Avatar and background image selection）
- Core Image / Core Graphics（二维码生成与裁剪 / QR code generation and image cropping）

## 兼容性 / Compatibility
- iOS 17+
- iPhone 和 iPad

## 安装 / Installation

1. 克隆仓库 / Clone the repository:
   ```bash
   git clone https://github.com/Rebirth39/MeQR.git
   ```
2. 在 Xcode 中打开 `QRID.xcodeproj`。Open `QRID.xcodeproj` in Xcode.
3. 在 **Signing & Capabilities** 中选择你的 Apple Development Team，并将 Bundle Identifier 修改为你自己的。Select your Apple Development Team in **Signing & Capabilities**, and change the Bundle Identifier to your own.
4. 编译并运行到真机或模拟器；完整构建验证需要 Xcode。Build and run on a physical device or simulator; full build verification requires Xcode.

## 隐私 / Privacy
喜劳转扩（原 MeQR）所有数据均存储在本地，不上传至任何服务器，无需网络权限。

All data in 喜劳转扩 (formerly MeQR) is stored locally and is not uploaded to any server. No network permissions are required.


## 作者 / Author
重生Rebirth


# 来自开发者的碎碎念
老师们好这里是重生！也是这个App的开发者！

这个App其实是我用一周时间用Kimi开发出来的（笑）所以还有点buggy，但我也在修改了

目前只支持iOS……绝对不是因为这个软件其实是为了让我能在线下扩列的时候展示用的（笑）后续应该会支持安卓！

如果对这个项目感兴趣的话可以来扩列呀：QQID **Rebirth39** 可直搜 

感谢你读到这里:) 现在你可以上去读软件概要了
