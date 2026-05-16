import 'package:image_picker/image_picker.dart';

import '../../orders/service/rider_api.dart';

class AuthApi {
  static Future<dynamic> login({
    required String emailOrPhone,
    required String password,
    String? oneSignalPlayerId,
  }) async {
    return RiderApi.login(
      email: emailOrPhone,
      password: password,
      oneSignalPlayerId: oneSignalPlayerId,
    );
  }

  static Future<dynamic> forgotPassword({required String email}) {
    return RiderApi.forgotPassword(email: email);
  }

  static Future<dynamic> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
    required String dateOfBirth,
    required String gender,
    required String homeAddress,
    required String state,
    required String city,
    required String deliveryZone,
    required String vehicleType,
    required String vehicleModel,
    required String plateNumber,
    required String licenseNumber,
    required String idType,
    required String idNumber,
    required String bankName,
    required String accountNumber,
    required String accountName,
    required String emergencyName,
    required String emergencyPhone,
    required String emergencyRelationship,
    required XFile ninFront,
    required XFile ninBack,
    required XFile platePhoto,
    required XFile selfie,
  }) async {
    final upload = await RiderApi.uploadRegistrationDocuments(
      ninFront: ninFront,
      ninBack: ninBack,
      platePhoto: platePhoto,
      selfie: selfie,
    );

    return RiderApi.register(
      fullName: fullName,
      phoneNumber: phone,
      email: email,
      password: password,
      dateOfBirth: dateOfBirth,
      gender: gender,
      homeAddress: homeAddress,
      state: state,
      city: city,
      deliveryZone: deliveryZone,
      plateNumber: plateNumber,
      vehicleType: _normalizeVehicleType(vehicleType),
      vehicleModel: vehicleModel,
      licenseNumber: licenseNumber,
      idType: idType,
      idNumber: idNumber,
      bankName: bankName,
      accountNumber: accountNumber,
      accountName: accountName,
      emergencyName: emergencyName,
      emergencyPhone: emergencyPhone,
      emergencyRelationship: emergencyRelationship,
      documentUrls: Map<String, dynamic>.from(upload['urls'] as Map),
    );
  }

  static String _normalizeVehicleType(String value) {
    final normalized = value.trim().toLowerCase();

    if (normalized.contains('bike') || normalized.contains('motor')) {
      return 'motorcycle';
    }
    if (normalized.contains('bicycle')) return 'bicycle';
    if (normalized.contains('car')) return 'car';
    if (normalized.contains('scooter')) return 'scooter';

    return 'motorcycle';
  }
}
