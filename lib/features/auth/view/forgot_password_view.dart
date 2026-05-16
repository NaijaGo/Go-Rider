import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/primary_header.dart';
import '../../../core/widgets/section_card.dart';
import '../controller/auth_controller.dart';

class ForgotPasswordView extends StatelessWidget {
  const ForgotPasswordView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AuthController>();

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                IconButton(
                  onPressed: Get.back,
                  icon: const Icon(Icons.arrow_back),
                  color: AppTheme.textDark,
                ),
                const SizedBox(height: 10),
                const PrimaryHeader(
                  title: 'Forgot Password',
                  subtitle: 'Get a secure reset link by email.',
                  icon: Icons.lock_reset,
                ),
                const SizedBox(height: 28),
                const Text(
                  'Reset rider password',
                  style: TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter the email connected to your rider account.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                ),
                const SizedBox(height: 18),
                SectionCard(
                  child: Column(
                    children: [
                      TextField(
                        controller: controller.forgotEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Rider email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Obx(
                        () => ElevatedButton(
                          onPressed: controller.isResetLoading.value
                              ? null
                              : controller.requestPasswordReset,
                          child: Text(
                            controller.isResetLoading.value
                                ? 'Sending link...'
                                : 'Send reset link',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: TextButton(
                    onPressed: Get.back,
                    child: const Text(
                      'Back to login',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
