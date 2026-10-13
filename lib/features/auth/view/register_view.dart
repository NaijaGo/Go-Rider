import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/primary_header.dart';
import '../../../core/widgets/section_card.dart';
import '../controller/auth_controller.dart';
import '../service/registration_checks.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});
  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  late final AuthController controller;
  int _step = 0;
  String? _stepError;
  static const _titles = [
    'Your details',
    'Delivery area & vehicle',
    'Identity documents',
    'Payout account',
    'Emergency contact & review',
  ];

  @override
  void initState() {
    super.initState();
    controller = Get.find<AuthController>();
    if (controller.idTypeController.text.isEmpty) {
      controller.idTypeController.text = 'NIN';
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _move(int step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _step = step;
      _stepError = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _continue() {
    if (!_form.currentState!.validate()) return;
    if (_step == 2 &&
        [
          controller.ninFront.value,
          controller.ninBack.value,
          controller.platePhoto.value,
          controller.selfie.value,
        ].any((file) => file == null)) {
      setState(
        () => _stepError =
            'Please upload all four verification images before continuing.',
      );
      return;
    }
    if (_step < 4) {
      _move(_step + 1);
      return;
    }
    if (!controller.acceptedTerms.value) {
      setState(
        () => _stepError =
            'Please confirm your information and accept the rider terms.',
      );
      return;
    }
    controller.register();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 380;
    final cardPadding = EdgeInsets.all(compact ? 14 : 16);
    final sections = <List<Widget>>[
      [
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
                readOnly: controller.isGoogleSignup,
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

        if (!controller.isGoogleSignup) ...[
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
        ],
      ],
      [
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
      ],
      [
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
                  onTap: () =>
                      controller.pickRegistrationDocument(controller.ninFront),
                ),
              ),
              const SizedBox(height: 12),
              Obx(
                () => _UploadTile(
                  title: 'Upload NIN Back',
                  subtitle: 'Back image of rider NIN',
                  icon: Icons.file_upload_outlined,
                  selected: controller.ninBack.value?.name,
                  onTap: () =>
                      controller.pickRegistrationDocument(controller.ninBack),
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
                  onTap: () =>
                      controller.pickRegistrationDocument(controller.selfie),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),
      ],
      [
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
      ],
      [
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
      ],
    ];
    return Obx(
      () => PopScope(
        canPop: !controller.isLoading.value,
        child: Scaffold(
          body: AppBackground(
            child: SafeArea(
              child: SingleChildScrollView(
                controller: _scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 14 : 20,
                  vertical: 18,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Obx(
                      () => IconButton(
                        tooltip: _step > 0
                            ? 'Previous step'
                            : 'Back to sign in',
                        onPressed: controller.isLoading.value
                            ? null
                            : () {
                                if (_step > 0) {
                                  _move(_step - 1);
                                } else {
                                  controller.resetRegistrationForm();
                                  Navigator.of(context).pop();
                                }
                              },
                        icon: const Icon(Icons.arrow_back),
                      ),
                    ),
                    const PrimaryHeader(
                      title: 'Join NaijaGo',
                      subtitle: 'Complete your rider profile for verification.',
                      icon: Icons.two_wheeler,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Step ${_step + 1} of 5',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (_step + 1) / 5,
                      minHeight: 5,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _titles[_step],
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Obx(
                      () => AbsorbPointer(
                        absorbing: controller.isLoading.value,
                        child: Form(
                          key: _form,
                          child: Column(
                            children: [
                              ...sections[_step],
                              if (_step == 4) ...[
                                SectionCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Ready for review',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${controller.fullNameController.text} \u00b7 ${controller.phoneController.text}',
                                      ),
                                      Text(
                                        '${controller.cityController.text}, ${controller.stateController.text}',
                                      ),
                                      Text(
                                        '${controller.vehicleTypeController.text} \u00b7 ${controller.plateNumberController.text}',
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Your account stays pending until admin verifies and approves it. Use Previous to check or edit your details.',
                                      ),
                                    ],
                                  ),
                                ),
                                Obx(
                                  () => Material(
                                    color: Colors.transparent,
                                    child: CheckboxListTile(
                                      value: controller.acceptedTerms.value,
                                      onChanged: (value) {
                                        controller.acceptedTerms.value =
                                            value ?? false;
                                      },
                                      contentPadding: EdgeInsets.zero,
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      title: const Text(
                                        'I confirm that the information provided is correct. I will review and accept the Rider Partnership Agreement on the next screen.',
                                        style: TextStyle(
                                          color: AppTheme.textDark,
                                          fontSize: 13,
                                          height: 1.4,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_stepError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _stepError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Obx(
                      () => SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: controller.isLoading.value
                              ? null
                              : _continue,
                          child: Text(
                            controller.isLoading.value
                                ? 'Submitting...'
                                : _step == 4
                                ? 'Submit Registration'
                                : 'Continue',
                          ),
                        ),
                      ),
                    ),
                    if (_step > 0)
                      Obx(
                        () => Center(
                          child: TextButton(
                            onPressed: controller.isLoading.value
                                ? null
                                : () => _move(_step - 1),
                            child: const Text('Previous'),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
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
    bool readOnly = false,
    int maxLines = 1,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    return _RegistrationField(
      key: ValueKey(label),
      controller: controller,
      label: label,
      icon: icon,
      keyboardType: keyboardType,
      obscureText: obscureText,
      readOnly: readOnly || label == 'ID Type',
      maxLines: maxLines,
      capitalization: capitalization,
      validator: (value) => RegistrationChecks.field(
        label,
        value ?? '',
        password: this.controller.registerPasswordController.text.trim(),
        vehicle: this.controller.vehicleTypeController.text,
      ),
    );
  }

  Widget _gap() => const SizedBox(height: 14);
}

class _RegistrationField extends StatefulWidget {
  const _RegistrationField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.readOnly = false,
    this.maxLines = 1,
    this.capitalization = TextCapitalization.none,
  });
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final FormFieldValidator<String> validator;
  final TextInputType? keyboardType;
  final bool obscureText, readOnly;
  final int maxLines;
  final TextCapitalization capitalization;
  @override
  State<_RegistrationField> createState() => _RegistrationFieldState();
}

class _RegistrationFieldState extends State<_RegistrationField> {
  bool _visible = false;
  Future<void> _pickDate() async {
    final today = DateTime.now();
    final existing = DateTime.tryParse(widget.controller.text);
    final date = await showDatePicker(
      context: context,
      initialDate:
          existing != null && !existing.isAfter(today) && existing.year >= 1900
          ? existing
          : DateTime(today.year - 25, today.month, today.day),
      firstDate: DateTime(1900),
      lastDate: today,
    );
    if (date == null || !mounted) return;
    widget.controller.text =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.label == 'Vehicle Type'
        ? const ['motorcycle', 'bicycle', 'car', 'scooter']
        : widget.label == 'Gender'
        ? const ['Female', 'Male', 'Prefer not to say']
        : null;
    final decoration = InputDecoration(
      labelText: widget.label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      prefixIcon: Icon(widget.icon, size: 21),
      helperText: {
        'Date of Birth': 'Select your date of birth',
        'Preferred Delivery Zone': 'Optional: your preferred neighbourhood',
        'Gender': 'Optional',
        'ID Type': 'NIN is used for the required identity images',
        'Password': 'At least 6 characters',
        'Account Number': '10-digit bank account number',
      }[widget.label],
      helperMaxLines: 3,
      errorMaxLines: 3,
      suffixIcon: widget.obscureText
          ? IconButton(
              tooltip: _visible ? 'Hide password' : 'Show password',
              onPressed: () => setState(() => _visible = !_visible),
              icon: Icon(
                _visible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            )
          : widget.label == 'Date of Birth'
          ? const Icon(Icons.expand_more)
          : null,
    );
    if (options != null) {
      return DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: options.contains(widget.controller.text)
            ? widget.controller.text
            : null,
        decoration: decoration,
        validator: widget.validator,
        items: options
            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
            .toList(),
        onChanged: (value) => widget.controller.text = value ?? '',
      );
    }
    return TextFormField(
      controller: widget.controller,
      validator: widget.validator,
      readOnly: widget.readOnly || widget.label == 'Date of Birth',
      onTap: widget.label == 'Date of Birth' ? _pickDate : null,
      keyboardType: widget.keyboardType,
      obscureText: widget.obscureText && !_visible,
      autocorrect:
          !widget.obscureText &&
          widget.keyboardType != TextInputType.emailAddress,
      enableSuggestions: !widget.obscureText,
      autofillHints: {
        'Full Name': [AutofillHints.name],
        'Email': [AutofillHints.email],
        'Phone Number': [AutofillHints.telephoneNumber],
        'Password': [AutofillHints.newPassword],
        'Home Address': [AutofillHints.fullStreetAddress],
      }[widget.label],
      inputFormatters: widget.label == 'Account Number'
          ? [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ]
          : null,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      textCapitalization: widget.capitalization,
      textInputAction: widget.maxLines > 1
          ? TextInputAction.newline
          : TextInputAction.next,
      decoration: decoration,
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
