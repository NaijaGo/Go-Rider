import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/section_card.dart';
import '../controller/delivery_controller.dart';

class ConfirmDeliveredView extends StatefulWidget {
  const ConfirmDeliveredView({super.key});

  @override
  State<ConfirmDeliveredView> createState() => _ConfirmDeliveredViewState();
}

class _ConfirmDeliveredViewState extends State<ConfirmDeliveredView> {
  final customerCodeController = TextEditingController();
  final deliveryNoteController = TextEditingController();

  final ImagePicker picker = ImagePicker();

  XFile? deliveryImage;
  bool isSubmitting = false;

  Future<void> pickDeliveryImage() async {
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (image == null) return;

    setState(() {
      deliveryImage = image;
    });
  }

  Future<void> submitDeliveryConfirmation() async {
    final customerCode = customerCodeController.text.trim();

    if (deliveryImage == null) {
      Get.snackbar('Error', 'Please capture delivery proof image');
      return;
    }

    if (customerCode.isEmpty) {
      Get.snackbar('Error', 'Please enter customer verification code');
      return;
    }

    setState(() => isSubmitting = true);

    final confirmed = await Get.find<DeliveryController>().confirmDelivery(
      customerCode,
    );

    setState(() => isSubmitting = false);

    if (!confirmed) return;

    Get.back();
  }

  @override
  void dispose() {
    customerCodeController.dispose();
    deliveryNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deliveryController = Get.find<DeliveryController>();

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

                  const _DeliveredHeader(),

                  const SizedBox(height: 22),

                  const Text(
                    'Delivery Details',
                    style: TextStyle(
                      color: AppTheme.textDark,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Confirm that the goods have reached the customer safely.',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 18),

                  SectionCard(
                    child: Column(
                      children: [
                        _infoRow(
                          title: 'Order ID',
                          value: deliveryController.orderCode,
                          icon: Icons.receipt_long,
                        ),
                        const Divider(height: 24),
                        _infoRow(
                          title: 'Vendor Address',
                          value: deliveryController.vendorAddress.value,
                          icon: Icons.storefront,
                        ),
                        const Divider(height: 24),
                        _infoRow(
                          title: 'Customer Address',
                          value: deliveryController.customerAddress.value,
                          icon: Icons.location_on_outlined,
                        ),
                        const Divider(height: 24),
                        _infoRow(
                          title: 'Customer Phone',
                          value: deliveryController.customerPhone,
                          icon: Icons.phone_outlined,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  const Text(
                    'Delivery Verification',
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
                        _DeliveryImagePicker(
                          selectedImage: deliveryImage,
                          onTap: pickDeliveryImage,
                        ),

                        const SizedBox(height: 14),

                        TextField(
                          controller: customerCodeController,
                          keyboardType: TextInputType.visiblePassword,
                          textCapitalization: TextCapitalization.characters,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: const InputDecoration(
                            labelText: 'Customer Verification Code',
                            hintText: 'Enter code collected from customer',
                            prefixIcon: Icon(Icons.verified_user_outlined),
                          ),
                        ),

                        const SizedBox(height: 14),

                        TextField(
                          controller: deliveryNoteController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Delivery Note / Remark',
                            hintText: 'Optional note about this delivery',
                            prefixIcon: Icon(Icons.note_alt_outlined),
                          ),
                        ),

                        const SizedBox(height: 10),

                        const _CustomerCodeNotice(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  ElevatedButton.icon(
                    onPressed: isSubmitting ? null : submitDeliveryConfirmation,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      isSubmitting
                          ? 'Confirming Delivery...'
                          : 'Submit Delivery Confirmation',
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
            'Confirm Delivered',
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
}

class _DeliveredHeader extends StatelessWidget {
  const _DeliveredHeader();

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
          Icon(Icons.verified_outlined, color: Colors.white, size: 44),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivery Confirmation',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Capture proof and verify customer delivery code.',
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

class _DeliveryImagePicker extends StatelessWidget {
  final XFile? selectedImage;
  final VoidCallback onTap;

  const _DeliveryImagePicker({
    required this.selectedImage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = selectedImage != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        height: hasImage ? 210 : 140,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasImage ? AppTheme.green : const Color(0xFFE2E8F0),
          ),
        ),
        child: hasImage ? _imagePreview() : _emptyUpload(),
      ),
    );
  }

  Widget _emptyUpload() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo_outlined, color: AppTheme.secondary, size: 34),
        SizedBox(height: 10),
        Text(
          'Capture Delivery Proof',
          style: TextStyle(
            color: AppTheme.textDark,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Take a clear photo after handing over goods',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _imagePreview() {
    if (kIsWeb) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.network(
          selectedImage!.path,
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.file(
        File(selectedImage!.path),
        fit: BoxFit.cover,
        width: double.infinity,
      ),
    );
  }
}

class _CustomerCodeNotice extends StatelessWidget {
  const _CustomerCodeNotice();

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
              'The delivery verification code is sent to the customer through WhatsApp and Email. Collect the code from the customer before confirming delivery.',
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
