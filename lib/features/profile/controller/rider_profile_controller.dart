import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/api/api_helpers.dart';
import '../../../core/storage/app_storage.dart';
import '../../orders/service/rider_api.dart';

class RiderProfileController extends GetxController {
  // Account status
  final approvalStatus = 'Approved Rider'.obs;
  final statusDescription = 'You can receive and complete delivery jobs.'.obs;

  // Locked personal information
  final fullName = 'Not provided'.obs;
  final email = 'Not provided'.obs;
  final dateOfBirth = 'Not provided'.obs;
  final gender = 'Not provided'.obs;

  // Editable contact information
  final phoneController = TextEditingController(text: 'Not provided');
  final homeAddressController = TextEditingController(text: 'Not provided');

  // Editable operation information
  final stateController = TextEditingController(text: 'Not provided');
  final cityController = TextEditingController(text: 'Not provided');
  final deliveryZoneController = TextEditingController(text: 'Not provided');
  final vehicleTypeController = TextEditingController(text: 'Not provided');
  final vehicleModelController = TextEditingController(text: 'Not provided');
  final plateNumberController = TextEditingController(text: 'Not provided');

  // Locked verification information
  final licenseNumber = 'Not provided'.obs;
  final idType = 'Not provided'.obs;
  final idNumber = 'Not provided'.obs;

  // Editable bank information
  final bankNameController = TextEditingController(text: 'Not provided');
  final accountNumberController = TextEditingController(text: 'Not provided');
  final accountNameController = TextEditingController(text: 'Not provided');

  // Editable emergency contact
  final emergencyNameController = TextEditingController(text: 'Not provided');
  final emergencyPhoneController = TextEditingController(text: 'Not provided');
  final emergencyRelationshipController = TextEditingController(
    text: 'Not provided',
  );

  final isSaving = false.obs;

  @override
  void onInit() {
    super.onInit();
    if (_hasToken) loadProfile();
  }

  Future<void> loadProfile() async {
    if (!_hasToken) return;

    try {
      final data = await RiderApi.profile();
      final status = asString(data['status'], 'pending');
      approvalStatus.value = _statusLabel(status);
      statusDescription.value = _statusDescription(status);

      fullName.value = asString(data['fullName'], 'NaijaGo Rider');
      email.value = asString(data['email'], 'Not provided');
      dateOfBirth.value = _formatDate(data['dateOfBirth']);
      gender.value = asString(data['gender'], 'Not provided');
      phoneController.text = asString(data['phoneNumber'], 'Not provided');
      homeAddressController.text = asString(
        data['homeAddress'],
        'Not provided',
      );
      stateController.text = asString(data['state'], 'Not provided');
      cityController.text = asString(data['city'], 'Not provided');
      deliveryZoneController.text = asString(
        data['deliveryZone'],
        'Not provided',
      );
      vehicleTypeController.text = asString(data['vehicleType'], 'motorcycle');
      vehicleModelController.text = asString(
        data['vehicleBrand'],
        'Not provided',
      );
      plateNumberController.text = asString(
        data['plateNumber'],
        'Not provided',
      );
      licenseNumber.value = asString(data['licenseNumber'], 'Not provided');
      idType.value = asString(data['idType'], _documentLabel(data));
      idNumber.value = asString(data['idNumber'], 'Not provided');

      final emergency = asMap(data['emergencyContact']);
      emergencyNameController.text = asString(
        emergency['name'],
        'Not provided',
      );
      emergencyPhoneController.text = asString(
        emergency['phone'],
        'Not provided',
      );
      emergencyRelationshipController.text = asString(
        emergency['relationship'],
        'Not provided',
      );

      final bank = asMap(data['bankAccount']);
      bankNameController.text = asString(bank['bankName'], 'Not provided');
      accountNumberController.text = asString(
        bank['accountNumber'],
        'Not provided',
      );
      accountNameController.text = asString(
        bank['accountName'],
        fullName.value,
      );

      update();
    } catch (e) {
      Get.snackbar('Error', apiMessage(e, 'Unable to load rider profile'));
    }
  }

  Future<void> saveProfileChanges() async {
    if (!_hasToken) return;

    try {
      isSaving.value = true;

      await RiderApi.updateProfile(
        phoneNumber: _editableValue(phoneController.text),
        homeAddress: _editableValue(homeAddressController.text),
        state: _editableValue(stateController.text),
        city: _editableValue(cityController.text),
        deliveryZone: _editableValue(deliveryZoneController.text),
        vehicleType: _vehicleType(vehicleTypeController.text),
        vehicleBrand: _editableValue(vehicleModelController.text),
        licenseNumber: _editableValue(licenseNumber.value),
        idType: _editableValue(idType.value),
        idNumber: _editableValue(idNumber.value),
        emergencyName: _editableValue(emergencyNameController.text),
        emergencyPhone: _editableValue(emergencyPhoneController.text),
        emergencyRelationship: _editableValue(
          emergencyRelationshipController.text,
        ),
      );

      final bankName = _editableValue(bankNameController.text);
      final accountNumber = _editableValue(accountNumberController.text);
      final accountName = _editableValue(accountNameController.text);
      if (bankName != null && accountNumber != null && accountName != null) {
        await RiderApi.updateBankAccount(
          bankName: bankName,
          accountNumber: accountNumber,
          accountName: accountName,
        );
      }

      await loadProfile();

      Get.snackbar(
        'Profile Updated',
        'Your rider profile information has been updated.',
      );
    } catch (e) {
      Get.snackbar('Error', apiMessage(e, 'Unable to update profile'));
    } finally {
      isSaving.value = false;
    }
  }

  bool get _hasToken {
    final token = AppStorage.token;
    return token != null && token.isNotEmpty;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Approved Rider';
      case 'rejected':
        return 'Application Rejected';
      case 'suspended':
        return 'Account Suspended';
      default:
        return 'Pending Approval';
    }
  }

  String _statusDescription(String status) {
    switch (status) {
      case 'approved':
        return 'You can receive and complete delivery jobs.';
      case 'rejected':
        return 'Please contact NaijaGo support for next steps.';
      case 'suspended':
        return 'Please contact support to restore your account.';
      default:
        return 'Your rider application is under admin review.';
    }
  }

  String _vehicleType(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.contains('bike') || normalized.contains('motor')) {
      return 'motorcycle';
    }
    if (normalized.contains('bicycle')) return 'bicycle';
    if (normalized.contains('car')) return 'car';
    if (normalized.contains('scooter')) return 'scooter';
    return 'motorcycle';
  }

  String? _editableValue(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == 'Not provided') return null;
    return trimmed;
  }

  String _formatDate(dynamic value) {
    final text = asString(value);
    final date = DateTime.tryParse(text);
    if (date == null) return 'Not provided';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _documentLabel(Map<String, dynamic> data) {
    final documents = asMap(data['documents']);
    if (asString(documents['ninFront']).isNotEmpty ||
        asString(documents['ninBack']).isNotEmpty) {
      return 'NIN';
    }
    if (asString(documents['driverLicense']).isNotEmpty) {
      return 'Driver License';
    }
    return 'Not provided';
  }

  @override
  void onClose() {
    phoneController.dispose();
    homeAddressController.dispose();

    stateController.dispose();
    cityController.dispose();
    deliveryZoneController.dispose();
    vehicleTypeController.dispose();
    vehicleModelController.dispose();
    plateNumberController.dispose();

    bankNameController.dispose();
    accountNumberController.dispose();
    accountNameController.dispose();

    emergencyNameController.dispose();
    emergencyPhoneController.dispose();
    emergencyRelationshipController.dispose();

    super.onClose();
  }
}
