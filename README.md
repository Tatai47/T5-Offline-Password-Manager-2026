# 🔐 T5 Offline Password Manager 2026

> **A secure, local-first password manager and 2FA authenticator built with Flutter.** 🚀

T5 Offline Password Manager 2026 is a cross-platform Flutter application designed to help users store, organize, and manage their passwords without depending on a remote cloud service. The project focuses on **offline-first privacy**, a clean user experience, and convenient access to password vaults and two-factor authentication codes. 🛡️📱💻

All core data is designed to remain on the user's local device through SQLite-based storage, making the application useful in environments where privacy, local availability, or limited internet access is important. 🌐🚫

## ✨ Highlights

- 🔒 **Offline-first password storage** using a local SQLite database
- 👤 **User registration and login** functionality
- 🔢 **PIN-based quick unlock** for returning users
- 🗄️ **Multiple password vaults** for organizing credentials
- ➕ **Create, edit, view, and delete password entries**
- 🎲 **Built-in password generator** for creating stronger passwords
- 🔑 **TOTP / 2FA authenticator support** for time-based security codes
- 🧑‍💼 **Admin panel** for administrative management features
- 👤 **User profile management** with avatar support
- 🎨 **Light and dark themes** with locally persisted preferences
- 📂 **File and image picker integration** for selected profile or vault assets
- 🖥️ **Multi-platform database support** for mobile, desktop, and web environments
- 🧩 **Reusable Flutter widgets** for cards, dialogs, vault selection, and avatars

## 🧭 How It Works

1. 📝 Create an account or sign in.
2. 🗝️ Set up a secure PIN for faster access in future sessions.
3. 🗄️ Create or select a vault for your credentials.
4. ➕ Add website, application, username, password, notes, and other relevant information.
5. 🎲 Use the password generator when you need a new strong password.
6. 🔐 Add TOTP details to manage two-factor authentication codes.
7. 🔎 Browse and manage saved entries from the home screen.
8. ⚙️ Customize settings, appearance, profile information, and vault preferences.

## 🛠️ Technology Stack

| Technology | Purpose |
|---|---|
| 🎯 **Dart** | Application programming language |
| 🐦 **Flutter** | Cross-platform user interface and application framework |
| 🗃️ **SQLite / sqflite** | Local data persistence |
| 🖥️ **sqflite_common_ffi** | SQLite support for desktop platforms |
| 🌐 **sqflite_common_ffi_web** | SQLite support for web builds |
| 🔐 **crypto** | Cryptographic utilities used by the application |
| 🖼️ **image_picker** | Selecting images from supported devices |
| 📁 **file_picker** | Selecting files from the device |
| 🧭 **path / path_provider** | Platform-independent local file paths |
| 🎨 **Material Design** | Consistent Flutter interface components and styling |

## 📁 Project Structure

```text
T5-Offline-Password-Manager-2026/
├── README.md
└── flutter_application_1/
    ├── lib/
    │   ├── database/
    │   │   └── db_helper.dart              # SQLite database operations
    │   ├── models/
    │   │   ├── password_model.dart         # Password entry model
    │   │   ├── user_model.dart             # User and session model
    │   │   └── vault_model.dart            # Vault model
    │   ├── screens/
    │   │   ├── add_edit_password_screen.dart
    │   │   ├── admin_panel_screen.dart
    │   │   ├── home_screen.dart
    │   │   ├── login_screen.dart
    │   │   ├── pin_lock_screen.dart
    │   │   ├── profile_screen.dart
    │   │   ├── register_screen.dart
    │   │   └── settings_screen.dart
    │   ├── utils/
    │   │   └── app_theme.dart              # Application theme configuration
    │   ├── widgets/
    │   │   ├── create_vault_dialog.dart
    │   │   ├── password_card.dart
    │   │   ├── password_generator_dialog.dart
    │   │   ├── totp_card_widget.dart
    │   │   ├── user_avatar.dart
    │   │   ├── vault_logo_avatar.dart
    │   │   └── vault_selector_sheet.dart
    │   └── main.dart                        # Application entry point
    ├── android/                             # Android platform project
    ├── ios/                                 # iOS platform project
    ├── linux/                               # Linux platform project
    ├── macos/                               # macOS platform project
    ├── web/                                 # Web platform project
    ├── windows/                             # Windows platform project
    └── pubspec.yaml                         # Flutter dependencies and metadata
```

## 🚀 Getting Started

### ✅ Prerequisites

Install the following tools before running the project:

- 🐦 [Flutter SDK](https://docs.flutter.dev/get-started/install)
- 🎯 Dart SDK compatible with the version required in `pubspec.yaml`
- 🤖 Android Studio and/or an Android device for Android development
- 🍎 Xcode for iOS and macOS development
- 🪟 Visual Studio with desktop development tools for Windows builds
- 🐧 Required desktop dependencies for Linux builds

### 📥 Installation

```bash
# Clone the repository
git clone https://github.com/Tatai47/T5-Offline-Password-Manager-2026.git

# Enter the Flutter project directory
cd T5-Offline-Password-Manager-2026/flutter_application_1

# Install Dart and Flutter dependencies
flutter pub get
```

### ▶️ Run the Application

```bash
# Check available devices
flutter devices

# Run the application on the selected device
flutter run
```

You can also choose a specific device or platform:

```bash
flutter run -d chrome       # 🌐 Web
flutter run -d windows     # 🪟 Windows
flutter run -d macos       # 🍎 macOS
flutter run -d linux       # 🐧 Linux
```

## 📦 Build Commands

```bash
flutter build apk          # 🤖 Android APK
flutter build appbundle    # 📱 Android App Bundle
flutter build ios          # 🍎 iOS build
flutter build macos        # 🖥️ macOS build
flutter build windows      # 🪟 Windows build
flutter build linux        # 🐧 Linux build
flutter build web          # 🌐 Web build
```

## 🧪 Testing and Code Quality

Run the Flutter test suite and static analysis with:

```bash
flutter test
flutter analyze
```

For automatic code formatting:

```bash
dart format .
```

## 🔐 Privacy and Security Notes

- 📴 The application is designed around local, offline data storage.
- 🗃️ Password and vault information is managed through the local SQLite layer.
- 🔢 A saved PIN can provide a quick lock screen for returning sessions.
- 🔑 TOTP support helps users manage time-based two-factor authentication codes.
- ⚠️ Users should still protect their device, use a strong primary password and PIN, and maintain secure backups where appropriate.
- 🧠 Before using the application with real credentials, review the implementation and perform a security audit suitable for your deployment environment.

> **Important:** Offline storage improves local control and reduces cloud exposure, but the security of stored credentials also depends on the device, operating system, file permissions, backups, and the final application configuration. 🛡️

## 🌟 Main Application Areas

### 🏠 Home Screen
View saved password entries, switch between vaults, search for credentials, and access common password-management actions.

### 🔐 Password Entries
Create and edit credential records with account details, passwords, notes, and supporting information.

### 🎲 Password Generator
Generate passwords directly inside the application instead of reusing weak or predictable passwords.

### 🔑 Two-Factor Authentication
Store TOTP information and view generated time-based authentication codes when supported by the configured account data.

### 🗄️ Vault Management
Create and select separate vaults to keep personal, work, development, or other credentials organized.

### ⚙️ Settings and Appearance
Manage preferences such as the application theme and other local configuration options.

### 👤 Profile and Administration
Review profile information and access administrative features provided by the application.

## 🤝 Contributing

Contributions, suggestions, and improvements are welcome! 💡

1. 🍴 Fork the repository.
2. 🌿 Create a feature branch.
3. ✍️ Make your changes.
4. 🧪 Run `flutter analyze` and `flutter test`.
5. 📤 Open a pull request with a clear description of your contribution.

## 📄 License

No license has been specified for this repository yet. If you plan to use, modify, or distribute this project, please contact the repository owner or add an appropriate open-source license. ⚖️

## 👨‍💻 Project Information

- **Project:** T5 Offline Password Manager 2026
- **Repository:** `Tatai47/T5-Offline-Password-Manager-2026`
- **Description:** Application of Password Manager Using Flutter for offline save
- **Primary language:** Dart
- **Framework:** Flutter
- **Focus:** Local-first password management and 2FA authentication

⭐ If this project is useful to you, consider starring the repository and sharing feedback! 🚀🔐
