import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../../routes/app_routes.dart';

class OneSignalService {
  static const String _appId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: '76438b8d-4b39-49eb-805c-11eb934f5a66',
  );

  static bool _initialized = false;
  static bool _permissionRequested = false;

  static Future<void> initialize() async {
    if (_initialized) return;

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
        _openNotificationDestination(data);
      });
      _initialized = true;
    } catch (error) {
      debugPrint('Unable to initialize OneSignal: $error');
    }
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

  static void _openNotificationDestination(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    final hasOrder = (data['orderId']?.toString() ?? '').isNotEmpty;

    if (type == 'rider_order_assigned' ||
        type == 'delivery_offer' ||
        type == 'order_assigned') {
      Get.toNamed(
        type == 'order_assigned'
            ? AppRoutes.activeDelivery
            : AppRoutes.assignedOrders,
        arguments: hasOrder ? {'orderId': data['orderId']} : null,
      );
      return;
    }

    if (type.contains('delivery') || type.contains('order')) {
      Get.toNamed(AppRoutes.activeDelivery);
      return;
    }

    Get.toNamed(AppRoutes.notifications);
  }
}
