# applicatoin — CRANTROL Mobile App

This Flutter project is the mobile client for the CRANTROL system. It authenticates users, displays device dashboards, and sends relay commands via Firebase Realtime Database.

Where to look

- `lib/services/app_environment.dart` — how the app reads environment values (assets/.env then fallback)
- `lib/services/firebase_options.dart` — constructs FirebaseOptions consumed by Firebase initialization
- `lib/models/device.dart` — device and relay models (Hive annotations)
- `lib/providers/device_provider.dart` — device state and relay command logic
- `pubspec.yaml` — dependencies and assets (note `assets/.env` inclusion)

Build & run (verified commands)

```bash
cd applicatoin
flutter pub get
flutter pub run build_runner build   # generate Hive adapters
flutter analyze
flutter test
flutter run                           # for development
flutter build apk --debug             # produces debug APK
```

Environment

- Use `assets/.env` for packaging environment values into the app.
- For local testing, a non-tracked `.env` may be used, but never commit secrets.
- The app will fall back to placeholder values if env keys are not found — verify values before production.

Testing

- Unit and widget tests are available under `applicatoin/test/`.
- The project uses Provider for state management and Hive for local persistence.

Notes

- This README was refreshed to reflect CRANTROL usage and to point to the exact files implementing behavior in this workspace. No source code changes were made.


A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
