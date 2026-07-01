# MeTube

A lightweight, high-performance, cross-platform YouTube Cast Leanback Receiver built from scratch using Flutter. It transforms any Desktop (macOS, Linux, Windows) or Mobile device into a dedicated Smart TV target, allowing you to cast videos seamlessly from your phone's official YouTube app over local Wi-Fi or using a pairing code.

---

## Features

- **Zero-Friction Wi-Fi Casting (DIAL Protocol):** Implements a native SSDP multicast discovery engine and a background HTTP REST server. Your phone detects it instantly under the standard Cast menu.
- **Persistent Sessions:** Automatically saves cookies, local storage states, and device link tokens to disk across app restarts.
- **Native Desktop Edge-to-Edge Fullscreen:** Launches directly into true borderless fullscreen on desktop platforms, hiding standard window decorations and system top-bars.
- **Lightweight Core:** Wraps the official high-fidelity YouTube TV interface cleanly without heavy external web dependencies.

---

## Prerequisites & Large Files

This repository uses **Git LFS (Large File Storage)** to track large assets, pre-compiled platform libraries, or heavy graphics.

Before cloning, ensure you have Git LFS installed on your machine. If not, install it using your package manager:

```bash
# macOS (Homebrew)
brew install git-lfs

# Ubuntu/Debian
sudo apt-get install git-lfs

# Windows (Winget)
winget install GitHub.GitLFS

```

Initialize Git LFS globally once:

```bash
git lfs install

```

---

## Getting Started

### 1. Clone the Repository

Clone the repository normally. Git LFS will automatically pull down the actual asset pointer files during the process:

```bash
git clone https://github.com/your-username/metube.git
cd metube

```

### 2. Install Flutter Dependencies

Pull down the project package dependencies (including window management and platform webview hooks):

```bash
flutter pub get

```

### 3. Run the Application Localy

Ensure your target testing device or environment is connected, then run:

```bash
# Run on macOS desktop
flutter run -d macos

# Run on Linux desktop
flutter run -d linux

# Run on Android device
flutter run -d android

```

### 4. Build the Release Payload

To compile standalone, optimized production binaries:

```bash
# Compile Android APK
flutter build apk --release

# Compile macOS App Bundle
flutter build macos --release

# Compile Linux Application
flutter build linux --release

```

---

## How to Link & Cast

MeTube Receiver gives you two seamless methods to hook up your smartphone as a physical remote control. **Ensure both your phone and the MeTube platform are connected to the exact same Wi-Fi subnet.**

### Method A: Direct Link with Wi-Fi (Recommended)

1. Launch the MeTube Receiver app on your computer or Android device.
2. Open the official **YouTube app** on your iOS or Android phone.
3. Tap the **Cast icon** (the streaming screen symbol) at the top of the YouTube app.
4. Select **"MeTube"** from the discovered local device drawer.
5. The background DIAL engine instantly performs a handshake, mapping your phone directly to the front-end frame automatically!

### Method B: Link with TV Code

1. If your local network configuration drops multicast UDP packets, navigate manually inside the MeTube interface to **Settings $\rightarrow$ Link with TV Code**.
2. A blue 12-digit code will populate on screen.
3. Open your phone's YouTube app, go to **Settings $\rightarrow$ General $\rightarrow$ Watch on TV**, and tap **Enter TV Code**.
4. Type in the numbers. Your session will lock in place and save to disk securely for all future launches.
