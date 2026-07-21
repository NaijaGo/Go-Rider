import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/api/api_helpers.dart';
import '../../../core/socket/socket_service.dart';
import '../../../core/storage/app_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/section_card.dart';
import '../../../routes/app_routes.dart';
import '../../location/controller/rider_location_controller.dart';
import '../../location/service/rider_location_permission_service.dart';
import '../../notifications/controller/notification_controller.dart';
import '../../orders/controller/delivery_controller.dart';
import '../../orders/service/rider_api.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final _locationPermissionService = RiderLocationPermissionService();
  bool isOnline = false;
  bool isLoading = false;
  double todayEarnings = 0;
  int completedDeliveries = 0;
  int activeDeliveries = 0;
  int _statusRequestVersion = 0;
  Worker? _orderRefreshWorker;
  Worker? _activeOrderWorker;

  @override
  void initState() {
    super.initState();
    _bindLiveDashboardRefresh();
    _loadDashboard();
  }

  @override
  void dispose() {
    _orderRefreshWorker?.dispose();
    _activeOrderWorker?.dispose();
    super.dispose();
  }

  void _bindLiveDashboardRefresh() {
    if (Get.isRegistered<NotificationController>()) {
      final notificationController = Get.find<NotificationController>();
      _orderRefreshWorker = ever<int>(
        notificationController.orderRefreshVersion,
        (_) => _loadDashboard(),
      );
    }

    if (Get.isRegistered<DeliveryController>()) {
      final deliveryController = Get.find<DeliveryController>();
      _activeOrderWorker = ever(
        deliveryController.activeOrder,
        (_) => _loadDashboard(),
      );
    }
  }

  Future<void> _loadDashboard() async {
    try {
      final data = await RiderApi.dashboard();
      if (!mounted) return;
      final online = data['isAvailable'] == true && data['isActive'] == true;
      final dashboardActiveDeliveries = asDouble(
        data['activeDeliveries'],
      ).toInt();
      final localActiveDeliveries =
          Get.isRegistered<DeliveryController>() &&
              Get.find<DeliveryController>().activeOrder.value != null
          ? 1
          : 0;
      setState(() {
        todayEarnings = asDouble(data['todayEarnings']);
        completedDeliveries = asDouble(data['completedDeliveries']).toInt();
        activeDeliveries = dashboardActiveDeliveries > localActiveDeliveries
            ? dashboardActiveDeliveries
            : localActiveDeliveries;
        isOnline = online;
      });
      await AppStorage.saveRiderOnline(online);
      if (Get.isRegistered<NotificationController>()) {
        await Get.find<NotificationController>().setOnlineStatus(online);
      }
      if (Get.isRegistered<RiderLocationController>()) {
        await Get.find<RiderLocationController>().syncWithOnlineStatus(online);
      }
    } catch (_) {
      // Dashboard keeps zeroed state until the backend is reachable.
    }
  }

  Future<void> _setOnline(bool value) async {
    final requestVersion = ++_statusRequestVersion;
    final previousValue = isOnline;

    if (!value &&
        Get.isRegistered<DeliveryController>() &&
        Get.find<DeliveryController>().activeOrder.value != null) {
      final confirm = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Active delivery in progress'),
          content: const Text(
            'Going offline during an active delivery will notify admin. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Stay Online'),
            ),
            ElevatedButton(
              onPressed: () => Get.back(result: true),
              child: const Text('Go Offline'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    if (value) {
      if (!mounted) return;
      final permissionGranted = await _locationPermissionService
          .requestForGoingOnline(context);
      if (!permissionGranted || !mounted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Background location is required to go online and receive deliveries.',
              ),
            ),
          );
        }
        return;
      }
    }

    if (value && Get.isRegistered<RiderLocationController>()) {
      final location = await Get.find<RiderLocationController>()
          .refreshCurrentLocation(sendToServerWhenOnline: false);
      if (location == null) {
        Get.snackbar(
          'Location required',
          'Turn on GPS/location permission so NaijaGo can use your real rider position.',
        );
        return;
      }
    }

    setState(() {
      isLoading = true;
      isOnline = value;
    });
    await AppStorage.saveRiderOnline(value);
    if (Get.isRegistered<NotificationController>()) {
      await Get.find<NotificationController>().setOnlineStatus(value);
    }
    if (Get.isRegistered<RiderLocationController>()) {
      await Get.find<RiderLocationController>().syncWithOnlineStatus(value);
    }
    SocketService().emit('rider_status_update', {
      'isAvailable': value,
      'isActive': value,
    });

    try {
      final data = await RiderApi.updateAvailability(value);
      if (!mounted || requestVersion != _statusRequestVersion) return;
      final confirmedOnline =
          data['isAvailable'] == true && data['isActive'] == true;
      if (confirmedOnline != isOnline) {
        setState(() => isOnline = confirmedOnline);
        await AppStorage.saveRiderOnline(confirmedOnline);
        if (Get.isRegistered<NotificationController>()) {
          await Get.find<NotificationController>().setOnlineStatus(
            confirmedOnline,
          );
        }
        if (Get.isRegistered<RiderLocationController>()) {
          await Get.find<RiderLocationController>().syncWithOnlineStatus(
            confirmedOnline,
          );
        }
      }
    } catch (e) {
      if (!mounted || requestVersion != _statusRequestVersion) return;
      setState(() => isOnline = previousValue);
      await AppStorage.saveRiderOnline(previousValue);
      if (Get.isRegistered<NotificationController>()) {
        await Get.find<NotificationController>().setOnlineStatus(previousValue);
      }
      if (Get.isRegistered<RiderLocationController>()) {
        await Get.find<RiderLocationController>().syncWithOnlineStatus(
          previousValue,
        );
      }
      SocketService().emit('rider_status_update', {
        'isAvailable': previousValue,
        'isActive': previousValue,
      });
      Get.snackbar('Error', apiMessage(e, 'Unable to update rider status'));
    } finally {
      if (mounted && requestVersion == _statusRequestVersion) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationController = Get.find<NotificationController>();

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(
                  () => _DashboardTopBar(
                    isOnline: isOnline,
                    unreadCount: notificationController.unreadCount,
                    onNotificationTap: () =>
                        Get.toNamed(AppRoutes.notifications),
                    onProfileTap: () => Get.toNamed(AppRoutes.profile),
                  ),
                ),

                const SizedBox(height: 20),

                _EarningsHeroCard(
                  isOnline: isOnline,
                  isLoading: isLoading,
                  todayEarnings: todayEarnings,
                  onToggle: _setOnline,
                ),

                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        title: 'Completed',
                        value: completedDeliveries.toString(),
                        icon: Icons.check_circle_outline,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatTile(
                        title: 'Active',
                        value: activeDeliveries.toString(),
                        icon: Icons.pending_actions,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),

                SectionCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _ActionTile(
                        icon: Icons.assignment_outlined,
                        title: 'Assigned Orders',
                        subtitle: 'Accept or reject new delivery jobs',
                        onTap: () => Get.toNamed(AppRoutes.assignedOrders),
                      ),
                      const Divider(height: 1),
                      _ActionTile(
                        icon: Icons.delivery_dining,
                        title: 'Active Delivery',
                        subtitle: 'View your current assigned order',
                        onTap: () => Get.toNamed(AppRoutes.activeDelivery),
                      ),
                      const Divider(height: 1),
                      _ActionTile(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Earnings',
                        subtitle: 'Track your balance and completed jobs',
                        onTap: () => Get.toNamed(AppRoutes.earnings),
                      ),
                      const Divider(height: 1),
                      _ActionTile(
                        icon: Icons.notifications_none,
                        title: 'Notifications',
                        subtitle: 'View order alerts and admin messages',
                        badgeCount: notificationController.unreadCount,
                        onTap: () => Get.toNamed(AppRoutes.notifications),
                      ),
                      const Divider(height: 1),
                      _ActionTile(
                        icon: Icons.person_outline,
                        title: 'Profile',
                        subtitle: 'Manage rider details and documents',
                        onTap: () => Get.toNamed(AppRoutes.profile),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                const Text(
                  'Current Status',
                  style: TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),

                SectionCard(
                  child: Row(
                    children: [
                      Container(
                        height: 46,
                        width: 46,
                        decoration: BoxDecoration(
                          color: isOnline
                              ? AppTheme.green.withValues(alpha: 0.12)
                              : Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          isOnline ? Icons.wifi_tethering : Icons.wifi_off,
                          color: isOnline ? AppTheme.green : Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          isOnline
                              ? 'You are available to receive delivery requests.'
                              : 'You are offline. Turn online when you are ready to work.',
                          style: const TextStyle(
                            color: AppTheme.textDark,
                            fontSize: 14,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardTopBar extends StatelessWidget {
  final bool isOnline;
  final int unreadCount;
  final VoidCallback onNotificationTap;
  final VoidCallback onProfileTap;

  const _DashboardTopBar({
    required this.isOnline,
    required this.unreadCount,
    required this.onNotificationTap,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.delivery_dining,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NaijaGo Rider',
                style: TextStyle(
                  color: AppTheme.textDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Delivery partner dashboard',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),

        GestureDetector(
          onTap: onNotificationTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(
                  Icons.notifications_none,
                  color: AppTheme.primary,
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: -3,
                  top: -3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(width: 10),

        GestureDetector(
          onTap: onProfileTap,
          child: Stack(
            children: [
              const CircleAvatar(
                radius: 23,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: AppTheme.primary),
              ),
              Positioned(
                right: 1,
                bottom: 1,
                child: Container(
                  height: 11,
                  width: 11,
                  decoration: BoxDecoration(
                    color: isOnline ? AppTheme.green : Colors.orange,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EarningsHeroCard extends StatelessWidget {
  final bool isOnline;
  final bool isLoading;
  final double todayEarnings;
  final ValueChanged<bool> onToggle;

  const _EarningsHeroCard({
    required this.isOnline,
    required this.isLoading,
    required this.todayEarnings,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, Color(0xFF0B335C)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today Earnings',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₦${todayEarnings.toStringAsFixed(2)}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onToggle(!isOnline),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Icon(
                    isOnline ? Icons.power_settings_new : Icons.power_off,
                    color: isOnline ? AppTheme.green : Colors.white70,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOnline ? 'Online and ready' : 'Offline',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isOnline
                              ? 'Tap to go offline'
                              : 'Tap to receive orders',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  Switch(
                    value: isOnline,
                    onChanged: onToggle,
                    activeThumbColor: AppTheme.green,
                    inactiveThumbColor: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatTile({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.secondary),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textDark,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int badgeCount;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: AppTheme.secondary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.secondary),
          ),
          if (badgeCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  badgeCount > 9 ? '9+' : badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textDark,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
