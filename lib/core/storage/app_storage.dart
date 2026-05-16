import 'package:get_storage/get_storage.dart';

class AppStorage {
  static final GetStorage _box = GetStorage();

  static const String _tokenKey = 'auth_token';
  static const String _riderStatusKey = 'rider_status';
  static const String _riderOnlineKey = 'rider_online';
  static const String _riderNameKey = 'rider_name';
  static const String _riderEmailKey = 'rider_email';

  static String? get token => _box.read<String>(_tokenKey);
  static String? get riderStatus => _box.read<String>(_riderStatusKey);
  static bool get isRiderOnline => _box.read<bool>(_riderOnlineKey) ?? false;
  static String? get riderName => _box.read<String>(_riderNameKey);
  static String? get riderEmail => _box.read<String>(_riderEmailKey);

  static Future<void> saveToken(String token) async {
    await _box.write(_tokenKey, token);
  }

  static Future<void> saveRiderStatus(String status) async {
    await _box.write(_riderStatusKey, status);
  }

  static Future<void> saveRiderOnline(bool online) async {
    await _box.write(_riderOnlineKey, online);
  }

  static Future<void> saveRiderIdentity({
    required String name,
    required String email,
  }) async {
    await _box.write(_riderNameKey, name);
    await _box.write(_riderEmailKey, email);
  }

  static Future<void> clear() async {
    await _box.erase();
  }
}
