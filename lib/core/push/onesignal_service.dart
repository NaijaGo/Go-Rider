import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../../routes/app_routes.dart';

class OneSignalService {
  static const String _appId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: '',
  );

  static bool _initialized = false;
  static bool _permissionRequested = false;
  static final GetStorage _notificationStorage = GetStorage();
  static const String _pendingDestinationKey =
      'pending_notification_destination';

  static bool get isConfigured => _appId.isNotEmpty;

  static String get appIdSuffix =>
      _appId.length >= 6 ? _appId.substring(_appId.length - 6) : 'missing';

  static Future<void> initialize() async {
    if (_initialized) return;

    if (!isConfigured) {
      throw StateError(
        'ONESIGNAL_APP_ID is required. Build with '
        '--dart-define=ONESIGNAL_APP_ID=<rider-app-id>.',
      );
    }

    try {
      OneSignal.Debug.setLogLevel(
        kDebugMode ? OSLogLevel.warn : OSLogLevel.none,
      );
      OneSignal.initialize(_appId);
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        event.preventDefault();
        event.notification.display();
      });
      OneSignal.Notifications.addClickListener((event) {
        final data = event.notification.additionalData ?? {};
        debugPrint('Rider notification clicked: $data');
        _queueOrOpenNotificationDestination(data);
      });
      _initialized = true;
    } catch (error) {
      debugPrint('Unable to initialize OneSignal: $error');
    }
  }

  static Map<String, Object?> diagnostics() {
    final subscription = OneSignal.User.pushSubscription;
    return {
      'configured': isConfigured,
      'appIdSuffix': appIdSuffix,
      'permission': OneSignal.Notifications.permission,
      'optedIn': subscription.optedIn,
      'subscriptionId': subscription.id,
      'tokenPresent': (subscription.token ?? '').isNotEmpty,
    };
  }

  static Future<void> requestPermission() async {
    if (_permissionRequested) return;
    _permissionRequested = true;

    try {
      final canRequest = await OneSignal.Notifications.canRequest();
      if (canRequest) {
        await OneSignal.Notifications.requestPermission(false);
      }
    } catch (error) {
      debugPrint('Unable to request OneSignal permission: $error');
    }
  }

  static Future<String?> pushSubscriptionId() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        final pushId = OneSignal.User.pushSubscription.id;
        if (pushId != null && pushId.isNotEmpty) return pushId;
      } catch (error) {
        debugPrint('Unable to read OneSignal push subscription ID: $error');
        return null;
      }

      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    return null;
  }

  static Future<void> loginRider({
    required String riderId,
    required String email,
    required String status,
    required String vehicleType,
  }) async {
    if (riderId.isEmpty) return;

    try {
      await OneSignal.login(riderId);
      await OneSignal.User.addTags({
        'role': 'rider',
        'rider_id': riderId,
        'email': email,
        'status': status,
        'vehicle_type': vehicleType,
        'last_login': DateTime.now().toIso8601String(),
      });
    } catch (error) {
      debugPrint('Unable to link rider OneSignal account: $error');
    }
  }

  static Future<void> logout() async {
    try {
      await OneSignal.logout();
    } catch (error) {
      debugPrint('Unable to logout OneSignal rider account: $error');
    }
  }

  static Future<void> consumePendingDestination() async {
    final pending = _notificationStorage.read<dynamic>(_pendingDestinationKey);
    if (pending is! Map) return;
    await _notificationStorage.remove(_pendingDestinationKey);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    _openNotificationDestination(Map<String, dynamic>.from(pending));
  }

  static void _queueOrOpenNotificationDestination(Map<String, dynamic> data) {
    _notificationStorage.write(_pendingDestinationKey, data);
    if (Get.context == null) return;
    Future<void>.delayed(
      const Duration(milliseconds: 250),
      consumePendingDestination,
    );
  }

  static void _openNotificationDestination(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    final hasOrder = (data['orderId']?.toString() ?? '').isNotEmpty;
    final arguments = <String, dynamic>{
      if (hasOrder) 'orderId': data['orderId'].toString(),
      if ((data['shipmentId']?.toString() ?? '').isNotEmpty)
        'shipmentId': data['shipmentId'].toString(),
    };

    if (type == 'pickup_required' ||
        type == 'arrived_at_vendor' ||
        type == 'confirm_pickup') {
      Get.toNamed(AppRoutes.confirmPickup, arguments: arguments);
      return;
    }

    if (type == 'delivery_required' ||
        type == 'arrived_at_customer' ||
        type == 'confirm_delivery') {
      Get.toNamed(AppRoutes.confirmDelivered, arguments: arguments);
      return;
    }

    if (type == 'rider_order_assigned' ||
        type == 'delivery_offer' ||
        type == 'order_assigned') {
      Get.toNamed(
        type == 'order_assigned'
            ? AppRoutes.activeDelivery
            : AppRoutes.assignedOrders,
        arguments: arguments.isEmpty ? null : arguments,
      );
      return;
    }

    if (type.contains('withdraw') ||
        type.contains('earning') ||
        type.contains('payout')) {
      Get.toNamed(AppRoutes.earnings, arguments: arguments);
      return;
    }

    if (type.contains('delivery') || type.contains('order')) {
      Get.toNamed(AppRoutes.activeDelivery, arguments: arguments);
      return;
    }

    Get.toNamed(AppRoutes.notifications);
  }
}
