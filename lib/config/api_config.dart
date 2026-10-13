class ApiConfig {
  /// Base URL of your Backend API server (Protected against string extraction via --dart-define)
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://api.quicke.app',
  );

  /// Your API Secret Key or Bearer Token header (if needed)
  static String apiKey = '';

  /// API Endpoints
  static String loginEndpoint = '/users/login';
  static String registerEndpoint = '/users/register';
  static String categoriesEndpoint = '/categories';
  static String subcategoriesEndpoint = '/subcategories';
  static String productsEndpoint = '/products';
  static String uploadImageEndpoint = '/upload/image';
  static String uploadImagesEndpoint = '/upload/images';
  static String ordersEndpoint = '/orders';
  static String ordersStatsEndpoint = '/orders/stats';
}
