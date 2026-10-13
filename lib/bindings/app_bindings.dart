import 'package:get/get.dart';
import '../core/api/api_client.dart';
import '../core/api/api_helpers.dart';
import '../features/agreement/controller/rider_agreement_controller.dart';

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
    final agreement = Get.put<RiderAgreementController>(
      RiderAgreementController(),
      permanent: true,
    );
    ApiClient.onProtectedError = (error) {
      final code = asMap(error.response?.data)['code']?.toString() ?? '';
      if (code.startsWith('RIDER_AGREEMENT_')) agreement.requireReview();
      if (error.response?.statusCode == 401) agreement.ensureAccepted();
    };
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
