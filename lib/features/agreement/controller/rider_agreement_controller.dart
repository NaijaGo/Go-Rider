import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../core/api/api_helpers.dart';
import '../../../core/storage/app_storage.dart';
import '../../../core/socket/socket_service.dart';
import '../../../core/push/onesignal_service.dart';
import '../../../routes/app_routes.dart';
import '../../orders/controller/delivery_controller.dart';
import '../service/rider_agreement_api.dart';

class RiderAgreementDocument {
  RiderAgreementDocument(Map<String, dynamic> data)
    : id = asString(data['agreementId']),
      version = asString(data['version']),
      content = asString(data['content']),
      hash = asString(data['contentHash']);
  final String id, version, content, hash;
  bool get valid =>
      RegExp(r'^[a-f0-9]{24}$', caseSensitive: false).hasMatch(id) &&
      version.isNotEmpty &&
      content.trim().isNotEmpty &&
      RegExp(r'^[a-f0-9]{64}$').hasMatch(hash);
}

class RiderAgreementController extends GetxController
    with WidgetsBindingObserver {
  RiderAgreementController({
    Future<Map<String, dynamic>> Function()? fetchCurrent,
    Future<Map<String, dynamic>> Function()? fetchStatus,
    Future<Map<String, dynamic>> Function(Map<String, dynamic>)? saveAcceptance,
    bool Function()? hasSession,
    void Function()? onAccepted,
    Future<void> Function()? onExpired,
  }) : _fetchCurrent = fetchCurrent ?? RiderAgreementApi.current,
       _fetchStatus = fetchStatus ?? RiderAgreementApi.status,
       _saveAcceptance = saveAcceptance ?? RiderAgreementApi.accept,
       _hasSession =
           hasSession ??
           (() => (AppStorage.agreementToken ?? AppStorage.token ?? '')
               .isNotEmpty),
       _onAccepted = onAccepted,
       _onExpired = onExpired;
  final Future<Map<String, dynamic>> Function() _fetchCurrent, _fetchStatus;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)
  _saveAcceptance;
  final bool Function() _hasSession;
  final void Function()? _onAccepted;
  final Future<void> Function()? _onExpired;
  final agreement = Rxn<RiderAgreementDocument>();
  final consent = false.obs,
      loading = false.obs,
      submitting = false.obs,
      confirmed = false.obs;
  final error = ''.obs;
  Future<bool>? _checking;
  int _generation = 0;
  bool get authenticated => _hasSession();
  bool get canSubmit =>
      authenticated &&
      agreement.value?.valid == true &&
      consent.value &&
      !loading.value &&
      !submitting.value;
  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _hasSession() &&
        AppStorage.riderStatus == 'approved') {
      ensureAccepted();
    }
  }

  bool _accepted(Map<String, dynamic> data) {
    final doc = asMap(data['agreement']), record = asMap(data['acceptance']);
    return data['success'] == true &&
        RegExp(
          r'^[a-f0-9]{24}$',
          caseSensitive: false,
        ).hasMatch(asString(doc['agreementId'])) &&
        RegExp(r'^[a-f0-9]{64}$').hasMatch(asString(doc['contentHash'])) &&
        data['accepted'] == true &&
        data['requiresAcceptance'] == false &&
        asString(data['requiredVersion']).isNotEmpty &&
        doc['version'] == data['requiredVersion'] &&
        record['version'] == data['requiredVersion'] &&
        record['contentHash'] == doc['contentHash'] &&
        record['agreementId']?.toString() == doc['agreementId']?.toString() &&
        DateTime.tryParse(asString(record['acceptedAt'])) != null;
  }

  Future<void> load() async {
    if (loading.value || submitting.value) return;
    final generation = ++_generation;
    consent.value = false;
    confirmed.value = false;
    error.value = '';
    loading.value = true;
    try {
      if (!_hasSession()) {
        throw StateError('Sign in to read and accept your rider agreement.');
      }
      final data = await _fetchCurrent();
      if (isClosed || generation != _generation) return;
      final document = RiderAgreementDocument(asMap(data['agreement']));
      if (data['success'] != true || !document.valid) {
        throw const FormatException('Incomplete agreement response');
      }
      agreement.value = document;
      confirmed.value = _accepted(data);
    } catch (e) {
      if (generation == _generation && !isClosed) await _failure(e);
    } finally {
      if (generation == _generation && !isClosed) loading.value = false;
    }
  }

  Future<bool> ensureAccepted({bool navigate = true}) async {
    final running = _checking;
    if (running != null) {
      final accepted = await running;
      if (!accepted && navigate) requireReview();
      return accepted;
    }
    final check = _check();
    _checking = check;
    final accepted = await check;
    _checking = null;
    if (!accepted && navigate && _hasSession()) requireReview();
    return accepted;
  }

  Future<bool> _check() async {
    final generation = _generation;
    confirmed.value = false;
    try {
      if (!_hasSession()) return false;
      final data = await _fetchStatus();
      if (isClosed || generation != _generation) return false;
      confirmed.value = _accepted(data);
      return confirmed.value;
    } catch (e) {
      if (!isClosed && generation == _generation) await _failure(e);
      return false;
    }
  }

  Future<void> accept() async {
    if (!canSubmit) return;
    final document = agreement.value!;
    final generation = _generation;
    submitting.value = true;
    error.value = '';
    confirmed.value = false;
    var refreshDocument = false;
    try {
      // Persistence outcome is unknown until the authoritative GET confirms it.
      try {
        final result = await _saveAcceptance({
          'agreementId': document.id,
          'version': document.version,
          'contentHash': document.hash,
          'accepted': true,
          'appVersion': const String.fromEnvironment('APP_VERSION'),
          'platform': kIsWeb
              ? 'web'
              : switch (defaultTargetPlatform) {
                  TargetPlatform.android => 'android',
                  TargetPlatform.iOS => 'ios',
                  _ => 'unknown',
                },
        });
        if (result['success'] != true || result['accepted'] != true) {
          throw const FormatException('Acceptance was not confirmed');
        }
      } catch (e) {
        if (e is DioException && e.response?.statusCode == 401) {
          await _failure(e);
          return;
        }
        // Includes timeouts, lost responses and stale versions. Never blindly POST again.
        final status = await _fetchStatus();
        if (generation != _generation || isClosed) return;
        if (_accepted(status)) {
          confirmed.value = true;
          _continue();
          return;
        }
        refreshDocument = true;
        error.value =
            e is DioException &&
                asMap(e.response?.data)['code'] == 'RIDER_AGREEMENT_CHANGED'
            ? 'The required agreement changed. Please read and accept the latest version.'
            : 'Acceptance is not confirmed. Review the agreement and retry.';
        return;
      }
      final status = await _fetchStatus();
      if (generation != _generation || isClosed) return;
      if (!_accepted(status)) {
        refreshDocument = true;
        error.value =
            'A newer agreement is required. Read the latest version before continuing.';
        return;
      }
      confirmed.value = true;
      _continue();
    } catch (e) {
      if (!isClosed && generation == _generation) await _failure(e);
    } finally {
      if (!isClosed) submitting.value = false;
      if (refreshDocument && !isClosed && generation == _generation) {
        final message = error.value;
        await load();
        if (error.value.isEmpty) error.value = message;
      }
    }
  }

  void _continue() {
    if (_onAccepted != null) {
      _onAccepted();
      return;
    }
    if (AppStorage.riderStatus != 'approved' ||
        AppStorage.agreementToken != null) {
      Get.offAllNamed(AppRoutes.pendingApproval);
    } else {
      Get.offAllNamed(AppRoutes.dashboard);
      OneSignalService.consumePendingDestination();
    }
  }

  void continueIfAccepted() {
    if (confirmed.value) _continue();
  }

  void requireReview() {
    invalidate();
    // Customers' goods in transit are not abandoned when a new version is required.
    final finishing =
        Get.isRegistered<DeliveryController>() &&
        Get.find<DeliveryController>().activeOrder.value != null &&
        {
          AppRoutes.activeDelivery,
          AppRoutes.deliveryMap,
          AppRoutes.confirmPickup,
          AppRoutes.confirmDelivered,
        }.contains(Get.currentRoute);
    if (!finishing &&
        Get.context != null &&
        Get.currentRoute != AppRoutes.riderAgreement) {
      Get.toNamed(AppRoutes.riderAgreement);
    }
  }

  void invalidate() {
    _generation++;
    loading.value = false;
    agreement.value = null;
    confirmed.value = false;
    consent.value = false;
  }

  Future<void> _failure(Object e) async {
    confirmed.value = false;
    consent.value = false;
    // Unknown persistence/read outcomes require a successful authoritative refresh
    // before the rider can consent and submit again.
    agreement.value = null;
    if (e is DioException &&
        (e.response?.statusCode == 401 ||
            asMap(e.response?.data)['code'] == 'RIDER_ACCOUNT_RESTRICTED')) {
      error.value =
          'Your session expired or the rider account is restricted. Please sign in again.';
      if (_onExpired != null) {
        await _onExpired();
        return;
      }
      await AppStorage.clear();
      SocketService().dispose();
      await OneSignalService.logout();
      if (Get.context != null) Get.offAllNamed(AppRoutes.login);
    } else {
      error.value = apiMessage(
        e,
        'Unable to verify the rider agreement. Please retry; delivery work remains restricted.',
      );
    }
  }
}
