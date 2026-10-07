import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api/api_helpers.dart';
import '../../../core/storage/app_storage.dart';
import '../../earnings/controller/withdrawal_controller.dart';
import '../../map/controller/map_controller.dart';
import '../model/rider_order.dart';
import '../service/rider_api.dart';

enum DeliveryStage {
  goingToVendor,
  arrivedAtVendor,
  pickedUp,
  goingToCustomer,
  arrivedAtCustomer,
  delivered,
}

class DeliveryController extends GetxController {
  final stage = DeliveryStage.goingToVendor.obs;

  final activeOrder = Rxn<RiderOrder>();
  final isLoadingActiveDelivery = false.obs;
  final activeDeliveryError = ''.obs;
  final currentPickupIndex = 0.obs;

  final riderLocation = const LatLng(0, 0).obs;
  final vendorLocation = const LatLng(0, 0).obs;
  final customerLocation = const LatLng(0, 0).obs;

  final vendorAddress = 'Not available'.obs;
  final customerAddress = 'Not available'.obs;

  final distance = const Distance();

  @override
  void onInit() {
    super.onInit();
    if (_hasToken) loadActiveDelivery();
  }

  Future<void> loadActiveDelivery() async {
    if (!_hasToken) {
      clearActiveOrder();
      activeDeliveryError.value = '';
      return;
    }

    isLoadingActiveDelivery.value = true;
    activeDeliveryError.value = '';
    try {
      final orders = await RiderApi.activeOrders();
      if (orders.isEmpty) {
        clearActiveOrder();
        return;
      }

      setActiveOrder(RiderOrder.fromBackend(orders.first));
    } catch (e) {
      activeDeliveryError.value = apiMessage(
        e,
        'Unable to load active delivery',
      );
    } finally {
      isLoadingActiveDelivery.value = false;
    }
  }

  void setActiveOrder(RiderOrder order) {
    final isSameOrder = activeOrder.value?.id == order.id;
    final previousStage = stage.value;
    activeOrder.value = order.copyWith(status: RiderOrderStatus.accepted);
    if (!isSameOrder) {
      currentPickupIndex.value = 0;
    } else if (pickupStops.isNotEmpty) {
      currentPickupIndex.value = currentPickupIndex.value
          .clamp(0, pickupStops.length - 1)
          .toInt();
    }
    final firstStop = order.pickupStops.isNotEmpty ? order.pickupStops.first : null;
    final selectedStop = currentPickupStop ?? firstStop;
    vendorLocation.value = selectedStop?.location ?? order.vendorLocation;
    customerLocation.value = order.customerLocation;

    vendorAddress.value = selectedStop?.address ?? order.vendorAddress;
    customerAddress.value = order.customerAddress;

    stage.value = isSameOrder ? previousStage : DeliveryStage.goingToVendor;
    if (Get.isRegistered<RiderMapController>()) {
      Get.find<RiderMapController>().syncDelivery(this);
    }
  }

  void clearActiveOrder() {
    activeOrder.value = null;
    stage.value = DeliveryStage.goingToVendor;
  }

  String get orderCode => activeOrder.value?.orderCode ?? 'No active order';

  String get vendorName => currentPickupStop?.sellerName ??
      activeOrder.value?.vendorName ??
      'Not available';

  String get customerName => activeOrder.value?.customerName ?? 'Not available';

  String get customerPhone =>
      activeOrder.value?.customerPhone ?? 'Not available';

  String get goodsType => activeOrder.value?.goodsType ?? 'Not available';

  List<RiderPickupStop> get pickupStops =>
      activeOrder.value?.pickupStops ?? const <RiderPickupStop>[];

  RiderPickupStop? get currentPickupStop =>
      pickupStops.isEmpty || currentPickupIndex.value >= pickupStops.length
          ? null
          : pickupStops[currentPickupIndex.value];

  bool get hasNextPickupStop => currentPickupIndex.value + 1 < pickupStops.length;

  String get deliveryFeeText {
    final fee = activeOrder.value?.deliveryFee ?? 0;
    return '₦${fee.toStringAsFixed(0)}';
  }

  double get distanceToVendorKm {
    if (activeOrder.value == null) return 0;
    final meters = distance.as(
      LengthUnit.Meter,
      riderLocation.value,
      vendorLocation.value,
    );

    return meters / 1000;
  }

  double get distanceToCustomerKm {
    if (activeOrder.value == null) return 0;
    final meters = distance.as(
      LengthUnit.Meter,
      riderLocation.value,
      customerLocation.value,
    );

    return meters / 1000;
  }

  int get minutesToVendor {
    return _estimateMinutes(distanceToVendorKm);
  }

  int get minutesToCustomer {
    return _estimateMinutes(distanceToCustomerKm);
  }

  int _estimateMinutes(double km) {
    const averageBikeSpeedKmPerHour = 25;

    final minutes = (km / averageBikeSpeedKmPerHour) * 60;

    if (minutes < 1) return 1;

    return minutes.ceil();
  }

  bool get isGoingToVendor => stage.value == DeliveryStage.goingToVendor;

  bool get hasArrivedAtVendor => stage.value == DeliveryStage.arrivedAtVendor;

  bool get hasPickedUp =>
      stage.value == DeliveryStage.pickedUp ||
      stage.value == DeliveryStage.goingToCustomer ||
      stage.value == DeliveryStage.arrivedAtCustomer ||
      stage.value == DeliveryStage.delivered;

  bool get isGoingToCustomer => stage.value == DeliveryStage.goingToCustomer;

  bool get hasArrivedAtCustomer =>
      stage.value == DeliveryStage.arrivedAtCustomer;

  bool get isDelivered => stage.value == DeliveryStage.delivered;

  void markArrivedAtVendor() {
    stage.value = DeliveryStage.arrivedAtVendor;
  }

  void advanceToNextPickupStop() {
    if (!hasArrivedAtVendor || !hasNextPickupStop) return;

    currentPickupIndex.value++;
    final nextStop = currentPickupStop;
    if (nextStop == null) return;

    vendorLocation.value = nextStop.location;
    vendorAddress.value = nextStop.address;
    stage.value = DeliveryStage.goingToVendor;

    if (Get.isRegistered<RiderMapController>()) {
      Get.find<RiderMapController>().syncDelivery(this);
    }
  }

  void markPickedUp() {
    stage.value = DeliveryStage.goingToCustomer;
    if (Get.isRegistered<RiderMapController>()) {
      Get.find<RiderMapController>().syncDelivery(this);
    }
  }

  Future<bool> confirmPickup(String otp) async {
    final order = activeOrder.value;
    if (order == null) {
      Get.snackbar('Error', 'No active delivery selected');
      return false;
    }

    try {
      await RiderApi.verifyPickup(orderId: order.id, pickupOTP: otp);
      markPickedUp();
      return true;
    } catch (e) {
      Get.snackbar('Error', apiMessage(e, 'Pickup verification failed'));
      return false;
    }
  }

  void markArrivedAtCustomer() {
    stage.value = DeliveryStage.arrivedAtCustomer;
  }

  void markDelivered() {
    stage.value = DeliveryStage.delivered;

    if (activeOrder.value != null) {
      activeOrder.value = activeOrder.value!.copyWith(
        status: RiderOrderStatus.delivered,
      );
    }
  }

  Future<bool> confirmDelivery(String otp) async {
    final order = activeOrder.value;
    if (order == null) {
      Get.snackbar('Error', 'No active delivery selected');
      return false;
    }

    try {
      final data = await RiderApi.verifyDelivery(
        orderId: order.id,
        deliveryOTP: otp,
      );
      markDelivered();
      clearActiveOrder();
      if (Get.isRegistered<RiderMapController>()) {
        Get.find<RiderMapController>().stopTracking();
      }
      if (Get.isRegistered<WithdrawalController>()) {
        Get.find<WithdrawalController>().loadEarnings();
      }
      final earnings = asDouble(data['earnings']);
      Get.snackbar(
        'Delivery Complete',
        earnings > 0
            ? 'Actual earning: ₦${earnings.toStringAsFixed(0)}. You are available for the next job.'
            : asString(
                data['message'],
                'Delivery completed. You are available for the next job.',
              ),
      );
      return true;
    } catch (e) {
      Get.snackbar('Error', apiMessage(e, 'Delivery verification failed'));
      return false;
    }
  }

  bool get _hasToken {
    final token = AppStorage.token;
    return token != null && token.isNotEmpty;
  }
}
