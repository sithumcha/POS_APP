class ApiConfig {
  /// Base URL of your Backend API server
  static String baseUrl = 'https://api.quicke.app';

  /// Your API Secret Key or Bearer Token header (if needed)
  static String apiKey = '';

  /// API Endpoints
  static String loginEndpoint = '/users/login';
  static String registerEndpoint = '/users/register';
  static String categoriesEndpoint = '/categories';
  static String subcategoriesEndpoint = '/subcategories';
  static String productsEndpoint = '/products';

  /// Set to [false] to disable dummy data and connect to live backend API.
  static bool useMockApi = false;
}
