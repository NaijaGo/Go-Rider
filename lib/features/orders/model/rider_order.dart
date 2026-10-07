import 'package:latlong2/latlong.dart';

import '../../../core/api/api_helpers.dart';

enum RiderOrderStatus {
  assigned,
  accepted,
  rejected,
  arrivedVendor,
  pickedUp,
  arrivedCustomer,
  delivered,
  cancelled,
}

class RiderPickupStop {
  final String shipmentId;
  final int sequence;
  final String sellerName;
  final String address;
  final LatLng location;

  const RiderPickupStop({
    required this.shipmentId,
    required this.sequence,
    required this.sellerName,
    required this.address,
    required this.location,
  });

  factory RiderPickupStop.fromBackend(dynamic source, {int fallbackSequence = 1}) {
    final json = asMap(source);
    final location = asMap(json['vendorLocation']);
    return RiderPickupStop(
      shipmentId: asString(json['shipment'] ?? json['_id']),
      sequence: asDouble(json['sequence'], fallbackSequence.toDouble())
          .toInt()
          .clamp(1, 999)
          .toInt(),
      sellerName: asString(
        json['sellerName'] ?? asMap(json['vendor'])['businessName'],
        'Vendor',
      ),
      address: asString(
        json['formattedAddress'] ??
            location['formattedAddress'] ??
            location['address'] ??
            location['addressLine'],
        'Vendor address unavailable',
      ),
      location: LatLng(
        asDouble(json['latitude'] ?? location['latitude'] ?? location['lat']),
        asDouble(json['longitude'] ?? location['longitude'] ?? location['lng']),
      ),
    );
  }
}

class RiderOrder {
  final String id;
  final String orderCode;
  final String vendorName;
  final String vendorAddress;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final String goodsType;
  final double deliveryFee;
  final double riderDistanceKm;
  final double riderRatePerKm;
  final LatLng vendorLocation;
  final LatLng customerLocation;
  final List<RiderPickupStop> pickupStops;
  final RiderOrderStatus status;

  const RiderOrder({
    required this.id,
    required this.orderCode,
    required this.vendorName,
    required this.vendorAddress,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.goodsType,
    required this.deliveryFee,
    this.riderDistanceKm = 0,
    this.riderRatePerKm = 0,
    required this.vendorLocation,
    required this.customerLocation,
    this.pickupStops = const [],
    required this.status,
  });

  factory RiderOrder.fromBackend(dynamic source) {
    final json = asMap(source);
    final shipments = asList(json['shipments']);
    final firstShipment = shipments.isNotEmpty ? asMap(shipments.first) : json;
    final vendor = asMap(firstShipment['vendor']);
    final user = asMap(json['user']);
    final shippingAddress = json['shippingAddress'];
    final shipmentVendorLocation = asMap(firstShipment['vendorLocation']);
    final serializedPickupStops = asList(json['pickupSequence']);
    final pickupStops = serializedPickupStops.isNotEmpty
        ? serializedPickupStops
              .asMap()
              .entries
              .map((entry) => RiderPickupStop.fromBackend(
                    entry.value,
                    fallbackSequence: entry.key + 1,
                  ))
              .toList()
        : shipments
              .where((item) {
                final shipment = asMap(item);
                final status = asString(shipment['shipmentStatus']).toLowerCase();
                return asString(shipment['fulfillmentMethod'], 'delivery').toLowerCase() != 'pickup' &&
                    !{'rejected', 'cancelled', 'returned'}.contains(status);
              })
              .toList()
              .asMap()
              .entries
              .map((entry) => RiderPickupStop.fromBackend(
                    {
                      ...asMap(entry.value),
                      'sellerName': asMap(entry.value)['sellerName'] ??
                          asMap(asMap(entry.value)['vendor'])['businessName'],
                      'sequence': entry.key + 1,
                    },
                    fallbackSequence: entry.key + 1,
                  ))
              .toList();
    final firstPickupStop = pickupStops.isNotEmpty ? pickupStops.first : null;
    final vendorLocation = firstPickupStop?.location ??
        _locationFromVendor(vendor, shipmentVendorLocation);
    final customerLocation = _locationFromOrder(json);
    final payoutBreakdown = asMap(json['riderPayoutBreakdown']);

    return RiderOrder(
      id: asString(json['_id'] ?? json['id']),
      orderCode:
          '#NGO-${asString(json['_id'] ?? json['id']).substring(0, asString(json['_id'] ?? json['id']).length < 6 ? asString(json['_id'] ?? json['id']).length : 6).toUpperCase()}',
      vendorName: firstPickupStop?.sellerName ?? asString(
        vendor['businessName'] ?? vendor['storeName'] ?? vendor['fullName'],
        'Vendor',
      ),
      vendorAddress: firstPickupStop?.address ??
          _addressFromVendor(vendor, shipmentVendorLocation),
      customerName:
          [
            asString(user['firstName']),
            asString(user['lastName']),
          ].where((part) => part.isNotEmpty).join(' ').trim().isEmpty
          ? 'Customer'
          : [
              asString(user['firstName']),
              asString(user['lastName']),
            ].where((part) => part.isNotEmpty).join(' '),
      customerPhone: asString(user['phoneNumber'], 'Not provided'),
      customerAddress: _addressText(shippingAddress),
      goodsType: shipments.length <= 1
          ? 'Delivery package'
          : '${shipments.length} shipments',
      deliveryFee: asDouble(
        json['riderPayoutAmount'] ??
            json['estimatedEarnings'] ??
            payoutBreakdown['amount'] ??
            json['totalShippingPrice'] ??
            firstShipment['shippingPrice'],
      ),
      riderDistanceKm: asDouble(
        json['riderDistanceKm'] ?? payoutBreakdown['totalDistanceKm'],
      ),
      riderRatePerKm: asDouble(
        json['riderRatePerKm'] ?? payoutBreakdown['ratePerKm'],
      ),
      vendorLocation: vendorLocation,
      customerLocation: customerLocation,
      pickupStops: pickupStops,
      status: _statusFromBackend(
        asString(json['shipmentStatus'] ?? json['mainOrderStatus']),
      ),
    );
  }

  RiderOrder copyWith({
    String? id,
    String? orderCode,
    String? vendorName,
    String? vendorAddress,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    String? goodsType,
    double? deliveryFee,
    double? riderDistanceKm,
    double? riderRatePerKm,
    LatLng? vendorLocation,
    LatLng? customerLocation,
    List<RiderPickupStop>? pickupStops,
    RiderOrderStatus? status,
  }) {
    return RiderOrder(
      id: id ?? this.id,
      orderCode: orderCode ?? this.orderCode,
      vendorName: vendorName ?? this.vendorName,
      vendorAddress: vendorAddress ?? this.vendorAddress,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      goodsType: goodsType ?? this.goodsType,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      riderDistanceKm: riderDistanceKm ?? this.riderDistanceKm,
      riderRatePerKm: riderRatePerKm ?? this.riderRatePerKm,
      vendorLocation: vendorLocation ?? this.vendorLocation,
      customerLocation: customerLocation ?? this.customerLocation,
      pickupStops: pickupStops ?? this.pickupStops,
      status: status ?? this.status,
    );
  }

  static RiderOrderStatus _statusFromBackend(String status) {
    switch (status) {
      case 'out_for_delivery':
        return RiderOrderStatus.accepted;
      case 'delivered':
      case 'completed':
        return RiderOrderStatus.delivered;
      case 'cancelled':
        return RiderOrderStatus.cancelled;
      default:
        return RiderOrderStatus.assigned;
    }
  }

  static LatLng _locationFromVendor(
    Map<String, dynamic> vendor,
    Map<String, dynamic> shipmentLocation,
  ) {
    final location = shipmentLocation.isNotEmpty
        ? shipmentLocation
        : asMap(vendor['businessLocation']);
    return LatLng(
      asDouble(location['latitude'] ?? location['lat']),
      asDouble(location['longitude'] ?? location['lng']),
    );
  }

  static LatLng _locationFromOrder(Map<String, dynamic> order) {
    final location = asMap(order['userLocation'] ?? order['deliveryLocation']);
    return LatLng(
      asDouble(location['latitude'] ?? location['lat']),
      asDouble(location['longitude'] ?? location['lng']),
    );
  }

  static String _addressFromVendor(
    Map<String, dynamic> vendor,
    Map<String, dynamic> shipmentLocation,
  ) {
    final location = shipmentLocation.isNotEmpty
        ? shipmentLocation
        : asMap(vendor['businessLocation']);
    return asString(
      location['formattedAddress'] ??
          location['address'] ??
          vendor['businessAddress'] ??
          vendor['address'],
      'Vendor address unavailable',
    );
  }

  static String _addressText(dynamic value) {
    if (value is String && value.isNotEmpty) return value;
    final address = asMap(value);
    final parts = [
      address['street'],
      address['address'],
      address['city'],
      address['state'],
    ].map((item) => asString(item)).where((item) => item.isNotEmpty);
    final text = parts.join(', ');
    return text.isEmpty ? 'Customer address unavailable' : text;
  }
}
