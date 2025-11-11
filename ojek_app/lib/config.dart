class AppConfig {
  static const String apiBaseUrl = 'http://localhost:8000/api';
  static const String pusherKey = '5ca9539b79ed4451bb0c';
  static const String pusherCluster = 'ap1';

  static const int baseFare = 3000; // biaya dasar
  static const int perKmRate = 2000; // biaya per km

  // Nearby drivers defaults
  static const double nearbyRadiusKm = 1.0;
  static const int nearbyLimit = 20;
  // Auto refresh interval (seconds) for customers map on driver dashboard
  static const int nearbyCustomersRefreshSec = 30;
}
