import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/primary_header.dart';
import '../../../core/widgets/section_card.dart';
import '../controller/auth_controller.dart';

class RegisterView extends StatelessWidget {
  const RegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AuthController>();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 380;
    final pagePadding = EdgeInsets.symmetric(
      horizontal: compact ? 14 : 20,
      vertical: 18,
    );
    final cardPadding = EdgeInsets.all(compact ? 14 : 16);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: Get.back,
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(height: 8),
                const PrimaryHeader(
                  title: 'Join NaijaGo',
                  subtitle: 'Complete your rider profile for verification.',
                  icon: Icons.two_wheeler,
                ),
                const SizedBox(height: 26),

                const _SectionTitle(
                  title: 'Personal Information',
                  subtitle: 'Basic identity details of the rider.',
                ),
                SectionCard(
                  padding: cardPadding,
                  child: Column(
                    children: [
                      _field(
                        controller: controller.fullNameController,
                        label: 'Full Name',
                        icon: Icons.badge_outlined,
                        capitalization: TextCapitalization.words,
                      ),
                      _gap(),
                      _field(
                        controller: controller.phoneController,
                        label: 'Phone Number',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      _gap(),
                      _field(
                        controller: controller.emailController,
                        label: 'Email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      _gap(),
                      _field(
                        controller: controller.dateOfBirthController,
                        label: 'Date of Birth',
                        icon: Icons.calendar_month_outlined,
                      ),
                      _gap(),
                      _field(
                        controller: controller.genderController,
                        label: 'Gender',
                        icon: Icons.person_outline,
                      ),
                      _gap(),
                      _field(
                        controller: controller.homeAddressController,
                        label: 'Home Address',
                        icon: Icons.home_outlined,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                const _SectionTitle(
                  title: 'Account Security',
                  subtitle: 'Create login password for the rider account.',
                ),
                SectionCard(
                  padding: cardPadding,
                  child: Column(
                    children: [
                      _field(
                        controller: controller.registerPasswordController,
                        label: 'Password',
                        icon: Icons.lock_outline,
                        obscureText: true,
                      ),
                      _gap(),
                      _field(
                        controller: controller.confirmPasswordController,
                        label: 'Confirm Password',
                        icon: Icons.lock_reset_outlined,
                        obscureText: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                const _SectionTitle(
                  title: 'Operation Information',
                  subtitle: 'Where and how the rider will operate.',
                ),
                SectionCard(
                  padding: cardPadding,
                  child: Column(
                    children: [
                      _field(
                        controller: controller.stateController,
                        label: 'State',
                        icon: Icons.map_outlined,
                      ),
                      _gap(),
                      _field(
                        controller: controller.cityController,
                        label: 'City / Operating Area',
                        icon: Icons.location_city_outlined,
                      ),
                      _gap(),
                      _field(
                        controller: controller.deliveryZoneController,
                        label: 'Preferred Delivery Zone',
                        icon: Icons.route_outlined,
                      ),
                      _gap(),
                      _field(
                        controller: controller.vehicleTypeController,
                        label: 'Vehicle Type',
                        icon: Icons.two_wheeler_outlined,
                      ),
                      _gap(),
                      _field(
                        controller: controller.vehicleModelController,
                        label: 'Vehicle Brand / Model',
                        icon: Icons.directions_bike_outlined,
                      ),
                      _gap(),
                      _field(
                        controller: controller.plateNumberController,
                        label: 'Plate Number',
                        icon: Icons.confirmation_number_outlined,
                        capitalization: TextCapitalization.characters,
                      ),
                      _gap(),
                      _field(
                        controller: controller.licenseNumberController,
                        label: 'Driver’s License Number',
                        icon: Icons.credit_card_outlined,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                const _SectionTitle(
                  title: 'Verification Documents',
                  subtitle: 'Documents required for admin approval.',
                ),
                SectionCard(
                  padding: cardPadding,
                  child: Column(
                    children: [
                      _field(
                        controller: controller.idTypeController,
                        label: 'ID Type',
                        icon: Icons.assignment_ind_outlined,
                      ),
                      _gap(),
                      _field(
                        controller: controller.idNumberController,
                        label: 'ID Number',
                        icon: Icons.numbers_outlined,
                      ),
                      const SizedBox(height: 14),
                      Obx(
                        () => _UploadTile(
                          title: 'Upload NIN Front',
                          subtitle: 'Front image of rider NIN',
                          icon: Icons.assignment_ind_outlined,
                          selected: controller.ninFront.value?.name,
                          onTap: () => controller.pickRegistrationDocument(
                            controller.ninFront,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Obx(
                        () => _UploadTile(
                          title: 'Upload NIN Back',
                          subtitle: 'Back image of rider NIN',
                          icon: Icons.file_upload_outlined,
                          selected: controller.ninBack.value?.name,
                          onTap: () => controller.pickRegistrationDocument(
                            controller.ninBack,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Obx(
                        () => _UploadTile(
                          title: 'Upload Plate Photo',
                          subtitle: 'Clear image of the vehicle plate',
                          icon: Icons.description_outlined,
                          selected: controller.platePhoto.value?.name,
                          onTap: () => controller.pickRegistrationDocument(
                            controller.platePhoto,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Obx(
                        () => _UploadTile(
                          title: 'Upload Selfie',
                          subtitle: 'Rider face photo for identification',
                          icon: Icons.account_circle_outlined,
                          selected: controller.selfie.value?.name,
                          onTap: () => controller.pickRegistrationDocument(
                            controller.selfie,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                const _SectionTitle(
                  title: 'Bank Information',
                  subtitle: 'Where rider earnings will be paid.',
                ),
                SectionCard(
                  padding: cardPadding,
                  child: Column(
                    children: [
                      _field(
                        controller: controller.bankNameController,
                        label: 'Bank Name',
                        icon: Icons.account_balance_outlined,
                      ),
                      _gap(),
                      _field(
                        controller: controller.accountNumberController,
                        label: 'Account Number',
                        icon: Icons.pin_outlined,
                        keyboardType: TextInputType.number,
                      ),
                      _gap(),
                      _field(
                        controller: controller.accountNameController,
                        label: 'Account Name',
                        icon: Icons.person_pin_outlined,
                        capitalization: TextCapitalization.words,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                const _SectionTitle(
                  title: 'Emergency Contact',
                  subtitle: 'Person NaijaGo can contact if needed.',
                ),
                SectionCard(
                  padding: cardPadding,
                  child: Column(
                    children: [
                      _field(
                        controller: controller.emergencyNameController,
                        label: 'Emergency Contact Name',
                        icon: Icons.contact_emergency_outlined,
                        capitalization: TextCapitalization.words,
                      ),
                      _gap(),
                      _field(
                        controller: controller.emergencyPhoneController,
                        label: 'Emergency Contact Phone',
                        icon: Icons.phone_in_talk_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      _gap(),
                      _field(
                        controller: controller.emergencyRelationshipController,
                        label: 'Relationship',
                        icon: Icons.group_outlined,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                Obx(
                  () => CheckboxListTile(
                    value: controller.acceptedTerms.value,
                    onChanged: (value) {
                      controller.acceptedTerms.value = value ?? false;
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'I confirm that the information provided is correct and I agree to NaijaGo rider terms.',
                      style: TextStyle(
                        color: AppTheme.textDark,
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                Obx(
                  () => ElevatedButton(
                    onPressed: controller.isLoading.value
                        ? null
                        : controller.register,
                    child: Text(
                      controller.isLoading.value
                          ? 'Submitting...'
                          : 'Submit Registration',
                    ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    int maxLines = 1,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      minLines: maxLines > 1 ? 1 : null,
      textCapitalization: capitalization,
      textInputAction: maxLines > 1
          ? TextInputAction.newline
          : TextInputAction.next,
      style: const TextStyle(
        color: AppTheme.textDark,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        hintText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        alignLabelWithHint: maxLines > 1,
        prefixIcon: Icon(icon, size: 21),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 42,
          minHeight: 48,
        ),
        contentPadding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        labelStyle: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: TextStyle(
          color: AppTheme.textMuted.withValues(alpha: 0.58),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.secondary, width: 1.5),
        ),
      ),
    );
  }

  Widget _gap() => const SizedBox(height: 14);
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textDark,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? selected;
  final VoidCallback onTap;

  const _UploadTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final hasSelected = selected != null && selected!.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textDark,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasSelected ? selected! : subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasSelected ? AppTheme.green : AppTheme.textMuted,
                      fontSize: 12,
                      fontWeight: hasSelected ? FontWeight.w800 : null,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              hasSelected ? Icons.check_circle : Icons.upload_file,
              color: hasSelected ? AppTheme.green : AppTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
