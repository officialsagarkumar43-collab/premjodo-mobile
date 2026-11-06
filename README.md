# Prem Jodo Mobile App (iOS & Android) 💖

Prem Jodo is a modern matchmaking and social discovery mobile application built with **Flutter**, **Riverpod**, **Socket.io**, and **Agora RTC**.

---

## 📱 Features Included

- **Authentication & Onboarding**: Phone OTP verification with secure JWT token storage.
- **Discovery & Match Swipe**: Tinder/Bumble-style swipe cards with compatibility scores, super-likes, and match popups.
- **Real-Time Chat**: Live messaging via Socket.io with typing indicators and online badges.
- **Agora Audio & Video Calling**: High-definition peer-to-peer audio and video calling.
- **AI Face Verification**: Live face verification screen with verification blue checkmark badge.
- **Prem Coins Wallet**: Coin top-up packages and monetization features (boosts, gifts, super likes).
- **Battle Arena & Meetups**: Multiplayer mini-games, trivia quizzes, and singles meetup event booking.

---

## 📁 Flutter Project Structure (Feature-First Clean Architecture)

```
prem-jodo-mobile/
├── android/                   # Android native configuration & AndroidManifest
├── ios/                       # iOS native configuration & Info.plist
├── lib/
│   ├── main.dart              # Application entry point (ProviderScope & Init)
│   ├── core/
│   │   ├── constants/         # AppColors, ApiEndpoints, Typography
│   │   ├── network/           # Dio ApiClient & SocketService
│   │   ├── services/          # StorageService, AgoraService
│   │   ├── theme/             # Material 3 Dark/Light Theme with Google Fonts
│   │   └── widgets/           # GlassContainer, CustomButton, CustomTextField
│   └── features/
│       ├── auth/              # Models, Repositories, Providers, Login & OTP Screens
│       ├── discovery/         # Models, Swiper, Providers, Discovery & Match Screens
│       ├── chat/              # Models, Repositories, Providers, ChatRoom & Call Screens
│       ├── profile/           # Profile Screen, Face Verification Screen
│       ├── wallet/            # Coins Wallet Screen & Top-up Packs
│       ├── battle/            # Battle Arena & Multiplayer Trivia Games
│       ├── events/            # Singles Meetup Events & Booking
│       └── navigation/        # Root Main Navigation Screen (BottomBar)
├── assets/                    # Images, icons, and sounds
└── pubspec.yaml               # Flutter package configuration & dependencies
```

---

## 🚀 How to Run

### 1. Prerequisites
- Flutter SDK (`>= 3.0.0`)
- Android Studio / Xcode installed (for iOS and Android simulators)

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Run on Device / Simulator
```bash
# Run on connected Android device / emulator
flutter run -d android

# Run on iOS Simulator / iPhone (macOS only)
flutter run -d ios
```
