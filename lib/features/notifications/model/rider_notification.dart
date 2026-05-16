enum RiderNotificationType {
  newOrder,
  orderCancelled,
  paymentUpdate,
  adminMessage,
}

class RiderNotification {
  final String id;
  final RiderNotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;

  const RiderNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });

  factory RiderNotification.fromJson(Map<String, dynamic> json) {
    final rawMessage = json['message']?.toString() ?? 'You have an update.';
    final splitIndex = rawMessage.indexOf(':');
    final title = splitIndex > 0 && splitIndex < 80
        ? rawMessage.substring(0, splitIndex).trim()
        : _titleForType(json['type']?.toString());
    final message = splitIndex > 0 && splitIndex < rawMessage.length - 1
        ? rawMessage.substring(splitIndex + 1).trim()
        : rawMessage;

    return RiderNotification(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      type: _typeFromString(json['type']?.toString()),
      title: title.isEmpty ? 'NaijaGo update' : title,
      message: message,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      isRead: json['read'] == true,
    );
  }

  RiderNotification copyWith({
    String? id,
    RiderNotificationType? type,
    String? title,
    String? message,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return RiderNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  static RiderNotificationType _typeFromString(String? value) {
    switch (value) {
      case 'new_order':
      case 'order_update':
      case 'delivery_offer':
      case 'order_assigned':
      case 'rider_order_assigned':
        return RiderNotificationType.newOrder;
      case 'order_cancelled':
      case 'cancelled':
        return RiderNotificationType.orderCancelled;
      case 'payment_received':
      case 'wallet_deposit':
      case 'wallet_withdrawal':
      case 'delivery_payout':
        return RiderNotificationType.paymentUpdate;
      case 'admin_message':
      case 'general':
      default:
        return RiderNotificationType.adminMessage;
    }
  }

  static String _titleForType(String? value) {
    switch (value) {
      case 'new_order':
      case 'order_update':
      case 'delivery_offer':
      case 'order_assigned':
      case 'rider_order_assigned':
        return 'New delivery request';
      case 'order_cancelled':
      case 'cancelled':
        return 'Order cancelled';
      case 'payment_received':
      case 'wallet_deposit':
      case 'wallet_withdrawal':
      case 'delivery_payout':
        return 'Payment update';
      default:
        return 'Admin message';
    }
  }
}
