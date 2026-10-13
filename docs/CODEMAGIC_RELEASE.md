# Go-Rider Codemagic release workflow

The repository-root `codemagic.yaml` contains Android Release and iOS App Store Release workflows. It retains the public Google client IDs, rider OneSignal app ID, package identifier and backend URL supplied by the owner. No private signing key, password or backend secret belongs in this file.

Both workflows validate required configuration, derive `APP_VERSION` from `pubspec.yaml`, install dependencies, prepare the public Google callback configuration, analyze the app and run its tests. Build commands pass the public API/Google/OneSignal settings and application-version metadata through Dart defines. Each script stops on failure. Android produces a signed APK and AAB; the existing iOS workflow produces an IPA and retains its previously configured TestFlight publication step.

## Start an Android build

1. Open Codemagic → Applications → Go-Rider.
2. Select branch `main` and reload/check `codemagic.yaml` after the GitHub push.
3. Confirm the existing private signing values are available to this YAML workflow: `CM_KEYSTORE` (base64-encoded keystore), `CM_KEYSTORE_PASSWORD`, `CM_KEY_ALIAS` and `CM_KEY_PASSWORD`. Store them as secrets in Codemagic; never paste them into GitHub or chat. Use the existing upload key, whose certificate is registered for Google sign-in.
4. Choose **Start new build → Android Release → main**.
5. Download the APK/AAB from the successful build's artifacts. The APK is for direct testing; the AAB is the Play Store upload artifact. Confirm the version code exceeds the last version uploaded to Play before a store submission. This task retains the repository's current `1.0.3+8` version.

For iOS, retain the existing App Store Connect integration and the signing certificate/provisioning profile for `com.naijago.gorider`. The iOS workflow was inspected but cannot be executed on the local Windows host.

## Rider agreement rollout prerequisite

The updated app requires the agreement-enabled backend, explicit collection/index setup and an approved published required agreement. A successful app build does not establish live agreement readiness. Backend/admin GitHub commits use `[skip render]` to prevent an immediate Render auto-deploy before these prerequisites are ready. Do not manually deploy the enforcing backend by itself: it blocks new rider work when agreement configuration is missing.

Use the [partnership setup and verification report](https://github.com/NaijaGo/naijago_backend/blob/main/docs/rider-partnership-local-review.md) for the coordinated staging/production plan. No agreement text, acceptance record or bonus credit was fabricated, and no production database setup was executed in this task.

## Local validation

The YAML was parsed using the already-installed Flutter tooling YAML package. All 16 embedded shell scripts passed `bash -n`. A local fixture verified that version metadata derives correctly from `pubspec.yaml`. The full rider regression suite was rerun after the CI edits. No Codemagic build, store publication or live backend deployment was triggered by the agent.

References: [Codemagic Flutter configuration](https://docs.codemagic.io/yaml-quick-start/building-a-flutter-app/), [built-in CI variables](https://docs.codemagic.io/yaml-basic-configuration/environment-variables/), [Render skip-deploy marker](https://render.com/docs/deploys).
