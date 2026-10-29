# ridemate

Pool-It Flutter app. Authentication uses Google (Firebase Auth) as the primary
option and WhatsApp OTP as an alternative.

## Firebase / Google sign-in setup

1. Create a Firebase project and add Android/iOS apps.
2. Enable **Authentication > Sign-in method > Google**.
3. Create OAuth clients in Google Cloud Console (Android, iOS, Web).
4. Add the web OAuth client ID as `GOOGLE_WEB_CLIENT_ID`. This is required as
   `serverClientId` on Android.
5. Register your Android signing certificate SHA-1/SHA-256 in Firebase
   (Project settings > Your apps > Android). Both debug and release keystores
   need to be registered, or Google sign-in will fail on release builds.
6. Add the reversed iOS client ID URL scheme to `ios/Runner/Info.plist`
   (`CFBundleURLTypes` > `CFBundleURLSchemes`).
7. Pass the Firebase values at build time:

```bash
flutter run \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_ANDROID_APP_ID=... \
  --dart-define=FIREBASE_IOS_APP_ID=... \
  --dart-define=GOOGLE_WEB_CLIENT_ID=... \
  --dart-define=GOOGLE_IOS_CLIENT_ID=...
```

Alternatively run `flutterfire configure` and replace `lib/firebase_options.dart`
with the generated file.

On Android, `android/app/google-services.json` is used automatically when the
dart-define values are absent (the Google Services Gradle plugin is enabled).
You still need `GOOGLE_WEB_CLIENT_ID` on Android because it is the
`serverClientId` used to obtain the Google ID token.

The backend must also have Firebase Admin credentials configured (see
`backend/.env.example`). Google sign-in is optional at runtime: if Firebase is
not configured, or initialization fails, the app keeps running and the Google
button shows an error while phone OTP continues to work.

Google sign-in handles both first-time signup and returning login. The backend
verifies the Firebase ID token, finds or creates the matching Supabase auth
user, and returns a Supabase token so the existing profile/RLS data keeps
working.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
