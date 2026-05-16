import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/section_card.dart';
import '../../../routes/app_routes.dart';
import '../controller/delivery_controller.dart';

class ActiveDeliveryView extends StatefulWidget {
  const ActiveDeliveryView({super.key});

  @override
  State<ActiveDeliveryView> createState() => _ActiveDeliveryViewState();
}

class _ActiveDeliveryViewState extends State<ActiveDeliveryView> {
  late final DeliveryController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.find<DeliveryController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadActiveDelivery();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Obx(() {
            if (controller.isLoadingActiveDelivery.value) {
              return const Center(child: CircularProgressIndicator());
            }

            if (controller.activeOrder.value == null) {
              return RefreshIndicator(
                onRefresh: controller.loadActiveDelivery,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const _DeliveryHeader(),
                    const SizedBox(height: 22),
                    SectionCard(
                      child: Column(
                        children: [
                          Icon(
                            Icons.delivery_dining_outlined,
                            color: AppTheme.secondary,
                            size: 54,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'No Active Delivery',
                            style: TextStyle(
                              color: AppTheme.textDark,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            controller.activeDeliveryError.value.isEmpty
                                ? 'Accepted rider orders will appear here from the backend.'
                                : controller.activeDeliveryError.value,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: controller.loadActiveDelivery,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: controller.loadActiveDelivery,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _DeliveryHeader(),
                    const SizedBox(height: 22),

                    const Text(
                      'Current Delivery',
                      style: TextStyle(
                        color: AppTheme.textDark,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Follow each step carefully from pickup to customer delivery.',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 18),

                    SectionCard(
                      child: Column(
                        children: [
                          _infoRow(
                            title: 'Order ID',
                            value: controller.orderCode,
                            icon: Icons.receipt_long,
                          ),
                          const Divider(height: 24),
                          _infoRow(
                            title: 'Vendor Address',
                            value: controller.vendorAddress.value,
                            icon: Icons.storefront,
                          ),
                          const Divider(height: 24),
                          _infoRow(
                            title: 'Customer Address',
                            value: controller.customerAddress.value,
                            icon: Icons.location_on_outlined,
                          ),
                          const Divider(height: 24),
                          _infoRow(
                            title: 'Delivery Fee',
                            value: controller.deliveryFeeText,
                            icon: Icons.payments_outlined,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    _EtaCard(controller: controller),

                    const SizedBox(height: 22),

                    const Text(
                      'Delivery Progress',
                      style: TextStyle(
                        color: AppTheme.textDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),

                    SectionCard(
                      child: Column(
                        children: [
                          _StepItem(
                            title: 'Arrive at Vendor',
                            subtitle:
                                'Confirm you have reached the pickup point',
                            active: controller.isGoingToVendor,
                            completed:
                                controller.hasArrivedAtVendor ||
                                controller.hasPickedUp,
                          ),
                          const _StepDivider(),
                          _StepItem(
                            title: 'Confirm Pickup',
                            subtitle: 'Collect order and verify pickup code',
                            active: controller.hasArrivedAtVendor,
                            completed: controller.hasPickedUp,
                          ),
                          const _StepDivider(),
                          _StepItem(
                            title: 'Arrive at Customer',
                            subtitle:
                                'Confirm you have reached customer location',
                            active: controller.isGoingToCustomer,
                            completed:
                                controller.hasArrivedAtCustomer ||
                                controller.isDelivered,
                          ),
                          const _StepDivider(),
                          _StepItem(
                            title: 'Confirm Delivered',
                            subtitle:
                                'Verify customer code and complete delivery',
                            active: controller.hasArrivedAtCustomer,
                            completed: controller.isDelivered,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    ElevatedButton.icon(
                      onPressed: controller.isGoingToVendor
                          ? controller.markArrivedAtVendor
                          : null,
                      icon: const Icon(Icons.storefront),
                      label: const Text('Mark Arrived at Vendor'),
                    ),

                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      onPressed: () => Get.toNamed(AppRoutes.deliveryMap),
                      icon: const Icon(Icons.map_outlined),
                      label: Text(
                        controller.isGoingToVendor
                            ? 'Follow Map to Vendor'
                            : controller.isGoingToCustomer
                            ? 'Follow Map to Customer'
                            : 'View Delivery Map',
                      ),
                    ),

                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      onPressed: controller.hasArrivedAtVendor
                          ? () => Get.toNamed(AppRoutes.confirmPickup)
                          : null,
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('Confirm Pickup'),
                    ),

                    const SizedBox(height: 12),

                    ElevatedButton.icon(
                      onPressed: controller.isGoingToCustomer
                          ? controller.markArrivedAtCustomer
                          : null,
                      icon: const Icon(Icons.location_on_outlined),
                      label: const Text('Mark Arrived at Customer'),
                    ),

                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      onPressed: controller.hasArrivedAtCustomer
                          ? () => Get.toNamed(AppRoutes.confirmDelivered)
                          : null,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Confirm Delivered'),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _infoRow({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            color: AppTheme.secondary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: AppTheme.secondary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EtaCard extends StatelessWidget {
  final DeliveryController controller;

  const _EtaCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final bool goingToVendor = controller.isGoingToVendor;
    final bool goingToCustomer = controller.isGoingToCustomer;

    String title = 'Current Route';
    String time = 'Waiting';
    String subtitle = 'Delivery route will update based on your progress.';
    IconData icon = Icons.route_outlined;
    Color color = AppTheme.secondary;

    if (goingToVendor) {
      title = 'Time to Vendor';
      time = '${controller.minutesToVendor} mins';
      subtitle =
          '${controller.distanceToVendorKm.toStringAsFixed(2)} km to pickup location';
      icon = Icons.storefront;
      color = Colors.orange;
    } else if (goingToCustomer) {
      title = 'Time to Customer';
      time = '${controller.minutesToCustomer} mins';
      subtitle =
          '${controller.distanceToCustomerKm.toStringAsFixed(2)} km to delivery location';
      icon = Icons.location_on_outlined;
      color = AppTheme.green;
    } else if (controller.hasArrivedAtVendor && !controller.hasPickedUp) {
      title = 'Vendor Reached';
      time = 'Arrived';
      subtitle = 'Confirm pickup with vendor verification code.';
      icon = Icons.verified_outlined;
      color = AppTheme.green;
    } else if (controller.hasArrivedAtCustomer && !controller.isDelivered) {
      title = 'Customer Reached';
      time = 'Arrived';
      subtitle = 'Confirm delivery with customer verification code.';
      icon = Icons.verified_outlined;
      color = AppTheme.green;
    } else if (controller.isDelivered) {
      title = 'Delivery Completed';
      time = 'Done';
      subtitle = 'This order has been completed successfully.';
      icon = Icons.check_circle_outline;
      color = AppTheme.green;
    }

    return SectionCard(
      child: Row(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryHeader extends StatelessWidget {
  const _DeliveryHeader();

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
      child: const Row(
        children: [
          Icon(Icons.delivery_dining, color: Colors.white, size: 44),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Delivery',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Follow route, confirm pickup, and complete delivery safely.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool active;
  final bool completed;

  const _StepItem({
    required this.title,
    required this.subtitle,
    required this.active,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = completed
        ? AppTheme.green
        : active
        ? AppTheme.secondary
        : AppTheme.textMuted;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          completed ? Icons.check_circle : Icons.radio_button_checked,
          color: color,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: active || completed
                      ? AppTheme.textDark
                      : AppTheme.textMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepDivider extends StatelessWidget {
  const _StepDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 11, top: 8, bottom: 8),
      height: 28,
      width: 2,
      color: const Color(0xFFE2E8F0),
    );
  }
}
