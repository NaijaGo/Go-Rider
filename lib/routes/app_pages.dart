import 'package:get/get.dart';
import 'package:naijago_ridersapp/features/earnings/view/withdrawal_request_view.dart';
import 'package:naijago_ridersapp/features/orders/view/assigned_orders_view.dart';
import 'package:naijago_ridersapp/features/orders/view/confirm_delivered_view.dart';
import 'package:naijago_ridersapp/features/orders/view/confirm_pickup_view.dart';

import '../features/auth/view/login_view.dart';
import '../features/auth/view/forgot_password_view.dart';
import '../features/auth/view/pending_approval_view.dart';
import '../features/auth/view/register_view.dart';
import '../features/auth/view/splash_view.dart';
import '../features/dashboard/view/dashboard_view.dart';
import '../features/earnings/view/earnings_view.dart';
import '../features/map/view/delivery_map_view.dart';
import '../features/notifications/view/notifications_view.dart';
import '../features/orders/view/active_delivery_view.dart';
import '../features/profile/view/profile_view.dart';
import 'app_routes.dart';

class AppPages {
  static final pages = [
    GetPage(name: AppRoutes.splash, page: () => const SplashView()),
    GetPage(name: AppRoutes.login, page: () => const LoginView()),
    GetPage(
      name: AppRoutes.forgotPassword,
      page: () => const ForgotPasswordView(),
    ),
    GetPage(name: AppRoutes.register, page: () => const RegisterView()),
    GetPage(
      name: AppRoutes.pendingApproval,
      page: () => const PendingApprovalView(),
    ),
    GetPage(name: AppRoutes.dashboard, page: () => const DashboardView()),
    GetPage(
      name: AppRoutes.activeDelivery,
      page: () => const ActiveDeliveryView(),
    ),
    GetPage(name: AppRoutes.earnings, page: () => const EarningsView()),
    GetPage(name: AppRoutes.profile, page: () => const ProfileView()),
    GetPage(
      name: AppRoutes.notifications,
      page: () => const NotificationsView(),
    ),
    GetPage(
      name: AppRoutes.confirmPickup,
      page: () => const ConfirmPickupView(),
    ),
    GetPage(
      name: AppRoutes.confirmDelivered,
      page: () => const ConfirmDeliveredView(),
    ),
    GetPage(
      name: AppRoutes.withdrawalRequest,
      page: () => const WithdrawalRequestView(),
    ),
    GetPage(
      name: AppRoutes.assignedOrders,
      page: () => const AssignedOrdersView(),
    ),
    GetPage(name: AppRoutes.deliveryMap, page: () => const DeliveryMapView()),
  ];
}
