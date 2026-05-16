import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/section_card.dart';
import '../controller/delivery_controller.dart';

class ConfirmPickupView extends StatefulWidget {
  const ConfirmPickupView({super.key});

  @override
  State<ConfirmPickupView> createState() => _ConfirmPickupViewState();
}

class _ConfirmPickupViewState extends State<ConfirmPickupView> {
  final goodsTypeController = TextEditingController();
  final verificationCodeController = TextEditingController();

  final ImagePicker picker = ImagePicker();

  XFile? selectedImage;
  bool isSubmitting = false;

  Future<void> pickGoodsImage() async {
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (image == null) return;

    setState(() {
      selectedImage = image;
    });
  }

  Future<void> submitPickupConfirmation() async {
    final goodsType = goodsTypeController.text.trim();
    final verificationCode = verificationCodeController.text.trim();

    if (goodsType.isEmpty) {
      Get.snackbar('Error', 'Please enter the type of goods picked');
      return;
    }

    if (selectedImage == null) {
      Get.snackbar('Error', 'Please upload or capture goods image');
      return;
    }

    if (verificationCode.isEmpty) {
      Get.snackbar('Error', 'Please enter vendor verification code');
      return;
    }

    setState(() => isSubmitting = true);

    final confirmed = await Get.find<DeliveryController>().confirmPickup(
      verificationCode,
    );

    setState(() => isSubmitting = false);

    if (!confirmed) return;

    Get.snackbar(
      'Pickup Confirmed',
      'Goods pickup has been confirmed successfully.',
      backgroundColor: AppTheme.green,
      colorText: Colors.white,
    );

    Get.back();
  }

  @override
  void dispose() {
    goodsTypeController.dispose();
    verificationCodeController.dispose();
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

                  const _PickupHeader(),

                  const SizedBox(height: 22),

                  const Text(
                    'Pickup Details',
                    style: TextStyle(
                      color: AppTheme.textDark,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Confirm the goods collected from the vendor before moving to the customer.',
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
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  const Text(
                    'Goods Verification',
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
                          controller: goodsTypeController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Type of Goods Picked',
                            hintText: 'Example: Food, groceries, electronics',
                            prefixIcon: Icon(Icons.inventory_2_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),

                        _GoodsImagePicker(
                          selectedImage: selectedImage,
                          onTap: pickGoodsImage,
                        ),

                        const SizedBox(height: 14),

                        TextField(
                          controller: verificationCodeController,
                          keyboardType: TextInputType.visiblePassword,
                          textCapitalization: TextCapitalization.characters,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: const InputDecoration(
                            labelText: 'Vendor Verification Code',
                            hintText: 'Enter pickup code from vendor message',
                            prefixIcon: Icon(Icons.verified_user_outlined),
                          ),
                        ),

                        const SizedBox(height: 10),

                        const _CodeNotice(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  ElevatedButton.icon(
                    onPressed: isSubmitting ? null : submitPickupConfirmation,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      isSubmitting
                          ? 'Confirming Pickup...'
                          : 'Submit Pickup Confirmation',
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
            'Confirm Pickup',
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

class _PickupHeader extends StatelessWidget {
  const _PickupHeader();

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
          Icon(Icons.inventory_2_outlined, color: Colors.white, size: 44),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pickup Confirmation',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Capture goods image and verify vendor pickup code.',
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

class _GoodsImagePicker extends StatelessWidget {
  final XFile? selectedImage;
  final VoidCallback onTap;

  const _GoodsImagePicker({required this.selectedImage, required this.onTap});

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
          'Capture Goods Image',
          style: TextStyle(
            color: AppTheme.textDark,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Take a clear photo of the goods picked',
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

class _CodeNotice extends StatelessWidget {
  const _CodeNotice();

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
              'The pickup code is shown in the vendor order message. Collect the code from the vendor before confirming pickup.',
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
