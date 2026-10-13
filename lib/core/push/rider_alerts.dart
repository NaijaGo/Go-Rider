import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../storage/app_storage.dart';
import '../../routes/app_routes.dart';
import '../../features/agreement/controller/rider_agreement_controller.dart';

/// Coalesces socket and push delivery of the same job; never accepts a job.
class RiderAlertPolicy {
  final Map<String, DateTime> _seen = {};
  static const jobTypes = {
    'delivery_offer',
    'rider_order_assigned',
    'order_assigned',
    'new_order',
  };

  static bool isJob(Map<String, dynamic> data) =>
      jobTypes.contains(data['type']?.toString());

  bool shouldAlert(
    Map<String, dynamic> data, {
    required bool approved,
    required bool online,
    required bool foreground,
    required DateTime now,
  }) {
    if (!approved || !online || !foreground || !isJob(data)) return false;
    _seen.removeWhere((_, time) => now.difference(time).inSeconds >= 15);
    final id = data['orderId'] ?? data['shipmentId'];
    final stage = data['type'] == 'order_assigned' ? 'accepted' : 'offer';
    final key = '${id ?? 'new-job'}|$stage';
    if (_seen.containsKey(key)) return false;
    _seen[key] = now;
    return true;
  }
}

class RiderAlerts {
  static const channel = MethodChannel('naijago/rider_alerts');
  static final _policy = RiderAlertPolicy();

  static bool get sessionReady =>
      (AppStorage.token?.isNotEmpty ?? false) &&
      AppStorage.riderStatus == 'approved';
  static bool get canNavigate =>
      (!Get.isRegistered<RiderAgreementController>() ||
          Get.find<RiderAgreementController>().confirmed.value) &&
      sessionReady &&
      Get.context != null &&
      !{
        AppRoutes.splash,
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.forgotPassword,
        AppRoutes.pendingApproval,
        AppRoutes.riderAgreement,
      }.contains(Get.currentRoute);

  static bool get canHandleIncoming =>
      canNavigate && foreground && AppStorage.isRiderOnline;

  static bool get foreground =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  static Future<void> play() async {
    try {
      final played = await channel.invokeMethod<bool>('playAlert');
      if (played == false) return;
    } on PlatformException {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    } on MissingPluginException {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  static void incoming(Map<String, dynamic> data) {
    if (!canNavigate) return;
    if (!_policy.shouldAlert(
      data,
      approved: sessionReady,
      online: AppStorage.isRiderOnline,
      foreground: foreground,
      now: DateTime.now(),
    )) {
      return;
    }
    play();
    // Open offers automatically only from the idle dashboard. Do not interrupt
    // driving, OTP verification, a dialog, or an account form.
    final target = destination(data);
    if (Get.currentRoute == AppRoutes.dashboard &&
        Get.isDialogOpen != true &&
        Get.isBottomSheetOpen != true) {
      Get.toNamed(target);
    } else if (Get.currentRoute != target) {
      Get.snackbar(
        data['type'] == 'order_assigned'
            ? 'Delivery assigned'
            : 'New delivery request',
        data['type'] == 'order_assigned'
            ? 'Open your active delivery to continue.'
            : 'Open your assigned orders to review the job.',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 8),
        mainButton: TextButton(
          onPressed: () => Get.toNamed(target),
          child: Text(
            data['type'] == 'order_assigned' ? 'View delivery' : 'View orders',
          ),
        ),
      );
    }
  }

  /// Push content never skips the existing arrival/OTP checks.
  static String destination(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    if (type == 'order_assigned') return AppRoutes.activeDelivery;
    if (RiderAlertPolicy.isJob(data)) return AppRoutes.assignedOrders;
    if (type.contains('withdraw') ||
        type.contains('earning') ||
        type.contains('payout')) {
      return AppRoutes.earnings;
    }
    if (type.contains('pickup') ||
        type.contains('delivery') ||
        type.contains('order') ||
        type == 'arrived_at_vendor' ||
        type == 'arrived_at_customer') {
      return AppRoutes.activeDelivery;
    }
    return AppRoutes.notifications;
  }
}
