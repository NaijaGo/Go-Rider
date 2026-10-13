import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'rider_alerts.dart';
import '../../features/agreement/controller/rider_agreement_controller.dart';
import '../../features/orders/controller/orders_controller.dart';
import '../../features/orders/controller/delivery_controller.dart';

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
        final data = event.notification.additionalData ?? {};
        if (RiderAlertPolicy.isJob(data) && RiderAlerts.canHandleIncoming) {
          event.preventDefault();
          RiderAlerts.incoming(data);
          _refreshOrderScreens();
        } else {
          event.notification.display();
        }
      });
      OneSignal.Notifications.addClickListener((event) {
        final data = event.notification.additionalData ?? {};
        handleNotificationTap(data);
      });
      _initialized = true;
    } catch (error) {
      debugPrint('Unable to initialize OneSignal: $error');
    }
  }

  static Map<String, Object?> diagnostics() {
    if (!_initialized) {
      return {
        'configured': isConfigured,
        'appIdSuffix': appIdSuffix,
        'permission': false,
        'optedIn': false,
        'subscriptionId': null,
        'tokenPresent': false,
      };
    }
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

  static bool get alertsConnected {
    final status = diagnostics();
    return status['permission'] == true &&
        status['optedIn'] == true &&
        (status['subscriptionId']?.toString().isNotEmpty ?? false) &&
        status['tokenPresent'] == true;
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
    await _notificationStorage.remove(_pendingDestinationKey);
    try {
      await OneSignal.logout();
    } catch (error) {
      debugPrint('Unable to logout OneSignal rider account: $error');
    }
  }

  static bool _consumingDestination = false;

  static bool get _canNavigate => RiderAlerts.canNavigate;

  static Future<void> consumePendingDestination() async {
    if (_consumingDestination) return;
    if (Get.isRegistered<RiderAgreementController>() &&
        !await Get.find<RiderAgreementController>().ensureAccepted()) {
      return;
    }
    if (!_canNavigate) return;
    final pending = _notificationStorage.read<dynamic>(_pendingDestinationKey);
    if (pending is! Map) return;
    _consumingDestination = true;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!_canNavigate) return;
      final data = Map<String, dynamic>.from(pending);
      _refreshOrderScreens();
      final destination = RiderAlerts.destination(data);
      if (Get.currentRoute != destination) Get.toNamed(destination);
      await _notificationStorage.remove(_pendingDestinationKey);
    } finally {
      _consumingDestination = false;
    }
  }

  static Future<void> handleNotificationTap(Map<String, dynamic> data) async {
    // Keep the destination until authentication and approval are complete.
    await _notificationStorage.write(_pendingDestinationKey, {
      'type': data['type']?.toString() ?? '',
      if (data['orderId'] != null) 'orderId': data['orderId'].toString(),
      if (data['shipmentId'] != null)
        'shipmentId': data['shipmentId'].toString(),
    });
    await consumePendingDestination();
  }

  static void _refreshOrderScreens() {
    if (Get.isRegistered<OrdersController>()) {
      Get.find<OrdersController>().loadAssignedOrders();
    }
    if (Get.isRegistered<DeliveryController>()) {
      Get.find<DeliveryController>().loadActiveDelivery();
    }
  }
}
