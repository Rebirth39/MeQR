# MeQR Android

Native Android adaptation of MeQR. This project is intentionally separate from the iOS codebase.

Implemented in Android 1.0.3 (4):

- Create multi-platform profile cards with avatar, intro text, appearance settings, background image, tags, and multiple QR entries.
- Switch between the standard card and Rhodes-style pass templates. The home screen, editor, onboarding, and shared image use the same production renderer.
- First-use setup now shares the iOS visual language: a dedicated welcome composition, five numbered setup stages, a persistent progress header and bottom action bar, production-card preview, and a separate completion screen. Drafts are only saved after confirmation, and the guide can be replayed from Settings.
- Import and decode QR codes from images with ZXing, with automatic platform detection where possible.
- Edit, reorder, and delete profiles.
- Generate QR codes with ZXing Core.
- Share a rendered profile card; sharing first saves the image to the system photo gallery.
- Crop selected avatar and background images before saving them to app storage.
- Generate a MeQR exchange code locally, then upgrade it to an online code after the selected profile uploads successfully; the offline fallback remains available if upload fails.
- Scan MeQR exchange codes with the camera, or import a QR image from the photo library. Local payloads, hybrid online/offline URLs, and remote profiles are decoded automatically.
- Save scanned people into Encounter Records with their name, intro, avatar, and shared platforms; add notes, tags, follow-up status, photo-return and freebie flags, and attach each record to an active event.
- Events: choose the default offline-expansion event, create custom events, or refresh remote events from the MeQR API; the active event is attached to newly saved encounters.
- Tag colors: the card tag index assigns project/IP colors (Vocaloid/Miku, Project Sekai units, MyGO!!!!!, Arknights, and more), and every tag can be recolored individually in the editor.
- Rhodes pass cards support a separate horizontal banner image on top of the vertical background image.
- Backup all card data (profiles.json plus images) to a zip file, and restore from a backup zip; the current data is kept as a pre-restore copy before import.
- Multilingual UI: Follow System, Simplified Chinese, Traditional Chinese (Hong Kong), Traditional Chinese (Taiwan), English, and Japanese.
- About screen with GitHub, privacy policy, email, and QID links.

Build notes:

- Open `/Users/lucasli/MeQR_for_push_Android` in Android Studio and sync Gradle.
- The project uses Android Gradle Plugin `8.6.1`, `compileSdk 35`, `minSdk 26`.
- The only external dependency is `com.google.zxing:core:3.5.3`.

Current limitations:

- Android widget support is not included in this first pass.
- Existing single-platform JSON is migrated automatically into the first QR entry. New saves retain legacy mirror fields for backward compatibility.
- Android widget support and the iOS widget preview are not included yet.

Privacy and network behavior:

- Profile cards are stored locally as JSON, with selected images copied into app storage.
- Creating an online MeQR exchange code uploads the selected profile data to the MeQR API. The app keeps a compact offline fallback in the generated code.
- The app does not include advertising or analytics SDKs.
