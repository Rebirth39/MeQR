# MeQR Android

Native Android adaptation of MeQR. This project is intentionally separate from the iOS codebase.

Implemented in this first Android version:

- Create profile cards with avatar, intro text, appearance settings, background image, platform, and QR content.
- Edit, reorder, and delete profiles.
- Generate QR codes with ZXing Core.
- Share a rendered profile card; sharing first saves the image to the system photo gallery.
- Multilingual UI: Follow System, Simplified Chinese, Traditional Chinese (Hong Kong), Traditional Chinese (Taiwan), English, and Japanese.
- About screen with GitHub, privacy policy, email, and QID links.

Build notes:

- Open `/Users/lucasli/MeQR_for_push_Android` in Android Studio and sync Gradle.
- The project uses Android Gradle Plugin `8.6.1`, `compileSdk 35`, `minSdk 26`.
- The only external dependency is `com.google.zxing:core:3.5.3`.

Current limitations:

- This is the first native Android pass, so the UI is functional and native but not yet visually polished to the same level as the iOS version.
- Avatar/background cropping and QR image decoding are not implemented yet; images can be selected and copied into app storage.
- Android widget support is not included in this first pass.
