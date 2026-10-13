import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_helpers.dart';
import '../../../core/storage/app_storage.dart';

class RiderAgreementApi {
  static Options get _options => Options(
    extra: {'explicitAuth': true, 'agreementRequest': true},
    headers: {
      'Authorization':
          'Bearer ${AppStorage.agreementToken ?? AppStorage.token ?? ''}',
    },
  );
  static Future<Map<String, dynamic>> current() async => asMap(
    (await ApiClient.dio.get(
      '/riders/agreements/current',
      options: _options,
    )).data,
  );
  static Future<Map<String, dynamic>> status() async => asMap(
    (await ApiClient.dio.get(
      '/riders/agreements/status',
      options: _options,
    )).data,
  );
  static Future<Map<String, dynamic>> accept(Map<String, dynamic> data) async =>
      asMap(
        (await ApiClient.dio.post(
          '/riders/agreements/accept',
          data: data,
          options: _options,
        )).data,
      );
}
