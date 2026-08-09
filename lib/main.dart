import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'bindings/app_bindings.dart';
import 'core/push/onesignal_service.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  if (!OneSignalService.isConfigured) {
    runApp(const _PushConfigurationErrorApp());
    return;
  }
  await OneSignalService.initialize();
  await OneSignalService.requestPermission();

  runApp(const NaijaGoRiderApp());
}

class _PushConfigurationErrorApp extends StatelessWidget {
  const _PushConfigurationErrorApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Rider push configuration is missing.\n\n'
                'Rebuild with:\n'
                '--dart-define=ONESIGNAL_APP_ID=<rider-app-id>',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NaijaGoRiderApp extends StatelessWidget {
  const NaijaGoRiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'NaijaGo Rider',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialBinding: AppBindings(),
      initialRoute: AppRoutes.splash,
      getPages: AppPages.pages,
    );
  }
}
