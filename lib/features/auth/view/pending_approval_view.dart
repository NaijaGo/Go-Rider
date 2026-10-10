import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../routes/app_routes.dart';

class PendingApprovalView extends StatelessWidget {
  const PendingApprovalView({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your rider account is under review.\n\nNaijaGo admin will approve your account after verification.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Get.offAllNamed(AppRoutes.login),
              child: const Text('Back to sign in'),
            ),
          ],
        ),
      ),
    ),
  );
}
