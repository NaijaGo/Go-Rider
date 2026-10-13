# Rider UI and mapping: local review

## Scope

The Go-Rider app now uses calm blue styling, softer cards, consistent buttons and
responsive layouts. Dashboard, entrance/login, assigned orders, active delivery,
earnings, withdrawals, profile, notifications and confirmation screens retain
their existing actions. No backend endpoints, dependencies or build version were
changed. This work is local, without a commit, push or deployment.

## Mapping and reliability changes

- Separate map and stop-detail areas; labelled rider, pickup and customer pins.
- Pickup sequence and customer-leg restoration use the existing server payload.
- Missing or invalid coordinates never produce invented delivery pins.
- Backend road routing works independently of the public map-tile token.
- Failed directions clear old timing and instructions, without a straight-line
  substitute. Stale GPS does not display a fresh ETA.
- Late route responses cannot replace the route for a newer pickup/customer leg.
- GPS denial, stream failure, disposal and stop/start races have recovery states.
- Location writes are serialized, with the latest pending position retained.
- Online tracking requires existing background permission and a fresh fix;
  going online cannot reuse an old position after a failed GPS read.
- Navigation can centre on the rider or show all stops. User pans remain respected.
- Google Maps retains its app/browser fallback; valid destination is required.
- Pickup and delivery OTP requests keep their existing endpoints and payloads.
  Failed or late verification cannot advance a different active order.
- Availability changes wait for backend confirmation; active-delivery offline
  confirmation and location disclosure remain required.
- Camera cancellation, permission errors and disposed confirmation screens are
  handled safely. Photo/OTP payload contracts remain unchanged.
- iOS location, camera and photo usage declarations and the location permission
  macro were added. Android manifest and Google OAuth callback remain unchanged.

## Actual local validation

- Baseline Flutter suite: 25 passed, 0 failed.
- Final full Flutter suite: **80 passed, 0 failed, 0 skipped**.
- Real-font UI suite, with preview generation: **25 passed, 0 failed**.
- Final Dart analysis: **No issues found**.
- Python plist parser: valid iOS plist, required usage descriptions/background
  location present, existing Google callback preserved.
- `git diff --check`: passed.

Tests use mocked HTTP, GPS, routes, local fixture storage and an offline tile
provider. They do not use live rider accounts, real orders, a database, paid
directions calls or real delivery updates. Flutter Map prints its standard OSM
tile-use notice even with the offline test tile provider; no tile HTTP requests
are made in these tests.

The final passing run followed corrections to the actual layout failures and
test fixture problems discovered during implementation; failed intermediate runs
were not counted as passing tests.

Run locally with installed dependencies:

```sh
flutter test --no-pub --reporter expanded
dart analyze
git diff --check
```

## Previews

These are actual Flutter renders with sample fixture data, not live rider data:

- [Dashboard](../output/previews/rider-dashboard.png)
- [Login](../output/previews/rider-login.png)
- [Active delivery](../output/previews/rider-active-delivery.png)

To regenerate readable previews, set `RIDER_PREVIEW_FONT` to an existing Roboto
TTF file and `RIDER_PREVIEW_ICONS` to an existing Material Icons OTF file, then run:

```sh
flutter test --no-pub test/rider_ui_test.dart --dart-define=RIDER_UI_PREVIEWS=true
```

Those optional environment values are local font file paths for the test harness.
They are not deployment settings or API credentials.

## Required device checks before release

Local fixtures cannot verify native OS behavior or live provider credentials.
An Android/iPhone device build still needs to verify:

1. Login and the existing approved/pending rider flows.
2. Location services off, denied permission, foreground and background permission.
3. Going online, background/locked-screen updates, going offline and reconnecting.
4. Multi-vendor pickup route, OTP pickup, customer route and delivery confirmation.
5. App restart after verified pickup and navigation to the customer.
6. Real map tiles, authenticated road routing and Google Maps app/browser launch.
7. Camera/photo selection and cancel/error behavior.
8. Notifications and the existing withdrawal workflow using test accounts.

No native iOS/Android release build, live GPS, live push or live map provider was
verified here. Windows cannot run an Xcode/iOS build. The app version stays
`1.0.3+8`; increase it as part of a separately requested release.

## Files

Modified source/platform files:

- `ios/Podfile`
- `ios/Runner/Info.plist`
- `lib/core/map/mapbox_config.dart`
- `lib/core/push/onesignal_service.dart`
- `lib/core/theme/app_theme.dart`
- `lib/core/widgets/app_background.dart`
- `lib/core/widgets/primary_header.dart`
- `lib/core/widgets/section_card.dart`
- `lib/features/auth/view/login_view.dart`
- `lib/features/auth/view/splash_view.dart`
- `lib/features/dashboard/view/dashboard_view.dart`
- `lib/features/earnings/view/earnings_view.dart`
- `lib/features/earnings/view/withdrawal_request_view.dart`
- `lib/features/location/controller/rider_location_controller.dart`
- `lib/features/location/service/rider_location_permission_service.dart`
- `lib/features/map/controller/map_controller.dart`
- `lib/features/map/view/delivery_map_view.dart`
- `lib/features/notifications/view/notifications_view.dart`
- `lib/features/orders/controller/delivery_controller.dart`
- `lib/features/orders/model/rider_order.dart`
- `lib/features/orders/view/active_delivery_view.dart`
- `lib/features/orders/view/confirm_delivered_view.dart`
- `lib/features/orders/view/confirm_pickup_view.dart`
- `lib/features/profile/controller/rider_profile_controller.dart`
- `lib/features/profile/view/profile_view.dart`

Created files:

- `lib/core/map/delivery_coordinates.dart`
- `lib/core/map/rider_tracking_settings.dart`
- `test/delivery_mapping_test.dart`
- `test/online_location_test.dart`
- `test/rider_ui_test.dart`
- `test/support/rider_fixtures.dart`
- The three PNG previews linked above.
- This review document.

No production database, secrets, production API configuration, dependency files,
other app repositories or backend implementation were modified by this task.
