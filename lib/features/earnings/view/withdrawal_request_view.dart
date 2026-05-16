import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/section_card.dart';
import '../controller/withdrawal_controller.dart';

class WithdrawalRequestView extends StatelessWidget {
  const WithdrawalRequestView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<WithdrawalController>();

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Obx(
              () => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _topBar(),
                  const SizedBox(height: 18),

                  const _WithdrawalHeader(),

                  const SizedBox(height: 22),

                  const Text(
                    'Withdrawal Request',
                    style: TextStyle(
                      color: AppTheme.textDark,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Request payout from your available rider earnings to your registered bank account.',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 18),

                  SectionCard(
                    child: Row(
                      children: [
                        Container(
                          height: 54,
                          width: 54,
                          decoration: BoxDecoration(
                            color: AppTheme.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_outlined,
                            color: AppTheme.green,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Available Balance',
                                style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₦${controller.availableBalance.value.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: AppTheme.textDark,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Bank Account',
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
                        _infoRow(
                          title: 'Bank Name',
                          value: controller.bankName.value,
                          icon: Icons.account_balance_outlined,
                        ),
                        const Divider(height: 24),
                        _infoRow(
                          title: 'Account Number',
                          value: controller.accountNumber.value,
                          icon: Icons.pin_outlined,
                        ),
                        const Divider(height: 24),
                        _infoRow(
                          title: 'Account Name',
                          value: controller.accountName.value,
                          icon: Icons.person_pin_outlined,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Request Details',
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
                        TextField(
                          controller: controller.amountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Withdrawal Amount',
                            hintText: 'Enter amount',
                            prefixIcon: Icon(Icons.payments_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: controller.noteController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Note / Remark',
                            hintText: 'Optional withdrawal note',
                            prefixIcon: Icon(Icons.note_alt_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const _WithdrawalNotice(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  ElevatedButton.icon(
                    onPressed: controller.isSubmitting.value
                        ? null
                        : () => _confirmWithdrawal(context, controller),
                    icon: const Icon(Icons.send_outlined),
                    label: Text(
                      controller.isSubmitting.value
                          ? 'Submitting Request...'
                          : 'Submit Withdrawal Request',
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        IconButton(onPressed: Get.back, icon: const Icon(Icons.arrow_back)),
        const SizedBox(width: 6),
        const Expanded(
          child: Text(
            'Withdrawal',
            style: TextStyle(
              color: AppTheme.textDark,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
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

  void _confirmWithdrawal(
    BuildContext context,
    WithdrawalController controller,
  ) {
    final amount = controller.amountController.text.trim();

    if (amount.isEmpty) {
      Get.snackbar('Error', 'Please enter withdrawal amount');
      return;
    }

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 5,
                width: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              const SizedBox(height: 20),
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: AppTheme.green,
                size: 42,
              ),
              const SizedBox(height: 12),
              const Text(
                'Confirm Withdrawal',
                style: TextStyle(
                  color: AppTheme.textDark,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You are requesting withdrawal of ₦$amount to your registered bank account.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              SectionCard(
                child: Column(
                  children: [
                    _infoRow(
                      title: 'Bank Name',
                      value: controller.bankName.value,
                      icon: Icons.account_balance_outlined,
                    ),
                    const Divider(height: 24),
                    _infoRow(
                      title: 'Account Number',
                      value: controller.accountNumber.value,
                      icon: Icons.pin_outlined,
                    ),
                    const Divider(height: 24),
                    _infoRow(
                      title: 'Account Name',
                      value: controller.accountName.value,
                      icon: Icons.person_pin_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () async {
                  Get.back();

                  final success = await controller.submitWithdrawal();

                  if (success) {
                    Get.snackbar(
                      'Request Submitted',
                      'Your withdrawal request has been submitted for processing.',
                      backgroundColor: AppTheme.green,
                      colorText: Colors.white,
                    );

                    Get.back();
                  }
                },
                child: const Text('Confirm Request'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: Get.back, child: const Text('Cancel')),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }
}

class _WithdrawalHeader extends StatelessWidget {
  const _WithdrawalHeader();

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
          Icon(Icons.payments_outlined, color: Colors.white, size: 44),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Request Payout',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Withdraw completed delivery earnings to your bank account.',
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

class _WithdrawalNotice extends StatelessWidget {
  const _WithdrawalNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.14)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppTheme.secondary, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Withdrawal requests are reviewed by NaijaGo admin before payout. Bank details can be updated from your rider profile.',
              style: TextStyle(
                color: AppTheme.textDark,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
