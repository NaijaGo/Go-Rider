import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/section_card.dart';
import '../../auth/controller/auth_controller.dart';
import '../controller/rider_profile_controller.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final profileController = Get.find<RiderProfileController>();

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: GetBuilder<RiderProfileController>(
            builder: (_) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _topBar(),
                  const SizedBox(height: 18),

                  _ProfileHeader(controller: profileController),

                  const SizedBox(height: 22),

                  const _SectionTitle(
                    title: 'Account Status',
                    subtitle: 'Your NaijaGo rider account verification status.',
                  ),

                  SectionCard(
                    child: Row(
                      children: [
                        Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.verified_user_outlined,
                            color: AppTheme.green,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Obx(
                            () => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profileController.approvalStatus.value,
                                  style: const TextStyle(
                                    color: AppTheme.textDark,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  profileController.statusDescription.value,
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  const _SectionTitle(
                    title: 'Personal Information',
                    subtitle: 'These details are locked after verification.',
                  ),

                  SectionCard(
                    child: Column(
                      children: [
                        _infoRow(
                          title: 'Full Name',
                          value: profileController.fullName.value,
                          icon: Icons.badge_outlined,
                          locked: true,
                        ),
                        const Divider(height: 24),
                        _infoRow(
                          title: 'Email',
                          value: profileController.email.value,
                          icon: Icons.email_outlined,
                          locked: true,
                        ),
                        const Divider(height: 24),
                        _infoRow(
                          title: 'Date of Birth',
                          value: profileController.dateOfBirth.value,
                          icon: Icons.calendar_month_outlined,
                          locked: true,
                        ),
                        const Divider(height: 24),
                        _infoRow(
                          title: 'Gender',
                          value: profileController.gender.value,
                          icon: Icons.person_outline,
                          locked: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  _EditableSectionTitle(
                    title: 'Contact & Address',
                    subtitle: 'You can update your phone number and address.',
                    onEdit: () =>
                        _openContactEditSheet(context, profileController),
                  ),

                  SectionCard(
                    child: Column(
                      children: [
                        _infoRow(
                          title: 'Phone Number',
                          value: profileController.phoneController.text,
                          icon: Icons.phone_outlined,
                        ),
                        const Divider(height: 24),
                        _infoRow(
                          title: 'Home Address',
                          value: profileController.homeAddressController.text,
                          icon: Icons.home_outlined,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  _EditableSectionTitle(
                    title: 'Operation Information',
                    subtitle: 'Your city, delivery zone and vehicle details.',
                    onEdit: () =>
                        _openOperationEditSheet(context, profileController),
                  ),

                  SectionCard(
                    child: Column(
                      children: [
                        _infoRow(
                          title: 'State',
                          value: profileController.stateController.text,
                          icon: Icons.map_outlined,
                        ),
                        const Divider(height: 24),
                        _infoRow(
                          title: 'City / Operating Area',
                          value: profileController.cityController.text,
                          icon: Icons.location_city_outlined,
                        ),
                        const Divider(height: 24),
                        _infoRow(
                          title: 'Preferred Delivery Zone',
                          value: profileController.deliveryZoneController.text,
                          icon: Icons.route_outlined,
                        ),
                        const Divider(height: 24),
                        _infoRow(
                          title: 'Vehicle Type',
                          value: profileController.vehicleTypeController.text,
                          icon: Icons.two_wheeler_outlined,
                        ),
                        const Divider(height: 24),
                        _infoRow(
                          title: 'Vehicle Model',
                          value: profileController.vehicleModelController.text,
                          icon: Icons.directions_bike_outlined,
                        ),
                        const Divider(height: 24),
                        _infoRow(
                          title: 'Plate Number',
                          value: profileController.plateNumberController.text,
                          icon: Icons.confirmation_number_outlined,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  const _SectionTitle(
                    title: 'Verification Information',
                    subtitle: 'Verification details cannot be edited directly.',
                  ),

                  SectionCard(
                    child: Column(
                      children: [
                        _infoRow(
                          title: 'Driver’s License Number',
                          value: profileController.licenseNumber.value,
                          icon: Icons.credit_card_outlined,
                          locked: true,
                        ),
                        const Divider(height: 24),
                        _infoRow(
                          title: 'ID Type',
                          value: profileController.idType.value,
                          icon: Icons.assignment_ind_outlined,
                          locked: true,
                        ),
                        const Divider(height: 24),
                        _infoRow(
                          title: 'ID Number',
                          value: profileController.idNumber.value,
                          icon: Icons.numbers_outlined,
                          locked: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  _EditableSectionTitle(
                    title: 'Bank Information',
                    subtitle: 'This is where rider earnings will be paid.',
                    onEdit: () =>
                        _openBankEditSheet(context, profileController),
                  ),

                  SectionCard(
                    child: Column(
                      children: [
                        _infoRow(
                          title: 'Bank Name',
                          value: profileController.bankNameController.text,
                          icon: Icons.account_balance_outlined,
                        ),
                        const Divider(height: 24),
                        _infoRow(
                          title: 'Account Number',
                          value: profileController.accountNumberController.text,
                          icon: Icons.pin_outlined,
                        ),
                        const Divider(height: 24),
                        _infoRow(
                          title: 'Account Name',
                          value: profileController.accountNameController.text,
                          icon: Icons.person_pin_outlined,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  _EditableSectionTitle(
                    title: 'Emergency Contact',
                    subtitle: 'Person NaijaGo can contact when necessary.',
                    onEdit: () =>
                        _openEmergencyEditSheet(context, profileController),
                  ),

                  SectionCard(
                    child: Column(
                      children: [
                        _infoRow(
                          title: 'Contact Name',
                          value: profileController.emergencyNameController.text,
                          icon: Icons.contact_emergency_outlined,
                        ),
                        const Divider(height: 24),
                        _infoRow(
                          title: 'Contact Phone',
                          value:
                              profileController.emergencyPhoneController.text,
                          icon: Icons.phone_in_talk_outlined,
                        ),
                        const Divider(height: 24),
                        _infoRow(
                          title: 'Relationship',
                          value: profileController
                              .emergencyRelationshipController
                              .text,
                          icon: Icons.group_outlined,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  const _SectionTitle(
                    title: 'Support',
                    subtitle: 'Get help from NaijaGo rider support.',
                  ),

                  SectionCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        _actionTile(
                          icon: Icons.support_agent,
                          title: 'Contact Support',
                          subtitle: 'Chat with NaijaGo support team',
                          onTap: () {
                            Get.snackbar(
                              'Support',
                              'Support chat will be connected soon.',
                            );
                          },
                        ),
                        const Divider(height: 1),
                        _actionTile(
                          icon: Icons.report_problem_outlined,
                          title: 'Report an Issue',
                          subtitle: 'Report payment, pickup, or delivery issue',
                          onTap: () {
                            Get.snackbar(
                              'Report Issue',
                              'Issue reporting will be connected soon.',
                            );
                          },
                        ),
                        const Divider(height: 1),
                        _actionTile(
                          icon: Icons.help_outline,
                          title: 'Help Center',
                          subtitle: 'View rider guides and common questions',
                          onTap: () {
                            Get.snackbar(
                              'Help Center',
                              'Help center will be added soon.',
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  SectionCard(
                    padding: const EdgeInsets.all(14),
                    child: _actionTile(
                      icon: Icons.logout,
                      title: 'Logout',
                      subtitle: 'Sign out from this rider account',
                      color: Colors.red,
                      onTap: authController.logout,
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              );
            },
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
            'Rider Profile',
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
    bool locked = false,
  }) {
    return Row(
      children: [
        Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            color: locked
                ? AppTheme.textMuted.withValues(alpha: 0.10)
                : AppTheme.secondary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            locked ? Icons.lock_outline : icon,
            color: locked ? AppTheme.textMuted : AppTheme.secondary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (locked)
                    const Text(
                      'Locked',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                value.isEmpty ? 'Not provided' : value,
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

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color color = AppTheme.secondary,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      leading: Container(
        height: 44,
        width: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textDark,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _openContactEditSheet(
    BuildContext context,
    RiderProfileController controller,
  ) {
    _openEditSheet(
      profileController: controller,
      title: 'Edit Contact & Address',
      children: [
        _editField(
          controller: controller.phoneController,
          label: 'Phone Number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 14),
        _editField(
          controller: controller.homeAddressController,
          label: 'Home Address',
          icon: Icons.home_outlined,
          maxLines: 2,
        ),
      ],
    );
  }

  void _openOperationEditSheet(
    BuildContext context,
    RiderProfileController controller,
  ) {
    _openEditSheet(
      profileController: controller,
      title: 'Edit Operation Info',
      children: [
        _editField(
          controller: controller.stateController,
          label: 'State',
          icon: Icons.map_outlined,
        ),
        const SizedBox(height: 14),
        _editField(
          controller: controller.cityController,
          label: 'City / Operating Area',
          icon: Icons.location_city_outlined,
        ),
        const SizedBox(height: 14),
        _editField(
          controller: controller.deliveryZoneController,
          label: 'Preferred Delivery Zone',
          icon: Icons.route_outlined,
        ),
        const SizedBox(height: 14),
        _editField(
          controller: controller.vehicleTypeController,
          label: 'Vehicle Type',
          icon: Icons.two_wheeler_outlined,
        ),
        const SizedBox(height: 14),
        _editField(
          controller: controller.vehicleModelController,
          label: 'Vehicle Brand / Model',
          icon: Icons.directions_bike_outlined,
        ),
        const SizedBox(height: 14),
        _editField(
          controller: controller.plateNumberController,
          label: 'Plate Number',
          icon: Icons.confirmation_number_outlined,
          capitalization: TextCapitalization.characters,
        ),
      ],
    );
  }

  void _openBankEditSheet(
    BuildContext context,
    RiderProfileController controller,
  ) {
    _openEditSheet(
      profileController: controller,
      title: 'Edit Bank Information',
      children: [
        _editField(
          controller: controller.bankNameController,
          label: 'Bank Name',
          icon: Icons.account_balance_outlined,
        ),
        const SizedBox(height: 14),
        _editField(
          controller: controller.accountNumberController,
          label: 'Account Number',
          icon: Icons.pin_outlined,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 14),
        _editField(
          controller: controller.accountNameController,
          label: 'Account Name',
          icon: Icons.person_pin_outlined,
          capitalization: TextCapitalization.words,
        ),
      ],
    );
  }

  void _openEmergencyEditSheet(
    BuildContext context,
    RiderProfileController controller,
  ) {
    _openEditSheet(
      profileController: controller,
      title: 'Edit Emergency Contact',
      children: [
        _editField(
          controller: controller.emergencyNameController,
          label: 'Emergency Contact Name',
          icon: Icons.contact_emergency_outlined,
          capitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 14),
        _editField(
          controller: controller.emergencyPhoneController,
          label: 'Emergency Contact Phone',
          icon: Icons.phone_in_talk_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 14),
        _editField(
          controller: controller.emergencyRelationshipController,
          label: 'Relationship',
          icon: Icons.group_outlined,
        ),
      ],
    );
  }

  void _openEditSheet({
    required RiderProfileController profileController,
    required String title,
    required List<Widget> children,
  }) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Obx(
              () => Column(
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
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textDark,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ...children,
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: profileController.isSaving.value
                        ? null
                        : () async {
                            await profileController.saveProfileChanges();
                            profileController.update();
                            Get.back();
                          },
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      profileController.isSaving.value
                          ? 'Saving...'
                          : 'Save Changes',
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: profileController.isSaving.value
                        ? null
                        : Get.back,
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _editField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textCapitalization: capitalization,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final RiderProfileController controller;

  const _ProfileHeader({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Container(
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
        child: Row(
          children: [
            const CircleAvatar(
              radius: 34,
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, color: Colors.white, size: 38),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.fullName.value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'NaijaGo verified delivery partner',
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
      ),
    );
  }
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

class _EditableSectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onEdit;

  const _EditableSectionTitle({
    required this.title,
    required this.subtitle,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _SectionTitle(title: title, subtitle: subtitle),
          ),
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text(
              'Edit',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}
