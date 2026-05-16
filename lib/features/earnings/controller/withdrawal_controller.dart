import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/api/api_helpers.dart';
import '../../../core/storage/app_storage.dart';
import '../../orders/service/rider_api.dart';

class WithdrawalController extends GetxController {
  final amountController = TextEditingController();
  final noteController = TextEditingController();

  final isLoading = false.obs;
  final isSubmitting = false.obs;

  final availableBalance = 0.0.obs;
  final totalEarnings = 0.0.obs;
  final pendingEarnings = 0.0.obs;
  final totalWithdrawn = 0.0.obs;
  final weeklyEarnings = 0.0.obs;
  final monthlyEarnings = 0.0.obs;
  final canWithdraw = false.obs;
  final withdrawalHistory = <Map<String, dynamic>>[].obs;

  final bankName = 'Not provided'.obs;
  final accountNumber = 'Not provided'.obs;
  final accountName = 'Not provided'.obs;

  @override
  void onInit() {
    super.onInit();
    if (_hasToken) loadEarnings();
  }

  Future<void> loadEarnings() async {
    if (!_hasToken) return;

    isLoading.value = true;
    try {
      final data = await RiderApi.earnings();
      availableBalance.value = asDouble(
        data['availableForWithdrawal'] ?? data['walletBalance'],
      );
      totalEarnings.value = asDouble(data['totalEarnings']);
      pendingEarnings.value = asDouble(data['pendingEarnings']);
      totalWithdrawn.value = asDouble(data['totalWithdrawn']);
      weeklyEarnings.value = asDouble(data['weeklyEarnings']);
      monthlyEarnings.value = asDouble(data['monthlyEarnings']);
      canWithdraw.value = data['canWithdraw'] == true;
      withdrawalHistory.assignAll(
        asList(data['withdrawalHistory']).map((item) => asMap(item)).toList(),
      );

      final profile = await RiderApi.profile();
      final bank = asMap(profile['bankAccount']);
      bankName.value = asString(bank['bankName'], 'Not provided');
      accountNumber.value = asString(bank['accountNumber'], 'Not provided');
      accountName.value = asString(bank['accountName'], 'Not provided');
    } catch (e) {
      Get.snackbar('Error', apiMessage(e, 'Unable to load rider earnings'));
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> submitWithdrawal() async {
    if (!_hasToken) return false;

    final amountText = amountController.text.trim();

    if (amountText.isEmpty) {
      Get.snackbar('Error', 'Please enter withdrawal amount');
      return false;
    }

    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      Get.snackbar('Error', 'Please enter a valid amount');
      return false;
    }

    if (amount > availableBalance.value) {
      Get.snackbar('Error', 'Amount is higher than available balance');
      return false;
    }

    if (bankName.value == 'Not provided' ||
        accountNumber.value == 'Not provided' ||
        accountName.value == 'Not provided') {
      Get.snackbar('Error', 'Please update your bank account in profile first');
      return false;
    }

    try {
      isSubmitting.value = true;

      final data = await RiderApi.requestWithdrawal(
        amount: amount,
        accountDetails: {
          'bankName': bankName.value,
          'accountNumber': accountNumber.value,
          'accountName': accountName.value,
        },
      );

      availableBalance.value = asDouble(
        data['newBalance'],
        availableBalance.value - amount,
      );
      amountController.clear();
      noteController.clear();
      await loadEarnings();

      return true;
    } catch (e) {
      Get.snackbar('Error', apiMessage(e, 'Withdrawal request failed'));
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  @override
  void onClose() {
    amountController.dispose();
    noteController.dispose();
    super.onClose();
  }

  bool get _hasToken {
    final token = AppStorage.token;
    return token != null && token.isNotEmpty;
  }
}
