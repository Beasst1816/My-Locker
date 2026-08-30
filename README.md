# Student Locker 🔐

A Flutter-based digital locker management system that generates unique QR codes for students using Firebase for authentication and data storage.

## 📥 Try It

Download **`mylocker.apk`** from the [Releases](../../releases) tab and sideload it onto an Android device.

> ⚠️ **Note:** This is an early build — not yet production-ready, so expect rough edges and possible bugs.

## 🚀 Features

- **Splash Screen**: Intelligent session management to auto-login returning users.
- **Secure Authentication**: Firebase Email/Password authentication.
- **Cloud Database**: Student profiles (Name, Email, Enrollment) stored in Cloud Firestore.
- **QR Generation**: Unique QR codes generated based on student enrollment numbers for easy scanning.
- **Persistence**: Local session handling using `shared_preferences`.
- **Modern UI**: Clean, responsive Material Design interface.

## 🛠️ Tech Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Firebase Authentication & Cloud Firestore
- **Local Storage**: Shared Preferences
- **Packages**:
  - `firebase_core`
  - `firebase_auth`
  - `cloud_firestore`
  - `qr_flutter`
  - `shared_preferences`

## ⚙️ Setup & Installation (Build from Source)

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Beasst1816/My-Locker.git
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Firebase Configuration**:
   - Create a project on the [Firebase Console](https://console.firebase.google.com/).
   - Add an Android app with the package name `com.mylocker.app`.
   - Download the `google-services.json` and place it in `android/app/`.
   - Enable **Email/Password** in Authentication settings.
   - Create a **Firestore Database** in test mode or with appropriate rules.

4. **Run the app**:
   ```bash
   flutter run
   ```

## 📱 Screenshots

*Coming Soon...*

## 📝 Author

- **Bhagvan Raval** - [GitHub Profile](https://github.com/Beasst1816)
