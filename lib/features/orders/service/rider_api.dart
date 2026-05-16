import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_helpers.dart';
import '../../../core/api/api_paths.dart';

class RiderApi {
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    String? oneSignalPlayerId,
  }) async {
    final response = await ApiClient.dio.post(
      ApiPaths.login,
      options: Options(extra: {'skipAuth': true}),
      data: {
        'email': email,
        'password': password,
        if (oneSignalPlayerId != null && oneSignalPlayerId.isNotEmpty)
          'oneSignalPlayerId': oneSignalPlayerId,
      },
    );

    return asMap(response.data);
  }

  static Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    final response = await ApiClient.dio.post(
      ApiPaths.forgotPassword,
      options: Options(extra: {'skipAuth': true}),
      data: {'email': email},
    );

    return asMap(response.data);
  }

  static Future<Map<String, dynamic>> uploadRegistrationDocuments({
    required XFile ninFront,
    required XFile ninBack,
    required XFile platePhoto,
    required XFile selfie,
  }) async {
    final formData = FormData.fromMap({
      'ninFront': await _multipart(ninFront),
      'ninBack': await _multipart(ninBack),
      'platePhoto': await _multipart(platePhoto),
      'selfie': await _multipart(selfie),
    });

    final response = await ApiClient.dio.post(
      ApiPaths.uploadRiderBundlePublic,
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        extra: {'skipAuth': true},
      ),
    );

    return asMap(response.data);
  }

  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String phoneNumber,
    required String email,
    required String password,
    required String dateOfBirth,
    required String gender,
    required String homeAddress,
    required String state,
    required String city,
    required String deliveryZone,
    required String plateNumber,
    required String vehicleType,
    required String vehicleModel,
    required String licenseNumber,
    required String idType,
    required String idNumber,
    required String bankName,
    required String accountNumber,
    required String accountName,
    required String emergencyName,
    required String emergencyPhone,
    required String emergencyRelationship,
    required Map<String, dynamic> documentUrls,
  }) async {
    final response = await ApiClient.dio.post(
      ApiPaths.register,
      options: Options(extra: {'skipAuth': true}),
      data: {
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'email': email,
        'password': password,
        'dateOfBirth': dateOfBirth,
        'gender': gender,
        'homeAddress': homeAddress,
        'state': state,
        'city': city,
        'deliveryZone': deliveryZone,
        'plateNumber': plateNumber,
        'vehicleType': vehicleType,
        'vehicleModel': vehicleModel,
        'licenseNumber': licenseNumber,
        'idType': idType,
        'idNumber': idNumber,
        'bankName': bankName,
        'accountNumber': accountNumber,
        'accountName': accountName,
        'emergencyName': emergencyName,
        'emergencyPhone': emergencyPhone,
        'emergencyRelationship': emergencyRelationship,
        'documentUrls': documentUrls,
      },
    );

    return asMap(response.data);
  }

  static Future<Map<String, dynamic>> profile() async {
    final response = await ApiClient.dio.get(ApiPaths.profile);
    return asMap(response.data);
  }

  static Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? phoneNumber,
    String? homeAddress,
    String? state,
    String? city,
    String? deliveryZone,
    String? vehicleType,
    String? vehicleBrand,
    String? vehicleColor,
    String? licenseNumber,
    String? idType,
    String? idNumber,
    String? emergencyName,
    String? emergencyPhone,
    String? emergencyRelationship,
  }) async {
    final response = await ApiClient.dio.put(
      ApiPaths.profile,
      data: {
        if (fullName != null) 'fullName': fullName,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (homeAddress != null) 'homeAddress': homeAddress,
        if (state != null) 'state': state,
        if (city != null) 'city': city,
        if (deliveryZone != null) 'deliveryZone': deliveryZone,
        if (vehicleType != null) 'vehicleType': vehicleType,
        if (vehicleBrand != null) 'vehicleBrand': vehicleBrand,
        if (vehicleColor != null) 'vehicleColor': vehicleColor,
        if (licenseNumber != null) 'licenseNumber': licenseNumber,
        if (idType != null) 'idType': idType,
        if (idNumber != null) 'idNumber': idNumber,
        if (emergencyName != null) 'emergencyName': emergencyName,
        if (emergencyPhone != null) 'emergencyPhone': emergencyPhone,
        if (emergencyRelationship != null)
          'emergencyRelationship': emergencyRelationship,
      },
    );

    return asMap(response.data);
  }

  static Future<Map<String, dynamic>> updateBankAccount({
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) async {
    final response = await ApiClient.dio.put(
      ApiPaths.bankAccount,
      data: {
        'bankName': bankName,
        'accountNumber': accountNumber,
        'accountName': accountName,
      },
    );

    return asMap(response.data);
  }

  static Future<Map<String, dynamic>> updateAvailability(bool online) async {
    final response = await ApiClient.dio.put(
      ApiPaths.riderStatus,
      data: {'isAvailable': online, 'isActive': online},
    );

    return asMap(response.data);
  }

  static Future<Map<String, dynamic>> updateLocation({
    required double lat,
    required double lng,
    String address = '',
  }) async {
    final response = await ApiClient.dio.put(
      ApiPaths.riderLocation,
      data: {'lat': lat, 'lng': lng, 'address': address},
    );

    return asMap(response.data);
  }

  static Future<Map<String, dynamic>> dashboard() async {
    final response = await ApiClient.dio.get(ApiPaths.dashboard);
    return asMap(response.data);
  }

  static Future<List<dynamic>> availableOrders() async {
    final response = await ApiClient.dio.get(ApiPaths.availableOrders);
    return asList(asMap(response.data)['orders']);
  }

  static Future<List<dynamic>> activeOrders() async {
    final response = await ApiClient.dio.get(ApiPaths.activeOrders);
    return asList(asMap(response.data)['orders']);
  }

  static Future<Map<String, dynamic>> claimOrder(String id) async {
    final response = await ApiClient.dio.put(ApiPaths.claimOrder(id));
    return asMap(response.data);
  }

  static Future<Map<String, dynamic>> rejectOrder(String id) async {
    final response = await ApiClient.dio.put(ApiPaths.rejectOrder(id));
    return asMap(response.data);
  }

  static Future<Map<String, dynamic>> verifyPickup({
    required String orderId,
    required String pickupOTP,
  }) async {
    final response = await ApiClient.dio.post(
      ApiPaths.verifyPickup,
      data: {'orderId': orderId, 'pickupOTP': pickupOTP},
    );

    return asMap(response.data);
  }

  static Future<Map<String, dynamic>> verifyDelivery({
    required String orderId,
    required String deliveryOTP,
  }) async {
    final response = await ApiClient.dio.post(
      ApiPaths.verifyDelivery,
      data: {'orderId': orderId, 'deliveryOTP': deliveryOTP},
    );

    return asMap(response.data);
  }

  static Future<Map<String, dynamic>> earnings() async {
    final response = await ApiClient.dio.get(ApiPaths.earnings);
    return asMap(response.data);
  }

  static Future<Map<String, dynamic>> requestWithdrawal({
    required double amount,
    required Map<String, dynamic> accountDetails,
  }) async {
    final response = await ApiClient.dio.post(
      ApiPaths.withdraw,
      data: {
        'amount': amount,
        'paymentMethod': 'bank_transfer',
        'accountDetails': accountDetails,
      },
    );

    return asMap(response.data);
  }

  static Future<List<dynamic>> notifications() async {
    final response = await ApiClient.dio.get(ApiPaths.notifications);
    return asList(asMap(response.data)['notifications']);
  }

  static Future<void> markNotificationRead(String id) async {
    await ApiClient.dio.put(ApiPaths.markNotificationRead(id));
  }

  static Future<void> markAllNotificationsRead() async {
    await ApiClient.dio.put(ApiPaths.markAllNotificationsRead);
  }

  static Future<Map<String, dynamic>> mapboxConfig() async {
    final response = await ApiClient.dio.get(ApiPaths.mapboxConfig);
    return asMap(response.data);
  }

  static Future<Map<String, dynamic>> mapboxDirections({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
  }) async {
    final response = await ApiClient.dio.get(
      ApiPaths.mapboxDirections,
      queryParameters: {
        'originLat': originLat,
        'originLng': originLng,
        'destinationLat': destinationLat,
        'destinationLng': destinationLng,
        'profile': 'driving',
      },
    );

    return asMap(response.data);
  }

  static Future<MultipartFile> _multipart(XFile file) async {
    if (kIsWeb) {
      return MultipartFile.fromBytes(
        await file.readAsBytes(),
        filename: file.name,
      );
    }

    return MultipartFile.fromFile(file.path, filename: file.name);
  }
}
