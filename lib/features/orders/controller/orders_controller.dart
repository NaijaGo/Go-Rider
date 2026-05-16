import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/api/api_helpers.dart';
import '../../../core/storage/app_storage.dart';
import '../../../routes/app_routes.dart';
import '../model/rider_order.dart';
import '../service/rider_api.dart';
import 'delivery_controller.dart';

class OrdersController extends GetxController {
  final isLoading = false.obs;
  final assignedOrders = <RiderOrder>[].obs;

  @override
  void onInit() {
    super.onInit();
    if (_hasToken) loadAssignedOrders();
  }

  Future<void> loadAssignedOrders() async {
    if (!_hasToken) {
      assignedOrders.clear();
      return;
    }

    try {
      isLoading.value = true;
      final orders = await RiderApi.availableOrders();
      assignedOrders.assignAll(orders.map(RiderOrder.fromBackend));
    } catch (e) {
      Get.snackbar('Error', apiMessage(e, 'Unable to load available orders'));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> acceptOrder(RiderOrder order) async {
    if (!_hasToken) return;

    try {
      isLoading.value = true;
      await RiderApi.claimOrder(order.id);

      Get.find<DeliveryController>().setActiveOrder(order);
      assignedOrders.removeWhere((item) => item.id == order.id);

      Get.snackbar(
        'Order Accepted',
        '${order.orderCode} is now your active delivery.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      Get.toNamed(AppRoutes.activeDelivery);
    } catch (e) {
      Get.snackbar('Error', apiMessage(e, 'Unable to accept order'));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> rejectOrder(RiderOrder order) async {
    if (!_hasToken) return;

    try {
      isLoading.value = true;
      await RiderApi.rejectOrder(order.id);

      assignedOrders.removeWhere((item) => item.id == order.id);

      Get.snackbar(
        'Order Rejected',
        '${order.orderCode} has been removed from your assigned orders.',
      );
    } catch (e) {
      Get.snackbar('Error', apiMessage(e, 'Unable to reject order'));
    } finally {
      isLoading.value = false;
    }
  }

  bool get _hasToken {
    final token = AppStorage.token;
    return token != null && token.isNotEmpty;
  }
}
