import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class RiderLocationPermissionService {
  Future<bool> requestForGoingOnline(BuildContext context) async {
    final accepted = await _showProminentDisclosure(context);
    if (!accepted || !context.mounted) return false;

    var foregroundStatus = await Permission.locationWhenInUse.status;
    if (!foregroundStatus.isGranted) {
      foregroundStatus = await Permission.locationWhenInUse.request();
    }
    if (!foregroundStatus.isGranted || !context.mounted) return false;

    var backgroundStatus = await Permission.locationAlways.status;
    if (backgroundStatus.isGranted) return true;
    if (!context.mounted) return false;

    final backgroundAccepted = await _showBackgroundExplanation(context);
    if (!backgroundAccepted || !context.mounted) return false;

    backgroundStatus = await Permission.locationAlways.request();
    if (backgroundStatus.isGranted) return true;
    if (!context.mounted) return false;

    await _showSettingsDialog(context);
    return Permission.locationAlways.isGranted;
  }

  Future<bool> _showProminentDisclosure(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Location access while you are online'),
            content: const SingleChildScrollView(
              child: Text(
                'Go-Rider collects your precise location while you are online '
                'so customers and dispatchers can see your live position, '
                'assign nearby deliveries, follow active trip progress, and '
                'confirm pickup and delivery.\n\n'
                'Location continues to be collected in the background when '
                'the app is minimized, the screen is locked, or you are not '
                'actively using the app.\n\n'
                'Collection starts when you go online and stops when you go '
                'offline. Your location is not used for advertising.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _showBackgroundExplanation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Allow background location'),
            content: const Text(
              'On the next Android screen, allow location access all the time. '
              'Go-Rider needs this so live rider and active trip tracking can '
              'continue while the app is minimized or the screen is locked.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showSettingsDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Background location required'),
        content: const Text(
          'To go online and maintain live tracking, open App Settings, select '
          'Permissions, select Location, and choose "Allow all the time".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await openAppSettings();
            },
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
  }
}
