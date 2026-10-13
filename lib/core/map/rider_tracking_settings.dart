import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

LocationSettings riderTrackingSettings({
  required bool activeDelivery,
  TargetPlatform? platform,
}) {
  final accuracy = activeDelivery
      ? LocationAccuracy.bestForNavigation
      : LocationAccuracy.high;
  final distanceFilter = activeDelivery ? 10 : 25;
  final target = platform ?? defaultTargetPlatform;
  if (!kIsWeb && target == TargetPlatform.android) {
    return AndroidSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
      intervalDuration: Duration(seconds: activeDelivery ? 10 : 15),
      foregroundNotificationConfig: ForegroundNotificationConfig(
        notificationTitle: activeDelivery
            ? 'NaijaGo active delivery'
            : 'NaijaGo delivery tracking',
        notificationText: activeDelivery
            ? 'Navigation is tracking your route to complete this delivery.'
            : 'Your rider location is active while you are online.',
        notificationChannelName: activeDelivery
            ? 'NaijaGo Active Delivery'
            : 'NaijaGo Rider Location',
        enableWakeLock: true,
        setOngoing: true,
      ),
    );
  }
  if (!kIsWeb && target == TargetPlatform.iOS) {
    return AppleSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
      activityType: ActivityType.otherNavigation,
      pauseLocationUpdatesAutomatically: false,
      showBackgroundLocationIndicator: true,
      allowBackgroundLocationUpdates: true,
    );
  }
  return LocationSettings(accuracy: accuracy, distanceFilter: distanceFilter);
}
