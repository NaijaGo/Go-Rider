import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/push/onesignal_service.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/section_card.dart';
import '../controller/notification_controller.dart';
import '../model/rider_notification.dart';

class NotificationsView extends StatelessWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<NotificationController>();

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: Get.back,
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Notifications',
                        style: TextStyle(
                          color: AppTheme.textDark,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => controller.markAllAsRead(),
                      child: const Text(
                        'Mark all read',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const _PushDiagnosticsCard(),
              Expanded(
                child: Obx(() {
                  if (controller.isLoading.value) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (controller.notifications.isEmpty) {
                    return const Center(
                      child: Text(
                        'No notifications yet.',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: controller.loadNotifications,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: controller.notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = controller.notifications[index];

                        return _NotificationCard(
                          notification: item,
                          onTap: () => controller.markAsRead(item.id),
                        );
                      },
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PushDiagnosticsCard extends StatefulWidget {
  const _PushDiagnosticsCard();

  @override
  State<_PushDiagnosticsCard> createState() => _PushDiagnosticsCardState();
}

class _PushDiagnosticsCardState extends State<_PushDiagnosticsCard> {
  Map<String, Object?> _status = const {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (mounted) setState(() => _status = OneSignalService.diagnostics());
  }

  @override
  Widget build(BuildContext context) {
    final connected =
        _status['permission'] == true &&
        _status['optedIn'] == true &&
        (_status['subscriptionId']?.toString().isNotEmpty ?? false) &&
        _status['tokenPresent'] == true;
    final subscriptionId = _status['subscriptionId']?.toString() ?? 'waiting';
    final shortId = subscriptionId.length > 12
        ? '${subscriptionId.substring(0, 12)}...'
        : subscriptionId;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: SectionCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              connected
                  ? Icons.notifications_active
                  : Icons.notification_important,
              color: connected ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                connected
                    ? 'Push connected | App ...${_status['appIdSuffix']} | $shortId'
                    : 'Push not ready | permission=${_status['permission']} | '
                          'optedIn=${_status['optedIn']} | subscription=$shortId',
                style: const TextStyle(
                  color: AppTheme.textDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Refresh push status',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final RiderNotification notification;
  final VoidCallback onTap;

  const _NotificationCard({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: SectionCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NotificationIcon(type: notification.type),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            color: AppTheme.textDark,
                            fontSize: 15,
                            fontWeight: unread
                                ? FontWeight.w900
                                : FontWeight.w700,
                          ),
                        ),
                      ),
                      if (unread)
                        Container(
                          height: 9,
                          width: 9,
                          decoration: const BoxDecoration(
                            color: AppTheme.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.message,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _formatTime(notification.createdAt),
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours} hrs ago';
    }

    return '${difference.inDays} days ago';
  }
}

class _NotificationIcon extends StatelessWidget {
  final RiderNotificationType type;

  const _NotificationIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      RiderNotificationType.newOrder => Icons.delivery_dining,
      RiderNotificationType.orderCancelled => Icons.cancel_outlined,
      RiderNotificationType.paymentUpdate =>
        Icons.account_balance_wallet_outlined,
      RiderNotificationType.adminMessage => Icons.campaign_outlined,
    };

    final color = switch (type) {
      RiderNotificationType.newOrder => AppTheme.secondary,
      RiderNotificationType.orderCancelled => Colors.red,
      RiderNotificationType.paymentUpdate => AppTheme.green,
      RiderNotificationType.adminMessage => AppTheme.primary,
    };

    return Container(
      height: 46,
      width: 46,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: color),
    );
  }
}
