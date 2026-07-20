# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this app is

ClearCase (`clearcase`, Firebase project `clearcase-c4af8`) is a Flutter co-parenting / family-court documentation app. Separated parents set up a *case*, register children, define custody and payment schedules from their court order, then log what actually happened — missed handovers, late or short support payments, disputes, non-compliance — and export a PDF evidence report for a lawyer or court.

Three bottom tabs ([lib/views/main_screen.dart](lib/views/main_screen.dart)): Calender, Insights, Settings.

## Commands

```bash
flutter run                      # device/emulator
flutter build apk / ipa
flutter analyze                  # lint (stock flutter_lints, no custom rules)
flutter test                     # see caveat below
flutter test test/widget_test.dart -p "name of test"
```

Cloud Functions ([functions/](functions/), Node 20):

```bash
cd functions
npm run serve     # firebase emulators:start --only functions
npm run deploy    # firebase deploy --only functions
npm run logs
```

**`flutter test` currently fails.** [test/widget_test.dart](test/widget_test.dart) is the untouched counter-app template pumping `MyApp`, which needs Firebase init. There is no real test suite, no mocks, no `integration_test/`. Don't treat a failure there as something you broke.

## Critical: the Firestore database is not the default one

Every Firestore access must go through the **named** database:

```dart
FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'clearcase')
```

There are 24 such call sites and zero uses of plain `FirebaseFirestore.instance`. That invariant is held by copy-paste, not by a shared accessor. Writing `FirebaseFirestore.instance` out of habit does **not** error — it silently reads an empty default database. The Cloud Function does the same thing via `getFirestore("clearcase")`.

## Data model

Everything is nested under the signed-in uid; `users` is the only top-level collection.

```
users/{uid}                      profile, fcmToken, tokenUpdatedAt, timezone,
  └── cases/{caseId}             notificationTime, isRemindersEnabled,
        ├── custodyRecords/{id}  isScheduledDatesEnabled, lastActive
        ├── paymentRecords/{id}
        ├── disputeRecords/{id}/logs/{id}
        ├── nonComplianceRecords/{id}
        ├── scheduledRules/{id}
        ├── reminders/{id}
        └── flaggedEvents/{id}
```

Models in [lib/models/](lib/models/) are hand-written (no freezed/json_serializable); `fromMap` factories take the `documentId` as a separate positional arg since Firestore data maps exclude the id.

## Architecture

**Provider + Firestore, no repository layer.** 16 `ChangeNotifierProvider`s registered eagerly in [lib/main.dart](lib/main.dart). Each provider owns its own `FirebaseFirestore` handle and builds raw collection paths itself — [lib/services/](lib/services/) is thin and does *not* cover Firestore. Two screens ([new_non_compliance_screen.dart:73](lib/views/home/new_non_compliance_screen.dart#L73), [new_dispute_screen.dart:74](lib/views/home/new_dispute_screen.dart#L74)) also query Firestore directly from the widget layer.

Provider naming: roughly one per screen/feature, with a separate `*_insight` variant for the read/analytics side. Fetch strategy is mixed per-provider — some use `.snapshots().listen` into a `StreamSubscription` cancelled in `dispose()`, others `await ...get()`. `CalendarProvider` and `InsightProvider` fan out: one stream on the cases list, then a `List<StreamSubscription>` of per-case streams torn down and rebuilt when the list changes.

**`CaseSelectionService`** ([lib/services/case_selection_service.dart](lib/services/case_selection_service.dart)) is a hand-rolled cross-provider event bus: a singleton `ChangeNotifier` that lives *outside* the provider tree. `CalendarProvider`, `ScheduledDatesProvider`, and `InsightProvider` all read and write it and wire listeners manually. The `if (_selectedCaseId == caseId) return;` guard is the only thing preventing infinite feedback loops between them — don't remove it.

The three services use three different patterns: `PushNotificationService` is all-static, `CaseSelectionService` is a singleton, `AuthService` is a plain instance class constructed ad-hoc at each use site.

**Routing** is named routes only — `getAppRoutes()` in [lib/core/utils/routers.dart](lib/core/utils/routers.dart) wired into `MaterialApp.routes`. Every screen declares `static const String routeName`; args come through `ModalRoute.of(context)?.settings.arguments` and are cast inside the builder. No go_router.

**Auth** ([lib/views/auth/auth_controller.dart](lib/views/auth/auth_controller.dart)): `SplashScreen` is the initial route and does a one-shot imperative check in `addPostFrameCallback` — there is no reactive `authStateChanges` gate in the routing layer. Branch order: no user → Login; not `emailVerified` → EmailVerification; no cases → CaseSetup; else MainScreen. Email/password + Google + Apple (iOS only; Android stays Google-only). Apple uses the nonce flow and account deletion does reauth + token revocation for App Store 5.1.1(v) — see [docs/superpowers/specs/2026-05-20-apple-sign-in-design.md](docs/superpowers/specs/2026-05-20-apple-sign-in-design.md). `AuthService` errors are thrown as raw `String`s, not typed exceptions.

**Notifications** are server-driven: [functions/index.js](functions/index.js) exports one `onSchedule` function running every 5 min in UTC. It reads each user's `notificationTime` + `timezone`, walks their `reminders` and `scheduledRules`, and sends FCM. Dedupe is a per-doc `lastNotifiedDate === todayStr` guard, deliberately using a window trigger (`nowLocal >= triggerLocal`) rather than exact-minute matching to tolerate Scheduler drift and DST. `data.kind` (`"reminder"` / `"scheduledRule"`) routes the tap client-side via `PushNotificationService.navigatorKey`. The offset tables map UI strings to day counts — if you change a dropdown label in the app, update the table in `index.js` or notifications silently stop matching.

No `firebase_options.dart`; `Firebase.initializeApp()` relies on native config. `firebase.json` deploys functions only — Firestore rules/indexes and Storage rules are not managed from this repo.

## Conventions

- **Colors**: use `AppColors` ([lib/core/theme/app_colors.dart](lib/core/theme/app_colors.dart)), add a token there rather than inlining hex. Adherence is currently poor (17 files use `AppColors`, 27 under `lib/views/` hardcode `Color(0x...)`), and `settings_screen.dart` uses a *different* purple from `AppColors.primary`. Follow the token, not the surrounding drift. There is no text-style or spacing file.
- **Attachments**: always read through `readAttachmentUrls()` ([lib/core/utils/attachments.dart](lib/core/utils/attachments.dart)) — writes go to `attachmentUrls` but legacy docs used `attachments`. After any attachment-bearing edit, call `deleteOrphanedStorageUrls()` ([lib/core/utils/storage_cleanup.dart](lib/core/utils/storage_cleanup.dart)) *after* the Firestore write.
- **Snackbars**: `showSnackBar(context, text)` from [lib/core/utils/helping_functions.dart](lib/core/utils/helping_functions.dart), called from providers and views alike.
- **Responsive helpers**: `getFontSize`/`getDeviceWidth` exist but are only used by the three auth screens. The other ~90% of the UI uses fixed sizes — don't reach for them in new screens.
- Reuse [lib/views/widgets/](lib/views/widgets/) `custom_*` components. Screen padding is consistently `EdgeInsets.all(20)`; loading is `Center(child: CircularProgressIndicator())`.
- New specs go in `docs/superpowers/specs/`.

## Known quirks

- "Remainder" is a persistent misspelling of "reminder" across filenames, providers, and the `remainder_*` files — the class is `NewReminderScreen`. Match the existing spelling when touching those files.
- `MainProvider` ([lib/provider/main_provider.dart](lib/provider/main_provider.dart)) is an empty class still registered in `main.dart`. `LocalKeys` ([lib/core/static/local_keys.dart](lib/core/static/local_keys.dart)) has zero usages. Both are dead.
- `DisputeInsightsProvider` is declared at line 208 of its file, `NonComplianceProviderInsight` at line 124 — those files have unrelated top-level code above the class. `payment_provider_insight.dart` declares a class named `PaymentProvider`, not `PaymentProviderInsight`.
- The theme seeds `ColorScheme.fromSeed(seedColor: Colors.deepPurple)`, which is **not** `AppColors.primary`, so Material-derived colors drift from the brand palette.
- The `Jost` font ships as a single TTF with no weights declared, so all weights are synthesized.
