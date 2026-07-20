# Apple Sign-In — Design Spec

**Date:** 2026-05-20
**Project:** ClearCase (Flutter)
**Author:** taran-bansal

## Goal

Add "Sign in with Apple" alongside the existing Google Sign-In and email/password flows, satisfying Apple App Store Guideline 4.8 (parity with other social logins) and Guideline 5.1.1(v) (token revocation on account deletion).

## Scope

- **iOS:** show both Apple and Google buttons on login + signup screens.
- **Android:** unchanged — Google only.
- **Web:** N/A — the social button widget already short-circuits on web.

## Non-Goals

- Apple Sign-In on Android (would require an Apple Services ID, redirect URL, and a web-based flow — out of scope per Question 2).
- Automated tests for auth providers — codebase has no such pattern today; not introducing one.
- Linking an existing email/Google account to Apple as a secondary credential.

## Architecture

### Dependency

Add to `pubspec.yaml`:

```yaml
sign_in_with_apple: ^6.1.4
```

Rationale: well-maintained Flutter package, supports the nonce-based credential flow Firebase requires plus the `getCredentialState` and revoke helpers.

### iOS Native Config

1. `ios/Runner/Runner.entitlements` — add:
   ```xml
   <key>com.apple.developer.applesignin</key>
   <array>
     <string>Default</string>
   </array>
   ```
   (Existing `aps-environment` entry is preserved.)
2. Xcode project (`Runner.xcodeproj`) — enable "Sign in with Apple" capability. The user has already touched `project.pbxproj`; we verify this is set during implementation.
3. **Manual steps** (documented, not code):
   - Apple Developer Console → App ID has "Sign in with Apple" capability enabled.
   - Firebase Console → Authentication → enable Apple provider.

### Android

No changes. The `SocialAuthButton` already short-circuits to Google on Android. Apple Developer setup for the web flow is out of scope.

### Files Touched

| File | Change |
|------|--------|
| `pubspec.yaml` | Add `sign_in_with_apple` |
| `ios/Runner/Runner.entitlements` | Add `com.apple.developer.applesignin` |
| `ios/Runner.xcodeproj/project.pbxproj` | Verify capability set (already partially modified) |
| `lib/services/auth_service.dart` | Add `signInWithApple()`, `revokeAppleSignIn(authCode)`, nonce helpers |
| `lib/provider/auth_provider.dart` | Add `appleSignInFunction()` + `isAppleLoading` flag |
| `lib/views/widgets/social_auth_button.dart` | Split into `GoogleSignInButton` + `AppleSignInButton`; keep `OrContinueWithDivider` |
| `lib/views/auth/login_screen.dart` | Render both buttons on iOS; wire Apple `onPressed` |
| `lib/views/auth/signup_screen.dart` | Same as login |
| `lib/provider/setting_provider.dart` | `deleteUserAccount` invokes Apple revoke when `authProvider == 'apple'` |

## Sign-In Flow

Mirrors `googleSignInFunction` in [auth_provider.dart](../../../lib/provider/auth_provider.dart):

1. User taps the Apple button on the login or signup screen → `AuthProvider.appleSignInFunction(context)`.
2. Generate a 32-character random nonce; SHA256-hash it.
3. Call `SignInWithApple.getAppleIDCredential(scopes: [email, fullName], nonce: <sha256>)`. User completes Apple's native sheet.
4. Build a Firebase credential:
   ```dart
   final oauth = OAuthProvider('apple.com').credential(
     idToken: cred.identityToken,
     rawNonce: rawNonce,
     accessToken: cred.authorizationCode,
   );
   ```
5. `FirebaseAuth.signInWithCredential(oauth)` → `UserCredential`.
6. **First-time name capture** — Apple returns `givenName` / `familyName` ONLY on the very first sign-in for this Apple ID. If `user.displayName` is empty and Apple gave us a name, call `user.updateDisplayName("$given $family")`.
7. Fetch FCM token, timezone, UTC offset. Build/merge Firestore user doc:
   - If new user: create the full doc (shape below) with `authProvider: 'apple'`.
   - If existing user: merge-update `fcmToken`, `tokenUpdatedAt`, `timezone`, `utcOffset` (same as Google path).
8. Persist Firebase ID token to local storage (same as Google: `setDataToLocal('firebase_id_token', token)`) and set `auth_provider = 'apple'`.
9. Call `_ensureUserDefaults(uid)` for backfill safety.
10. Initialise `SettingsProvider`.
11. Look up `users/<uid>/cases` — if empty, navigate to `CaseSetupScreen`; otherwise to `MainScreen` with `arguments: 0`.

### Firestore User Document (new Apple user)

```jsonc
{
  "uid": "<firebase uid>",
  "email": "<apple email or @privaterelay.appleid.com>",
  "firstName": "<from Apple on first sign-in, may be empty>",
  "lastName":  "<from Apple on first sign-in, may be empty>",
  "authProvider": "apple",
  "appleUserId": "<credential.userIdentifier>",
  "createdAt": "<serverTimestamp>",
  "children": [],
  "isDailyReminderEnabled": false,
  "isRemindersEnabled": true,
  "isScheduledDatesEnabled": true,
  "notificationTime": "09:00",
  "timezone": "<IANA tz>",
  "utcOffset": "+HH:MM",
  "fcmToken": "<token>",
  "tokenUpdatedAt": "<serverTimestamp>"
}
```

`appleUserId` is stored for later credential-state checks / revoke flows.

## UI Changes

### Widget Refactor (`social_auth_button.dart`)

Split the current dual-purpose `SocialAuthButton` into two purpose-specific widgets:

- **`GoogleSignInButton`** — white background, Google logo, "Continue with Google". Identical visual style to today's Android variant.
- **`AppleSignInButton`** — black background per [Apple HIG](https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple), white Apple logo, "Continue with Apple". Uses existing `assets/icons/apple.svg`.
- **`OrContinueWithDivider`** — unchanged.

Each widget takes `onPressed` + `isLoading` and gates itself.

### Login Screen Layout (iOS)

```
[Email]
[Password]
[Forgot password]
[Login button]
— or continue with —
[Apple button]   ← iOS only, on top per Apple HIG
[Google button]
[Create account link]
```

Android: only `[Google button]` after the divider — unchanged from today.

### Signup Screen

Same treatment — both social buttons on iOS, Google only on Android. Sign-up via a social provider routes through the same provider function, which creates the Firestore doc on first sign-in.

### Loading-State Interlock

`AuthProvider` gains `bool isAppleLoading` with `setAppleLoading(bool)`. Each social button's `onPressed` is disabled whenever ANY of `isLoading | isGoogleLoading | isAppleLoading` is true. This prevents double-taps from racing the email/Google/Apple paths.

## Account Deletion + Apple Token Revoke

Apple App Store Guideline 5.1.1(v) requires the app to revoke the Apple token when an account is deleted. Current deletion lives at [setting_provider.dart:391](../../../lib/provider/setting_provider.dart#L391). We extend it.

### Flow when `authProvider == 'apple'`

1. Read the user's `authProvider` field from Firestore (already loaded by `SettingsProvider` or fetched in-place).
2. Show a confirmation dialog: "Deleting your account will sign you out of Apple. Apple will prompt you to confirm."
3. Re-trigger Apple Sign-In via `SignInWithApple.getAppleIDCredential` to obtain a fresh `authorizationCode` (codes expire ~5 min, so the original from sign-in can't be reused).
4. Re-authenticate Firebase: `user.reauthenticateWithCredential(oauth)` — this also satisfies the `requires-recent-login` gate the existing code checks.
5. Call `FirebaseAuth.instance.revokeTokenWithAuthorizationCode(authorizationCode)` (Firebase SDK 6.x built-in; relays revocation to Apple).
6. Proceed with the existing flow: notification cleanup → storage cleanup → Firestore cleanup → `user.delete()`.

Google and email/password deletion paths are unchanged.

### Sign-Out

No special handling — `_auth.signOut()` only. Revoke is reserved for full account deletion.

## Error Handling

### Apple-Specific (`SignInWithAppleAuthorizationException`)

| Code | Behaviour |
|------|-----------|
| `canceled` | Silent — reset `isAppleLoading`, no snackbar (matches Google's `googleUser == null` path) |
| `failed`, `invalidResponse`, `notHandled`, `unknown`, `notInteractive` | Snackbar: "Apple sign-in failed. Please try again." |

### Firebase Exceptions on Credential Exchange

| Code | Behaviour |
|------|-----------|
| `account-exists-with-different-credential` | Snackbar: "An account with this email already exists. Please sign in with your original method." |
| Any other | Reuse `AuthService._handleAuthException(e)` |

### Defensive

- `credential.identityToken == null` → fail with the generic Apple message. Should not happen in practice.

## Edge Cases

1. **Hide-my-email proxy address** (`@privaterelay.appleid.com`) — stored verbatim. The user doc happily holds a relay email.
2. **Empty name on first sign-in** (user blanked the fields in Apple's sheet) — persist `firstName: ''`, `lastName: ''`. User can fix in settings via the existing `updateUserName` path.
3. **Reinstall + sign-in on a fresh device** — Apple does not return the name again, but Firebase resolves to the same UID; our Firestore doc already holds the original name.
4. **Android user hits Apple path** — guarded by UI (button not rendered on Android). No code-level guard added.
5. **Simulator quirks on macOS < 13** — accepted limitation; real-device testing is the gate.

## Testing

- **Manual on real iOS device:**
  - First-time Apple sign-up (verify name + email captured, user doc created, navigates to `CaseSetupScreen`).
  - Subsequent Apple sign-in (verify no name overwrite, merges FCM/timezone, navigates to `MainScreen`).
  - Cancel Apple sheet (verify no snackbar, button re-enables).
  - Hide-my-email path (verify relay address persists).
  - Account deletion as an Apple user (verify Apple re-prompt, revoke, full cleanup).
  - Google sign-in still works.
- **No automated tests** — out of scope per "Non-Goals".

## Open Items / Manual Steps for the User

These cannot be automated by code changes:

1. Enable "Sign in with Apple" capability for the App ID in Apple Developer Console.
2. Enable the Apple provider in Firebase Console → Authentication → Sign-in method.
3. Confirm the iOS Xcode project has the "Sign in with Apple" capability checked (verify on first build).
