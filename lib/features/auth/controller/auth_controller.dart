import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_helpers.dart';
import '../../../core/push/onesignal_service.dart';
import '../../../core/storage/app_storage.dart';
import '../../../features/earnings/controller/withdrawal_controller.dart';
import '../../../features/notifications/controller/notification_controller.dart';
import '../../../features/orders/controller/delivery_controller.dart';
import '../../../features/orders/controller/orders_controller.dart';
import '../../../features/profile/controller/rider_profile_controller.dart';
import '../../../routes/app_routes.dart';
import '../service/auth_api.dart';

class AuthController extends GetxController {
  final emailOrPhoneController = TextEditingController();
  final passwordController = TextEditingController();
  final forgotEmailController = TextEditingController();

  // Personal information
  final fullNameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final registerPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final dateOfBirthController = TextEditingController();
  final genderController = TextEditingController();
  final homeAddressController = TextEditingController();

  // Operation information
  final stateController = TextEditingController();
  final cityController = TextEditingController();
  final deliveryZoneController = TextEditingController();
  final vehicleTypeController = TextEditingController();
  final vehicleModelController = TextEditingController();
  final plateNumberController = TextEditingController();
  final licenseNumberController = TextEditingController();

  // Verification information
  final idTypeController = TextEditingController();
  final idNumberController = TextEditingController();

  // Bank information
  final bankNameController = TextEditingController();
  final accountNumberController = TextEditingController();
  final accountNameController = TextEditingController();

  // Emergency contact
  final emergencyNameController = TextEditingController();
  final emergencyPhoneController = TextEditingController();
  final emergencyRelationshipController = TextEditingController();

  final ninFront = Rxn<XFile>();
  final ninBack = Rxn<XFile>();
  final platePhoto = Rxn<XFile>();
  final selfie = Rxn<XFile>();

  final isLoading = false.obs;
  final isResetLoading = false.obs;
  final acceptedTerms = false.obs;

  final _imagePicker = ImagePicker();

  Future<void> pickRegistrationDocument(Rx<XFile?> target) async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image != null) target.value = image;
  }

  Future<void> login() async {
    final emailOrPhone = emailOrPhoneController.text.trim();
    final password = passwordController.text.trim();

    if (emailOrPhone.isEmpty || password.isEmpty) {
      Get.snackbar('Error', 'Please enter email/phone and password');
      return;
    }

    try {
      isLoading.value = true;
      final oneSignalPlayerId = await OneSignalService.pushSubscriptionId();

      final data = asMap(
        await AuthApi.login(
          emailOrPhone: emailOrPhone,
          password: password,
          oneSignalPlayerId: oneSignalPlayerId,
        ),
      );

      final riderId = asString(data['_id']);
      final status = asString(data['status'], 'pending');
      final email = asString(data['email'], emailOrPhone);
      final vehicleType = asString(data['vehicleType']);

      await AppStorage.saveToken(asString(data['token']));
      await AppStorage.saveRiderStatus(status);
      await AppStorage.saveRiderIdentity(
        name: asString(data['fullName'], 'NaijaGo Rider'),
        email: email,
      );
      await OneSignalService.loginRider(
        riderId: riderId,
        email: email,
        status: status,
        vehicleType: vehicleType,
      );
      if (Get.isRegistered<NotificationController>()) {
        await Get.find<NotificationController>().startAfterLogin();
      }
      _refreshProtectedControllers();

      if (AppStorage.riderStatus == 'approved') {
        Get.offAllNamed(AppRoutes.dashboard);
      } else {
        Get.offAllNamed(AppRoutes.pendingApproval);
      }
    } catch (e) {
      Get.snackbar('Error', apiMessage(e, 'Login failed'));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> requestPasswordReset() async {
    final email = forgotEmailController.text.trim();

    if (email.isEmpty || !GetUtils.isEmail(email)) {
      Get.snackbar('Error', 'Please enter your rider account email');
      return;
    }

    try {
      isResetLoading.value = true;
      final data = asMap(await AuthApi.forgotPassword(email: email));
      Get.snackbar(
        'Password reset',
        asString(
          data['message'],
          'If this rider email exists, a reset link has been sent.',
        ),
      );
    } catch (e) {
      Get.snackbar('Error', apiMessage(e, 'Unable to send reset link'));
    } finally {
      isResetLoading.value = false;
    }
  }

  Future<void> register() async {
    if (registerPasswordController.text.trim() !=
        confirmPasswordController.text.trim()) {
      Get.snackbar('Error', 'Passwords do not match');
      return;
    }

    if (!acceptedTerms.value) {
      Get.snackbar('Error', 'Please accept the terms and conditions');
      return;
    }

    if (ninFront.value == null ||
        ninBack.value == null ||
        platePhoto.value == null ||
        selfie.value == null) {
      Get.snackbar('Error', 'Please upload all required verification images');
      return;
    }

    try {
      isLoading.value = true;

      await AuthApi.register(
        fullName: fullNameController.text.trim(),
        phone: phoneController.text.trim(),
        email: emailController.text.trim(),
        password: registerPasswordController.text.trim(),
        dateOfBirth: dateOfBirthController.text.trim(),
        gender: genderController.text.trim(),
        homeAddress: homeAddressController.text.trim(),
        state: stateController.text.trim(),
        city: cityController.text.trim(),
        deliveryZone: deliveryZoneController.text.trim(),
        vehicleType: vehicleTypeController.text.trim(),
        vehicleModel: vehicleModelController.text.trim(),
        plateNumber: plateNumberController.text.trim(),
        licenseNumber: licenseNumberController.text.trim(),
        idType: idTypeController.text.trim(),
        idNumber: idNumberController.text.trim(),
        bankName: bankNameController.text.trim(),
        accountNumber: accountNumberController.text.trim(),
        accountName: accountNameController.text.trim(),
        emergencyName: emergencyNameController.text.trim(),
        emergencyPhone: emergencyPhoneController.text.trim(),
        emergencyRelationship: emergencyRelationshipController.text.trim(),
        ninFront: ninFront.value!,
        ninBack: ninBack.value!,
        platePhoto: platePhoto.value!,
        selfie: selfie.value!,
      );

      Get.offAllNamed(AppRoutes.pendingApproval);
    } catch (e) {
      Get.snackbar('Error', apiMessage(e, 'Registration failed'));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    if (Get.isRegistered<NotificationController>()) {
      Get.find<NotificationController>().stopLiveNotifications();
    }
    await OneSignalService.logout();
    await AppStorage.clear();
    resetLoginForm();
    Get.offAllNamed(AppRoutes.login);
  }

  void resetRegistrationForm() {
    fullNameController.clear();
    phoneController.clear();
    emailController.clear();
    registerPasswordController.clear();
    confirmPasswordController.clear();
    dateOfBirthController.clear();
    genderController.clear();
    homeAddressController.clear();

    stateController.clear();
    cityController.clear();
    deliveryZoneController.clear();
    vehicleTypeController.clear();
    vehicleModelController.clear();
    plateNumberController.clear();
    licenseNumberController.clear();

    idTypeController.clear();
    idNumberController.clear();

    bankNameController.clear();
    accountNumberController.clear();
    accountNameController.clear();

    emergencyNameController.clear();
    emergencyPhoneController.clear();
    emergencyRelationshipController.clear();

    ninFront.value = null;
    ninBack.value = null;
    platePhoto.value = null;
    selfie.value = null;
    acceptedTerms.value = false;
  }

  void resetLoginForm() {
    emailOrPhoneController.clear();
    passwordController.clear();
    forgotEmailController.clear();
  }

  void _refreshProtectedControllers() {
    if (Get.isRegistered<RiderProfileController>()) {
      Get.find<RiderProfileController>().loadProfile();
    }
    if (Get.isRegistered<WithdrawalController>()) {
      Get.find<WithdrawalController>().loadEarnings();
    }
    if (Get.isRegistered<DeliveryController>()) {
      Get.find<DeliveryController>().loadActiveDelivery();
    }
    if (Get.isRegistered<OrdersController>()) {
      Get.find<OrdersController>().loadAssignedOrders();
    }
  }

  // Important:
  // We are not disposing TextEditingControllers here because this controller is
  // registered globally with GetX and reused across login, register, profile,
  // browser refresh, and web routes. Disposing them can cause:
  // "A TextEditingController was used after being disposed."
}
