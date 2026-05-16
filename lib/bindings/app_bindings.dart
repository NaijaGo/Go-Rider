import 'package:get/get.dart';

import '../features/auth/controller/auth_controller.dart';
import '../features/earnings/controller/withdrawal_controller.dart';
import '../features/location/controller/rider_location_controller.dart';
import '../features/map/controller/map_controller.dart';
import '../features/notifications/controller/notification_controller.dart';
import '../features/orders/controller/delivery_controller.dart';
import '../features/orders/controller/orders_controller.dart';
import '../features/profile/controller/rider_profile_controller.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() {
    Get.put<AuthController>(AuthController(), permanent: true);

    Get.put<NotificationController>(NotificationController(), permanent: true);

    Get.put<RiderLocationController>(
      RiderLocationController(),
      permanent: true,
    );

    Get.put<RiderMapController>(RiderMapController(), permanent: true);

    Get.put<DeliveryController>(DeliveryController(), permanent: true);

    Get.put<OrdersController>(OrdersController(), permanent: true);

    Get.put<WithdrawalController>(WithdrawalController(), permanent: true);

    Get.put<RiderProfileController>(RiderProfileController(), permanent: true);
  }
}
