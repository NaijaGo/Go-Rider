class ApiPaths {
  static const login = '/riders/login';
  static const register = '/riders/register';
  static const forgotPassword = '/riders/forgot-password';
  static const uploadRiderBundlePublic = '/uploads/rider-bundle-public';

  static const profile = '/riders/profile';
  static const riderStatus = '/riders/status';
  static const riderLocation = '/riders/location';
  static const bankAccount = '/riders/bank-account';

  static const availableOrders = '/riders/orders/available';
  static const activeOrders = '/riders/orders/active';
  static const completedOrders = '/riders/orders/completed';
  static String claimOrder(String id) => '/riders/orders/claim/$id';
  static String rejectOrder(String id) => '/riders/orders/reject/$id';
  static const verifyPickup = '/riders/orders/verify-pickup';
  static const verifyDelivery = '/riders/orders/verify-delivery';
  static const cancelOrder = '/riders/orders/cancel';

  static const earnings = '/riders/earnings';
  static const dashboard = '/riders/dashboard';
  static const withdraw = '/riders/withdraw';
  static const notifications = '/riders/notifications';
  static String markNotificationRead(String id) =>
      '/riders/notifications/mark-read/$id';
  static const markAllNotificationsRead = '/riders/notifications/mark-read';

  static const mapboxConfig = '/mapbox/config';
  static const mapboxDirections = '/mapbox/directions';
}
