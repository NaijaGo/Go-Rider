# Rider alerts and registration — local review

## Implemented

- Distinct original 6.4-second PCM rider notification chime, packaged in Android
  raw resources and the iOS Runner resource bundle. The sound keeps the existing
  `rider_job_alert` resource name and Android `naijago_rider_jobs_v1` channel.
- Foreground socket and push copies are coalesced by job and stage. Online,
  authenticated, approved riders can open job offers automatically from the idle
  dashboard. An already accepted assignment opens Active Delivery. Other screens
  get a view action without interrupting driving, dialogs or OTP verification.
- Background notification taps wait for authentication and approval. Arrival and
  verification alerts open Active Delivery rather than skipping to an OTP screen.
  Pending destinations store routing fields only, not OTPs, and clear on logout.
- Notifications includes Test sound and Alert settings. Confirmed online status
  warns when push subscription/permission is not connected; it does not change
  backend dispatch permissions.
- Five registration steps keep every original field and four required identity
  images. Date selection, supported vehicle choices, password visibility, inline
  validation, keyboard actions and bank account formatting improve entry. Back
  navigation between steps retains entries. Gender and delivery zone remain
  optional; driving license entry is optional for bicycles. Submission stays
  pending admin approval. Google onboarding retains its existing token refresh
  and identity checks.
- Local validation runs before document uploads. Server registration/upload APIs,
  approval rules, earnings, inventory and payment code are unchanged.

## Validation

- Full Flutter fixture suite: **108 passed, 0 failed, 0 skipped**.
- Backend `node --test test/notificationPlatform.test.js`: **3 passed**, mocked
  transport; no real OneSignal request or database connection.
- Dart static analysis: **No issues found**.
- Real-font fixture preview suite before final assignment-routing correction:
  **107 passed**; normal and enlarged-text signup previews inspected.
- Both sound assets are mono 16-bit PCM at 22050 Hz, duration 6.4 seconds. Xcode
  file, group and Resources build references checked.
- Android `:app:compileDebugKotlin --offline`: **BUILD SUCCESSFUL**, 168 tasks;
  no native compile failures. Existing Gradle/AGP/Kotlin deprecation/support warnings
  remain; build tool versions were not changed for this feature.
- iOS native compilation and physical-device push/audio tests have not been run.

Early UI tests found notification-page overflow with enlarged text and hidden
terms-row Material feedback. Both were corrected and final tests passed.

## Device verification before release

1. Build/install the updated rider app with its existing public OneSignal/Google
   build configuration. No credentials were changed locally.
2. Open Notifications, Test sound, then Alert settings. Enable sound/vibration
   for NaijaGo Urgent Alerts and check notification volume. Existing channel/user
   settings are not reset. Check both a fresh install and an upgrade.
3. With an approved test rider online, send an authorized test offer while the
   app is foreground, background and screen-locked. Check sound, vibration,
   notification tap and authenticated navigation. Foreground offers on the idle
   dashboard should open Assigned Orders without accepting a job.
4. Confirm background taps open the app, while account forms, active delivery
   and OTP screens are not interrupted by foreground offers.
5. Confirm pending/suspended riders cannot reach operational screens. Check photo
   permission denial, upload failures, regular and Google signup and admin review.

Ordinary delivery push notifications cannot reliably force the app into the
foreground without a tap. Android full-screen intent use is restricted, and
sound/volume, silent mode, Focus, battery restrictions and force-stop behavior
remain controlled by the operating system and rider settings. No full-screen
intent, critical-alert entitlement, DND bypass or forced volume change was added.

Official references:

- https://developer.android.com/about/versions/14/behavior-changes-14
- https://documentation.onesignal.com/docs/en/notification-sounds

## Files in this task

Created:

- `lib/core/push/rider_alerts.dart`
- `lib/features/auth/service/registration_checks.dart`
- `test/rider_alert_registration_test.dart`
- `android/app/src/main/res/raw/rider_job_alert.wav`
- `android/app/src/main/res/raw/z_keep.xml`
- `ios/Runner/rider_job_alert.wav`
- `output/previews/rider-registration.png`
- `output/previews/rider-registration-accessible.png`
- This review document.

Modified:

- `android/app/src/main/kotlin/com/naijago/gorider/MainActivity.kt`
- `ios/Runner/AppDelegate.swift`
- `ios/Runner.xcodeproj/project.pbxproj`
- `lib/core/push/onesignal_service.dart`
- `lib/features/auth/controller/auth_controller.dart`
- `lib/features/auth/view/register_view.dart`
- `lib/features/dashboard/view/dashboard_view.dart`
- `lib/features/notifications/controller/notification_controller.dart`
- `lib/features/notifications/view/notifications_view.dart`
- `test/rider_ui_test.dart` (includes the preceding local rider UI work).
- Existing dashboard/login/active-delivery fixture previews regenerated.

Replaced `android/app/src/main/res/raw/rider_job_alert.mp3` with the WAV resource;
Android cannot package two raw files with the same resource name.

Prior local rider UI/mapping work remains uncommitted in the same checkout.
No backend source changes, dependency changes, production database operations,
commits, pushes, deployments or real delivery updates occurred in this task.
