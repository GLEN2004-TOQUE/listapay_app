# listapay

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Create Android emulator (Windows)

### Option A: Android Studio (GUI)
1. Open **Android Studio** → **Tools** → **Device Manager**.
2. Click **Create device**.
3. Choose a device (e.g. Pixel 7).
4. Select a system image such as **Google APIs** (x86_64) and download it.
5. Click **Finish**.

### Option B: CLI (scripts)
This repo includes scripts to install emulator tooling, create an AVD, and start it.

**Prerequisites:**
1. Open **Android Studio** -> **Settings** -> **Languages & Frameworks** -> **Android SDK**.
2. Go to the **SDK Tools** tab.
3. Check **Android SDK Command-line Tools (latest)** and click **Apply**.
   - This provides `avdmanager` and `sdkmanager` used by the scripts.

1. Ensure `ANDROID_SDK_ROOT` is set, e.g. in a terminal:
   - `set ANDROID_SDK_ROOT=C:\\Users\\<you>\\AppData\\Local\\Android\\Sdk`
2. Run:
   - `scripts\create-android-emulator.bat`
3. Then run your app on the emulator:
   - `flutter run -d emulator`
   - or `flutter devices` to find the exact emulator id.

## Create iOS simulator (macOS)

1. Install **Xcode** from the App Store.
2. Open Xcode and go to **Settings** -> **Platforms** to download an iOS version.
3. Run the simulator via terminal:
   - `open -a Simulator`
4. Run your app:
   - `flutter run`

Notes:
- The script targets an AVD named `listapay_api34` by default.
- `scripts/create-android-emulator.bat` will try to locate `cmdline-tools` automatically (so `avdmanager.bat` doesn’t have to be in `cmdline-tools\latest`).
- If your `ANDROID_SDK_ROOT` is wrong, set it correctly before running the scripts.
