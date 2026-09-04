# Student Locker 🔐 — Digital Gatepass System

A Flutter-based digital gatepass and locker management system for students, with role-based access control, Firebase-backed authentication, and QR-code verification.

## 📥 Try It

Download **`mylocker.apk`** from the [Releases](../../releases) tab and sideload it onto an Android device.

> ⚠️ **Note:** This is an early build — not yet production-ready, so expect rough edges and possible bugs. The admin dashboard described below is still in development.

## 🚀 Features

- **Role-Based Access Control (RBAC):** Two roles — **Student** and **Guard** — each with their own app flow and permissions.
- **Guard Scanner:** Guards scan a student's generated QR code to validate entry/exit.
- **Secure Authentication:** Firebase Email/Password authentication.
- **Cloud Database:** Student profiles (Name, Email, Enrollment) stored in Cloud Firestore.
- **Atomic Transactions:** Uses Firestore `WriteBatch` operations so entry/exit records stay consistent even under concurrent scans.
- **QR Generation:** Unique QR codes generated per student enrollment number.
- **Splash Screen:** Intelligent session management to auto-login returning users.
- **Persistence:** Local session handling using `shared_preferences`.
- **Modern UI:** Clean, responsive Material Design interface.
- 🚧 **Admin Web Dashboard (in progress):** A separate web-based panel for real-time monitoring of entry/exit logs — not yet released.

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

### Student Dashboard
![Student QR Screen](https://raw.githubusercontent.com/Beasst1816/My-Locker/main/lib/assets/student_dashboard.jpg)

### Guard Dashboard
![Guard Scanner Panel](https://raw.githubusercontent.com/Beasst1816/My-Locker/main/lib/assets/guard_dashboard.jpg)

### Admin Panel
![Admin Dashboard](https://raw.githubusercontent.com/Beasst1816/My-Locker/main/lib/assets/admin_dashboard.png)

## 📝 Author

- **Bhagvan Raval** - [GitHub Profile](https://github.com/Beasst1816)
