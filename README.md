# NaijaGo Rider

Flutter application for NaijaGo delivery riders.

## Push notification configuration

The Rider app must use its own OneSignal application. Supply the public Rider
OneSignal App ID at build time; do not hard-code it in source control:

```powershell
flutter build apk --release --dart-define=ONESIGNAL_APP_ID=YOUR_RIDER_APP_ID
```

The backend must provide these deployment environment variables:

```text
RIDER_ONESIGNAL_APP_ID
RIDER_ONESIGNAL_REST_API_KEY
```

`RIDER_ONESIGNAL_REST_API_KEY` is secret and must only be stored in the backend
hosting provider's environment settings.

Rider pushes use the native Android notification channel
`naijago_rider_jobs_v1`. To use a branded alert, add a licensed Android audio
resource named `rider_job_alert.wav`, `rider_job_alert.ogg`, or
`rider_job_alert.mp3` under `android/app/src/main/res/raw/`. If it is absent,
the app uses the device's default notification sound.

Android notification-channel sound choices are persistent after installation.
When testing a changed sound, uninstall the previous app build or clear its app
data before installing the new APK.
