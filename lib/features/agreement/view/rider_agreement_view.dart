import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/section_card.dart';
import '../../../routes/app_routes.dart';
import '../../../core/storage/app_storage.dart';
import '../../orders/controller/delivery_controller.dart';
import '../../auth/controller/auth_controller.dart';
import '../controller/rider_agreement_controller.dart';

class RiderAgreementView extends StatefulWidget {
  const RiderAgreementView({super.key, this.controller});
  final RiderAgreementController? controller;
  @override
  State<RiderAgreementView> createState() => _RiderAgreementViewState();
}

class _RiderAgreementViewState extends State<RiderAgreementView> {
  late final RiderAgreementController controller;
  bool finishing = false;

  Future<void> finishActiveDelivery() async {
    if (finishing || !Get.isRegistered<DeliveryController>()) return;
    setState(() => finishing = true);
    try {
      final delivery = Get.find<DeliveryController>();
      await delivery.loadActiveDelivery();
      if (!mounted) return;
      if (delivery.activeDeliveryError.value.isNotEmpty ||
          delivery.activeOrder.value == null) {
        controller.error.value = delivery.activeDeliveryError.value.isNotEmpty
            ? delivery.activeDeliveryError.value
            : 'No claimed active delivery was found.';
        return;
      }
      Get.toNamed(AppRoutes.activeDelivery);
    } finally {
      if (mounted) setState(() => finishing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    controller = widget.controller ?? Get.find<RiderAgreementController>();
    controller.load();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Obx(
            () => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Icon(
                  Icons.handshake_outlined,
                  size: 42,
                  color: AppTheme.primary,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Rider Partnership Agreement',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26),
                ),
                const SizedBox(height: 6),
                const Text(
                  'NaijaGo App Ltd',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  controller.paused.value
                      ? 'The agreement requirement is temporarily paused by NaijaGo. Account approval and existing delivery requirements still apply.'
                      : 'Acceptance is required before going online or accepting new delivery orders. Account approval and existing delivery requirements also apply.',
                ),
                if (Get.isRegistered<DeliveryController>() &&
                    AppStorage.riderStatus == 'approved' &&
                    (AppStorage.token?.isNotEmpty ?? false))
                  TextButton.icon(
                    onPressed: finishing || controller.submitting.value
                        ? null
                        : finishActiveDelivery,
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: Text(
                      finishing
                          ? 'Checking claimed delivery...'
                          : 'Finish an already claimed delivery',
                    ),
                  ),
                const SizedBox(height: 20),
                if (controller.loading.value)
                  const Center(child: CircularProgressIndicator())
                else if (controller.paused.value) ...[
                  const SectionCard(
                    child: Text(
                      'Agreement requirement temporarily paused. No acceptance has been recorded by this action. You will be asked to review the agreement when the requirement resumes.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: controller.accessConfirmed
                        ? controller.continueIfAccepted
                        : null,
                    child: const Text('Continue'),
                  ),
                ] else if (controller.agreement.value != null) ...[
                  Text(
                    'Agreement version ${controller.agreement.value!.version}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    child: SelectableText(
                      controller.agreement.value!.content,
                      key: const ValueKey('complete-rider-agreement'),
                      style: const TextStyle(
                        height: 1.6,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Material(
                    color: Colors.transparent,
                    child: CheckboxListTile(
                      value: controller.consent.value,
                      contentPadding: EdgeInsets.zero,
                      onChanged:
                          controller.submitting.value ||
                              controller.confirmed.value
                          ? null
                          : (value) => controller.consent.value = value == true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'I have read and agree to the NaijaGo Rider Partnership Agreement.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed:
                        controller.canSubmit && !controller.confirmed.value
                        ? controller.accept
                        : null,
                    child: Text(
                      controller.submitting.value
                          ? 'Confirming acceptance...'
                          : 'I Agree and Accept',
                    ),
                  ),
                  if (controller.confirmed.value) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Acceptance confirmed by NaijaGo.',
                        style: TextStyle(color: AppTheme.green),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: controller.continueIfAccepted,
                      child: const Text('Continue'),
                    ),
                  ],
                ],
                if (controller.error.value.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      controller.error.value,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (!controller.loading.value && !controller.submitting.value)
                  TextButton.icon(
                    onPressed: controller.load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh agreement status'),
                  ),
                TextButton(
                  onPressed: controller.submitting.value
                      ? null
                      : () async {
                          if (Get.isRegistered<AuthController>()) {
                            await Get.find<AuthController>().logout();
                          } else {
                            Get.offAllNamed(AppRoutes.login);
                          }
                        },
                  child: const Text('Sign out'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
