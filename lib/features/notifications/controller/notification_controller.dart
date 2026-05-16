import 'dart:async';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/api/api_helpers.dart';
import '../../../core/storage/app_storage.dart';
import '../../../core/socket/socket_service.dart';
import '../../orders/controller/delivery_controller.dart';
import '../../orders/controller/orders_controller.dart';
import '../../orders/service/rider_api.dart';
import '../model/rider_notification.dart';

class NotificationController extends GetxController {
  static const String _onlineStatusNotificationId = 'local-online-status';

  final notifications = <RiderNotification>[].obs;
  final isLoading = false.obs;
  final orderRefreshVersion = 0.obs;
  final SocketService _socketService = SocketService();

  int get unreadCount {
    return notifications.where((item) => !item.isRead).length;
  }

  @override
  void onInit() {
    super.onInit();
    startAfterLogin();
  }

  @override
  void onClose() {
    _socketService.dispose();
    super.onClose();
  }

  Future<void> loadNotifications({bool showLoading = true}) async {
    if (!_hasToken) {
      notifications.clear();
      return;
    }

    if (showLoading) isLoading.value = true;

    try {
      final data = await RiderApi.notifications();
      notifications.assignAll(
        _withLocalOnlineStatus(
          _dedupeNotifications(
            data
                .map((item) => RiderNotification.fromJson(asMap(item)))
                .where((item) => item.id.isNotEmpty)
                .toList(),
          ),
        ),
      );
    } catch (error) {
      if (_hasToken) {
        Get.snackbar(
          'Notifications unavailable',
          apiMessage(error),
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } finally {
      if (showLoading) isLoading.value = false;
    }
  }

  Future<void> markAsRead(String id) async {
    if (!_hasToken) return;

    if (id == _onlineStatusNotificationId) {
      await setOnlineStatus(AppStorage.isRiderOnline);
      return;
    }

    final index = notifications.indexWhere((item) => item.id == id);

    if (index == -1) return;

    notifications[index] = notifications[index].copyWith(isRead: true);

    await RiderApi.markNotificationRead(id);
  }

  Future<void> markAllAsRead() async {
    if (!_hasToken) return;

    notifications.assignAll(
      notifications.map((item) {
        if (item.id == _onlineStatusNotificationId &&
            AppStorage.isRiderOnline) {
          return item.copyWith(isRead: false);
        }
        return item.copyWith(isRead: true);
      }).toList(),
    );
    await RiderApi.markAllNotificationsRead();
    if (AppStorage.isRiderOnline) {
      await setOnlineStatus(true);
    }
  }

  Future<void> startAfterLogin() async {
    if (!_hasToken) return;
    connectLiveNotifications();
    await loadNotifications(showLoading: false);
  }

  void connectLiveNotifications() {
    if (!_hasToken) return;

    _socketService.connect();
    for (final event in const [
      'notification',
      'rider_notification',
      'order_assigned',
      'rider_order_assigned',
      'delivery_offer',
      'new_order',
      'order_updated',
    ]) {
      _socketService.off(event);
      _socketService.on(event, (payload) {
        unawaited(_playUrgentAlert());
        loadNotifications(showLoading: false);
        _refreshOrders(payload);
      });
    }

    _socketService.off('admin_message');
    _socketService.on('admin_message', (_) {
      unawaited(_playUrgentAlert());
      loadNotifications(showLoading: false);
    });
  }

  void stopLiveNotifications() {
    _socketService.dispose();
    notifications.clear();
  }

  Future<void> setOnlineStatus(bool online) async {
    await AppStorage.saveRiderOnline(online);

    final existingIndex = notifications.indexWhere(
      (item) => item.id == _onlineStatusNotificationId,
    );

    if (!online) {
      if (existingIndex != -1) {
        notifications.removeAt(existingIndex);
      }
      return;
    }

    final onlineNotification = RiderNotification(
      id: _onlineStatusNotificationId,
      type: RiderNotificationType.adminMessage,
      title: 'You are online',
      message:
          'You are visible to admin dispatch and can receive delivery assignments. Turn offline when you are no longer available.',
      createdAt: DateTime.now(),
    );

    if (existingIndex == -1) {
      notifications.insert(0, onlineNotification);
    } else {
      notifications[existingIndex] = onlineNotification;
    }
  }

  bool get _hasToken {
    final token = AppStorage.token;
    return token != null && token.isNotEmpty;
  }

  void _refreshOrders([dynamic payload]) {
    if (Get.isRegistered<OrdersController>()) {
      Get.find<OrdersController>().loadAssignedOrders();
      if (_isOrderOfferPayload(payload)) {
        Future<void>.delayed(const Duration(milliseconds: 900), () {
          if (Get.isRegistered<OrdersController>()) {
            Get.find<OrdersController>().loadAssignedOrders();
          }
        });
      }
    }
    if (Get.isRegistered<DeliveryController>()) {
      Get.find<DeliveryController>().loadActiveDelivery();
    }
    orderRefreshVersion.value++;
  }

  bool _isOrderOfferPayload(dynamic payload) {
    final data = payload is Map ? payload : const {};
    final type = data['type']?.toString();
    return type == 'delivery_offer' ||
        type == 'rider_order_assigned' ||
        type == 'order_assigned' ||
        data['orderId'] != null;
  }

  Future<void> _playUrgentAlert() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 320));
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.vibrate();
    } catch (_) {
      // Some targets do not support alert sounds or haptics.
    }
  }

  List<RiderNotification> _dedupeNotifications(List<RiderNotification> items) {
    final seen = <String>{};
    final result = <RiderNotification>[];

    for (final item in items) {
      final key = '${item.type.name}|${item.title}|${item.message}';
      if (seen.add(key)) {
        result.add(item);
      }
    }

    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  List<RiderNotification> _withLocalOnlineStatus(
    List<RiderNotification> items,
  ) {
    final result = items
        .where((item) => item.id != _onlineStatusNotificationId)
        .toList();

    if (!AppStorage.isRiderOnline) return result;

    result.insert(
      0,
      RiderNotification(
        id: _onlineStatusNotificationId,
        type: RiderNotificationType.adminMessage,
        title: 'You are online',
        message:
            'You are visible to admin dispatch and can receive delivery assignments. Turn offline when you are no longer available.',
        createdAt: DateTime.now(),
      ),
    );

    return result;
  }
}
