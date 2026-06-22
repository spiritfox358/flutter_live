# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Build & Run Commands

```bash
# Install dependencies
flutter pub get

# Run on connected device (debug)
flutter run

# iOS release build
flutter run --release

# Web deploy (served at /live_app/ on efzxt.com)
flutter build web --base-href /live_app/

# Static analysis / lint
flutter analyze

# Run tests (minimal test suite in test/)
flutter test
```

## Architecture Overview

This is a Flutter **live streaming app** (FZXT) targeting Android, iOS, and Web. It uses Tencent TRTC for real-time video/audio streaming with custom native video compositing plugins.

### Layer Map

```
lib/
├── main.dart                  # Entry point, MaterialApp, 5-tab shell (MainContainer)
├── screens/                   # UI layer — all pages organized by feature
│   ├── home/                  #   Main feed, live rooms, following feed
│   │   ├── live/              #   Live room core (RealLivePage, TRTCManager)
│   │   └── feed/              #   Short video / recommendation feed
│   ├── login/                 #   Login & register pages
│   ├── me/                    #   Profile, edit profile, followers, visitors
│   ├── message/               #   Messages inbox
│   ├── works/                 #   Short video publishing
│   └── dashboard/ranking/     #   User rankings with charts
├── services/                  # Backend API and external service calls
├── store/                     # Client-side state (UserStore singleton)
├── tools/                     # Utility classes (HTTP, dates, audio, colors)
├── models/                    # Data models (UserModel, etc.)
├── bridge/                    # Platform channel bridges to native code
└── widgets/                   # Shared/common UI widgets
```

### Core Systems

**Live Streaming** (`lib/screens/home/live/`):
- `RealLivePage` — The main live room widget. Supports multiple room types via `LiveRoomType` enum: `normal`, `music`, `voice`, `game`, `video`. Handles TRTC video views, chat, gifts, PK battles, music panel, and user entrance effects. This is the largest file in the project (~2000+ lines).
- `TRTCManager` — Singleton wrapper around `tencent_rtc_sdk`. Manages room entry/exit, local/remote video, audio mute, PK mode, snapshot, beauty filters. Uses a `_isExiting` lock to prevent C++ engine collision when switching rooms.
- `LiveSwipePage` — Vertical PageView for swiping between live rooms (TikTok-style).
- Room rendering modes are in `widgets/room_mode/` (`VideoRoomContentView`, `VoiceRoomContentView`, `MusicRoomContentView`).
- Multi-anchor layouts are in `widgets/view_mode/` (`SingleModeView`, `CoHostVideoList`, `PKRealBattleView`, `PKMultiBattleView`).

**Custom Native Plugins**:
- `my_alpha_player/` — Custom Flutter plugin for video playback with alpha channel (transparent video overlays, used for gift effects).
- `plugins/hardcore_mixer/` — Native video compositing engine. Flutter communicates via `MethodChannel('hardcore_mixer')` to play multiple RTMP streams composited into a single texture. Key methods: `initEngine()`, `playStreams()`, `dispose()`, `getReadyUrls()`, `setMuted()`.

**Networking**:
- `HttpUtil` — Dio-based HTTP singleton. Base URL: `https://dance.koruhq.com`. Auto-attaches Bearer token from `UserStore`. Expects backend response format `{code: 200, data: ..., msg: ...}`.
- `web_socket_channel` — Used for real-time chat and events inside live rooms.
- API keys are hardcoded in source (e.g., DeepSeek API key in `services/ai_service.dart`). **Do not commit these to public repos.**

**State Management**:
- `UserStore` — Singleton backed by `SharedPreferences`. Stores auth token, user profile (as JSON), and an avatar version key for cache busting. All state is read/written imperatively (no streams/ChangeNotifier).
- `ValueNotifier<int> globalRefreshRecommendNotifier` — Global signal to refresh the recommendation feed when re-tapping the Home tab.
- `GlobalKey<NavigatorState> navigatorKey` — Global navigator key for navigation from anywhere.

**Room flow**: Login → MainContainer (5 tabs) → HomeTabsPage (Recommend/Live/Following) → LiveListPage → LiveSwipePage → RealLivePage.

**Gift System**: `GiftApi` fetches tabs + gift list. `GiftPanel` widget handles gift selection and sending. Gift effects render via `GiftEffectLayer` and `GiftTrayEffectLayer` using the alpha player plugin. `gift_convert.md` documents FFmpeg commands for converting gift animations to the required alpha-channel format.

**AI Services**: DeepSeek API integration (`ai_service.dart`), AI music generation (`ai_music_service.dart`), AI real-time voice (`ai_realtime_voice_service.dart`).

### Key Patterns

- **Singleton via factory**: `HttpUtil`, `TRTCManager`, `UserStore` all use `_internal()` private constructors with static `_instance` + factory or getter.
- **Global state via ValueNotifier**: Simple imperative refresh signals (`globalRefreshRecommendNotifier`, `globalMainTabNotifier` — defined in `main.dart`).
- **Platform channels**: Native features (video compositing, alpha player) use `MethodChannel` with string-based method names, not pigeon/protobuf.
- **No provider/bloc/riverpod**: This project uses manual state management, not a state management framework.
- **Dark mode**: The app has full light/dark theme support with some pages (recommend feed, live rooms) forcing dark/black backgrounds for immersive video experience.

### Platform Notes

- **Android**: Enabled Impeller. Requires `INTERNET`, `CAMERA`, `RECORD_AUDIO`, `VIBRATE` permissions. Cleartext traffic allowed (`usesCleartextTraffic: true`).
- **iOS**: Info.plist should include camera and microphone usage descriptions.
- **Web**: Serves at `/live_app/` base href. Loads custom `alpha_player_web.js` for web alpha playback support.
- **TRTC**: Requires `GenerateTestUserSig` (in `lib/screens/home/live/generate_test_user_sig.dart`) for local development. Production must generate signatures server-side.
